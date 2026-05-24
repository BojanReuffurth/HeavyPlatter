import SwiftUI
import SwiftData
import ComposableArchitecture

struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>
    @Environment(Settings.self) private var settings
    @Query(filter: #Predicate<Record> { $0.isWishlist == false }) private var collectionRecords: [Record]
    @Query(filter: #Predicate<Record> { $0.isWishlist == true })  private var wishlistRecords: [Record]
    @State private var showStats    = false
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            statsBar
            Rectangle().fill(Theme.divide).frame(height: 1)
            TabView(selection: $store.tab.sending(\.tabSelected)) {
                CollectionView(store: store.scope(state: \.collection, action: \.collection))
                    .tag(AppFeature.Tab.collection)
                    .toolbar(.hidden, for: .tabBar)
                CollectionView(store: store.scope(state: \.wishlist, action: \.wishlist))
                    .tag(AppFeature.Tab.wishlist)
                    .toolbar(.hidden, for: .tabBar)
            }
        }
        .background(Theme.bg0)
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        .overlay(alignment: .bottomTrailing) {
            fab.padding(.trailing, 20).padding(.bottom, 16)
        }
        .environment(\.font, Theme.courier(14))
        .preferredColorScheme(settings.preferredScheme)
        .onChange(of: settings.accentHex) { _, new in AppearanceSetup.apply(accent: new) }
        .onChange(of: settings.schemeKey) { _, _   in AppearanceSetup.apply(accent: settings.accentHex) }
        .sheet(isPresented: $showStats) {
            StatsView(store: store.scope(state: \.stats, action: \.stats))
                .preferredColorScheme(settings.preferredScheme)
                .environment(\.font, Theme.courier(14))
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(store: store.scope(state: \.settings, action: \.settings))
                .preferredColorScheme(settings.preferredScheme)
                .environment(\.font, Theme.courier(14))
        }
    }

    // MARK: – Stats bar (always-on 2×3 grid)
    private var statsBar: some View {
        let paid  = collectionRecords.compactMap(\.paidPrice).reduce(0, +)
        let value = collectionRecords.compactMap(\.currentValue).reduce(0, +)
        let gain  = paid > 0 ? ((value - paid) / paid) * 100 : 0.0
        let gainColor: Color = paid > 0 ? (gain >= 0 ? .green : .red) : Theme.textT
        let paidStr  = paid  > 0 ? "\(settings.currency) \(Int(paid))"  : "\(settings.currency) –"
        let valStr   = value > 0 ? "\(settings.currency) \(Int(value))" : "\(settings.currency) –"
        let gainStr  = paid  > 0 ? String(format: "%+.0f %%", gain)     : "– %"
        return HStack(spacing: 0) {
            statCell("PAID",  paidStr,  Theme.textS)
            Rectangle().fill(Theme.divide).frame(width: 1).frame(maxHeight: .infinity)
            statCell("VALUE", valStr,   Theme.textS)
            Rectangle().fill(Theme.divide).frame(width: 1).frame(maxHeight: .infinity)
            statCell("±",     gainStr,  gainColor)
        }
        .background(Theme.bg1)
    }

    private func statCell(_ label: String, _ value: String, _ valueColor: Color) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(Theme.courier(9, .semibold))
                .foregroundStyle(Theme.textT)
                .lineLimit(1)
            Text(value)
                .font(Theme.courier(13, .bold))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    // MARK: – Bottom bar (tab counts + action icons)
    private var bottomBar: some View {
        HStack(spacing: 0) {
            // Collection tab
            tabCount(.collection, count: collectionRecords.count, label: "RECORDS")
            Rectangle().fill(Theme.divide).frame(width: 1).frame(maxHeight: 32)
            // Wishlist tab
            tabCount(.wishlist,   count: wishlistRecords.count,   label: "WISHLIST")
            Rectangle().fill(Theme.divide).frame(width: 1).frame(maxHeight: 32)
            // Action icons
            HStack(spacing: 0) {
                iconBtn("music.note", color: Color(hex: "#1DB954")) {
                    if let u = URL(string: "spotify:"), UIApplication.shared.canOpenURL(u) {
                        UIApplication.shared.open(u)
                    } else if let u = URL(string: "https://open.spotify.com") {
                        UIApplication.shared.open(u)
                    }
                }
                iconBtn("chart.bar.fill", color: Theme.textS) { showStats    = true }
                iconBtn("gearshape.fill", color: Theme.textS) { showSettings = true }
            }
            .frame(width: 120)
        }
        .padding(.vertical, 10)
        .background(Theme.bg1.ignoresSafeArea(edges: .bottom))
    }

    private func tabCount(_ tab: AppFeature.Tab, count: Int, label: String) -> some View {
        Button { store.send(.tabSelected(tab)) } label: {
            VStack(spacing: 2) {
                Text("\(count)")
                    .font(Theme.courier(22, .bold))
                    .foregroundStyle(store.tab == tab ? settings.accentColor : Theme.textT)
                Text(label)
                    .font(Theme.courier(9, .semibold))
                    .foregroundStyle(Theme.textT)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func iconBtn(_ name: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 15))
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
    }

    // MARK: – Floating action button
    private var fab: some View {
        Button {
            store.send(store.tab == .wishlist ? .wishlist(.addTapped) : .collection(.addTapped))
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.black)
                .frame(width: 56, height: 56)
                .background(settings.accentColor)
                .clipShape(Circle())
                .shadow(color: settings.accentColor.opacity(0.4), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}
