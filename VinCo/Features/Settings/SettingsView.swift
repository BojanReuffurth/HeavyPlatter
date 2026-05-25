import SwiftUI
import SwiftData
import ComposableArchitecture

struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsFeature>
    @Environment(\.modelContext) private var ctx
    @Environment(Settings.self) private var settings
    @Query private var all: [Record]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabBar
                Rectangle().fill(Theme.divide).frame(height: 1)
                ScrollView {
                    VStack(spacing: 20) {
                        switch store.tab {
                        case .look:    lookTab
                        case .profile: profileTab
                        case .genres:  genresTab
                        case .backup:  backupTab
                        case .connect: connectTab
                        case .tools:   toolsTab
                        }
                    }
                    .padding(16).padding(.bottom, 40)
                    .animation(.easeInOut(duration: 0.15), value: store.tab)
                }
                .scrollIndicators(.hidden)
            }
            .background(Theme.bg0.ignoresSafeArea())
            .navigationTitle("Settings")
            .toolbarBackground(Theme.bg1, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CloseButton()
                }
            }
        }
    }

    // MARK: – Horizontal tab bar (matches PWA look)
    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(SettingsFeature.Tab.allCases, id: \.self) { t in
                    Button { store.send(.tabSelected(t)) } label: {
                        VStack(spacing: 6) {
                            Text(t.rawValue)
                                .font(.system(size: 13, weight: store.tab == t ? .semibold : .regular))
                                .foregroundStyle(store.tab == t ? settings.accentColor : Theme.textS)
                            Rectangle()
                                .fill(store.tab == t ? settings.accentColor : Color.clear)
                                .frame(height: 2)
                        }
                        .padding(.horizontal, 18).padding(.top, 10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(height: 46).background(Theme.bg1)
    }

    @State private var iconFeedback: String? = nil

    // MARK: – LOOK
    private var lookTab: some View {
        @Bindable var settings = settings
        return VStack(spacing: 20) {
            RBSection("Color Scheme") {
                RBRow(divider: false) {
                    HStack(spacing: 10) {
                        ForEach([("System","system"),("Light","light"),("Dark","dark")], id: \.1) { lbl, key in
                            Button { settings.schemeKey = key } label: {
                                Text(lbl)
                                    .font(.system(size: 13, weight: settings.schemeKey == key ? .semibold : .regular))
                                    .foregroundStyle(settings.schemeKey == key ? .black : Theme.textS)
                                    .padding(.horizontal, 16).padding(.vertical, 8)
                                    .background(settings.schemeKey == key ? settings.accentColor : Theme.bg2)
                                    .clipShape(Capsule())
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }

            RBSection("Accent Color") {
                RBRow(divider: false) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Settings.accents, id: \.1) { _, hex in
                                ZStack {
                                    Circle().fill(Color(hex: hex)).frame(width: 34, height: 34)
                                    if settings.accentHex == hex {
                                        Circle().stroke(Color.white, lineWidth: 2.5).frame(width: 40, height: 40)
                                    }
                                }
                                .onTapGesture { settings.accentHex = hex }
                            }
                        }.padding(.vertical, 4)
                    }
                }
            }

            RBSection("App Icon") {
                RBRow(divider: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            MiniVinylIcon(color: Color(hex: settings.iconAccentHex), size: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("App Icon Color")
                                    .font(.system(size: 14)).foregroundStyle(Theme.textP)
                                Text("Changes the label colour on your home screen icon")
                                    .font(.system(size: 12)).foregroundStyle(Theme.textT)
                            }
                        }
                        if let msg = iconFeedback {
                            Text(msg)
                                .font(.system(size: 11)).foregroundStyle(
                                    msg.contains("✓") ? .green : Theme.textT
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Settings.accents, id: \.1) { name, hex in
                                    ZStack {
                                        Circle().fill(Color(hex: hex)).frame(width: 30, height: 30)
                                        if settings.iconAccentHex == hex {
                                            Circle().stroke(Color.white, lineWidth: 2.5).frame(width: 36, height: 36)
                                        }
                                    }
                                    .onTapGesture { applyAppIcon(name: name, hex: hex) }
                                }
                            }.padding(.vertical, 4)
                        }
                    }
                }
            }

            RBSection("Currency") {
                RBRow(divider: false) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Settings.currencies, id: \.self) { c in
                                Button { settings.currency = c } label: {
                                    Text(c)
                                        .font(.system(size: 14, weight: settings.currency == c ? .semibold : .regular))
                                        .foregroundStyle(settings.currency == c ? .black : Theme.textS)
                                        .frame(width: 44, height: 36)
                                        .background(settings.currency == c ? settings.accentColor : Theme.bg2)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }.buttonStyle(.plain)
                            }
                        }.padding(.vertical, 4)
                    }
                }
            }

            RBSection("Cards") {
                RBRow {
                    HStack {
                        Text("Show Artwork").font(.system(size: 14)).foregroundStyle(Theme.textP)
                        Spacer()
                        Toggle("", isOn: $settings.showArtwork).tint(settings.accentColor)
                    }
                }
                RBRow(divider: false) {
                    HStack {
                        Text("Layout").font(.system(size: 14)).foregroundStyle(Theme.textP)
                        Spacer()
                        HStack(spacing: 8) {
                            ForEach([("grid","square.grid.2x2"),("list","list.bullet")], id: \.0) { val, icon in
                                Button { settings.layout = val } label: {
                                    Image(systemName: icon).font(.system(size: 15))
                                        .foregroundStyle(settings.layout == val ? settings.accentColor : Theme.textT)
                                        .padding(8)
                                        .background(settings.layout == val ? Theme.bg3 : Color.clear)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: – PROFILE
    private var profileTab: some View {
        @Bindable var settings = settings
        return VStack(spacing: 20) {
            RBSection("Identity") {
                RBRow {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("USERNAME")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.textT)
                        TextField("Choose a username…", text: $settings.username)
                            .font(.system(size: 14)).foregroundStyle(Theme.textP)
                            .tint(settings.accentColor)
                            .autocorrectionDisabled().textInputAutocapitalization(.never)
                    }
                }
                RBRow(divider: false) {
                    HStack {
                        Text("Public Profile").font(.system(size: 14)).foregroundStyle(Theme.textP)
                        Spacer()
                        Toggle("", isOn: $settings.isPublic).tint(settings.accentColor)
                    }
                }
            }
            if !settings.username.isEmpty {
                RBSection("Profile URL") {
                    RBRow(divider: false) {
                        Text("vinco.app/u/\(settings.username)")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(settings.accentColor)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    // MARK: – GENRES
    private var genresTab: some View {
        VStack(spacing: 20) {
            RBSection("Built-in") {
                ForEach(Array(Settings.builtIn.enumerated()), id: \.element) { i, g in
                    RBRow(divider: i < Settings.builtIn.count - 1) {
                        Text(g).font(.system(size: 14)).foregroundStyle(Theme.textS)
                    }
                }
            }
            RBSection("Custom") {
                if settings.customGenres.isEmpty {
                    RBRow(divider: true) {
                        Text("No custom genres yet.")
                            .font(.system(size: 13)).foregroundStyle(Theme.textT)
                    }
                } else {
                    ForEach(Array(settings.customGenres.enumerated()), id: \.element) { i, g in
                        RBRow {
                            HStack {
                                Text(g).font(.system(size: 14)).foregroundStyle(Theme.textP)
                                Spacer()
                                Button {
                                    var list = settings.customGenres
                                    list.remove(at: i)
                                    settings.customGenres = list
                                } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.textT)
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }
                RBRow(divider: false) {
                    HStack {
                        TextField("Add genre…", text: $store.newGenre)
                            .font(.system(size: 14)).foregroundStyle(Theme.textP)
                            .tint(settings.accentColor)
                            .onSubmit { addGenre() }
                        Button("Add") { addGenre() }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(store.newGenre.trimmingCharacters(in: .whitespaces).isEmpty
                                             ? Theme.textT : settings.accentColor)
                            .disabled(store.newGenre.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
    }

    // MARK: – BACKUP
    private var backupTab: some View {
        VStack(spacing: 20) {
            RBSection("Export") {
                RBRow(divider: false) {
                    Button { exportCSV() } label: {
                        HStack {
                            Image(systemName: "arrow.up.doc").foregroundStyle(settings.accentColor)
                            Text("Export Collection to CSV")
                                .font(.system(size: 14)).foregroundStyle(Theme.textP)
                            Spacer()
                        }
                    }.buttonStyle(.plain)
                }
            }
            RBSection("Stats") {
                RBRow {
                    HStack {
                        Text("Collection").font(.system(size: 14)).foregroundStyle(Theme.textS)
                        Spacer()
                        Text("\(all.filter{!$0.isWishlist}.count) records")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(settings.accentColor)
                    }
                }
                RBRow(divider: false) {
                    HStack {
                        Text("Wishlist").font(.system(size: 14)).foregroundStyle(Theme.textS)
                        Spacer()
                        Text("\(all.filter{$0.isWishlist}.count) records")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(settings.accentColor)
                    }
                }
            }
        }
    }

    // MARK: – CONNECT
    private var connectTab: some View {
        @Bindable var settings = settings
        return VStack(spacing: 20) {
            RBSection("Discogs") {
                RBRow {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("PERSONAL TOKEN")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.textT)
                        SecureField("Paste token here…", text: $settings.discogsToken)
                            .font(.system(size: 14)).foregroundStyle(Theme.textP)
                            .tint(settings.accentColor)
                            .autocorrectionDisabled().textInputAutocapitalization(.never)
                    }
                }
                RBRow(divider: false) {
                    Text("Optional — raises rate limit 25 → 60 req/min.\nGet one free at discogs.com/settings/developers")
                        .font(.system(size: 12)).foregroundStyle(Theme.textT)
                }
            }
            RBSection("Spotify") {
                RBRow {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("CLIENT ID")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.textT)
                        SecureField("Paste Client ID here…", text: $settings.spotifyId)
                            .font(.system(size: 14)).foregroundStyle(Theme.textP)
                            .tint(settings.accentColor)
                            .autocorrectionDisabled().textInputAutocapitalization(.never)
                    }
                }
                RBRow(divider: false) {
                    Text("Create a free app at developer.spotify.com, add your redirect URI, then paste the Client ID above.")
                        .font(.system(size: 12)).foregroundStyle(Theme.textT)
                }
            }
        }
    }

    // MARK: – TOOLS
    private var toolsTab: some View {
        VStack(spacing: 20) {
            if let msg = store.batchMsg {
                RBSection {
                    RBRow(divider: false) {
                        HStack(spacing: 10) {
                            if store.batchRunning { ProgressView().tint(settings.accentColor) }
                            Text(msg).font(.system(size: 13)).foregroundStyle(settings.accentColor)
                        }
                    }
                }
            }
            RBSection("Batch Operations") {
                toolBtn("Fetch Cover Art for All",     icon: "photo.badge.magnifyingglass") { batchCovers() }
                toolBtn("Fetch Tracklists for All",    icon: "music.note.list")             { batchTracks() }
                toolBtn("Refresh Values (Discogs)",    icon: "chart.line.uptrend.xyaxis", last: true) { /* Phase 2 */ }
            }
            RBSection("Danger Zone") {
                RBRow(divider: false) {
                    Button(role: .destructive) { deleteAll() } label: {
                        HStack {
                            Image(systemName: "trash").foregroundStyle(.red)
                            Text("Delete All Records").font(.system(size: 14)).foregroundStyle(.red)
                            Spacer()
                        }
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private func toolBtn(_ label: String, icon: String, last: Bool = false, action: @escaping () -> Void) -> some View {
        RBRow(divider: !last) {
            Button(action: action) {
                HStack {
                    Image(systemName: icon).foregroundStyle(settings.accentColor)
                    Text(label).font(.system(size: 14)).foregroundStyle(Theme.textP)
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(Theme.textT)
                }
            }.buttonStyle(.plain)
        }
    }

    // MARK: – Helpers
    private func applyAppIcon(name: String, hex: String) {
        settings.iconAccentHex = hex
        guard UIApplication.shared.supportsAlternateIcons else {
            iconFeedback = "Icon switching requires a real device (not Simulator)."
            return
        }
        let iconName: String? = (name == "Amber") ? nil : "VinCo-Icon-\(name)"
        Task {
            do {
                try await UIApplication.shared.setAlternateIconName(iconName)
                await MainActor.run { iconFeedback = "Icon changed to \(name) ✓" }
            } catch {
                await MainActor.run {
                    iconFeedback = "Change failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func addGenre() {
        let g = store.newGenre.trimmingCharacters(in: .whitespaces)
        guard !g.isEmpty, !settings.allGenres.contains(g) else { return }
        settings.customGenres = settings.customGenres + [g]
        store.newGenre = ""
    }

    private func exportCSV() {
        let col = all.filter { !$0.isWishlist }
        let wl  = all.filter {  $0.isWishlist }
        guard let url = CSVExporter.saveToTemp(CSVExporter.export(collection: col, wishlist: wl)) else { return }
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let scene  = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first,
           let root   = window.rootViewController {
            root.present(av, animated: true)
        }
    }

    private func deleteAll() {
        all.forEach { ctx.delete($0) }
    }

    private func batchCovers() {
        let missing = all.filter { $0.coverData == nil }
        guard !missing.isEmpty else {
            store.send(.batchDone("All records already have cover art.")); return
        }
        store.send(.batchProgress("Fetching covers… 0 / \(missing.count)"))
        Task {
            for (i, r) in missing.enumerated() {
                let res = await iTunesClient.liveValue.fetch(r.artist, r.album)
                if let u = res.coverURL, let url = URL(string: u),
                   let (data,_) = try? await URLSession.shared.data(from: url) {
                    await MainActor.run { r.coverData = data }
                }
                try? await Task.sleep(nanoseconds: 300_000_000)
                await MainActor.run {
                    _ = store.send(.batchProgress("Fetching covers… \(i+1) / \(missing.count)"))
                }
            }
            await MainActor.run {
                _ = store.send(.batchDone("Done — \(missing.count) records processed."))
            }
        }
    }

    private func batchTracks() {
        let missing = all.filter { $0.tracks.isEmpty }
        guard !missing.isEmpty else {
            store.send(.batchDone("All records already have tracklists.")); return
        }
        store.send(.batchProgress("Fetching tracklists… 0 / \(missing.count)"))
        Task {
            for (i, r) in missing.enumerated() {
                let res = await iTunesClient.liveValue.fetch(r.artist, r.album)
                if !res.tracks.isEmpty {
                    await MainActor.run { r.tracks = res.tracks }
                } else {
                    let mb = await MusicBrainzClient.liveValue.fetchTracks(r.artist, r.album)
                    if !mb.isEmpty { await MainActor.run { r.tracks = mb } }
                }
                try? await Task.sleep(nanoseconds: 400_000_000)
                await MainActor.run {
                    _ = store.send(.batchProgress("Fetching tracklists… \(i+1) / \(missing.count)"))
                }
            }
            await MainActor.run {
                _ = store.send(.batchDone("Done — \(missing.count) records processed."))
            }
        }
    }
}
