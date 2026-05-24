import SwiftUI
import SwiftData
import ComposableArchitecture

@main
struct VinCoApp: App {
    /// Single shared store for the whole app.
    static let store = Store(initialState: AppFeature.State()) {
        AppFeature()
            ._printChanges()   // remove this line before shipping — logs every action to console
    }

    @State private var settings = Settings()

    init() {
        AppearanceSetup.apply()
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: VinCoApp.store)
                .modelContainer(for: Record.self)
                .environment(settings)
                .preferredColorScheme(.dark)
        }
    }
}
