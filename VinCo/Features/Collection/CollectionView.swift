import SwiftUI
import SwiftData
import ComposableArchitecture

struct CollectionView: View {
    @Bindable var store: StoreOf<CollectionFeature>
    @Environment(\.modelContext) private var ctx
    @Environment(Settings.self) private var settings

    @Query(sort: \Record.dateAdded, order: .reverse) private var allRecords: [Record]

    private var records: [Record] { allRecords.filter { $0.isWishlist == store.isWishlist } }
    private var genres: [String] {
        ["All"] + Set(records.compactMap { $0.genre.isEmpty ? nil : $0.genre }).sorted()
    }
    private var displayed: [Record] {
        var r = records
        if !store.search.isEmpty {
            r = r.filter { $0.artist.localizedCaseInsensitiveContains(store.search) ||
                           $0.album.localizedCaseInsensitiveContains(store.search) }
        }
        if store.genre != "All" { r = r.filter { $0.genre == store.genre } }
        switch store.sortBy {
        case .dateAdded: r.sort { $0.dateAdded > $1.dateAdded }
        case .artistAZ:  r.sort { $0.artist.lowercased() < $1.artist.lowercased() }
        case .artistZA:  r.sort { $0.artist.lowercased() > $1.artist.lowercased() }
        case .albumAZ:   r.sort { $0.album.lowercased()  < $1.album.lowercased()  }
        case .yearAsc:   r.sort { $0.year < $1.year }
        case .yearDesc:  r.sort { $0.year > $1.year }
        }
        return r
    }
    private let cols = [GridItem(.adaptive(minimum: 155), spacing: 12)]

    // Flip+zoom overlay state
    @State private var expandedRecord: Record? = nil

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                searchBar
                filterBar
                Rectangle().fill(Theme.divide).frame(height: 1)
                if displayed.isEmpty { emptyState }
                else if settings.layout == "list" { listContent }
                else { gridContent }
            }
            .background(Theme.bg0)

            // Flip+zoom overlay
            if let rec = expandedRecord {
                Color.black.opacity(0.65)
                    .ignoresSafeArea()
                    .onTapGesture { dismissExpanded() }
                    .transition(.opacity)

                FlipDetailCard(
                    record: rec,
                    onEdit:    { store.send(.editTapped(rec));  dismissExpanded() },
                    onMove:    { rec.isWishlist.toggle();       dismissExpanded() },
                    onDelete:  { ctx.delete(rec);               dismissExpanded() },
                    onDismiss: { dismissExpanded() }
                )
                .frame(width: min(UIScreen.main.bounds.width * 0.88, 360))
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.55).combined(with: .opacity),
                    removal:   .scale(scale: 0.55).combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: expandedRecord?.id)
        .task { await autofetchPrices() }
        .sheet(item: $store.scope(state: \.detail, action: \.detail)) { s in
            DetailView(store: s)
                .preferredColorScheme(settings.preferredScheme)
                .environment(\.font, Theme.courier(14))
        }
        .sheet(item: $store.scope(state: \.edit, action: \.edit)) { s in
            EditView(store: s)
                .preferredColorScheme(settings.preferredScheme)
                .environment(\.font, Theme.courier(14))
        }
    }

    private func dismissExpanded() {
        withAnimation(.spring(response: 0.38)) { expandedRecord = nil }
    }

    // MARK: – Search bar
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.textT).font(.system(size: 14))
            TextField("Search…", text: $store.search.sending(\.searchChanged))
                .font(Theme.courier(14)).foregroundStyle(Theme.textP)
                .autocorrectionDisabled()
            if !store.search.isEmpty {
                Button { store.send(.searchChanged("")) } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.textT)
                }
                .buttonStyle(.plain)
            }
            // Share button
            Button { shareCollection() } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14)).foregroundStyle(Theme.textT)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Theme.bg2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Theme.bg1)
    }

    // MARK: – Filter bar
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    ForEach(CollectionFeature.SortBy.allCases, id: \.self) { opt in
                        Button { store.send(.sortSelected(opt)) } label: {
                            if store.sortBy == opt {
                                Label(opt.rawValue, systemImage: "checkmark")
                            } else { Text(opt.rawValue) }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.up.arrow.down").font(.system(size: 11, weight: .semibold))
                        Text(store.sortBy.rawValue).font(Theme.courier(13))
                    }
                    .foregroundStyle(Theme.textS)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Theme.bg2).clipShape(Capsule())
                }
                .buttonStyle(.plain)
                ForEach(genres, id: \.self) { g in
                    Button { store.send(.genreSelected(g)) } label: {
                        Text(g)
                            .font(Theme.courier(13, store.genre == g ? .semibold : .regular))
                            .foregroundStyle(store.genre == g ? Color.black : Theme.textS)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(store.genre == g ? settings.accentColor : Theme.bg2)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
        }
        .background(Theme.bg1)
    }

    // MARK: – Grid content
    private var gridContent: some View {
        ScrollView {
            LazyVGrid(columns: cols, spacing: 12) {
                ForEach(displayed) { rec in
                    CardView(record: rec)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                                expandedRecord = rec
                            }
                        }
                        .contextMenu { ctxMenu(rec) }
                }
            }
            .padding(12)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: – List content
    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(displayed) { rec in
                    listRow(rec)
                }
            }
            .padding(12)
        }
        .scrollIndicators(.hidden)
    }

    private func listRow(_ rec: Record) -> some View {
        HStack(spacing: 12) {
            Group {
                if let d = rec.coverData, let img = UIImage(data: d) {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    ZStack { Theme.bg2; VinylView(color: rec.colorHex) }
                }
            }
            .frame(width: 54, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(rec.album).font(Theme.courier(14, .semibold))
                    .foregroundStyle(Theme.textP).lineLimit(1)
                Text(rec.artist).font(Theme.courier(12))
                    .foregroundStyle(Theme.textS).lineLimit(1)
                HStack(spacing: 4) {
                    if !rec.year.isEmpty {
                        Text(rec.year).font(Theme.courier(9, .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.black.opacity(0.40))
                            .clipShape(Capsule())
                    }
                    if !rec.genre.isEmpty {
                        Text(rec.genre).font(Theme.courier(9, .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(settings.accentColor.opacity(0.80))
                            .clipShape(Capsule())
                    }
                }
            }
            Spacer()
            Button { store.send(.editTapped(rec)) } label: {
                Image(systemName: "pencil").foregroundStyle(Theme.textT)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Theme.bg1)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) { expandedRecord = rec }
        }
    }

    // MARK: – Empty state
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: store.isWishlist ? "heart.slash" : "square.stack.3d.up.slash")
                .font(.system(size: 56)).foregroundStyle(Theme.textT)
            Text(store.isWishlist ? "Wishlist is empty" : "Collection is empty")
                .font(Theme.courier(17)).foregroundStyle(Theme.textS)
            Button { store.send(.addTapped) } label: {
                Label("Add a Record", systemImage: "plus")
                    .font(Theme.courier(15, .semibold)).foregroundStyle(.black)
                    .padding(.horizontal, 24).padding(.vertical, 11)
                    .background(settings.accentColor).clipShape(Capsule())
            }
            .buttonStyle(.plain)
            Spacer()
        }
    }

    @ViewBuilder
    private func ctxMenu(_ rec: Record) -> some View {
        Button { store.send(.editTapped(rec)) } label: { Label("Edit", systemImage: "pencil") }
        Button { rec.isWishlist.toggle() } label: {
            Label(rec.isWishlist ? "Move to Collection" : "Move to Wishlist",
                  systemImage: rec.isWishlist ? "square.stack.3d.up" : "heart")
        }
        Divider()
        Button(role: .destructive) { ctx.delete(rec) } label: { Label("Delete", systemImage: "trash") }
    }

    // MARK: – Auto-fetch missing prices in background
    @MainActor
    private func autofetchPrices() async {
        let missing = records.filter { $0.discogsId != nil && $0.currentValue == nil }
        guard !missing.isEmpty else { return }
        let token = UserDefaults.standard.string(forKey: "rb_discogs") ?? ""
        for rec in missing {
            guard let did = rec.discogsId else { continue }
            if let price = await DiscogsClient.liveValue.fetchPrice(did, token) {
                rec.currentValue = price
            }
            try? await Task.sleep(nanoseconds: 400_000_000) // rate-limit
        }
    }

    // MARK: – Share
    private func shareCollection() {
        let title = store.isWishlist ? "My Wishlist" : "My Collection"
        let lines = displayed.map { r in
            var s = "\(r.album) — \(r.artist)"
            if !r.year.isEmpty { s += " (\(r.year))" }
            if !r.genre.isEmpty { s += " [\(r.genre)]" }
            return s
        }
        let text = "🎵 \(title) (\(displayed.count) records)\n\n" + lines.joined(separator: "\n") + "\n\n— shared via VinCo"
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let scene  = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first,
           let root   = window.rootViewController {
            root.present(av, animated: true)
        }
    }
}

// MARK: – Flip+Zoom Detail Card (shown as overlay in CollectionView)
struct FlipDetailCard: View {
    let record: Record
    var onEdit:    () -> Void = {}
    var onMove:    () -> Void = {}
    var onDelete:  () -> Void = {}
    var onDismiss: () -> Void = {}
    @Environment(Settings.self) private var settings
    @State private var isFlipped = false
    @State private var isFetchingTracks = false

    var body: some View {
        ZStack {
            front
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 0 : 1)
            back
                .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 1 : 0)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardR + 4))
        .shadow(color: .black.opacity(0.65), radius: 28, x: 0, y: 10)
        .onTapGesture {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { isFlipped.toggle() }
        }
        .onAppear {
            // Auto-flip to back after a brief zoom pause
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.76)) { isFlipped = true }
            }
        }
    }

    // Front — same as CardView but full-width
    private var front: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let d = record.coverData, let img = UIImage(data: d) {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    ZStack { Theme.bg1; VinylView(color: record.colorHex).padding(40) }
                }
            }
            .aspectRatio(1, contentMode: .fit).frame(maxWidth: .infinity).clipped()

            VStack(alignment: .leading, spacing: 2) {
                Text(record.album).font(Theme.courier(15, .bold)).lineLimit(1)
                Text(record.artist).font(Theme.courier(12)).lineLimit(1).opacity(0.80)
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardGrad()).foregroundStyle(.white)
        }
        .overlay(alignment: .topLeading) {
            HStack(spacing: 4) {
                if !record.year.isEmpty {
                    Text(record.year).font(Theme.courier(9, .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Color.black.opacity(0.60)).clipShape(Capsule())
                }
                if !record.genre.isEmpty {
                    Text(record.genre).font(Theme.courier(9, .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(settings.accentColor.opacity(0.85)).clipShape(Capsule())
                }
            }.padding(10)
        }
        .overlay(alignment: .topTrailing) {
            Button { onDismiss() } label: {
                Text("✕").font(Theme.courier(13, .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(10)
            }.buttonStyle(.plain)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // Back — full record detail
    private var back: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(record.album).font(Theme.courier(15, .bold))
                        .foregroundStyle(Theme.textP).lineLimit(1)
                    Text(record.artist).font(Theme.courier(12))
                        .foregroundStyle(Theme.textS).lineLimit(1)
                }
                Spacer()
                Button { onDismiss() } label: {
                    Text("✕").font(Theme.courier(13)).foregroundStyle(Theme.textT)
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 10)

            Rectangle().fill(Theme.divide).frame(height: 1)

            // Info rows
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    if !record.year.isEmpty      { infoRow("YEAR",    record.year)      }
                    if !record.genre.isEmpty     { infoRow("GENRE",   record.genre)     }
                    if !record.condition.isEmpty { infoRow("COND.",   record.condition) }
                    if !record.label.isEmpty     { infoRow("LABEL",   record.label)     }
                    if !record.format.isEmpty    { infoRow("FORMAT",  record.format)    }
                    if !record.country.isEmpty   { infoRow("COUNTRY", record.country)   }
                    if !record.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("NOTES").font(Theme.courier(9, .semibold)).foregroundStyle(Theme.textT)
                            Text(record.notes).font(Theme.courier(11)).foregroundStyle(Theme.textS).lineLimit(5)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        Rectangle().fill(Theme.divide).frame(height: 1)
                    }
                    if let p = record.paidPrice, let v = record.currentValue {
                        HStack(spacing: 16) {
                            valItem("PAID",  "\(p)")
                            valItem("VALUE", "\(v)")
                            let gain = ((v-p)/p)*100
                            valItem("GAIN", String(format: "%+.0f%%", gain), gain >= 0 ? .green : .red)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        Rectangle().fill(Theme.divide).frame(height: 1)
                    }

                    // Tracklist
                    if record.tracks.isEmpty {
                        HStack {
                            Button {
                                let ar = record.artist, al = record.album
                                isFetchingTracks = true
                                Task { @MainActor in
                                    let res = await iTunesClient.liveValue.fetch(ar, al)
                                    if !res.tracks.isEmpty { record.tracks = res.tracks }
                                    isFetchingTracks = false
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    if isFetchingTracks {
                                        ProgressView().tint(settings.accentColor).scaleEffect(0.75)
                                    } else {
                                        Image(systemName: "list.bullet").font(.system(size: 12))
                                    }
                                    Text(isFetchingTracks ? "Fetching…" : "Get Tracklist")
                                        .font(Theme.courier(11))
                                }
                                .foregroundStyle(settings.accentColor)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            Spacer()
                        }
                        Rectangle().fill(Theme.divide).frame(height: 1)
                    } else {
                        Text("TRACKLIST")
                            .font(Theme.courier(9, .semibold))
                            .foregroundStyle(Theme.textT)
                            .padding(.horizontal, 14).padding(.top, 8).padding(.bottom, 2)
                        ForEach(record.tracks) { track in
                            VStack(spacing: 0) {
                                HStack(spacing: 6) {
                                    Text("\(track.number)")
                                        .font(Theme.courier(9)).foregroundStyle(Theme.textT)
                                        .frame(width: 18, alignment: .trailing)
                                    Text(track.name)
                                        .font(Theme.courier(11)).foregroundStyle(Theme.textS)
                                        .lineLimit(1)
                                    Spacer()
                                    if !track.durationStr.isEmpty {
                                        Text(track.durationStr)
                                            .font(Theme.courier(9)).foregroundStyle(Theme.textT)
                                    }
                                }
                                .padding(.horizontal, 14).padding(.vertical, 5)
                                Rectangle().fill(Theme.divide).frame(height: 1)
                            }
                        }
                    }
                }
            }

            // Actions
            HStack(spacing: 0) {
                actionBtn("pencil",  settings.accentColor)  { onEdit()   }
                Rectangle().fill(Theme.divide).frame(width:1).frame(maxHeight:.infinity)
                actionBtn(record.isWishlist ? "square.stack.3d.up" : "heart", Theme.textS) { onMove()   }
                Rectangle().fill(Theme.divide).frame(width:1).frame(maxHeight:.infinity)
                actionBtn("trash",   .red)                  { onDelete() }
            }
            .frame(height: 50)
        }
        .background(Theme.bg2)
        .aspectRatio(1, contentMode: .fit)
    }

    private func infoRow(_ key: String, _ val: String) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 4) {
                Text(key).font(Theme.courier(9, .semibold)).foregroundStyle(Theme.textT).frame(width: 54, alignment: .leading)
                Text(val).font(Theme.courier(11)).foregroundStyle(Theme.textS).lineLimit(2)
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 7)
            Rectangle().fill(Theme.divide).frame(height: 1)
        }
    }

    private func valItem(_ l: String, _ v: String, _ c: Color = Theme.textP) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(l).font(Theme.courier(9, .semibold)).foregroundStyle(Theme.textT)
            Text(v).font(Theme.courier(12, .bold)).foregroundStyle(c)
        }
    }

    private func actionBtn(_ icon: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(color)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }.buttonStyle(.plain)
    }
}
