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
        .background(Theme.bg0)
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

    // MARK: – App header
    private var appHeader: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                ZStack {
                    Circle().fill(settings.accentColor.opacity(0.15)).frame(width: 32, height: 32)
                    Image(systemName: "opticaldisc.fill")
                        .font(.system(size: 15)).foregroundStyle(settings.accentColor)
                }
                Text("VinCo")
                    .font(Theme.courier(20, .bold)).foregroundStyle(Theme.textP)
            }
            Spacer()

            // Collection-value mini badge (paid · value · ±gain)
            if settings.pinnedStats.contains("value") {
                collectionValueBadge
            }

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
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Theme.bg1)
    }

    private var collectionValueBadge: some View {
        let paid  = collectionRecords.compactMap(\.paidPrice).reduce(0, +)
        let value = collectionRecords.compactMap(\.currentValue).reduce(0, +)
        let gain  = paid > 0 ? ((value - paid) / paid) * 100 : 0.0
        return HStack(spacing: 8) {
            miniVal("PAID",  "\(settings.currency)\(Int(paid))",  Theme.textS)
            Rectangle().fill(Theme.divide).frame(width: 1, height: 22)
            miniVal("VAL",   "\(settings.currency)\(Int(value))", Theme.textS)
            if paid > 0 {
                Rectangle().fill(Theme.divide).frame(width: 1, height: 22)
                miniVal("±", String(format: "%+.0f%%", gain), gain >= 0 ? .green : .red)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Theme.bg2)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func miniVal(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 1) {
            Text(value).font(Theme.courier(12, .bold)).foregroundStyle(color)
            Text(label).font(Theme.courier(8,  .semibold)).foregroundStyle(Theme.textT)
        }
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
        .background(Theme.bg1.ignoresSafeArea(edges: .bottom))
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
