import SwiftUI
import SwiftData
import Charts
import ComposableArchitecture

struct StatsView: View {
    let store: StoreOf<StatsFeature>
    @Query private var all: [Record]
    @Environment(Settings.self) private var settings

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
        NavigationStack {
            ZStack { Theme.bg0.ignoresSafeArea() }
            ScrollView {
                VStack(spacing: 20) {
                    summaryGrid
                    if paid > 0 || value > 0 { valuationCard }
                    if !genres.isEmpty  { barChart("GENRES",    data: genres,  horizontal: true) }
                    if !decades.isEmpty { barChart("BY DECADE", data: decades, horizontal: false) }
                    if !artists.isEmpty { topArtistsCard }
                }
                .padding(16).padding(.bottom, 32)
            }
            .background(Theme.bg0).scrollIndicators(.hidden)
            .navigationTitle("Stats")
            .toolbarBackground(Theme.bg1, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard("\(col.count)", "Records",   "square.stack.3d.up.fill", settings.accentColor)
            statCard("\(wl.count)",  "Wishlist",  "heart.fill",              .pink)
            statCard("\(genres.count)","Genres",  "music.note",              .purple)
            statCard(artists.first?.0 ?? "—", "Top Artist", "star.fill",    .orange)
        }
    }

    private func statCard(_ v: String, _ l: String, _ icon: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
            Text(v).font(.system(size: 22, weight: .bold)).foregroundStyle(Theme.textP).lineLimit(1).minimumScaleFactor(0.5)
            Text(l).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.textS)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.bg1).clipShape(RoundedRectangle(cornerRadius: Theme.sectR))
    }

    private var valuationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("COLLECTION VALUE").font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(Theme.textT)
            HStack(spacing: 28) {
                valItem("PAID",  "\(settings.currency)\(Int(paid))",  .white)
                Rectangle().fill(Theme.divide).frame(width:1,height:40)
                valItem("VALUE", "\(settings.currency)\(Int(value))", .white)
                if paid > 0 {
                    let pct = ((value-paid)/paid)*100
                    Rectangle().fill(Theme.divide).frame(width:1,height:40)
                    valItem("GAIN", String(format:"%+.0f%%",pct), pct>=0 ? .green : .red)
                }
            }
        }
        .padding(16).background(Theme.bg1).clipShape(RoundedRectangle(cornerRadius: Theme.sectR))
    }

    private func valItem(_ l: String, _ v: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(l).font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(Theme.textT)
            Text(v).font(.system(size: 20, weight: .bold)).foregroundStyle(c)
        }
    }

    private func barChart(_ title: String, data: [(String,Int)], horizontal: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(Theme.textT)
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
        .padding(16).background(Theme.bg1).clipShape(RoundedRectangle(cornerRadius: Theme.sectR))
    }

    private var topArtistsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("TOP ARTISTS").font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(Theme.textT)
            ForEach(Array(artists.enumerated()), id: \.element.0) { i, item in
                HStack {
                    Text("\(i+1)").font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.textT).frame(width: 20)
                    Text(item.0).font(.system(size: 14)).foregroundStyle(Theme.textP)
                    Spacer()
                    Text("\(item.1)").font(.system(size: 13, weight: .medium, design: .monospaced)).foregroundStyle(settings.accentColor)
                }
                if i < artists.count-1 { Rectangle().fill(Theme.divide).frame(height:1) }
            }
        }
        .padding(16).background(Theme.bg1).clipShape(RoundedRectangle(cornerRadius: Theme.sectR))
    }

    private func grouped(_ records: [Record], by key: (Record)->String) -> [(String,Int)] {
        Dictionary(grouping: records, by: key).map { ($0.key,$0.value.count) }
    }
}
