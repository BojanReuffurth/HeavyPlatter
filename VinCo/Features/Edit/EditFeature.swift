import Foundation
import ComposableArchitecture
import SwiftData
import SwiftUI

@Reducer
struct EditFeature {
    @ObservableState
    struct State: Equatable {
        var record:     Record? = nil
        var isWishlist: Bool    = false

        var artist    = ""; var album     = ""; var year      = ""
        var genre     = ""; var rpm       = ""; var label     = ""
        var format    = ""; var country   = ""; var notes     = ""; var condition = "VG"
        var colorHex  = Record.randomColor()
        var coverData: Data? = nil
        var paidPrice = ""; var curValue = ""
        var discogsId: Int?  = nil

        // Discogs
        var query:     String          = ""
        var results:   [DiscogsResult] = []
        var searching: Bool            = false

        // Cover art
        var fetchingArt: Bool = false
        // Price fetch
        var fetchingPrice: Bool = false
        // Tracklist
        var tracks: [Track] = []
        var fetchingTracks: Bool = false

        var canSave:  Bool { !artist.trimmingCharacters(in: .whitespaces).isEmpty &&
                             !album.trimmingCharacters(in: .whitespaces).isEmpty }
        var isEditing: Bool { record != nil }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case appeared
        case queryChanged(String)
        case searchTapped
        case resultsReceived([DiscogsResult])
        case resultPicked(DiscogsResult)
        case fetchArtTapped
        case artReceived(Data?)
        case priceReceived(Double)
        case fetchTracksTapped
        case tracksReceived([Track])
        case addEmptyTrack
        case deleteTrack(IndexSet)
        case saveTapped
        case cancelTapped
    }

    @Dependency(\.iTunes)  var iTunes
    @Dependency(\.discogs) var discogs

    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .appeared:
                guard let r = state.record else { return .none }
                state.artist    = r.artist;  state.album   = r.album;   state.year      = r.year
                state.genre     = r.genre;   state.rpm     = r.rpm;     state.label     = r.label
                state.format    = r.format;  state.country = r.country; state.notes     = r.notes
                state.condition = r.condition; state.colorHex = r.colorHex; state.coverData = r.coverData
                state.discogsId = r.discogsId; state.tracks = r.tracks
                if let p = r.paidPrice    { state.paidPrice = String(format: "%.2f", p) }
                if let v = r.currentValue { state.curValue  = String(format: "%.2f", v) }
                return .none

            case .queryChanged(let q): state.query = q; return .none

            case .searchTapped:
                let q = state.query.trimmingCharacters(in: .whitespaces)
                guard !q.isEmpty else { return .none }
                state.searching = true; state.results = []
                return .run { [q] send in
                    let token = UserDefaults.standard.string(forKey: "rb_discogs") ?? ""
                    let r = await discogs.search(q, token)
                    await send(.resultsReceived(r))
                }

            case .resultsReceived(let r):
                state.results = r; state.searching = false; return .none

            case .resultPicked(let r):
                let parts = r.title.components(separatedBy: " - ")
                state.artist  = parts.first?.trimmingCharacters(in: .whitespaces) ?? ""
                state.album   = parts.dropFirst().joined(separator: " - ").trimmingCharacters(in: .whitespaces)
                if state.album.isEmpty { state.album = r.title }
                if !r.year.isEmpty    { state.year    = r.year    }
                if !r.label.isEmpty   { state.label   = r.label   }
                if !r.country.isEmpty { state.country = r.country }
                if !r.format.isEmpty  { state.format  = r.format  }
                if !r.genre.isEmpty && state.genre.isEmpty { state.genre = r.genre }
                state.discogsId = r.id > 0 ? r.id : nil
                state.results = []; state.query = ""
                let rid = r.id
                return .merge(
                    .send(.fetchArtTapped),
                    .send(.fetchTracksTapped),
                    .run { send in
                        guard rid > 0 else { return }
                        let token = UserDefaults.standard.string(forKey: "rb_discogs") ?? ""
                        if let price = await discogs.fetchPrice(rid, token) {
                            await send(.priceReceived(price))
                        }
                    }
                )

            case .fetchArtTapped:
                guard !state.artist.isEmpty || !state.album.isEmpty else { return .none }
                state.fetchingArt = true
                let ar = state.artist, al = state.album
                return .run { send in
                    let res = await iTunes.fetch(ar, al)
                    if let u = res.coverURL, let url = URL(string: u),
                       let (data,_) = try? await URLSession.shared.data(from: url) {
                        await send(.artReceived(data)); return
                    }
                    await send(.artReceived(nil))
                }

            case .artReceived(let data):
                state.coverData = data; state.fetchingArt = false
                if let data = data, let hex = ColorExtractor.dominant(from: data) {
                    state.colorHex = hex
                }
                return .none

            case .priceReceived(let price):
                if state.curValue.isEmpty { state.curValue = String(format: "%.2f", price) }
                return .none

            case .fetchTracksTapped:
                guard !state.artist.isEmpty || !state.album.isEmpty else { return .none }
                state.fetchingTracks = true; state.tracks = []
                let ar = state.artist, al = state.album
                return .run { send in
                    let res = await iTunes.fetch(ar, al)
                    await send(.tracksReceived(res.tracks))
                }

            case .tracksReceived(let tracks):
                state.tracks = tracks; state.fetchingTracks = false; return .none

            case .addEmptyTrack:
                let next = (state.tracks.map(\.number).max() ?? 0) + 1
                state.tracks.append(Track(name: "", number: next, duration: 0, preview: ""))
                return .none

            case .deleteTrack(let offsets):
                state.tracks.remove(atOffsets: offsets)
                for i in state.tracks.indices { state.tracks[i].number = i + 1 }
                return .none

            case .saveTapped, .cancelTapped: return .none
            case .binding: return .none
            }
        }
    }
}
