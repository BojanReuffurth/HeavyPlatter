import SwiftUI
import SwiftData
import ComposableArchitecture

struct CollectionView: View {
    @Bindable var store: StoreOf<CollectionFeature>
    @Environment(\.modelContext) private var ctx
    @Environment(Settings.self)  private var settings

    @Query(sort: \Record.dateAdded, order: .reverse) private var allRecords: [Record]

    private var records: [Record] { allRecords.filter { $0.isWishlist == store.isWishlist } }

    // MARK: – Available filter options (computed from current records)
    private var genres:     [String] { options(\.genre) }
    private var conditions: [String] { options(\.condition) }
    private var formats:    [String] { options(\.format) }
    private var countries:  [String] { options(\.country) }
    private func options(_ kp: KeyPath<Record, String>) -> [String] {
        ["All"] + Set(records.map { $0[keyPath: kp] }.filter { !$0.isEmpty }).sorted()
    }

    // MARK: – Filtered + sorted list
    private var displayed: [Record] {
        var r = records
        if !store.search.isEmpty {
            r = r.filter { $0.artist.localizedCaseInsensitiveContains(store.search) ||
                           $0.album.localizedCaseInsensitiveContains(store.search) }
        }
        if store.genre     != "All" { r = r.filter { $0.genre     == store.genre     } }
        if store.condition != "All" { r = r.filter { $0.condition == store.condition } }
        if store.format    != "All" { r = r.filter { $0.format    == store.format    } }
        if store.country   != "All" { r = r.filter { $0.country   == store.country   } }

        switch store.sortBy {
        case .dateAdded: r.sort { $0.dateAdded  > $1.dateAdded }
        case .dateOld:   r.sort { $0.dateAdded  < $1.dateAdded }
        case .artistAZ:  r.sort { $0.artist.lowercased() < $1.artist.lowercased() }
        case .artistZA:  r.sort { $0.artist.lowercased() > $1.artist.lowercased() }
        case .albumAZ:   r.sort { $0.album.lowercased()  < $1.album.lowercased()  }
        case .albumZA:   r.sort { $0.album.lowercased()  > $1.album.lowercased()  }
        case .yearAsc:   r.sort { $0.year < $1.year }
        case .yearDesc:  r.sort { $0.year > $1.year }
        case .valueAsc:  r.sort { ($0.currentValue ?? -1) < ($1.currentValue ?? -1) }
        case .valueDesc: r.sort { ($0.currentValue ?? -1) > ($1.currentValue ?? -1) }
        case .paidAsc:   r.sort { ($0.paidPrice ?? -1)    < ($1.paidPrice ?? -1)    }
        case .paidDesc:  r.sort { ($0.paidPrice ?? -1)    > ($1.paidPrice ?? -1)    }
        case .gainAsc:   r.sort { gain($0) < gain($1) }
        case .gainDesc:  r.sort { gain($0) > gain($1) }
        case .labelAZ:   r.sort { $0.label.lowercased() < $1.label.lowercased() }
        case .labelZA:   r.sort { $0.label.lowercased() > $1.label.lowercased() }
        case .condAsc:   r.sort { condOrder($0) < condOrder($1) }
        case .condDesc:  r.sort { condOrder($0) > condOrder($1) }
        }
        return r
    }
    private func gain(_ r: Record) -> Double {
        guard let p = r.paidPrice, p > 0, let v = r.currentValue else { return -999 }
        return (v - p) / p
    }
    private let condOrder: [String: Int] = ["M":0,"NM":1,"VG+":2,"VG":3,"G+":4,"G":5,"F":6,"P":7]
    private func condOrder(_ r: Record) -> Int { condOrder[r.condition] ?? 99 }

    private let cols = [GridItem(.adaptive(minimum: 155), spacing: 12)]
    @State private var expandedRecord: Record? = nil

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                searchBar
                filterSortBar
                Rectangle().fill(Theme.divide).frame(height: 1)
                if displayed.isEmpty { emptyState }
                else if settings.layout == "list" { listContent }
                else { gridContent }
            }
            .background(settings.bg0)

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
            Button { shareCollection() } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14)).foregroundStyle(Theme.textT)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(settings.bg2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(settings.bg1)
    }

    // MARK: – Combined filter + sort bar
    private var filterSortBar: some View {
        HStack(spacing: 8) {
            // FILTER funnel
            Menu {
                filterMenu(title: "Genre",     options: genres,     current: store.genre)     { store.send(.genreSelected($0)) }
                filterMenu(title: "Condition", options: conditions, current: store.condition) { store.send(.conditionSelected($0)) }
                filterMenu(title: "Format",    options: formats,    current: store.format)    { store.send(.formatSelected($0)) }
                filterMenu(title: "Country",   options: countries,  current: store.country)   { store.send(.countrySelected($0)) }
                if store.hasActiveFilter {
                    Divider()
                    Button(role: .destructive) { store.send(.clearFilters) } label: {
                        Label("Clear All Filters", systemImage: "xmark.circle")
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: store.hasActiveFilter
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease.circle")
                        .font(.system(size: 15, weight: .semibold))
                    if store.hasActiveFilter {
                        Text("Filtered")
                            .font(Theme.courier(12, .semibold))
                    }
                }
                .foregroundStyle(store.hasActiveFilter ? settings.accentColor : Theme.textS)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(settings.bg2).clipShape(Capsule())
            }
            .buttonStyle(.plain)

            // SORT sub-menus
            Menu {
                sortSubMenu(label: "Date Added") {
                    sortItem(.dateAdded, "Newest first")
                    sortItem(.dateOld,   "Oldest first")
                }
                sortSubMenu(label: "Artist") {
                    sortItem(.artistAZ, "A → Z")
                    sortItem(.artistZA, "Z → A")
                }
                sortSubMenu(label: "Album") {
                    sortItem(.albumAZ, "A → Z")
                    sortItem(.albumZA, "Z → A")
                }
                sortSubMenu(label: "Year") {
                    sortItem(.yearAsc,  "Oldest first ↑")
                    sortItem(.yearDesc, "Newest first ↓")
                }
                sortSubMenu(label: "Value") {
                    sortItem(.valueAsc,  "Lowest ↑")
                    sortItem(.valueDesc, "Highest ↓")
                }
                sortSubMenu(label: "Paid") {
                    sortItem(.paidAsc,  "Lowest ↑")
                    sortItem(.paidDesc, "Highest ↓")
                }
                sortSubMenu(label: "Gain") {
                    sortItem(.gainAsc,  "Lowest ↑")
                    sortItem(.gainDesc, "Highest ↓")
                }
                sortSubMenu(label: "Label") {
                    sortItem(.labelAZ, "A → Z")
                    sortItem(.labelZA, "Z → A")
                }
                sortSubMenu(label: "Condition") {
                    sortItem(.condAsc,  "Best first ↑")
                    sortItem(.condDesc, "Worst first ↓")
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 11, weight: .semibold))
                    Text(store.sortBy.rawValue)
                        .font(Theme.courier(12))
                        .lineLimit(1)
                }
                .foregroundStyle(Theme.textS)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(settings.bg2).clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(settings.bg1)
    }

    @ViewBuilder
    private func filterMenu(title: String, options: [String], current: String, onSelect: @escaping (String) -> Void) -> some View {
        if options.count > 2 {   // only show sub-menu if there's actually choice (> "All" + 1)
            Menu(title) {
                ForEach(options, id: \.self) { opt in
                    Button {
                        onSelect(opt)
                    } label: {
                        if current == opt {
                            Label(opt.isEmpty ? "None" : opt, systemImage: "checkmark")
                        } else {
                            Text(opt.isEmpty ? "None" : opt)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func sortSubMenu<C: View>(label: String, @ViewBuilder content: () -> C) -> some View {
        Menu(label) { content() }
    }

    @ViewBuilder
    private func sortItem(_ sort: CollectionFeature.SortBy, _ label: String) -> some View {
        Button {
            store.send(.sortSelected(sort))
        } label: {
            if store.sortBy == sort {
                Label(label, systemImage: "checkmark")
            } else {
                Text(label)
            }
        }
    }

    // MARK: – Grid
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
            .padding(.bottom, Theme.tabBarHeight)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: – List
    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(displayed) { rec in listRow(rec) }
            }
            .padding(12)
            .padding(.bottom, Theme.tabBarHeight)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    private func listRow(_ rec: Record) -> some View {
        HStack(spacing: 12) {
            Group {
                if settings.showArtwork, let d = rec.coverData, let img = UIImage(data: d) {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    ZStack { settings.bg2; VinylView(color: rec.colorHex) }
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
                        listBadge(rec.year, Color.black.opacity(0.40))
                    }
                    if !rec.genre.isEmpty {
                        listBadge(rec.genre, Color(hex: rec.colorHex).opacity(0.90))
                    }
                    if !rec.rpm.isEmpty {
                        listBadge("\(rec.rpm) RPM", Color(hex: rec.colorHex).opacity(0.65))
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
        .background(settings.bg1)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) { expandedRecord = rec }
        }
    }

    private func listBadge(_ text: String, _ bg: Color) -> some View {
        Text(text).font(Theme.courier(9, .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(bg).clipShape(Capsule())
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

    // MARK: – Auto-fetch missing prices
    @MainActor
    private func autofetchPrices() async {
        let missing = records.filter { $0.discogsId != nil && $0.currentValue == nil }
        guard !missing.isEmpty else { return }
        let token = UserDefaults.standard.string(forKey: "rb_discogs") ?? ""
        for rec in missing {
            guard let did = rec.discogsId else { continue }
            if let price = await DiscogsClient.liveValue.fetchPrice(did, token) { rec.currentValue = price }
            try? await Task.sleep(nanoseconds: 400_000_000)
        }
    }

    // MARK: – Share
    private func shareCollection() {
        let title = store.isWishlist ? "My Wishlist" : "My Collection"
        let lines = displayed.map { r in
            var s = "\(r.album) — \(r.artist)"
            if !r.year.isEmpty  { s += " (\(r.year))" }
            if !r.genre.isEmpty { s += " [\(r.genre)]" }
            return s
        }
        let text = "🎵 \(title) (\(displayed.count) records)\n\n"
            + lines.joined(separator: "\n") + "\n\n— shared via VinCo"
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let scene  = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first, let root = window.rootViewController {
            root.present(av, animated: true)
        }
    }
}

// MARK: – Flip+Zoom Detail Card
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.76)) { isFlipped = true }
            }
        }
    }

    // Front — same as CardView but full-width
    private var front: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if settings.showArtwork, let d = record.coverData, let img = UIImage(data: d) {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    ZStack { settings.bg1; VinylView(color: record.colorHex).padding(40) }
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
                    flipBadge(record.year, Color.black.opacity(0.60))
                }
                if !record.genre.isEmpty {
                    flipBadge(record.genre, Color(hex: record.colorHex).opacity(0.90))
                }
                if !record.rpm.isEmpty {
                    flipBadge("\(record.rpm) RPM", Color(hex: record.colorHex).opacity(0.65))
                }
            }.padding(10)
        }
        .overlay(alignment: .topTrailing) {
            Button { onDismiss() } label: {
                Text("✕").font(Theme.courier(13, .medium)).foregroundStyle(.white.opacity(0.7)).padding(10)
            }.buttonStyle(.plain)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // Back — full record detail
    private var back: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(record.album).font(Theme.courier(15, .bold)).foregroundStyle(Theme.textP).lineLimit(1)
                    Text(record.artist).font(Theme.courier(12)).foregroundStyle(Theme.textS).lineLimit(1)
                }
                Spacer()
                Button { onDismiss() } label: {
                    Text("✕").font(Theme.courier(13)).foregroundStyle(Theme.textT)
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 10)

            Rectangle().fill(Theme.divide).frame(height: 1)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    if !record.year.isEmpty      { infoRow("YEAR",      record.year)      }
                    if !record.genre.isEmpty     { infoRow("GENRE",     record.genre)     }
                    if !record.rpm.isEmpty       { infoRow("RPM",       record.rpm)       }
                    if !record.condition.isEmpty { infoRow("COND.",     record.condition) }
                    if !record.label.isEmpty     { infoRow("LABEL",     record.label)     }
                    if !record.format.isEmpty    { infoRow("FORMAT",    record.format)    }
                    if !record.country.isEmpty   { infoRow("COUNTRY",   record.country)   }
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
                            valItem("PAID",  String(format: "%.0f", p))
                            valItem("VALUE", String(format: "%.0f", v))
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
                                    if isFetchingTracks { ProgressView().tint(settings.accentColor).scaleEffect(0.75) }
                                    else { Image(systemName: "list.bullet").font(.system(size: 12)) }
                                    Text(isFetchingTracks ? "Fetching…" : "Get Tracklist").font(Theme.courier(11))
                                }
                                .foregroundStyle(settings.accentColor)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            Spacer()
                        }
                        Rectangle().fill(Theme.divide).frame(height: 1)
                    } else {
                        Text("TRACKLIST").font(Theme.courier(9, .semibold)).foregroundStyle(Theme.textT)
                            .padding(.horizontal, 14).padding(.top, 8).padding(.bottom, 2)
                        ForEach(record.tracks) { track in
                            VStack(spacing: 0) {
                                HStack(spacing: 6) {
                                    Text("\(track.number)").font(Theme.courier(9)).foregroundStyle(Theme.textT)
                                        .frame(width: 18, alignment: .trailing)
                                    Text(track.name).font(Theme.courier(11)).foregroundStyle(Theme.textS).lineLimit(1)
                                    Spacer()
                                    if !track.durationStr.isEmpty {
                                        Text(track.durationStr).font(Theme.courier(9)).foregroundStyle(Theme.textT)
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
                actionBtn(record.isWishlist ? "square.stack.3d.up" : "heart", Theme.textS) { onMove() }
                Rectangle().fill(Theme.divide).frame(width:1).frame(maxHeight:.infinity)
                actionBtn("trash", .red) { onDelete() }
            }
            .frame(height: 50)
        }
        .background(settings.bg2)
        .aspectRatio(1, contentMode: .fit)
    }

    private func flipBadge(_ text: String, _ bg: Color) -> some View {
        Text(text).font(Theme.courier(9, .bold)).foregroundStyle(.white)
            .padding(.horizontal, 6).padding(.vertical, 3).background(bg).clipShape(Capsule())
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
