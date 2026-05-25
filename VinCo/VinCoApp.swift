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
    /// App-level model container — shared with the view hierarchy via .modelContainer(modelContainer).
    @State private var modelContainer: ModelContainer = {
        do { return try ModelContainer(for: Record.self) }
        catch { fatalError("SwiftData ModelContainer failed: \(error)") }
    }()

    @Environment(\.scenePhase) private var scenePhase

    init() {
        AppearanceSetup.apply()
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: VinCoApp.store)
                .modelContainer(modelContainer)
                .environment(settings)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                writeAutoBackup()
            }
        }
    }

    /// Writes the continuous auto-backup to the Documents directory when the app backgrounds.
    @MainActor
    private func writeAutoBackup() {
        let records = (try? modelContainer.mainContext.fetch(FetchDescriptor<Record>())) ?? []
        BackupManager.writeAutoBackup(records: records)
    }
}
