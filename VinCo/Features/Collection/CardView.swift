import SwiftUI
struct CardView: View {
    let record: Record
    @Environment(Settings.self) private var settings
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let d = record.coverData, let img = UIImage(data: d) {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    ZStack { Theme.bg1; VinylView(color: record.colorHex).padding(24) }
                }
            }
            .aspectRatio(1, contentMode: .fit).frame(maxWidth: .infinity).clipped()

            VStack(alignment: .leading, spacing: 3) {
                Text(record.artist).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                Text(record.album).font(.system(size: 11)).lineLimit(1).opacity(0.8)
                if !record.condition.isEmpty {
                    Text(record.condition)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(settings.accentColor)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardGrad()).foregroundStyle(.white)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardR))
        .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
    }
}
