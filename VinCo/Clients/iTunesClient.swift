import Foundation
import ComposableArchitecture

nonisolated struct iTunesFetch: Equatable {
    var coverURL: String?
    var itunesId: Int?
    var tracks:   [Track] = []
}

struct iTunesClient {
    var fetch: @Sendable (String, String) async -> iTunesFetch
}

extension iTunesClient: DependencyKey {
    static let liveValue = iTunesClient { artist, album in
        var out = iTunesFetch()
        let q = "\(artist) \(album)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "https://itunes.apple.com/search?term=\(q)&entity=album&media=music&limit=10&country=us")
        else { return out }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let resp = try JSONDecoder().decode(SearchResp.self, from: data)
            guard let best = await bestMatch(resp.results, ar: artist.lowercased(), al: album.lowercased())
            else { return out }
            out.itunesId = best.collectionId
            if let art = best.artworkUrl100 {
                out.coverURL = art.replacingOccurrences(of: "100x100bb", with: "600x600bb")
            }
            if let id = best.collectionId { out.tracks = await fetchTracks(id) }
        } catch {}
        return out
    }
}

private func bestMatch(_ r: [Album], ar: String, al: String) -> Album? {
    r.max { score($0, ar: ar, al: al) < score($1, ar: ar, al: al) }
}
private func score(_ a: Album, ar: String, al: String) -> Int {
    var s = 0
    let rAl = (a.collectionName ?? "").lowercased()
    let rAr = (a.artistName ?? "").lowercased()
    if rAl.contains(al) || al.contains(rAl) { s += 3 }
    if rAr.contains(ar) || ar.contains(rAr) { s += 2 }
    if rAl == al { s += 5 }; if rAr == ar { s += 3 }
    return s
}
private func fetchTracks(_ id: Int) async -> [Track] {
    guard let url = URL(string: "https://itunes.apple.com/lookup?id=\(id)&entity=song&limit=60&country=us")
    else { return [] }
    do {
        let (data, _) = try await URLSession.shared.data(from: url)
        let resp = try JSONDecoder().decode(LookupResp.self, from: data)
        return resp.results.filter { $0.wrapperType == "track" }
            .sorted { ($0.discNumber ?? 1)*100+($0.trackNumber ?? 0) < ($1.discNumber ?? 1)*100+($1.trackNumber ?? 0) }
            .map { Track(name: $0.trackName ?? "", number: $0.trackNumber ?? 0,
                         duration: Int(($0.trackTimeMillis ?? 0)/1000), preview: $0.previewUrl ?? "") }
    } catch { return [] }
}

private nonisolated struct SearchResp:  Decodable { let results: [Album] }
private nonisolated struct Album:       Decodable { let collectionId: Int?; let collectionName: String?; let artistName: String?; let artworkUrl100: String? }
private nonisolated struct LookupResp:  Decodable { let results: [Item] }
private nonisolated struct Item:        Decodable { let wrapperType: String?; let trackName: String?; let trackNumber: Int?; let discNumber: Int?; let trackTimeMillis: Double?; let previewUrl: String? }

extension DependencyValues {
    var iTunes: iTunesClient {
        get { self[iTunesClient.self] }
        set { self[iTunesClient.self] = newValue }
    }
}
