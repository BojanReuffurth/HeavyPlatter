import Foundation
struct CSVExporter {
    static let cols = ["artist","album","year","genre","rpm","label","format",
                       "country","condition","notes","dateAdded","paidPrice","currentValue"]
    static func export(collection: [Record], wishlist: [Record]) -> String {
        let hdr = cols.joined(separator: ",")
        let df  = DateFormatter(); df.dateStyle = .short
        var csv = "COLLECTION\n\(hdr)\n" + collection.map { row($0, df) }.joined(separator: "\n")
        csv    += "\n\nWISHLIST\n\(hdr)\n"  + wishlist.map { row($0, df) }.joined(separator: "\n")
        return csv
    }
    static func saveToTemp(_ csv: String) -> URL? {
        let u = FileManager.default.temporaryDirectory
            .appendingPathComponent("VinCo_\(Int(Date().timeIntervalSince1970)).csv")
        return (try? csv.write(to: u, atomically: true, encoding: .utf8)) != nil ? u : nil
    }
    private static func row(_ r: Record, _ df: DateFormatter) -> String {
        [r.artist, r.album, r.year, r.genre, r.rpm, r.label, r.format, r.country,
         r.condition, r.notes, df.string(from: r.dateAdded),
         r.paidPrice.map    { String(format: "%.2f", $0) } ?? "",
         r.currentValue.map { String(format: "%.2f", $0) } ?? ""]
        .map { s -> String in
            let e = s.replacingOccurrences(of: "\"", with: "\"\"")
            return (s.contains(",") || s.contains("\n")) ? "\"\(e)\"" : e
        }.joined(separator: ",")
    }
}
