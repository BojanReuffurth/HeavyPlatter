import Foundation
import ComposableArchitecture
import SwiftData
import SwiftUI

@Reducer
struct CollectionFeature {

    // MARK: – Sort options (grouped by category for the sub-menu UI)
    enum SortBy: String, CaseIterable, Equatable {
        case dateAdded  = "Date Added ↓"
        case dateOld    = "Date Added ↑"
        case artistAZ   = "Artist A→Z"
        case artistZA   = "Artist Z→A"
        case albumAZ    = "Album A→Z"
        case albumZA    = "Album Z→A"
        case yearAsc    = "Year ↑"
        case yearDesc   = "Year ↓"
        case valueAsc   = "Value ↑"
        case valueDesc  = "Value ↓"
        case paidAsc    = "Paid ↑"
        case paidDesc   = "Paid ↓"
        case gainAsc    = "Gain ↑"
        case gainDesc   = "Gain ↓"
        case labelAZ    = "Label A→Z"
        case labelZA    = "Label Z→A"
        case condAsc    = "Condition ↑"
        case condDesc   = "Condition ↓"
    }

    @ObservableState
    struct State: Equatable {
        let isWishlist: Bool
        var search:    String   = ""
        var sortBy:    SortBy   = .dateAdded
        // Active filters ("All" = no filter)
        var genre:     String   = "All"
        var condition: String   = "All"
        var format:    String   = "All"
        var country:   String   = "All"

        var showAdd:   Bool     = false
        @Presents var detail: DetailFeature.State?
        @Presents var edit:   EditFeature.State?

        var hasActiveFilter: Bool {
            genre != "All" || condition != "All" || format != "All" || country != "All"
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case searchChanged(String)
        case sortSelected(SortBy)
        case genreSelected(String)
        case conditionSelected(String)
        case formatSelected(String)
        case countrySelected(String)
        case clearFilters
        case recordTapped(Record)
        case editTapped(Record)
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
            case .searchChanged(let s):    state.search = s;                return .none
            case .sortSelected(let s):     state.sortBy = s;                return .none
            case .genreSelected(let g):    state.genre = g;                 return .none
            case .conditionSelected(let c): state.condition = c;            return .none
            case .formatSelected(let f):   state.format = f;                return .none
            case .countrySelected(let c):  state.country = c;               return .none
            case .clearFilters:
                state.genre = "All"; state.condition = "All"
                state.format = "All"; state.country = "All"
                return .none
            case .addTapped:           state.edit = .init(isWishlist: state.isWishlist); return .none
            case .editTapped(let r):   state.edit = .init(record: r, isWishlist: r.isWishlist); return .none
            case .addDismissed:        state.showAdd = false;               return .none
            case .recordTapped(let r): state.detail = .init(record: r);     return .none
            case .deleteRecord, .moveRecord: return .none
            case .detail, .edit, .binding:   return .none
            }
        }
        .ifLet(\.$detail, action: \.detail) { DetailFeature() }
        .ifLet(\.$edit,   action: \.edit)   { EditFeature()   }
    }
}
