import Foundation
import ComposableArchitecture

struct MusicBrainzClient {
    var fetchTracks: @Sendable (String, String) async -> [Track]
}
extension MusicBrainzClient: DependencyKey {
    static let liveValue = MusicBrainzClient { artist, album in
        let q = "release:\"\(album)\" AND artist:\"\(artist)\""
        guard let enc = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://musicbrainz.org/ws/2/release?query=\(enc)&limit=5&fmt=json")
        else { return [] }
        do {
            var req = URLRequest(url: url)
            req.setValue("VinCo/1.0 iOS", forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: req)
            let resp = try JSONDecoder().decode(MBSearch.self, from: data)
            guard let rid = resp.releases.first?.id else { return [] }
            return await recordings(rid)
        } catch { return [] }
    }
}
private func recordings(_ id: String) async -> [Track] {
    guard let url = URL(string: "https://musicbrainz.org/ws/2/release/\(id)?inc=recordings&fmt=json")
    else { return [] }
    do {
        var req = URLRequest(url: url); req.setValue("VinCo/1.0 iOS", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: req)
        let rel = try JSONDecoder().decode(MBRelease.self, from: data)
        return (rel.media ?? []).flatMap { m in (m.tracks ?? []).map {
            Track(name: $0.title ?? "", number: $0.number.flatMap(Int.init) ?? 0,
                  duration: ($0.length ?? 0)/1000, preview: "") } }
    } catch { return [] }
}
private struct MBSearch:  Decodable { let releases: [MBRef] }
private struct MBRef:     Decodable { let id: String }
private struct MBRelease: Decodable { let media: [MBMedium]? }
private struct MBMedium:  Decodable { let tracks: [MBTrack]? }
private struct MBTrack:   Decodable { let title: String?; let number: String?; let length: Int? }
extension DependencyValues {
    var musicBrainz: MusicBrainzClient {
        get { self[MusicBrainzClient.self] }
        set { self[MusicBrainzClient.self] = newValue }
    }
}
