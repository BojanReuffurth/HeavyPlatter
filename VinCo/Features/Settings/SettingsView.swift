import SwiftUI
import SwiftData
import ComposableArchitecture
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsFeature>
    @Environment(\.modelContext) private var ctx
    @Environment(Settings.self)  private var settings
    @Environment(\.dismiss)      private var dismiss
    @Query private var all: [Record]

    // MARK: – Transient UI state
    @State private var iconFeedback:  String? = nil
    @State private var currencyMsg:   String? = nil
    @State private var converting:    Bool    = false
    @State private var importMsg:     String? = nil
    @State private var showImporter:  Bool    = false
    @State private var autoBackupMsg: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            ModalNavBar("Settings", onClose: { dismiss() })
            Rectangle().fill(Theme.divide).frame(height: 1)
            tabBar
            Rectangle().fill(Theme.divide).frame(height: 1)
            ScrollView {
                VStack(spacing: 20) {
                    switch store.tab {
                    case .look:    lookTab
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
            .scrollDismissesKeyboard(.interactively)
        }
        .background(settings.bg0.ignoresSafeArea())
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json, .commaSeparatedText, .text],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
    }

    // MARK: – Horizontal tab bar
    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(SettingsFeature.Tab.allCases, id: \.self) { t in
                    Button { store.send(.tabSelected(t)) } label: {
                        VStack(spacing: 6) {
                            Text(t.rawValue)
                                .font(Theme.courier(13, store.tab == t ? .semibold : .regular))
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
        .frame(height: 46).background(settings.bg1)
    }

    // MARK: – LOOK
    private var lookTab: some View {
        @Bindable var settings = settings
        return VStack(spacing: 20) {

            // Background Style — dark & light rows
            RBSection("Background Style") {
                RBRow(divider: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DARK")
                                .font(Theme.courier(10, .semibold)).foregroundStyle(Theme.textT)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(ThemePalette.dark, id: \.name) { paletteSwatch($0) }
                                }.padding(.vertical, 4)
                            }
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("LIGHT")
                                .font(Theme.courier(10, .semibold)).foregroundStyle(Theme.textT)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(ThemePalette.light, id: \.name) { paletteSwatch($0) }
                                }.padding(.vertical, 4)
                            }
                        }
                    }
                }
            }

            // Accent Color
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

            // App Icon
            RBSection("App Icon") {
                RBRow(divider: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            MiniVinylIcon(color: Color(hex: settings.iconAccentHex), size: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("App Icon Color")
                                    .font(Theme.courier(14)).foregroundStyle(Theme.textP)
                                Text("Changes the label colour on your home screen icon")
                                    .font(Theme.courier(12)).foregroundStyle(Theme.textT)
                            }
                        }
                        if let msg = iconFeedback {
                            Text(msg)
                                .font(Theme.courier(11))
                                .foregroundStyle(msg.contains("✓") ? .green : Theme.textT)
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

            // Currency
            RBSection("Currency") {
                RBRow(divider: !converting && currencyMsg == nil) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Settings.currencies, id: \.self) { c in
                                Button {
                                    guard c != settings.currency, !converting else { return }
                                    switchCurrency(to: c)
                                } label: {
                                    Text(c)
                                        .font(Theme.courier(14, settings.currency == c ? .semibold : .regular))
                                        .foregroundStyle(settings.currency == c ? .black : Theme.textS)
                                        .frame(width: 50, height: 36)
                                        .background(settings.currency == c ? settings.accentColor : settings.bg2)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }.buttonStyle(.plain)
                            }
                            if converting {
                                ProgressView().tint(settings.accentColor).scaleEffect(0.8)
                            }
                        }.padding(.vertical, 4)
                    }
                }
                if let msg = currencyMsg {
                    RBRow(divider: false) {
                        Text(msg)
                            .font(Theme.courier(12))
                            .foregroundStyle(msg.contains("✓") || msg.contains("Converted") ? .green : Theme.textT)
                    }
                }
            }

            // Cards
            RBSection("Cards") {
                RBRow {
                    HStack {
                        Text("Show Artwork").font(Theme.courier(14)).foregroundStyle(Theme.textP)
                        Spacer()
                        Toggle("", isOn: $settings.showArtwork).tint(settings.accentColor)
                    }
                }
                RBRow(divider: false) {
                    HStack {
                        Text("Layout").font(Theme.courier(14)).foregroundStyle(Theme.textP)
                        Spacer()
                        HStack(spacing: 8) {
                            ForEach([("grid","square.grid.2x2"),("list","list.bullet")], id: \.0) { val, icon in
                                Button { settings.layout = val } label: {
                                    Image(systemName: icon).font(.system(size: 15))
                                        .foregroundStyle(settings.layout == val ? settings.accentColor : Theme.textT)
                                        .padding(8)
                                        .background(settings.layout == val ? settings.bg2 : Color.clear)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            // Show / Hide
            RBSection("Show / Hide") {
                RBRow {
                    HStack {
                        Text("Value Bar").font(Theme.courier(14)).foregroundStyle(Theme.textP)
                        Spacer()
                        Toggle("", isOn: $settings.showValueBar).tint(settings.accentColor)
                    }
                }
                RBRow {
                    HStack {
                        Text("Suggestions Button").font(Theme.courier(14)).foregroundStyle(Theme.textP)
                        Spacer()
                        Toggle("", isOn: $settings.showSuggestions).tint(settings.accentColor)
                    }
                }
                RBRow(divider: false) {
                    HStack {
                        Text("Stats Button").font(Theme.courier(14)).foregroundStyle(Theme.textP)
                        Spacer()
                        Toggle("", isOn: $settings.showStatsBtn).tint(settings.accentColor)
                    }
                }
            }
        }
    }

    private func paletteSwatch(_ palette: ThemePalette) -> some View {
        let selected = settings.paletteKey == palette.name
        return Button { settings.paletteKey = palette.name } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(palette.bg0)
                        .frame(width: 54, height: 54)
                    VStack(spacing: 2) {
                        HStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 3).fill(palette.bg1).frame(width: 22, height: 22)
                            RoundedRectangle(cornerRadius: 3).fill(palette.bg2).frame(width: 22, height: 22)
                        }
                        HStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 3).fill(palette.bg2).frame(width: 22, height: 22)
                            RoundedRectangle(cornerRadius: 3).fill(palette.bg3).frame(width: 22, height: 22)
                        }
                    }
                }
                .overlay {
                    if selected {
                        RoundedRectangle(cornerRadius: 10).stroke(settings.accentColor, lineWidth: 2)
                    }
                }
                Text(palette.name)
                    .font(Theme.courier(10, selected ? .semibold : .regular))
                    .foregroundStyle(selected ? settings.accentColor : Theme.textT)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: – GENRES
    private var genresTab: some View {
        VStack(spacing: 20) {
            RBSection("Built-in") {
                ForEach(Array(Settings.builtIn.enumerated()), id: \.element) { i, g in
                    RBRow(divider: i < Settings.builtIn.count - 1) {
                        Text(g).font(Theme.courier(14)).foregroundStyle(Theme.textS)
                    }
                }
            }
            RBSection("Custom") {
                if settings.customGenres.isEmpty {
                    RBRow(divider: true) {
                        Text("No custom genres yet.")
                            .font(Theme.courier(13)).foregroundStyle(Theme.textT)
                    }
                } else {
                    ForEach(Array(settings.customGenres.enumerated()), id: \.element) { i, g in
                        RBRow {
                            HStack {
                                Text(g).font(Theme.courier(14)).foregroundStyle(Theme.textP)
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
                            .font(Theme.courier(14)).foregroundStyle(Theme.textP)
                            .tint(settings.accentColor)
                            .onSubmit { addGenre() }
                        Button("Add") { addGenre() }
                            .font(Theme.courier(13, .semibold))
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
            // Export
            RBSection("Export") {
                RBRow {
                    Button { exportJSON() } label: {
                        HStack {
                            Image(systemName: "arrow.up.doc.fill").foregroundStyle(settings.accentColor)
                            Text("Export Backup (JSON)")
                                .font(Theme.courier(14)).foregroundStyle(Theme.textP)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12)).foregroundStyle(Theme.textT)
                        }
                    }.buttonStyle(.plain)
                }
                RBRow(divider: false) {
                    Button { exportCSV() } label: {
                        HStack {
                            Image(systemName: "tablecells").foregroundStyle(settings.accentColor)
                            Text("Export Collection (CSV)")
                                .font(Theme.courier(14)).foregroundStyle(Theme.textP)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12)).foregroundStyle(Theme.textT)
                        }
                    }.buttonStyle(.plain)
                }
            }

            // Import
            RBSection("Import") {
                RBRow(divider: false) {
                    Button { showImporter = true } label: {
                        HStack {
                            Image(systemName: "arrow.down.doc.fill").foregroundStyle(settings.accentColor)
                            Text("Import Backup or CSV")
                                .font(Theme.courier(14)).foregroundStyle(Theme.textP)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12)).foregroundStyle(Theme.textT)
                        }
                    }.buttonStyle(.plain)
                }
                if let msg = importMsg {
                    RBRow(divider: false) {
                        Text(msg)
                            .font(Theme.courier(12))
                            .foregroundStyle(msg.contains("✓") || msg.contains("imported") ? .green : .red)
                    }
                }
            }

            // Auto-Backup
            RBSection("Auto-Backup") {
                RBRow {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Continuous local backup").font(Theme.courier(14)).foregroundStyle(Theme.textP)
                            Text("Saved automatically when app goes to background")
                                .font(Theme.courier(11)).foregroundStyle(Theme.textT)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green).font(.system(size: 16))
                    }
                }
                RBRow(divider: false) {
                    Button {
                        BackupManager.writeAutoBackup(records: all)
                        autoBackupMsg = "Backup written ✓"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { autoBackupMsg = nil }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise").foregroundStyle(settings.accentColor)
                            Text(autoBackupMsg ?? "Write Backup Now")
                                .font(Theme.courier(13))
                                .foregroundStyle(autoBackupMsg != nil ? .green : settings.accentColor)
                            Spacer()
                        }
                    }.buttonStyle(.plain)
                }
            }

            // Stats
            RBSection("Stats") {
                RBRow {
                    HStack {
                        Text("Collection").font(Theme.courier(14)).foregroundStyle(Theme.textS)
                        Spacer()
                        Text("\(all.filter{!$0.isWishlist}.count) records")
                            .font(Theme.courier(13))
                            .foregroundStyle(settings.accentColor)
                    }
                }
                RBRow(divider: false) {
                    HStack {
                        Text("Wishlist").font(Theme.courier(14)).foregroundStyle(Theme.textS)
                        Spacer()
                        Text("\(all.filter{$0.isWishlist}.count) records")
                            .font(Theme.courier(13))
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

            // Discogs
            RBSection("Discogs") {
                RBRow {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("PERSONAL TOKEN")
                            .font(Theme.courier(11, .semibold)).foregroundStyle(Theme.textT)
                        SecureField("Paste token here…", text: $settings.discogsToken)
                            .font(Theme.courier(14)).foregroundStyle(Theme.textP)
                            .tint(settings.accentColor)
                            .autocorrectionDisabled().textInputAutocapitalization(.never)
                    }
                }
                RBRow(divider: false) {
                    Text("Optional — raises rate limit 25 → 60 req/min.\nGet one free at discogs.com/settings/developers")
                        .font(Theme.courier(12)).foregroundStyle(Theme.textT)
                }
            }

            // Spotify
            RBSection("Spotify") {
                RBRow {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Connection status").font(Theme.courier(14)).foregroundStyle(Theme.textP)
                            Text(settings.isSpotifyConnected ? "Connected ✓" : "Not connected")
                                .font(Theme.courier(12))
                                .foregroundStyle(settings.isSpotifyConnected ? .green : Theme.textT)
                        }
                        Spacer()
                        if settings.isSpotifyConnected {
                            Button("Disconnect") {
                                UserDefaults.standard.removeObject(forKey: "rb_sp_token")
                                UserDefaults.standard.removeObject(forKey: "rb_sp_expiry")
                                UserDefaults.standard.removeObject(forKey: "rb_sp_refresh")
                            }
                            .font(Theme.courier(12))
                            .foregroundStyle(.red)
                            .buttonStyle(.plain)
                        }
                    }
                }
                RBRow(divider: false) {
                    Text("Tap the ✦ wand button on the home screen, then choose Spotify to sign in with your account.")
                        .font(Theme.courier(12)).foregroundStyle(Theme.textT)
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
                            Text(msg).font(Theme.courier(13)).foregroundStyle(settings.accentColor)
                        }
                    }
                }
            }
            RBSection("Batch Operations") {
                toolBtn("Fetch Cover Art for All",   icon: "photo.badge.magnifyingglass") { batchCovers() }
                toolBtn("Fetch Tracklists for All",  icon: "music.note.list")             { batchTracks() }
                toolBtn("Refresh Values (Discogs)",  icon: "chart.line.uptrend.xyaxis", last: true) { /* Phase 2 */ }
            }
            RBSection("Danger Zone") {
                RBRow(divider: false) {
                    Button(role: .destructive) { deleteAll() } label: {
                        HStack {
                            Image(systemName: "trash").foregroundStyle(.red)
                            Text("Delete All Records").font(Theme.courier(14)).foregroundStyle(.red)
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
                    Text(label).font(Theme.courier(14)).foregroundStyle(Theme.textP)
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(Theme.textT)
                }
            }.buttonStyle(.plain)
        }
    }

    // MARK: – App Icon
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
                await MainActor.run { iconFeedback = "Change failed: \(error.localizedDescription)" }
            }
        }
    }

    // MARK: – Currency conversion
    private func switchCurrency(to newSymbol: String) {
        let oldCode = settings.currencyCode
        let newCode = Settings.code(for: newSymbol)
        settings.currency = newSymbol   // update display immediately
        converting = true
        currencyMsg = nil
        Task {
            let msg = await CurrencyService.convertAll(
                records: all, from: oldCode, to: newCode
            )
            await MainActor.run {
                converting = false
                currencyMsg = msg + " ✓"
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) { currencyMsg = nil }
            }
        }
    }

    // MARK: – Genre
    private func addGenre() {
        let g = store.newGenre.trimmingCharacters(in: .whitespaces)
        guard !g.isEmpty, !settings.allGenres.contains(g) else { return }
        settings.customGenres = settings.customGenres + [g]
        store.newGenre = ""
    }

    // MARK: – Export
    private func exportJSON() {
        guard let url = BackupManager.exportToTemp(records: all) else { return }
        present(url)
    }

    private func exportCSV() {
        let col = all.filter { !$0.isWishlist }
        let wl  = all.filter {  $0.isWishlist }
        guard let url = CSVExporter.saveToTemp(CSVExporter.export(collection: col, wishlist: wl)) else { return }
        present(url)
    }

    private func present(_ url: URL) {
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let scene  = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first,
           let root   = window.rootViewController {
            root.present(av, animated: true)
        }
    }

    // MARK: – Import
    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .failure(let err):
            importMsg = "Import failed: \(err.localizedDescription)"
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                importMsg = "Permission denied for file."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            guard let data = try? Data(contentsOf: url) else {
                importMsg = "Could not read file."
                return
            }
            let (updated, inserted, errMsg) = BackupManager.importBackup(data: data, context: ctx)
            if let e = errMsg {
                importMsg = e
            } else {
                importMsg = "Imported \(inserted) new, updated \(updated) ✓"
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { importMsg = nil }
            }
        }
    }

    // MARK: – Delete all
    private func deleteAll() {
        all.forEach { ctx.delete($0) }
    }

    // MARK: – Batch covers
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
                   let (data, _) = try? await URLSession.shared.data(from: url) {
                    await MainActor.run { r.coverData = data }
                }
                try? await Task.sleep(nanoseconds: 300_000_000)
                await MainActor.run {
                    _ = store.send(.batchProgress("Fetching covers… \(i+1) / \(missing.count)"))
                }
            }
            await MainActor.run { _ = store.send(.batchDone("Done — \(missing.count) records processed.")) }
        }
    }

    // MARK: – Batch tracks
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
            await MainActor.run { _ = store.send(.batchDone("Done — \(missing.count) records processed.")) }
        }
    }
}
