import SwiftUI
import SwiftData
import ComposableArchitecture

struct DetailView: View {
    @Bindable var store: StoreOf<DetailFeature>
    @Environment(\.dismiss)      private var dismiss
    @Environment(\.modelContext) private var ctx
    @Environment(Settings.self)  private var settings
    @StateObject private var audio = AudioPlayer()

    var rec: Record { store.record }

    var body: some View {
        NavigationStack {
            ZStack { Theme.bg0.ignoresSafeArea() }
            ScrollView {
                VStack(spacing: 0) {
                    coverHeader
                    chipRow
                    if !rec.notes.isEmpty { notesBlock }
                    trackHeader
                    trackBody
                }
            }
            .background(Theme.bg0).scrollIndicators(.hidden)
            .navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bg1, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar { navBar }
            .sheet(item: $store.scope(state: \.edit, action: \.edit)) { EditView(store: $0) }
            .fullScreenCover(isPresented: $store.showFullArt) { fullArt }
            .confirmationDialog("Delete \"\(rec.album)\"?", isPresented: $store.showDeleteAlert, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { ctx.delete(rec); dismiss() }
            }
        }
        .onDisappear { audio.stop() }
    }

    private var coverHeader: some View {
        ZStack(alignment: .bottom) {
            Group {
                if let d = rec.coverData, let img = UIImage(data: d) {
                    Image(uiImage: img).resizable().scaledToFill()
                        .onTapGesture { store.send(.toggleFullArt) }
                } else {
                    ZStack { Theme.bg1; VinylView(color: rec.colorHex, spin: true).padding(60) }
                }
            }
            .frame(maxWidth: .infinity).frame(height: 310).clipped()

            VStack(alignment: .leading, spacing: 5) {
                Text(rec.artist).font(.system(size: 22, weight: .bold))
                Text(rec.album).font(.system(size: 16)).opacity(0.82)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.bottom, 16).padding(.top, 80)
            .background(Theme.headerGrad()).foregroundStyle(.white)
        }
    }

    private var chipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(rec.year,      "calendar",             !rec.year.isEmpty)
                chip(rec.condition, "checkmark.seal.fill",  !rec.condition.isEmpty, accent: true)
                chip(rec.genre,     "music.note",           !rec.genre.isEmpty)
                chip(rec.label,     "building.2",           !rec.label.isEmpty)
                chip(rec.format,    "opticaldisc",          !rec.format.isEmpty)
                chip(rec.country,   "globe",                !rec.country.isEmpty)
                if let p = rec.paidPrice    { chip("\(settings.currency)\(Int(p)) paid",  "eurosign.circle", true) }
                if let v = rec.currentValue { chip("\(settings.currency)\(Int(v)) value", "chart.line.uptrend.xyaxis", true) }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
        .background(Theme.bg1)
    }

    @ViewBuilder
    private func chip(_ text: String, _ icon: String, _ show: Bool, accent: Bool = false) -> some View {
        if show {
            Label(text, systemImage: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(accent ? settings.accentColor : Theme.textS)
                .padding(.horizontal, 11).padding(.vertical, 6)
                .background(Theme.bg2).clipShape(Capsule())
        }
    }

    private var notesBlock: some View {
        Text(rec.notes).font(.system(size: 14)).foregroundStyle(Theme.textS)
            .frame(maxWidth: .infinity, alignment: .leading).padding(16).background(Theme.bg1)
    }

    private var trackHeader: some View {
        HStack {
            Text("TRACKLIST")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
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
        if rec.tracks.isEmpty && !store.isFetching {
            Text("No tracklist — tap ↓ to load.")
                .font(.system(size: 13)).foregroundStyle(Theme.textT)
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
            .background(Theme.bg1).clipShape(RoundedRectangle(cornerRadius: Theme.sectR))
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

    @ToolbarContentBuilder
    private var navBar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Done") { dismiss() }.foregroundStyle(settings.accentColor)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button { store.send(.editTapped)  } label: { Label("Edit", systemImage: "pencil") }
                Button { store.send(.moveTapped)  } label: {
                    Label(rec.isWishlist ? "Move to Collection" : "Move to Wishlist",
                          systemImage: rec.isWishlist ? "square.stack.3d.up" : "heart")
                }
                Divider()
                Button(role: .destructive) { store.send(.deleteTapped) } label: { Label("Delete", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis.circle").foregroundStyle(settings.accentColor)
            }
        }
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
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.textT).frame(width: 28, alignment: .trailing)
            VStack(alignment: .leading, spacing: 5) {
                Text(track.name)
                    .font(.system(size: 14))
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
                .font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.textT)
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
