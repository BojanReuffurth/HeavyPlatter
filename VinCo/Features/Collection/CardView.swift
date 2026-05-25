import SwiftUI

/// Front-face grid card.
struct CardView: View {
    let record: Record
    @Environment(Settings.self) private var settings

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Cover art or vinyl placeholder
            Group {
                if settings.showArtwork, let d = record.coverData, let img = UIImage(data: d) {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    ZStack { settings.bg1; VinylView(color: record.colorHex).padding(24) }
                }
            }
            .aspectRatio(1, contentMode: .fit).frame(maxWidth: .infinity).clipped()

            // Bottom gradient: album bold, artist secondary
            VStack(alignment: .leading, spacing: 2) {
                Text(record.album).font(Theme.courier(13, .bold)).lineLimit(1)
                Text(record.artist).font(Theme.courier(11)).lineLimit(1).opacity(0.80)
            }
            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardGrad()).foregroundStyle(.white)
        }
        // Year + genre + RPM badges — top left
        .overlay(alignment: .topLeading) {
            HStack(spacing: 4) {
                if !record.year.isEmpty {
                    badge(record.year, Color.black.opacity(0.60))
                }
                if !record.genre.isEmpty {
                    badge(record.genre, Color(hex: record.colorHex).opacity(0.90))
                }
                if !record.rpm.isEmpty {
                    badge("\(record.rpm) RPM", Color(hex: record.colorHex).opacity(0.65))
                }
            }
            .padding(8)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardR))
        .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
    }

    private func badge(_ text: String, _ bg: Color) -> some View {
        Text(text)
            .font(Theme.courier(9, .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(bg)
            .clipShape(Capsule())
    }
}
