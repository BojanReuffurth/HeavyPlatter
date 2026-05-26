import SwiftUI
import SwiftData
import ComposableArchitecture

struct DetailView: View {
    @Bindable var store: StoreOf<DetailFeature>
    @Environment(\.dismiss)      private var dismiss
    @Environment(\.modelContext) private var ctx
    @Environment(Settings.self)  private var settings
    @StateObject private var audio = AudioPlayer()
    @State private var showFindOnline     = false
    @State private var showConditionGuide = false

    var rec: Record { store.record }

    var body: some View {
        VStack(spacing: 0) {
            // Custom header — no iOS 26 toolbar glass treatment
            HStack(spacing: 12) {
                Button { dismiss() } label: {
                    Text("✕").font(Theme.courier(15)).foregroundStyle(Theme.textT)
                }.buttonStyle(.plain)
                Spacer()
                Menu {
                    Button { store.send(.editTapped)  } label: { Label("Edit", systemImage: "pencil") }
                    if rec.isWishlist {
                        Button { showFindOnline = true } label: {
                            Label("Find Online", systemImage: "cart.fill")
                        }
                    }
                    Button { store.send(.moveTapped) } label: {
                        Label(rec.isWishlist ? "Move to Collection" : "Move to Wishlist",
                              systemImage: rec.isWishlist ? "square.stack.3d.up" : "heart")
                    }
                    Divider()
                    Button(role: .destructive) { store.send(.deleteTapped) } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis").foregroundStyle(settings.accentColor)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(settings.bg1)
            Rectangle().fill(Theme.divide).frame(height: 1)

            ScrollView {
                VStack(spacing: 0) {
                    coverHeader
                    chipRow
                    if !rec.notes.isEmpty { notesBlock }
                    trackHeader
                    trackBody
                }
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .background(settings.bg0.ignoresSafeArea())
        .sheet(item: $store.scope(state: \.edit, action: \.edit)) { s in
            EditView(store: s)
                .preferredColorScheme(settings.preferredScheme)
                .fontDesign(.monospaced)
        }
        .fullScreenCover(isPresented: $store.showFullArt) { fullArt }
        .confirmationDialog("Delete \"\(rec.album)\"?", isPresented: $store.showDeleteAlert, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { ctx.delete(rec); dismiss() }
        }
        .sheet(isPresented: $showFindOnline) {
            FindOnlineView(record: rec).environment(settings)
        }
        .sheet(isPresented: $showConditionGuide) {
            ConditionGuideView()
                .environment(settings)
                .presentationDetents([.medium, .large])
        }
        .onDisappear { audio.stop() }
    }

    private var coverHeader: some View {
        ZStack(alignment: .bottom) {
            Group {
                if let d = rec.coverData, let img = UIImage(data: d) {
                    Image(uiImage: img).resizable().scaledToFill()
                        .overlay(alignment: .topTrailing) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.55))
                                .padding(8)
                        }
                        .onTapGesture { store.send(.toggleFullArt) }
                } else {
                    ZStack { settings.bg1; VinylView(color: rec.colorHex).padding(60) }
                }
            }
            .frame(maxWidth: .infinity).frame(height: 310).clipped()

            VStack(alignment: .leading, spacing: 5) {
                Text(rec.album).font(Theme.courier(22, .bold))
                Text(rec.artist).font(Theme.courier(16)).opacity(0.82)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.bottom, 16).padding(.top, 80)
            .background(Theme.headerGrad()).foregroundStyle(.white)
        }
    }

    private var chipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(rec.year,      "calendar",                !rec.year.isEmpty)
                chip(rec.condition, "checkmark.seal.fill",     !rec.condition.isEmpty, accent: true)
                if !rec.condition.isEmpty {
                    Button { showConditionGuide = true } label: {
                        Image(systemName: "info.circle")
                            .font(Theme.courier(12, .medium))
                            .foregroundStyle(Theme.textT)
                            .padding(.horizontal, 6).padding(.vertical, 6)
                            .background(settings.bg2).clipShape(Capsule())
                    }.buttonStyle(.plain)
                }
                chip(rec.genre,     "music.note",              !rec.genre.isEmpty)
                chip(rec.rpm.isEmpty ? "" : "\(rec.rpm) RPM", "dial.low", !rec.rpm.isEmpty)
                chip(rec.label,     "building.2",              !rec.label.isEmpty)
                chip(rec.format,    "opticaldisc",             !rec.format.isEmpty)
                chip(rec.country,   "globe",                   !rec.country.isEmpty)
                if let p = rec.paidPrice    { chip("\(settings.currency) \(Int(p)) paid",  "eurosign.circle", true) }
                if let v = rec.currentValue { chip("\(settings.currency) \(Int(v)) value", "chart.line.uptrend.xyaxis", true) }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
        .background(settings.bg1)
    }

    @ViewBuilder
    private func chip(_ text: String, _ icon: String, _ show: Bool, accent: Bool = false) -> some View {
        if show {
            Label(text, systemImage: icon)
                .font(Theme.courier(12, .medium))
                .foregroundStyle(accent ? settings.accentColor : Theme.textS)
                .padding(.horizontal, 11).padding(.vertical, 6)
                .background(settings.bg2).clipShape(Capsule())
        }
    }

    private var notesBlock: some View {
        Text(rec.notes).font(Theme.courier(14)).foregroundStyle(Theme.textS)
            .frame(maxWidth: .infinity, alignment: .leading).padding(16).background(settings.bg1)
    }

    private var trackHeader: some View {
        HStack {
            Text("TRACKLIST")
                .font(Theme.courier(11, .semibold))
                .foregroundStyle(Theme.textT)
            Spacer()
            if store.isFetching {
                ProgressView().tint(settings.accentColor)
            } else {
                Button { store.send(.fetchTracks) } label: {
                    Image(systemName: rec.tracks.isEmpty ? "arrow.down.circle" : "arrow.clockwise")
                        .font(.system(size: 15)).foregroundStyle(settings.accentColor)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    @ViewBuilder
    private var trackBody: some View {
        if let err = audio.errorMsg {
            Text(err)
                .font(Theme.courier(12)).foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16).padding(.vertical, 6)
        }
        if rec.tracks.isEmpty && !store.isFetching {
            Text("No tracklist — tap ↓ to load.")
                .font(Theme.courier(13)).foregroundStyle(Theme.textT)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16).padding(.bottom, 32)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(Array(rec.tracks.enumerated()), id: \.element.id) { i, t in
                    TrackRow(track: t, index: i,
                             playing: audio.currentURL == t.preview && audio.isPlaying,
                             progress: audio.currentURL == t.preview ? audio.progress : 0) {
                        audio.currentURL == t.preview && audio.isPlaying
                            ? audio.pause() : audio.play(url: t.preview)
                    }
                    if i < rec.tracks.count - 1 {
                        Rectangle().fill(Theme.divide).frame(height: 1).padding(.leading, 52)
                    }
                }
            }
            .background(settings.bg1).clipShape(RoundedRectangle(cornerRadius: Theme.sectR))
            .padding(.horizontal, 14).padding(.bottom, 32)
        }
    }

    private var fullArt: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let d = rec.coverData, let img = UIImage(data: d) {
                Image(uiImage: img).resizable().scaledToFit()
            }
        }
        .onTapGesture { store.showFullArt = false }
    }

}

struct TrackRow: View {
    let track: Track; let index: Int
    let playing: Bool; let progress: Double
    let toggle: () -> Void
    @Environment(Settings.self) private var settings

    var body: some View {
        HStack(spacing: 12) {
            Text("\(track.number > 0 ? track.number : index+1)")
                .font(Theme.courier(12, .medium))
                .foregroundStyle(Theme.textT).frame(width: 28, alignment: .trailing)
            VStack(alignment: .leading, spacing: 5) {
                Text(track.name)
                    .font(Theme.courier(14))
                    .foregroundStyle(playing ? settings.accentColor : Theme.textP).lineLimit(1)
                if playing {
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.bg3).frame(height: 3)
                            Capsule().fill(settings.accentColor)
                                .frame(width: g.size.width * max(0, min(1, progress)), height: 3)
                        }
                    }.frame(height: 3)
                }
            }
            Spacer()
            Text(track.durationStr)
                .font(Theme.courier(12)).foregroundStyle(Theme.textT)
            if track.hasPreview {
                Button(action: toggle) {
                    Image(systemName: playing ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 22)).foregroundStyle(settings.accentColor)
                }
                .buttonStyle(.plain)
            } else { Color.clear.frame(width: 22) }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }
}
