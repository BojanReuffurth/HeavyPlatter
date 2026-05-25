import Foundation
import SwiftData
import SwiftUI

// MARK: – Codable envelope for a full backup
struct VinCoBackup: Codable {
    let version:   Int
    let exportDate: Date
    let records:   [RecordBackup]
}

struct RecordBackup: Codable {
    var id:           UUID
    var artist:       String
    var album:        String
    var year:         String
    var genre:        String
    var rpm:          String
    var label:        String
    var format:       String
    var country:      String
    var notes:        String
    var condition:    String
    var colorHex:     String
    var isWishlist:   Bool
    var dateAdded:    Date
    var paidPrice:    Double?
    var currentValue: Double?
    var itunesId:     Int?
    var discogsId:    Int?
    var tracksJSON:   String
    var coverBase64:  String?   // base-64 encoded cover image

    init(from record: Record) {
        id           = record.id
        artist       = record.artist
        album        = record.album
        year         = record.year
        genre        = record.genre
        rpm          = record.rpm
        label        = record.label
        format       = record.format
        country      = record.country
        notes        = record.notes
        condition    = record.condition
        colorHex     = record.colorHex
        isWishlist   = record.isWishlist
        dateAdded    = record.dateAdded
        paidPrice    = record.paidPrice
        currentValue = record.currentValue
        itunesId     = record.itunesId
        discogsId    = record.discogsId
        tracksJSON   = record.tracksJSON
        coverBase64  = record.coverData.map { $0.base64EncodedString() }
    }

    func apply(to record: Record) {
        record.artist       = artist
        record.album        = album
        record.year         = year
        record.genre        = genre
        record.rpm          = rpm
        record.label        = label
        record.format       = format
        record.country      = country
        record.notes        = notes
        record.condition    = condition
        record.colorHex     = colorHex
        record.isWishlist   = isWishlist
        record.dateAdded    = dateAdded
        record.paidPrice    = paidPrice
        record.currentValue = currentValue
        record.itunesId     = itunesId
        record.discogsId    = discogsId
        record.tracksJSON   = tracksJSON
        if let b64 = coverBase64 { record.coverData = Data(base64Encoded: b64) }
    }
}

// MARK: – Manager
struct BackupManager {

    // MARK: – Paths
    static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    static var autoBackupURL: URL {
        documentsURL.appendingPathComponent("VinCo_AutoBackup.json")
    }

    // MARK: – Export
    static func export(records: [Record]) throws -> Data {
        let backups = records.map { RecordBackup(from: $0) }
        let bundle  = VinCoBackup(version: 1, exportDate: Date(), records: backups)
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try enc.encode(bundle)
    }

    static func exportToTemp(records: [Record]) -> URL? {
        guard let data = try? export(records: records) else { return nil }
        let name = "VinCo_Backup_\(Int(Date().timeIntervalSince1970)).json"
        let url  = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? data.write(to: url)
        return url
    }

    // MARK: – Auto-backup (silently overwrites the fixed auto-backup file)
    static func writeAutoBackup(records: [Record]) {
        guard let data = try? export(records: records) else { return }
        try? data.write(to: autoBackupURL)
    }

    // MARK: – Import (merges by UUID — existing records updated, new ones inserted)
    /// Returns (updated, inserted, errorMsg)
    @MainActor
    static func importBackup(data: Data, context: ModelContext) -> (Int, Int, String?) {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        guard let bundle = try? dec.decode(VinCoBackup.self, from: data) else {
            // Try CSV fallback
            if let csv = String(data: data, encoding: .utf8) {
                return importCSV(csv, context: context)
            }
            return (0, 0, "Could not parse backup file.")
        }

        // Fetch all existing records
        let existing = (try? context.fetch(FetchDescriptor<Record>())) ?? []
        let byID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        var updated = 0, inserted = 0
        for b in bundle.records {
            if let rec = byID[b.id] {
                b.apply(to: rec); updated += 1
            } else {
                let rec = Record(isWishlist: b.isWishlist)
                rec.id = b.id
                context.insert(rec)
                b.apply(to: rec); inserted += 1
            }
        }
        return (updated, inserted, nil)
    }

    // MARK: – Smart CSV import
    @MainActor
    static func importCSV(_ csv: String, context: ModelContext) -> (Int, Int, String?) {
        var lines = csv.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Detect and skip section headers (COLLECTION / WISHLIST)
        var isWishlist = false
        var inserted   = 0

        // Build column map from first header row we find
        var colMap: [String: Int] = [:]
        var headerIdx = -1
        for (i, line) in lines.enumerated() {
            let lc = line.lowercased()
            if lc.hasPrefix("collection") || lc.hasPrefix("wishlist") { continue }
            let cols = parseCSVRow(line)
            // A header row has at least artist & album
            if cols.contains(where: { $0.lowercased() == "artist" }) &&
               cols.contains(where: { $0.lowercased() == "album" }) {
                for (j, col) in cols.enumerated() { colMap[col.lowercased()] = j }
                headerIdx = i
                break
            }
        }
        guard headerIdx >= 0 else { return (0, 0, "No valid header row found in CSV.") }

        func val(_ row: [String], _ key: String) -> String {
            guard let i = colMap[key], i < row.count else { return "" }
            return row[i].trimmingCharacters(in: .whitespaces)
        }

        let df = DateFormatter(); df.dateStyle = .short

        for i in (headerIdx + 1) ..< lines.count {
            let line = lines[i]
            if line.lowercased().hasPrefix("wishlist") { isWishlist = true; continue }
            if line.lowercased().hasPrefix("collection") { isWishlist = false; continue }
            let cols = parseCSVRow(line)
            guard !cols.isEmpty else { continue }
            let artist = val(cols, "artist"); let album = val(cols, "album")
            guard !artist.isEmpty || !album.isEmpty else { continue }
            let rec = Record(isWishlist: isWishlist)
            rec.artist       = artist
            rec.album        = album
            rec.year         = val(cols, "year")
            rec.genre        = val(cols, "genre")
            rec.rpm          = val(cols, "rpm")
            rec.label        = val(cols, "label")
            rec.format       = val(cols, "format")
            rec.country      = val(cols, "country")
            rec.condition    = val(cols, "condition").isEmpty ? "VG" : val(cols, "condition")
            rec.notes        = val(cols, "notes")
            rec.paidPrice    = Double(val(cols, "paidprice").replacingOccurrences(of: ",", with: "."))
            rec.currentValue = Double(val(cols, "currentvalue").replacingOccurrences(of: ",", with: "."))
            if let d = df.date(from: val(cols, "dateadded")) { rec.dateAdded = d }
            context.insert(rec)
            inserted += 1
        }
        return (0, inserted, nil)
    }

    // MARK: – RFC-4180 CSV parser (handles quoted fields with commas/newlines)
    static func parseCSVRow(_ line: String) -> [String] {
        var fields: [String] = []
        var cur = ""
        var inQuote = false
        var chars = line.makeIterator()
        while let c = chars.next() {
            if inQuote {
                if c == "\"" {
                    // Peek: doubled quote = escaped quote
                    cur.append(c); inQuote = false
                } else { cur.append(c) }
            } else {
                if c == "\"" { inQuote = true; cur = cur.isEmpty ? "" : cur }
                else if c == "," { fields.append(cur); cur = "" }
                else { cur.append(c) }
            }
        }
        fields.append(cur)
        return fields
    }
}
