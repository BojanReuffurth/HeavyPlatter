import Foundation
import ComposableArchitecture
import SwiftData

@Reducer
struct CollectionFeature {
    enum SortBy: String, CaseIterable, Equatable {
        case dateAdded="Date Added", artistAZ="Artist A→Z", artistZA="Artist Z→A"
        case albumAZ="Album A→Z",   yearAsc="Year ↑",      yearDesc="Year ↓"
    }

    @ObservableState
    struct State: Equatable {
        let isWishlist: Bool
        var search:    String   = ""
        var sortBy:    SortBy   = .dateAdded
        var genre:     String   = "All"
        var showAdd:   Bool     = false
        @Presents var detail: DetailFeature.State?
        @Presents var edit:   EditFeature.State?
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case searchChanged(String)
        case sortSelected(SortBy)
        case genreSelected(String)
        case recordTapped(Record)
        case addTapped
        case deleteRecord(Record)
        case moveRecord(Record)
        case detail(PresentationAction<DetailFeature.Action>)
        case edit(PresentationAction<EditFeature.Action>)
        case addDismissed
    }

    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .searchChanged(let s): state.search = s;              return .none
            case .sortSelected(let s):  state.sortBy = s;              return .none
            case .genreSelected(let g): state.genre = g;               return .none
            case .addTapped:            state.edit = .init(isWishlist: state.isWishlist); return .none
            case .addDismissed:         state.showAdd = false;         return .none
            case .recordTapped(let r):  state.detail = .init(record: r); return .none
            // Delete/move handled by view (needs ModelContext)
            case .deleteRecord, .moveRecord: return .none
            case .detail, .edit, .binding:   return .none
            }
        }
        .ifLet(\.$detail, action: \.detail) { DetailFeature() }
        .ifLet(\.$edit,   action: \.edit)   { EditFeature()   }
    }
}
