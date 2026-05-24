import ComposableArchitecture
import Foundation

@Reducer
struct DetailFeature {
    @ObservableState
    struct State: Equatable {
        var record:          Record
        var isFetching:      Bool   = false
        var showFullArt:     Bool   = false
        var showEdit:        Bool   = false
        var showDeleteAlert: Bool   = false
        @Presents var edit:  EditFeature.State?
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case fetchTracks
        case tracksFetched([Track])
        case coverCached(Data)
        case toggleFullArt
        case editTapped
        case deleteTapped
        case confirmDelete
        case moveTapped
        case edit(PresentationAction<EditFeature.Action>)
    }

    @Dependency(\.iTunes)       var iTunes
    @Dependency(\.musicBrainz)  var musicBrainz

    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .fetchTracks:
                guard !state.isFetching else { return .none }
                state.isFetching = true
                let ar = state.record.artist, al = state.record.album
                return .run { send in
                    let res = await iTunes.fetch(ar, al)
                    if !res.tracks.isEmpty {
                        await send(.tracksFetched(res.tracks))
                        if let u = res.coverURL, let url = URL(string: u),
                           let (data,_) = try? await URLSession.shared.data(from: url) {
                            await send(.coverCached(data))
                        }
                        return
                    }
                    let mb = await musicBrainz.fetchTracks(ar, al)
                    await send(.tracksFetched(mb))
                }

            case .tracksFetched(let tracks):
                state.isFetching = false
                state.record.tracks = tracks
                return .none

            case .coverCached(let data):
                if state.record.coverData == nil { state.record.coverData = data }
                return .none

            case .toggleFullArt:  state.showFullArt     = true;  return .none
            case .editTapped:     state.edit = .init(record: state.record); return .none
            case .deleteTapped:   state.showDeleteAlert  = true;  return .none
            case .confirmDelete:  return .none   // deletion handled in view (needs ModelContext)
            case .moveTapped:     state.record.isWishlist.toggle(); return .none
            case .edit, .binding: return .none
            }
        }
        .ifLet(\.$edit, action: \.edit) { EditFeature() }
    }
}
