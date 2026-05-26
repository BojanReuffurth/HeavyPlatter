import SwiftUI
import SwiftData
import PhotosUI
import VisionKit
import ComposableArchitecture

struct EditView: View {
    @Bindable var store: StoreOf<EditFeature>
    @Environment(\.dismiss)      private var dismiss
    @Environment(\.modelContext) private var ctx
    @State private var showConditionGuide = false
    @Environment(Settings.self)  private var settings

    // Scan sheet presentation state (local UI, not in TCA store)
    @State private var showBarcodeScanner = false
    @State private var showCameraCapture  = false
    @State private var showPhotoPicker    = false
    @State private var photoItem: PhotosPickerItem? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Custom header — plain buttons, Courier New title, no iOS 26 glass
            HStack(spacing: 12) {
                Button { dismiss() } label: {
                    Text("✕").font(Theme.courier(15)).foregroundStyle(Theme.textT)
                }.buttonStyle(.plain)
                Text(store.isEditing ? "Edit Record" : "Add Record")
                    .font(Theme.courier(17, .semibold)).foregroundStyle(Theme.textP)
                Spacer()
                Button(store.isEditing ? "Save" : "Add") { save() }
                    .font(Theme.courier(14, .semibold))
                    .foregroundStyle(store.canSave ? settings.accentColor : Theme.textT)
                    .disabled(!store.canSave)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(settings.bg1)
            Rectangle().fill(Theme.divide).frame(height: 1)

            ScrollView {
                VStack(spacing: 20) {
                    if !store.isEditing { scanBlock }
                    coverBlock
                    discogsBlock
                    detailsBlock
                    pricingBlock
                    tracklistBlock
                    colorBlock
                }
                .padding(16).padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .background(settings.bg0.ignoresSafeArea())
        .onAppear { store.send(.appeared) }
        // Condition grading guide
        .sheet(isPresented: $showConditionGuide) {
            ConditionGuideView()
                .environment(settings)
                .presentationDetents([.medium, .large])
        }
        // Barcode scanner — full-screen sheet with live DataScanner
        .sheet(isPresented: $showBarcodeScanner) {
            BarcodeScannerSheet(
                onDetected: { barcode in
                    showBarcodeScanner = false
                    store.send(.barcodeDetected(barcode))
                },
                onCancel: { showBarcodeScanner = false }
            )
            .environment(settings)
            .ignoresSafeArea()
        }
        // Camera capture — for album cover text recognition
        .fullScreenCover(isPresented: $showCameraCapture) {
            CoverCameraView(
                onCapture: { data in
                    showCameraCapture = false
                    store.send(.imageAcquired(data))
                },
                onCancel: { showCameraCapture = false }
            )
            .ignoresSafeArea()
        }
        // Photo library picker — for screenshot / saved image import
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    store.send(.imageAcquired(data))
                }
                photoItem = nil
            }
        }
    }

    // MARK: – Scan block (new records only)
    private var scanBlock: some View {
        RBSection("Quick Fill") {
            RBRow(divider: false) {
                VStack(alignment: .leading, spacing: 14) {
                    // Three scan mode buttons
                    HStack(spacing: 10) {
                        scanModeButton(
                            icon: "barcode.viewfinder",
                            label: "Barcode",
                            active: store.scannedBarcode != nil && store.searching
                        ) { showBarcodeScanner = true }

                        scanModeButton(
                            icon: "camera.viewfinder",
                            label: "Scan Cover",
                            active: false
                        ) { showCameraCapture = true }

                        scanModeButton(
                            icon: "photo.badge.magnifyingglass",
                            label: "Import Photo",
                            active: false
                        ) { showPhotoPicker = true }
                    }

                    // Status row: analysing / searching / scanned-barcode badge
                    if store.recognizing {
                        HStack(spacing: 8) {
                            ProgressView().scaleEffect(0.75).tint(settings.accentColor)
                            Text("Analysing image…")
                                .font(Theme.courier(12)).foregroundStyle(Theme.textS)
                        }
                    } else if store.searching {
                        HStack(spacing: 8) {
                            ProgressView().scaleEffect(0.75).tint(settings.accentColor)
                            Text(store.scannedBarcode != nil ? "Looking up barcode…" : "Searching Discogs…")
                                .font(Theme.courier(12)).foregroundStyle(Theme.textS)
                        }
                    } else if let barcode = store.scannedBarcode {
                        HStack(spacing: 6) {
                            Image(systemName: "barcode")
                                .font(.system(size: 11)).foregroundStyle(Theme.textT)
                            Text(barcode)
                                .font(Theme.courier(11)).foregroundStyle(Theme.textT)
                                .lineLimit(1)
                            Spacer()
                            // Allow re-scanning
                            Button {
                                store.scannedBarcode = nil
                                showBarcodeScanner = true
                            } label: {
                                Text("Re-scan")
                                    .font(Theme.courier(11)).foregroundStyle(settings.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func scanModeButton(icon: String, label: String, active: Bool,
                                action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(active
                              ? settings.accentColor
                              : settings.accentColor.opacity(0.12))
                        .frame(width: 56, height: 56)
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(active ? .black : settings.accentColor)
                }
                Text(label)
                    .font(Theme.courier(10, .semibold))
                    .foregroundStyle(Theme.textS)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: – Cover block
    private var coverBlock: some View {
        RBSection {
            VStack(spacing: 14) {
                // Selected cover or vinyl placeholder
                ZStack {
                    if let d = store.coverData, let img = UIImage(data: d) {
                        Image(uiImage: img).resizable().scaledToFill()
                            .frame(width: 130, height: 130).clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        RoundedRectangle(cornerRadius: 12).fill(settings.bg2).frame(width: 130, height: 130)
                            .overlay(VinylView(color: store.colorHex).frame(width: 80, height: 80))
                    }
                }
                .padding(.top, 16)

                // Find Art / Clear buttons
                HStack(spacing: 12) {
                    Button { store.send(.fetchArtTapped) } label: {
                        HStack(spacing: 6) {
                            if store.fetchingArt { ProgressView().tint(.black).scaleEffect(0.8) }
                            else { Image(systemName: "photo.badge.magnifyingglass") }
                            Text(store.fetchingArt ? "Searching…" : "Find Art")
                        }
                        .font(Theme.courier(13, .semibold)).foregroundStyle(.black)
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(settings.accentColor).clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled((store.artist.isEmpty && store.album.isEmpty) || store.fetchingArt)
                    if store.coverData != nil {
                        // Clears cover; suggestions remain so user can pick another
                        Button { store.coverData = nil } label: {
                            Image(systemName: "xmark.circle.fill").font(.system(size: 22)).foregroundStyle(Theme.textT)
                        }.buttonStyle(.plain)
                    }
                }

                // Cover suggestions strip — shown when multiple options found
                if store.coverSuggestions.count > 1 {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("CHOOSE COVER")
                            .font(Theme.courier(10, .semibold)).foregroundStyle(Theme.textT)
                            .padding(.horizontal, 16)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(store.coverSuggestions, id: \.self) { urlStr in
                                    let isSelected = store.coverData != nil &&
                                        store.coverSuggestions.firstIndex(of: urlStr) ==
                                        store.coverSuggestions.firstIndex(where: { _ in true })
                                    Button {
                                        store.send(.coverSuggestionPicked(urlStr))
                                    } label: {
                                        if let url = URL(string: urlStr) {
                                            AsyncImage(url: url) { img in
                                                img.resizable().scaledToFill()
                                            } placeholder: {
                                                settings.bg2
                                            }
                                            .frame(width: 72, height: 72)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(settings.accentColor, lineWidth: 2)
                                                    .opacity(isSelected ? 1 : 0)
                                            )
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16).padding(.vertical, 4)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 16)
        }
    }

    // MARK: – Discogs block (with artwork thumbnails)
    private var discogsBlock: some View {
        RBSection("Search Discogs") {
            RBRow(divider: !store.results.isEmpty) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.textT)
                    TextField("Artist or album…", text: $store.query.sending(\.queryChanged))
                        .font(Theme.courier(14)).foregroundStyle(Theme.textP).tint(settings.accentColor)
                        .onSubmit { store.send(.searchTapped) }
                    if store.searching { ProgressView().tint(settings.accentColor) }
                    else {
                        Button("Go") { store.send(.searchTapped) }
                            .font(Theme.courier(12, .semibold))
                            .foregroundStyle(store.query.isEmpty ? Theme.textT : settings.accentColor)
                            .buttonStyle(.plain)
                            .disabled(store.query.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            ForEach(store.results) { r in
                Button { store.send(.resultPicked(r)) } label: {
                    HStack(spacing: 10) {
                        // Artwork thumbnail from Discogs
                        Group {
                            if !r.thumbURL.isEmpty, let url = URL(string: r.thumbURL) {
                                AsyncImage(url: url) { img in
                                    img.resizable().scaledToFill()
                                } placeholder: {
                                    settings.bg2
                                }
                            } else {
                                settings.bg2
                            }
                        }
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(r.title)
                                .font(Theme.courier(14, .medium)).foregroundStyle(Theme.textP).lineLimit(1)
                            if !r.subtitle.isEmpty {
                                Text(r.subtitle).font(Theme.courier(12)).foregroundStyle(Theme.textS)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(Theme.textT)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                if r.id != store.results.last?.id {
                    Rectangle().fill(Theme.divide).frame(height: 1).padding(.leading, 16)
                }
            }
        }
    }

    // MARK: – Details block
    private var detailsBlock: some View {
        RBSection("Record Details") {
            field("Artist *",          $store.artist)
            field("Album *",           $store.album)
            field("Year",              $store.year,   kb: .numberPad)
            chipRow("Genre",     selection: $store.genre,     opts: [""] + settings.allGenres)
            chipRow("RPM",       selection: $store.rpm,       opts: [""] + Settings.rpms)
            conditionRow
            field("Label",             $store.label)
            field("Format (LP, 7\"…)", $store.format)
            field("Country",           $store.country)
            RBRow(divider: false) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Notes").font(Theme.courier(14)).foregroundStyle(Theme.textS)
                    TextField("Optional…", text: $store.notes, axis: .vertical)
                        .lineLimit(3...6).font(Theme.courier(14))
                        .foregroundStyle(Theme.textP).tint(settings.accentColor)
                }
            }
        }
    }

    // MARK: – Pricing block
    private var pricingBlock: some View {
        RBSection("Pricing") {
            RBRow {
                HStack {
                    Text("Paid").font(Theme.courier(14)).foregroundStyle(Theme.textS)
                    Spacer()
                    TextField("\(settings.currency) 0", text: $store.paidPrice)
                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        .font(Theme.courier(14)).foregroundStyle(Theme.textP)
                        .tint(settings.accentColor).frame(width: 90)
                }
            }
            RBRow(divider: false) {
                HStack {
                    Text("Current Value").font(Theme.courier(14)).foregroundStyle(Theme.textS)
                    Spacer()
                    TextField("\(settings.currency) 0", text: $store.curValue)
                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        .font(Theme.courier(14)).foregroundStyle(Theme.textP)
                        .tint(settings.accentColor).frame(width: 90)
                }
            }
        }
    }

    // MARK: – Tracklist block
    private var tracklistBlock: some View {
        RBSection("Tracklist") {
            if store.fetchingTracks {
                RBRow(divider: false) {
                    HStack(spacing: 10) {
                        ProgressView().tint(settings.accentColor)
                        Text("Fetching tracks…").font(Theme.courier(13)).foregroundStyle(Theme.textS)
                    }
                }
            } else if store.tracks.isEmpty {
                RBRow(divider: false) {
                    Button { store.send(.fetchTracksTapped) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "list.bullet").font(.system(size: 13))
                            Text("Fetch Tracklist").font(Theme.courier(13))
                        }
                        .foregroundStyle((store.artist.isEmpty && store.album.isEmpty)
                                         ? Theme.textT : settings.accentColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(store.artist.isEmpty && store.album.isEmpty)
                }
            } else {
                ForEach($store.tracks, id: \.id) { $track in
                    RBRow(divider: true) {
                        HStack(spacing: 8) {
                            Text("\(track.number)")
                                .font(Theme.courier(11)).foregroundStyle(Theme.textT)
                                .frame(width: 22, alignment: .trailing)
                            TextField("Track name", text: $track.name)
                                .font(Theme.courier(13)).foregroundStyle(Theme.textP)
                                .tint(settings.accentColor)
                            Spacer()
                            TextField("0:00", text: Binding(
                                get: { track.duration > 0 ? track.durationStr : "" },
                                set: { s in
                                    var updated = track
                                    let parts = s.split(separator: ":").compactMap { Int($0) }
                                    if parts.count == 2 { updated.duration = parts[0]*60 + parts[1] }
                                    else if let sec = Int(s) { updated.duration = sec }
                                    $track.wrappedValue = updated
                                }
                            ))
                            .font(Theme.courier(11)).foregroundStyle(Theme.textT)
                            .keyboardType(.numbersAndPunctuation)
                            .frame(width: 44).multilineTextAlignment(.trailing)
                            .tint(settings.accentColor)
                            Button {
                                if let idx = store.tracks.firstIndex(where: { $0.id == track.id }) {
                                    store.send(.deleteTrack(IndexSet([idx])))
                                }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 18)).foregroundStyle(.red.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                RBRow(divider: false) {
                    Button { store.send(.addEmptyTrack) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16)).foregroundStyle(settings.accentColor)
                            Text("Add Track").font(Theme.courier(13)).foregroundStyle(settings.accentColor)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: – Color block
    private var colorBlock: some View {
        RBSection("Vinyl Color") {
            RBRow(divider: false) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Settings.accents, id: \.1) { _, hex in
                            ZStack {
                                Circle().fill(Color(hex: hex)).frame(width: 32, height: 32)
                                if store.colorHex == hex {
                                    Circle().stroke(Color.white, lineWidth: 2).frame(width: 38, height: 38)
                                }
                            }
                            .onTapGesture { store.colorHex = hex }
                        }
                    }.padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: – Condition row (chip picker + ⓘ guide button)
    private var conditionRow: some View {
        RBRow {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text("Condition").font(Theme.courier(14)).foregroundStyle(Theme.textS)
                    Button { showConditionGuide = true } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textT)
                    }
                    .buttonStyle(.plain)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Settings.conditions, id: \.self) { opt in
                            let selected = store.condition == opt
                            Button { store.condition = opt } label: {
                                Text(opt)
                                    .font(Theme.courier(13, selected ? .semibold : .regular))
                                    .foregroundStyle(selected ? .black : Theme.textS)
                                    .padding(.horizontal, 14).padding(.vertical, 7)
                                    .background(selected ? settings.accentColor : settings.bg2)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: – Helpers
    private func field(_ ph: String, _ binding: Binding<String>, kb: UIKeyboardType = .default) -> some View {
        RBRow {
            TextField(ph, text: binding)
                .font(Theme.courier(14)).foregroundStyle(Theme.textP)
                .tint(settings.accentColor).keyboardType(kb)
        }
    }

    private func chipRow(_ lbl: String, selection: Binding<String>, opts: [String]) -> some View {
        RBRow {
            VStack(alignment: .leading, spacing: 8) {
                Text(lbl).font(Theme.courier(14)).foregroundStyle(Theme.textS)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(opts, id: \.self) { opt in
                            let label    = opt.isEmpty ? "None" : opt
                            let selected = selection.wrappedValue == opt
                            Button { selection.wrappedValue = opt } label: {
                                Text(label)
                                    .font(Theme.courier(13, selected ? .semibold : .regular))
                                    .foregroundStyle(selected ? .black : Theme.textS)
                                    .padding(.horizontal, 14).padding(.vertical, 7)
                                    .background(selected ? settings.accentColor : settings.bg2)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func save() {
        let r: Record
        if let existing = store.record {
            r = existing
        } else {
            r = Record(isWishlist: store.isWishlist)
            ctx.insert(r)
        }
        r.artist = store.artist.trimmingCharacters(in: .whitespaces)
        r.album  = store.album.trimmingCharacters(in: .whitespaces)
        r.year   = store.year;    r.genre     = store.genre;  r.rpm    = store.rpm
        r.label  = store.label;   r.format    = store.format; r.country = store.country
        r.notes  = store.notes;   r.condition = store.condition; r.colorHex = store.colorHex
        r.coverData = store.coverData   // always write — nil clears the cover
        r.paidPrice    = Double(store.paidPrice)
        r.currentValue = Double(store.curValue)
        if let did = store.discogsId { r.discogsId = did }
        if !store.tracks.isEmpty { r.tracks = store.tracks }
        // Auto-add new genre to the custom list
        let g = store.genre.trimmingCharacters(in: .whitespaces)
        if !g.isEmpty && !settings.allGenres.contains(g) {
            settings.customGenres = settings.customGenres + [g]
        }
        dismiss()
    }
}
