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
            appHeader
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
        .background(settings.bg0)
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomCounts }
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

    // MARK: – App header (vinyl icon + compact stats badge + action buttons)
    private var appHeader: some View {
        HStack(spacing: 10) {
            // Vinyl icon only (no text)
            ZStack {
                Circle().fill(settings.accentColor.opacity(0.15)).frame(width: 32, height: 32)
                MiniVinylIcon(color: settings.accentColor, size: 20)
            }

            Spacer()

            // Compact 2-row stats badge (labels top / values bottom)
            if settings.pinnedStats.contains("value") {
                collectionValueBadge
            }

            // Spotify
            Button {
                if let u = URL(string: "spotify:"), UIApplication.shared.canOpenURL(u) {
                    UIApplication.shared.open(u)
                } else if let u = URL(string: "https://open.spotify.com") {
                    UIApplication.shared.open(u)
                }
            } label: {
                Image(systemName: "music.note")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: "#1DB954"))
                    .frame(width: 34, height: 34)
                    .background(Theme.bg2)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Button { showStats = true } label: {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textS)
                    .frame(width: 34, height: 34)
                    .background(Theme.bg2)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textS)
                    .frame(width: 34, height: 34)
                    .background(Theme.bg2)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(settings.bg1)
    }

    // MARK: – Compact stats badge  (2 rows × 3 columns)
    // Labels row on top, values row on bottom.  Each column is a VStack with
    // label centred over value; VStack.frame(minWidth:) forces equal widths.
    private var collectionValueBadge: some View {
        let paid  = collectionRecords.compactMap(\.paidPrice).reduce(0, +)
        let value = collectionRecords.compactMap(\.currentValue).reduce(0, +)
        let gain  = paid > 0 ? ((value - paid) / paid) * 100 : 0.0
        let gainColor: Color = gain >= 0 ? .green : .red
        return HStack(spacing: 0) {
            badgeCol("PAID",  "\(settings.currency) \(Int(paid))",  Theme.textS)
            Rectangle().fill(Theme.divide).frame(width: 1, height: 26)
            badgeCol("VAL",   "\(settings.currency) \(Int(value))", Theme.textS)
            if paid > 0 {
                Rectangle().fill(Theme.divide).frame(width: 1, height: 26)
                badgeCol("±", String(format: "%+.0f%%", gain), gainColor)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(settings.bg2)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func badgeCol(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(Theme.courier(7, .semibold))
                .foregroundStyle(Theme.textT)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .center)
            Text(value)
                .font(Theme.courier(11, .bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(minWidth: 44)
        .padding(.horizontal, 4)
    }

    // MARK: – Bottom counts bar
    private var bottomCounts: some View {
        HStack(spacing: 0) {
            Button { store.send(.tabSelected(.collection)) } label: {
                VStack(spacing: 2) {
                    Text("\(collectionRecords.count)")
                        .font(Theme.courier(22, .bold))
                        .foregroundStyle(store.tab == .collection ? settings.accentColor : Theme.textT)
                    Text("COLLECTION")
                        .font(Theme.courier(9, .semibold))
                        .foregroundStyle(Theme.textT)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            Rectangle().fill(Theme.divide).frame(width: 1, height: 32)

            Button { store.send(.tabSelected(.wishlist)) } label: {
                VStack(spacing: 2) {
                    Text("\(wishlistRecords.count)")
                        .font(Theme.courier(22, .bold))
                        .foregroundStyle(store.tab == .wishlist ? settings.accentColor : Theme.textT)
                    Text("WISHLIST")
                        .font(Theme.courier(9, .semibold))
                        .foregroundStyle(Theme.textT)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
        .background(settings.bg1.ignoresSafeArea(edges: .bottom))
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
