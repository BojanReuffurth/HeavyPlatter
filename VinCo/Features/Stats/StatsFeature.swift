import Foundation
import ComposableArchitecture

@Reducer
struct StatsFeature {
    @ObservableState
    struct State: Equatable {}
    enum Action {}
    var body: some Reducer<State, Action> { EmptyReducer() }
}
