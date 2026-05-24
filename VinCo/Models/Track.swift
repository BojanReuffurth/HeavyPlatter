import Foundation

struct Track: Codable, Identifiable, Hashable, Equatable {
    var id:       UUID   = UUID()
    var name:     String
    var number:   Int
    var duration: Int       // seconds
    var preview:  String    // iTunes 30s URL, empty if none

    enum CodingKeys: String, CodingKey {
        case id; case name = "n"; case number = "tn"
        case duration = "d"; case preview = "p"
    }

    var durationStr: String {
        guard duration > 0 else { return "" }
        return String(format: "%d:%02d", duration / 60, duration % 60)
    }
    var hasPreview: Bool { !preview.isEmpty }
}
