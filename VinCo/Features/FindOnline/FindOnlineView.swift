import SwiftUI

/// Sheet presented when the user wants to buy a wishlist record online.
/// Builds a pre-filled search URL for each supported marketplace and
/// opens it in the default browser.
struct FindOnlineView: View {
    let record: Record
    @Environment(\.dismiss)     private var dismiss
    @Environment(Settings.self) private var settings

    // MARK: – Marketplace model
    private struct MarketplaceEntry: Identifiable {
        let id    = UUID()
        let name:  String
        let icon:  String   // SF Symbol
        let color: Color
        let url:   URL?
    }

    private var marketplaces: [MarketplaceEntry] {
        let raw = "\(record.artist) \(record.album)"
        let q   = raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? raw
        return [
            .init(name:  "Discogs",
                  icon:  "opticaldisc",
                  color: Color(hex: "#4B4B4B"),
                  url:   URL(string: "https://www.discogs.com/search/?q=\(q)&type=release")),

            .init(name:  "eBay",
                  icon:  "cart.fill",
                  color: Color(hex: "#E53238"),
                  url:   URL(string: "https://www.ebay.com/sch/i.html?_nkw=\(q)+vinyl+record")),

            .init(name:  "Amazon",
                  icon:  "shippingbox.fill",
                  color: Color(hex: "#FF9900"),
                  url:   URL(string: "https://www.amazon.com/s?k=\(q)+vinyl+record")),

            .init(name:  "Bandcamp",
                  icon:  "music.note.house.fill",
                  color: Color(hex: "#1DA0C3"),
                  url:   URL(string: "https://bandcamp.com/search?q=\(q)&item_type=a")),

            .init(name:  "Juno Records",
                  icon:  "building.2.fill",
                  color: Color(hex: "#E84B2B"),
                  url:   URL(string: "https://www.juno.co.uk/search/?q=\(q)")),
        ]
    }

    // MARK: – Body
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button { dismiss() } label: {
                    Text("✕").font(Theme.courier(15)).foregroundStyle(Theme.textT)
                }.buttonStyle(.plain)
                Text("Find Online")
                    .font(Theme.courier(17, .semibold)).foregroundStyle(Theme.textP)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(settings.bg1)
            Rectangle().fill(Theme.divide).frame(height: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    searchPill
                    storeList
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(settings.bg0.ignoresSafeArea())
        }
        .preferredColorScheme(settings.preferredScheme)
    }

    // MARK: – Search pill
    private var searchPill: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textT)
            Text("\"\(record.artist)  —  \(record.album)\"")
                .font(Theme.courier(12))
                .foregroundStyle(Theme.textS)
                .lineLimit(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(settings.bg2)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: – Store rows
    private var storeList: some View {
        VStack(spacing: 0) {
            ForEach(Array(marketplaces.enumerated()), id: \.element.id) { i, entry in
                if let url = entry.url {
                    Button { UIApplication.shared.open(url) } label: {
                        storeRow(entry)
                    }
                    .buttonStyle(.plain)

                    if i < marketplaces.count - 1 {
                        Rectangle()
                            .fill(Theme.divide)
                            .frame(height: 1)
                            .padding(.leading, 74)
                    }
                }
            }
        }
        .background(settings.bg1)
        .clipShape(RoundedRectangle(cornerRadius: Theme.sectR))
    }

    private func storeRow(_ entry: MarketplaceEntry) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(entry.color.opacity(0.14))
                    .frame(width: 46, height: 46)
                Image(systemName: entry.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(entry.color)
            }

            Text(entry.name)
                .font(Theme.courier(15, .semibold))
                .foregroundStyle(Theme.textP)

            Spacer()

            Image(systemName: "arrow.up.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textT)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
