import SwiftUI
import ComposableArchitecture

struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>
    @Environment(Settings.self) private var settings

    var body: some View {
        TabView(selection: $store.tab.sending(\.tabSelected)) {
            CollectionView(store: store.scope(state: \.collection, action: \.collection))
                .tabItem { Label("Collection", systemImage: "square.stack.3d.up.fill") }
                .tag(AppFeature.Tab.collection)

            CollectionView(store: store.scope(state: \.wishlist, action: \.wishlist))
                .tabItem { Label("Wishlist", systemImage: "heart.fill") }
                .tag(AppFeature.Tab.wishlist)

            StatsView(store: store.scope(state: \.stats, action: \.stats))
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
                .tag(AppFeature.Tab.stats)

            SettingsView(store: store.scope(state: \.settings, action: \.settings))
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(AppFeature.Tab.settings)
        }
        .tint(settings.accentColor)
        .preferredColorScheme(settings.preferredScheme ?? .dark)
        .onChange(of: settings.accentHex) { _, new in AppearanceSetup.apply(accent: new) }
    }
}
