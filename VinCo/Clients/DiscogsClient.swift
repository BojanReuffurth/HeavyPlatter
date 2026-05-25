import Foundation
import ComposableArchitecture

struct DiscogsResult: Equatable, Identifiable {
    let id: Int; let title: String; let subtitle: String
    let year: String; let label: String; let country: String; let format: String
    let genre: String; let thumbURL: String
}

struct DiscogsClient {
    var search:     @Sendable (String, String) async -> [DiscogsResult]
    var fetchPrice: @Sendable (Int, String) async -> Double?
}

extension DiscogsClient: DependencyKey {
    static let liveValue = DiscogsClient(
        search: { query, token in
            guard let q = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: "https://api.discogs.com/database/search?q=\(q)&type=release&per_page=15")
            else { return [] }
            var req = URLRequest(url: url)
            req.setValue("VinCo/1.0 iOS", forHTTPHeaderField: "User-Agent")
            if !token.isEmpty { req.setValue("Discogs token=\(token)", forHTTPHeaderField: "Authorization") }
            do {
                let (data, _) = try await URLSession.shared.data(for: req)
                let resp = try JSONDecoder().decode(DResp.self, from: data)
                return resp.results.prefix(15).map { r in
                    let yr = r.year ?? ""
                    let lb = r.label?.first ?? ""
                    let co = r.country ?? ""
                    let fm = r.format?.first ?? ""
                    let gn = r.genre?.first ?? ""
                    let th = r.thumb ?? ""
                    return DiscogsResult(id: r.id, title: r.title,
                        subtitle: [yr, lb, co].filter { !$0.isEmpty }.joined(separator: " · "),
                        year: yr, label: lb, country: co, format: fm, genre: gn, thumbURL: th)
                }
            } catch { return [] }
        },
        fetchPrice: { releaseId, token in
            guard releaseId > 0,
                  let url = URL(string: "https://api.discogs.com/releases/\(releaseId)")
            else { return nil }
            var req = URLRequest(url: url)
            req.setValue("VinCo/1.0 iOS", forHTTPHeaderField: "User-Agent")
            if !token.isEmpty { req.setValue("Discogs token=\(token)", forHTTPHeaderField: "Authorization") }
            do {
                let (data, _) = try await URLSession.shared.data(for: req)
                let resp = try JSONDecoder().decode(ReleaseResp.self, from: data)
                return resp.lowest_price
            } catch { return nil }
        }
    )
}

private nonisolated struct DResp:       Decodable { let results: [DRelease] }
private nonisolated struct DRelease:    Decodable {
    let id: Int; let title: String; let year: String?
    let label: [String]?; let country: String?; let format: [String]?
    let genre: [String]?; let thumb: String?
}
private nonisolated struct ReleaseResp: Decodable { let lowest_price: Double? }

extension DependencyValues {
    var discogs: DiscogsClient {
        get { self[DiscogsClient.self] }
        set { self[DiscogsClient.self] = newValue }
    }
}
