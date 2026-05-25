import Foundation

struct Track: Codable, Identifiable {
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

// Explicit nonisolated conformances so they can be used from Sendable/nonisolated
// contexts (e.g. ForEach($store.tracks) under SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor).
extension Track: Equatable {
    nonisolated static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.number == rhs.number &&
        lhs.duration == rhs.duration &&
        lhs.preview == rhs.preview
    }
}

extension Track: Hashable {
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
