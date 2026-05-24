import Foundation
import ComposableArchitecture
import SwiftData

@Reducer
struct EditFeature {
    @ObservableState
    struct State: Equatable {
        // Mode
        var record:     Record? = nil     // nil = add mode
        var isWishlist: Bool    = false

        // Form fields
        var artist    = ""; var album   = ""; var year      = ""
        var genre     = ""; var label   = ""; var format    = ""
        var country   = ""; var notes   = ""; var condition = "VG"
        var colorHex  = Record.randomColor()
        var coverData: Data? = nil
        var paidPrice = ""; var curValue = ""

        // Discogs
        var query:    String         = ""
        var results:  [DiscogsResult] = []
        var searching:Bool           = false

        // Cover art
        var fetchingArt: Bool = false

        var canSave: Bool { !artist.trimmingCharacters(in: .whitespaces).isEmpty &&
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
                state.artist = r.artist; state.album  = r.album;  state.year    = r.year
                state.genre  = r.genre;  state.label  = r.label;  state.format  = r.format
                state.country = r.country; state.notes = r.notes; state.condition = r.condition
                state.colorHex = r.colorHex; state.coverData = r.coverData
                if let p = r.paidPrice    { state.paidPrice = String(format: "%.2f", p) }
                if let v = r.currentValue { state.curValue  = String(format: "%.2f", v) }
                return .none

            case .queryChanged(let q): state.query = q; return .none

            case .searchTapped:
                let q = state.query.trimmingCharacters(in: .whitespaces)
                guard !q.isEmpty else { return .none }
                state.searching = true; state.results = []
                let token = state.record.map { _ in "" } ?? ""   // token injected from Settings in view
                return .run { [q] send in
                    // Token passed via DiscogsClient; here we pass empty — view will inject token
                    let r = await discogs.search(q, "")
                    await send(.resultsReceived(r))
                }

            case .resultsReceived(let r): state.results = r; state.searching = false; return .none

            case .resultPicked(let r):
                let parts = r.title.components(separatedBy: " - ")
                state.artist  = parts.first?.trimmingCharacters(in: .whitespaces) ?? ""
                state.album   = parts.dropFirst().joined(separator: " - ").trimmingCharacters(in: .whitespaces)
                if state.album.isEmpty { state.album = r.title }
                if !r.year.isEmpty    { state.year    = r.year    }
                if !r.label.isEmpty   { state.label   = r.label   }
                if !r.country.isEmpty { state.country = r.country }
                if !r.format.isEmpty  { state.format  = r.format  }
                state.results = []; state.query = ""
                return .send(.fetchArtTapped)

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

            case .artReceived(let data): state.coverData = data; state.fetchingArt = false; return .none

            // Save / cancel handled in view (needs ModelContext)
            case .saveTapped, .cancelTapped: return .none
            case .binding: return .none
            }
        }
    }
}
