import SwiftUI
import SwiftData
import Charts
import ComposableArchitecture
import Foundation

struct StatsView: View {
    let store: StoreOf<StatsFeature>
    @Query private var all: [Record]
    @Environment(Settings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    private var col: [Record] { all.filter { !$0.isWishlist } }
    private var wl:  [Record] { all.filter {  $0.isWishlist } }
    private var genres:  [(String,Int)] { grouped(col) { $0.genre.isEmpty ? "Unknown" : $0.genre }.sorted{$0.1>$1.1}.prefix(8).map{$0} }
    private var decades: [(String,Int)] {
        grouped(col) { r -> String in
            guard let y = Int(r.year), y >= 1900 else { return "?" }
            return "\(y/10*10)s"
        }.sorted{$0.0<$1.0}
    }
    private var artists: [(String,Int)] { grouped(col){$0.artist}.filter{$0.1>1}.sorted{$0.1>$1.1}.prefix(5).map{$0} }
    private var paid:  Double { col.compactMap(\.paidPrice).reduce(0,+) }
    private var value: Double { col.compactMap(\.currentValue).reduce(0,+) }

    var body: some View {
        VStack(spacing: 0) {
            // Custom header — close left, title centre, refresh right
            HStack(spacing: 12) {
                Button { dismiss() } label: {
                    Text("✕").font(Theme.courier(15)).foregroundStyle(Theme.textT)
                }.buttonStyle(.plain)
                Text("Stats")
                    .font(Theme.courier(17, .semibold)).foregroundStyle(Theme.textP)
                Spacer()
                Button {
                    guard !store.isRefreshing else { return }
                    refreshAllPrices()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15))
                        .foregroundStyle(store.isRefreshing ? Theme.textT : settings.accentColor)
                }
                .buttonStyle(.plain)
                .disabled(store.isRefreshing)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(settings.bg1)
            Rectangle().fill(Theme.divide).frame(height: 1)

            ScrollView {
                VStack(spacing: 20) {
                    if let msg = store.refreshMsg {
                        HStack(spacing: 8) {
                            if store.isRefreshing { ProgressView().tint(settings.accentColor).scaleEffect(0.8) }
                            Text(msg).font(Theme.courier(12)).foregroundStyle(settings.accentColor)
                            Spacer()
                        }
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(settings.bg1).clipShape(RoundedRectangle(cornerRadius: Theme.sectR))
                    }
                    summaryGrid
                    if paid > 0 || value > 0 { valuationCard }
                    if !genres.isEmpty  { barChart("GENRES",    data: genres,  horizontal: true) }
                    if !decades.isEmpty { barChart("BY DECADE", data: decades, horizontal: false) }
                    if !artists.isEmpty { topArtistsCard }
                }
                .padding(16).padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .background(settings.bg0.ignoresSafeArea())
    }

    private func refreshAllPrices() {
        let eligible = col.filter { $0.discogsId != nil }
        guard !eligible.isEmpty else {
            store.send(.refreshDone("No Discogs IDs found — search and pick results to link records."))
            return
        }
        store.send(.refreshStarted)
        Task {
            let token = UserDefaults.standard.string(forKey: "rb_discogs") ?? ""
            var updated = 0
            for (i, rec) in eligible.enumerated() {
                guard let did = rec.discogsId else { continue }
                if let price = await DiscogsClient.liveValue.fetchPrice(did, token) {
                    await MainActor.run { rec.currentValue = price; updated += 1 }
                }
                await MainActor.run { store.send(.refreshProgress("Fetching… \(i+1)/\(eligible.count)")) }
                try? await Task.sleep(nanoseconds: 350_000_000)
            }
            await MainActor.run { store.send(.refreshDone("Updated \(updated)/\(eligible.count) records ✓")) }
        }
    }

    // MARK: – Summary grid
    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard("\(col.count)", "Records",      "square.stack.3d.up.fill", settings.accentColor)
            statCard("\(wl.count)",  "Wishlist",     "heart.fill",              .pink)
            statCard("\(genres.count)", "Genres",    "music.note",              .purple)
            statCard(artists.first?.0 ?? "—", "Top Artist", "star.fill",       .orange)
        }
    }

    private func statCard(_ v: String, _ l: String, _ icon: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
            Text(v).font(Theme.courier(22, .bold)).foregroundStyle(Theme.textP).lineLimit(1).minimumScaleFactor(0.5)
            Text(l).font(Theme.courier(11, .medium)).foregroundStyle(Theme.textS)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(settings.bg1).clipShape(RoundedRectangle(cornerRadius: Theme.sectR))
    }

    private var valuationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("COLLECTION VALUE").font(Theme.courier(11, .semibold)).foregroundStyle(Theme.textT)
            HStack(spacing: 28) {
                valItem("PAID",  "\(settings.currency) \(Int(paid))",  .white)
                Rectangle().fill(Theme.divide).frame(width:1,height:40)
                valItem("VALUE", "\(settings.currency) \(Int(value))", .white)
                if paid > 0 {
                    let pct = ((value-paid)/paid)*100
                    Rectangle().fill(Theme.divide).frame(width:1,height:40)
                    valItem("GAIN", String(format:"%+.0f%%",pct), pct>=0 ? .green : .red)
                }
            }
        }
        .padding(16).background(settings.bg1).clipShape(RoundedRectangle(cornerRadius: Theme.sectR))
    }

    private func valItem(_ l: String, _ v: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(l).font(Theme.courier(10, .semibold)).foregroundStyle(Theme.textT)
            Text(v).font(Theme.courier(20, .bold)).foregroundStyle(c)
        }
    }

    private func barChart(_ title: String, data: [(String,Int)], horizontal: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(Theme.courier(11, .semibold)).foregroundStyle(Theme.textT)
            Chart(data, id: \.0) { item in
                if horizontal {
                    BarMark(x: .value("n", item.1), y: .value("l", item.0))
                } else {
                    BarMark(x: .value("l", item.0), y: .value("n", item.1))
                }
            }
            .foregroundStyle(settings.accentColor.gradient)
            .chartXAxis { AxisMarks { AxisValueLabel().foregroundStyle(Theme.textS)
                AxisGridLine(stroke:.init(lineWidth:0.5)).foregroundStyle(Theme.divide) } }
            .chartYAxis { AxisMarks { AxisValueLabel().foregroundStyle(Theme.textS) } }
            .frame(height: horizontal ? CGFloat(data.count)*36 : 180)
        }
        .padding(16).background(settings.bg1).clipShape(RoundedRectangle(cornerRadius: Theme.sectR))
    }

    private var topArtistsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("TOP ARTISTS").font(Theme.courier(11, .semibold)).foregroundStyle(Theme.textT)
            ForEach(Array(artists.enumerated()), id: \.element.0) { i, item in
                HStack {
                    Text("\(i+1)").font(Theme.courier(12, .medium)).foregroundStyle(Theme.textT).frame(width: 20)
                    Text(item.0).font(Theme.courier(14)).foregroundStyle(Theme.textP)
                    Spacer()
                    Text("\(item.1)").font(Theme.courier(13, .medium)).foregroundStyle(settings.accentColor)
                }
                if i < artists.count-1 { Rectangle().fill(Theme.divide).frame(height:1) }
            }
        }
        .padding(16).background(settings.bg1).clipShape(RoundedRectangle(cornerRadius: Theme.sectR))
    }

    private func grouped(_ records: [Record], by key: (Record)->String) -> [(String,Int)] {
        Dictionary(grouping: records, by: key).map { ($0.key,$0.value.count) }
    }
}
