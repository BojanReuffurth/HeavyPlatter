import SwiftUI
import SwiftData
import ComposableArchitecture

struct EditView: View {
    @Bindable var store: StoreOf<EditFeature>
    @Environment(\.dismiss)      private var dismiss
    @Environment(\.modelContext) private var ctx
    @Environment(Settings.self)  private var settings

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    coverBlock
                    discogsBlock
                    detailsBlock
                    pricingBlock
                    tracklistBlock
                    colorBlock
                }
                .padding(16).padding(.bottom, 40)
            }
            .background(Theme.bg0.ignoresSafeArea()).scrollIndicators(.hidden)
            .navigationTitle(store.isEditing ? "Edit Record" : "Add Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bg1, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Text("✕").font(Theme.courier(15)).foregroundStyle(Theme.textT)
                    }.buttonStyle(.plain)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(store.isEditing ? "Save" : "Add") { save() }
                        .font(Theme.courier(14, .semibold))
                        .foregroundStyle(store.canSave ? settings.accentColor : Theme.textT)
                        .disabled(!store.canSave)
                }
            }
            .onAppear { store.send(.appeared) }
        }
    }

    // MARK: – Cover block

    private var coverBlock: some View {
        RBSection {
            VStack(spacing: 14) {
                ZStack {
                    if let d = store.coverData, let img = UIImage(data: d) {
                        Image(uiImage: img).resizable().scaledToFill()
                            .frame(width: 130, height: 130).clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        RoundedRectangle(cornerRadius: 12).fill(Theme.bg2).frame(width: 130, height: 130)
                            .overlay(VinylView(color: store.colorHex).frame(width: 80, height: 80))
                    }
                }
                .padding(.top, 16)
                HStack(spacing: 12) {
                    Button { store.send(.fetchArtTapped) } label: {
                        HStack(spacing: 6) {
                            if store.fetchingArt { ProgressView().tint(.black).scaleEffect(0.8) }
                            else { Image(systemName: "photo.badge.magnifyingglass") }
                            Text(store.fetchingArt ? "Searching…" : "Find Art")
                        }
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(.black)
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(settings.accentColor).clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled((store.artist.isEmpty && store.album.isEmpty) || store.fetchingArt)
                    if store.coverData != nil {
                        Button { store.coverData = nil } label: {
                            Image(systemName: "xmark.circle.fill").font(.system(size: 22)).foregroundStyle(Theme.textT)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: – Discogs block
    private var discogsBlock: some View {
        RBSection("Search Discogs") {
            RBRow(divider: !store.results.isEmpty) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.textT)
                    TextField("Artist or album…", text: $store.query.sending(\.queryChanged))
                        .foregroundStyle(Theme.textP).tint(settings.accentColor)
                        .onSubmit { store.send(.searchTapped) }
                    if store.searching { ProgressView().tint(settings.accentColor) }
                    else {
                        Button("Go") { store.send(.searchTapped) }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(store.query.isEmpty ? Theme.textT : settings.accentColor)
                            .buttonStyle(.plain)
                            .disabled(store.query.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            ForEach(store.results) { r in
                Button { store.send(.resultPicked(r)) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(r.title).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.textP).lineLimit(1)
                            if !r.subtitle.isEmpty { Text(r.subtitle).font(.system(size: 12)).foregroundStyle(Theme.textS) }
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(Theme.textT)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 11)
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
            chipRow("Condition", selection: $store.condition, opts: Settings.conditions)
            field("Label",             $store.label)
            field("Format (LP, 7\"…)", $store.format)
            field("Country",           $store.country)
            RBRow(divider: false) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Notes").font(.system(size: 14)).foregroundStyle(Theme.textS)
                    TextField("Optional…", text: $store.notes, axis: .vertical)
                        .lineLimit(3...6).font(.system(size: 14))
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
                    Text("Paid").font(.system(size: 14)).foregroundStyle(Theme.textS)
                    Spacer()
                    TextField("\(settings.currency) 0", text: $store.paidPrice)
                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        .foregroundStyle(Theme.textP).tint(settings.accentColor).frame(width: 90)
                }
            }
            RBRow(divider: false) {
                HStack {
                    Text("Current Value").font(.system(size: 14)).foregroundStyle(Theme.textS)
                    Spacer()
                    TextField("\(settings.currency) 0", text: $store.curValue)
                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        .foregroundStyle(Theme.textP).tint(settings.accentColor).frame(width: 90)
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
                        Text("Fetching tracks…")
                            .font(.system(size: 13)).foregroundStyle(Theme.textS)
                    }
                }
            } else if store.tracks.isEmpty {
                RBRow(divider: false) {
                    Button { store.send(.fetchTracksTapped) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 13))
                            Text("Fetch Tracklist")
                                .font(.system(size: 13))
                        }
                        .foregroundStyle(
                            (store.artist.isEmpty && store.album.isEmpty)
                                ? Theme.textT : settings.accentColor
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(store.artist.isEmpty && store.album.isEmpty)
                }
            } else {
                ForEach(Array(store.tracks.enumerated()), id: \.element.id) { idx, track in
                    RBRow(divider: idx < store.tracks.count - 1) {
                        HStack(spacing: 8) {
                            Text("\(track.number)")
                                .font(.system(size: 11)).foregroundStyle(Theme.textT)
                                .frame(width: 22, alignment: .trailing)
                            Text(track.name)
                                .font(.system(size: 13)).foregroundStyle(Theme.textP)
                                .lineLimit(1)
                            Spacer()
                            if !track.durationStr.isEmpty {
                                Text(track.durationStr)
                                    .font(.system(size: 11)).foregroundStyle(Theme.textT)
                            }
                        }
                    }
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

    // MARK: – Helpers
    private func field(_ ph: String, _ binding: Binding<String>, kb: UIKeyboardType = .default) -> some View {
        RBRow {
            TextField(ph, text: binding)
                .font(.system(size: 14)).foregroundStyle(Theme.textP)
                .tint(settings.accentColor).keyboardType(kb)
        }
    }

    private func chipRow(_ lbl: String, selection: Binding<String>, opts: [String]) -> some View {
        RBRow {
            VStack(alignment: .leading, spacing: 8) {
                Text(lbl).font(.system(size: 14)).foregroundStyle(Theme.textS)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(opts, id: \.self) { opt in
                            let label = opt.isEmpty ? "None" : opt
                            let selected = selection.wrappedValue == opt
                            Button { selection.wrappedValue = opt } label: {
                                Text(label)
                                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
                                    .foregroundStyle(selected ? .black : Theme.textS)
                                    .padding(.horizontal, 14).padding(.vertical, 7)
                                    .background(selected ? settings.accentColor : Theme.bg2)
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
        r.year   = store.year;   r.genre   = store.genre;  r.label  = store.label
        r.format = store.format; r.country = store.country; r.notes = store.notes
        r.condition = store.condition; r.colorHex = store.colorHex
        if let d = store.coverData { r.coverData = d }
        r.paidPrice    = Double(store.paidPrice)
        r.currentValue = Double(store.curValue)
        if let did = store.discogsId { r.discogsId = did }
        if !store.tracks.isEmpty { r.tracks = store.tracks }
        dismiss()
    }
}
