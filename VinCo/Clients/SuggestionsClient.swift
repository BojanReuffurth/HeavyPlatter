import Foundation
import MediaPlayer
import ComposableArchitecture

// MARK: – Provider enum

nonisolated enum MusicProvider: String, CaseIterable, Equatable, Hashable, Codable, Sendable {
    case collectionDNA = "collection"
    case appleMusic    = "appleMusic"

    var displayName: String {
        switch self {
        case .collectionDNA: return "Collection DNA"
        case .appleMusic:    return "Apple Music"
        }
    }

    var icon: String {
        switch self {
        case .collectionDNA: return "square.stack.3d.up"
        case .appleMusic:    return "music.note"
        }
    }
}

// MARK: – Suggested record value type

nonisolated struct SuggestedRecord: Equatable, Identifiable, Sendable {
    var id: String { "\(artist.lowercased())|\(album.lowercased())" }
    let artist:        String
    let album:         String
    let year:          String
    let genre:         String
    /// Discogs thumb (150 px) — used on grid cards.
    let coverURL:      String
    /// Discogs cover_image (600 px+) — used in the detail sheet.
    let coverImageURL: String
    let discogsId:     Int
    let provider:      MusicProvider
    let vinylFormat:   String
}

// MARK: – Learnable preferences

struct SuggestionPreferences: Codable, Equatable, Sendable {
    var likedArtists: [String]    = []
    var likedGenres:  [String]    = []
    /// "artist|album" keys that the user thumbed-down — never shown again.
    var dislikedIds:  Set<String> = []

    mutating func like(artist: String, genre: String) {
        if !artist.isEmpty, !likedArtists.contains(artist) {
            likedArtists.insert(artist, at: 0)
        }
        if !genre.isEmpty, !likedGenres.contains(genre) {
            likedGenres.insert(genre, at: 0)
        }
    }
}

// MARK: – Request

struct SuggestionRequest: Sendable {
    let genres:       [String]
    let artists:      [String]
    /// Owned records + disliked records — never returned.
    let excluded:     Set<String>
    let providers:    Set<MusicProvider>
    let seed:         Int
    let discogsToken: String
    /// Liked artists (boost them first in searches).
    let likedArtists: [String]
    /// Liked genres (boost them first in searches).
    let likedGenres:  [String]
}

// MARK: – Discogs release detail (for the suggestion detail sheet)

struct DiscogsTrack: Sendable, Identifiable {
    var id: String { "\(position)|\(title)" }
    let position: String
    let title:    String
    let duration: String
}

struct DiscogsReleaseDetail: Sendable {
    let tracklist:     [DiscogsTrack]
    let labels:        [String]       // "Label (CAT-001)"
    let country:       String
    let communityHave: Int
    let communityWant: Int
    let lowestPrice:   Double?
    let numForSale:    Int
    let coverImageURL: String         // primary image from Discogs release
    let styles:        [String]
    let rating:        Double?
    let ratingCount:   Int
}

/// Fetch the full release detail from Discogs.
/// Called from SuggestionDetailSheet when it appears.
func fetchDiscogsRelease(id: Int, token: String) async -> DiscogsReleaseDetail? {
    guard id > 0, let url = URL(string: "https://api.discogs.com/releases/\(id)") else { return nil }
    var req = URLRequest(url: url)
    req.setValue("VinCo/1.0 iOS", forHTTPHeaderField: "User-Agent")
    if !token.isEmpty { req.setValue("Discogs token=\(token)", forHTTPHeaderField: "Authorization") }
    do {
        let (data, _) = try await URLSession.shared.data(for: req)
        let resp = try JSONDecoder().decode(DReleaseResp.self, from: data)
        let tracks = resp.tracklist
            .filter { ($0.type_ ?? "track") != "heading" }
            .map { DiscogsTrack(position: $0.position ?? "", title: $0.title, duration: $0.duration ?? "") }
        let labels = (resp.labels ?? []).map { l -> String in
            guard let catno = l.catno, !catno.isEmpty, catno.lowercased() != "none" else { return l.name }
            return "\(l.name) (\(catno))"
        }
        let coverURL = resp.images?.first(where: { $0.type_ == "primary" })?.uri
            ?? resp.images?.first?.uri ?? ""
        return DiscogsReleaseDetail(
            tracklist: tracks, labels: labels,
            country: resp.country ?? "",
            communityHave: resp.community?.have ?? 0,
            communityWant: resp.community?.want ?? 0,
            lowestPrice: resp.lowest_price,
            numForSale: resp.num_for_sale ?? 0,
            coverImageURL: coverURL,
            styles: resp.styles ?? [],
            rating: resp.community?.rating?.average,
            ratingCount: resp.community?.rating?.count ?? 0
        )
    } catch { return nil }
}

private nonisolated struct DReleaseResp: Decodable {
    let tracklist: [DTrack]; let labels: [DLabel]?; let country: String?
    let community: DCommunity?; let lowest_price: Double?; let num_for_sale: Int?
    let images: [DImage]?; let styles: [String]?
}
private nonisolated struct DTrack: Decodable {
    let position: String?; let title: String; let duration: String?; let type_: String?
}
private nonisolated struct DLabel: Decodable { let name: String; let catno: String? }
private nonisolated struct DCommunity: Decodable { let have: Int?; let want: Int?; let rating: DRating? }
private nonisolated struct DRating: Decodable { let count: Int?; let average: Double? }
private nonisolated struct DImage: Decodable {
    let type_: String?; let uri: String?
    enum CodingKeys: String, CodingKey { case type_ = "type"; case uri }
}

// MARK: – Client

struct SuggestionsClient {
    var suggest: @Sendable (SuggestionRequest) async -> [SuggestedRecord]
}

extension SuggestionsClient: DependencyKey {
    static let liveValue = SuggestionsClient { req in
        var all: [SuggestedRecord] = []

        await withTaskGroup(of: [SuggestedRecord].self) { group in
            if req.providers.contains(.collectionDNA) {
                group.addTask { await fetchCollectionDNA(req) }
            }
            if req.providers.contains(.appleMusic) {
                group.addTask { await fetchAppleMusic(req) }
            }
            for await batch in group { all.append(contentsOf: batch) }
        }

        var seen = Set<String>()
        var unique: [SuggestedRecord] = []
        for r in all {
            guard !seen.contains(r.id), !req.excluded.contains(r.id),
                  !r.artist.isEmpty, !r.album.isEmpty else { continue }
            seen.insert(r.id)
            unique.append(r)
        }
        var rng = SeededRNG(seed: UInt64(bitPattern: Int64(req.seed &* 6364136223846793005 &+ 1)))
        unique.shuffle(using: &rng)
        return Array(unique.prefix(20))
    }
}

extension DependencyValues {
    var suggestions: SuggestionsClient {
        get { self[SuggestionsClient.self] }
        set { self[SuggestionsClient.self] = newValue }
    }
}

// MARK: – Seeded RNG

nonisolated struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    nonisolated init(seed: UInt64) { state = seed == 0 ? 0xDEADBEEF : seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// MARK: – Collection DNA

private func fetchCollectionDNA(_ req: SuggestionRequest) async -> [SuggestedRecord] {
    let fallbackGenres = ["Rock", "Jazz", "Electronic", "Soul", "Blues", "Folk"]
    let baseGenres  = req.genres.isEmpty ? fallbackGenres : req.genres
    let baseArtists = req.artists

    // Boost liked genres/artists by putting them first
    let genres  = (req.likedGenres  + baseGenres).uniqued().rotated(by: req.seed)
    let artists = (req.likedArtists + baseArtists).uniqued().rotated(by: req.seed)

    var results: [SuggestedRecord] = []
    let page = (req.seed % 5) + 1

    for genre in genres.prefix(3) {
        let items = await discogsVinylSearch(param: "genre", value: genre, page: page, token: req.discogsToken)
        results += items.map { SuggestedRecord(artist: $0.artist, album: $0.album, year: $0.year,
            genre: genre, coverURL: $0.thumbURL, coverImageURL: $0.coverImageURL,
            discogsId: $0.id, provider: .collectionDNA, vinylFormat: $0.format) }
        try? await Task.sleep(nanoseconds: 80_000_000)
        if results.count >= 8 { break }
    }

    for artist in artists.prefix(2) {
        let items = await discogsVinylSearch(param: "artist", value: artist, page: page + 1, token: req.discogsToken)
        results += items.prefix(3).map { SuggestedRecord(artist: $0.artist, album: $0.album, year: $0.year,
            genre: $0.genre, coverURL: $0.thumbURL, coverImageURL: $0.coverImageURL,
            discogsId: $0.id, provider: .collectionDNA, vinylFormat: $0.format) }
        try? await Task.sleep(nanoseconds: 80_000_000)
    }

    return results
}

// MARK: – Apple Music

private func fetchAppleMusic(_ req: SuggestionRequest) async -> [SuggestedRecord] {
    guard MPMediaLibrary.authorizationStatus() == .authorized else { return [] }

    let (libraryArtists, libraryGenres): ([String], [String]) = await Task.detached(priority: .userInitiated) {
        let artists = (MPMediaQuery.artists().collections ?? [])
            .compactMap { $0.representativeItem?.artist }.filter { !$0.isEmpty }
        let genres  = (MPMediaQuery.genres().collections ?? [])
            .compactMap { $0.representativeItem?.genre }.filter { !$0.isEmpty }
        return (artists, genres)
    }.value

    var results: [SuggestedRecord] = []
    let page = max(1, (req.seed % 4) + 1)

    // Prefer artists not already in vinyl collection
    let newArtists = libraryArtists
        .filter { a in !req.artists.contains(where: { $0.lowercased() == a.lowercased() }) }
        .rotated(by: req.seed)

    for artist in newArtists.prefix(2) {
        let items = await discogsVinylSearch(param: "artist", value: artist, page: page, token: req.discogsToken)
        results += items.prefix(3).map { SuggestedRecord(artist: $0.artist, album: $0.album, year: $0.year,
            genre: $0.genre, coverURL: $0.thumbURL, coverImageURL: $0.coverImageURL,
            discogsId: $0.id, provider: .appleMusic, vinylFormat: $0.format) }
        try? await Task.sleep(nanoseconds: 80_000_000)
    }

    // Prefer genres not already prominent in vinyl collection
    let newGenres = libraryGenres
        .filter { g in !req.genres.contains(where: { $0.lowercased() == g.lowercased() }) }
        .rotated(by: req.seed)

    for genre in newGenres.prefix(2) {
        let items = await discogsVinylSearch(param: "genre", value: genre, page: page, token: req.discogsToken)
        results += items.prefix(2).map { SuggestedRecord(artist: $0.artist, album: $0.album, year: $0.year,
            genre: genre, coverURL: $0.thumbURL, coverImageURL: $0.coverImageURL,
            discogsId: $0.id, provider: .appleMusic, vinylFormat: $0.format) }
        try? await Task.sleep(nanoseconds: 80_000_000)
    }

    // Fallback: if nothing found via "new" content, use any library genres
    // (the excluded set already prevents showing owned albums)
    if results.isEmpty {
        let fallbackGenres = libraryGenres.rotated(by: req.seed + 2)
        for genre in fallbackGenres.prefix(3) {
            let items = await discogsVinylSearch(param: "genre", value: genre,
                                                 page: page + 2, token: req.discogsToken)
            results += items.prefix(3).map { SuggestedRecord(artist: $0.artist, album: $0.album, year: $0.year,
                genre: genre, coverURL: $0.thumbURL, coverImageURL: $0.coverImageURL,
                discogsId: $0.id, provider: .appleMusic, vinylFormat: $0.format) }
            try? await Task.sleep(nanoseconds: 80_000_000)
            if results.count >= 6 { break }
        }
        // Final fallback: use library artists even if they overlap with collection
        if results.isEmpty {
            for artist in libraryArtists.rotated(by: req.seed).prefix(2) {
                let items = await discogsVinylSearch(param: "artist", value: artist,
                                                     page: page + 3, token: req.discogsToken)
                results += items.prefix(3).map { SuggestedRecord(artist: $0.artist, album: $0.album, year: $0.year,
                    genre: $0.genre, coverURL: $0.thumbURL, coverImageURL: $0.coverImageURL,
                    discogsId: $0.id, provider: .appleMusic, vinylFormat: $0.format) }
                try? await Task.sleep(nanoseconds: 80_000_000)
            }
        }
    }

    return results
}

// MARK: – Discogs vinyl search

private struct DiscogsVinylItem: Sendable {
    let id: Int; let artist: String; let album: String
    let year: String; let genre: String
    let thumbURL: String        // small (150 px)
    let coverImageURL: String   // large (600 px+)
    let format: String
}

private func discogsVinylSearch(param: String, value: String, page: Int, token: String) async -> [DiscogsVinylItem] {
    guard !value.isEmpty,
          let enc = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
    else { return [] }

    let urlStr = "https://api.discogs.com/database/search?\(param)=\(enc)&type=release&format=Vinyl&per_page=8&page=\(page)"
    guard let url = URL(string: urlStr) else { return [] }

    var req = URLRequest(url: url)
    req.setValue("VinCo/1.0 iOS", forHTTPHeaderField: "User-Agent")
    if !token.isEmpty { req.setValue("Discogs token=\(token)", forHTTPHeaderField: "Authorization") }

    do {
        let (data, _) = try await URLSession.shared.data(for: req)
        let resp = try JSONDecoder().decode(DVSearchResp.self, from: data)
        return resp.results.compactMap { r -> DiscogsVinylItem? in
            let parts  = r.title.components(separatedBy: " - ")
            let artist = parts.first?.trimmingCharacters(in: .whitespaces) ?? ""
            let album  = parts.dropFirst().joined(separator: " - ").trimmingCharacters(in: .whitespaces)
            guard !artist.isEmpty, !album.isEmpty else { return nil }
            let fmts = r.format ?? []
            let vinylFmt = fmts.first(where: { ["LP","7\"","12\"","10\"","EP","Single","Album"].contains($0) }) ?? "Vinyl"
            // Handle empty-string thumb/cover_image (Discogs returns "" not null for missing images)
            let thumb    = r.thumb?.isEmpty    == false ? r.thumb!    : ""
            let coverImg = r.cover_image?.isEmpty == false ? r.cover_image! : thumb
            return DiscogsVinylItem(
                id: r.id, artist: artist, album: album,
                year: r.year ?? "", genre: r.genre?.first ?? "",
                thumbURL: thumb,
                coverImageURL: coverImg,
                format: vinylFmt)
        }
    } catch { return [] }
}

private nonisolated struct DVSearchResp:  Decodable { let results: [DVReleaseItem] }
private nonisolated struct DVReleaseItem: Decodable {
    let id: Int; let title: String; let year: String?
    let genre: [String]?; let format: [String]?
    let thumb: String?; let cover_image: String?
}

// MARK: – Array helpers

private extension Array {
    func rotated(by offset: Int) -> [Element] {
        guard count > 1 else { return self }
        let n = ((offset % count) + count) % count
        return Array(self[n...] + self[..<n])
    }
}

private extension Array where Element: Equatable {
    func uniqued() -> [Element] {
        var seen: [Element] = []
        for el in self where !seen.contains(el) { seen.append(el) }
        return seen
    }
}
