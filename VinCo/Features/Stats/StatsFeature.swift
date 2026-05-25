import Foundation
import ComposableArchitecture

@Reducer
struct StatsFeature {
    @ObservableState
    struct State: Equatable {
        var isRefreshing: Bool   = false
        var refreshMsg:  String? = nil
    }
    enum Action {
        case refreshStarted
        case refreshProgress(String)
        case refreshDone(String)
    }
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .refreshStarted:
                state.isRefreshing = true; state.refreshMsg = "Fetching prices…"; return .none
            case .refreshProgress(let msg):
                state.refreshMsg = msg; return .none
            case .refreshDone(let msg):
                state.isRefreshing = false; state.refreshMsg = msg; return .none
            }
        }
    }
}
