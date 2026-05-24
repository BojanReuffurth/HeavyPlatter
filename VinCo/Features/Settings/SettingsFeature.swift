import Foundation
import ComposableArchitecture
import SwiftData

@Reducer
struct SettingsFeature {
    enum Tab: String, CaseIterable, Equatable {
        case look = "Look", genres = "Genres", backup = "Backup"
        case connect = "Connect", tools = "Tools"
    }

    @ObservableState
    struct State: Equatable {
        var tab:          Tab    = .look
        var newGenre:     String = ""
        var batchMsg:     String? = nil
        var batchRunning: Bool   = false
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case tabSelected(Tab)
        case addGenreTapped
        case removeGenre(Int)
        case exportCSVTapped
        case batchCoversTapped
        case batchTracksTapped
        case batchProgress(String)
        case batchDone(String)
        case deleteAllTapped
    }

    @Dependency(\.iTunes)      var iTunes
    @Dependency(\.musicBrainz) var musicBrainz

    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .tabSelected(let t):   state.tab = t;           return .none
            case .addGenreTapped:       state.newGenre = "";      return .none   // handled in view
            case .removeGenre:          return .none                              // handled in view
            case .exportCSVTapped:      return .none                              // handled in view
            case .deleteAllTapped:      return .none                              // handled in view
            case .batchProgress(let m): state.batchMsg = m;      return .none
            case .batchDone(let m):     state.batchMsg = m; state.batchRunning = false; return .none

            case .batchCoversTapped:
                state.batchRunning = true; state.batchMsg = "Starting…"
                return .none   // actual batch work done in view (needs ModelContext + records)

            case .batchTracksTapped:
                state.batchRunning = true; state.batchMsg = "Starting…"
                return .none

            case .binding: return .none
            }
        }
    }
}
