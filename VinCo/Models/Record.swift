import Foundation
import SwiftData

/// Concise rename of VinylRecord. Tracks stored as JSON string for SwiftData iOS 17 compatibility.
@Model
final class Record {
    var id:           UUID   = UUID()
    var artist:       String = ""
    var album:        String = ""
    var year:         String = ""
    var genre:        String = ""
    var label:        String = ""
    var format:       String = ""
    var country:      String = ""
    var notes:        String = ""
    var condition:    String = "VG"
    var colorHex:     String = "#E8A87C"
    var coverData:    Data?  = nil
    var coverURL:     String = ""
    var isWishlist:   Bool   = false
    var dateAdded:    Date   = Date()
    var tracksJSON:   String = "[]"
    var paidPrice:    Double? = nil
    var currentValue: Double? = nil
    var itunesId:     Int?  = nil
    var discogsId:    Int?  = nil
    var rpm:          String = ""

    init(artist: String = "", album: String = "", year: String = "",
         genre: String = "", label: String = "", format: String = "",
         country: String = "", notes: String = "", condition: String = "VG",
         isWishlist: Bool = false) {
        self.id        = UUID()
        self.artist    = artist;  self.album   = album;  self.year    = year
        self.genre     = genre;   self.label   = label;  self.format  = format
        self.country   = country; self.notes   = notes;  self.condition = condition
        self.colorHex  = Record.randomColor()
        self.isWishlist = isWishlist
        self.dateAdded  = Date()
    }

    static func randomColor() -> String {
        ["#E8A87C","#7CB8E8","#A87CE8","#7CE8A8","#E87C9A",
         "#E8D87C","#E87C7C","#5ECFCF","#6674E8","#FFB085",
         "#A8E87C","#C9B0F0","#E84444","#44C8B4","#F0C844","#B0BCC8"].randomElement()!
    }

    var tracks: [Track] {
        get { (try? JSONDecoder().decode([Track].self, from: Data(tracksJSON.utf8))) ?? [] }
        set { tracksJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "[]" }
    }
}
