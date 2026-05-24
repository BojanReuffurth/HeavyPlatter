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

    var body: some View {
        NavigationStack {
            ZStack { Theme.bg0.ignoresSafeArea() }
            VStack(spacing: 0) {
                filterBar
                Rectangle().fill(Theme.divide).frame(height: 1)
                if displayed.isEmpty { emptyState }
                else {
                    ScrollView {
                        LazyVGrid(columns: cols, spacing: 12) {
                            ForEach(displayed) { rec in
                                CardView(record: rec)
                                    .onTapGesture { store.send(.recordTapped(rec)) }
                                    .contextMenu { ctxMenu(rec) }
                            }
                        }
                        .padding(12)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .background(Theme.bg0)
            .navigationTitle(store.isWishlist ? "Wishlist" : "Collection")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Theme.bg1, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .searchable(text: $store.search.sending(\.searchChanged), prompt: "Search…")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("\(displayed.count)")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.textT)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { store.send(.addTapped) } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3).foregroundStyle(settings.accentColor)
                    }
                }
            }
            .sheet(item: $store.scope(state: \.detail, action: \.detail)) { s in
                DetailView(store: s)
            }
            .sheet(item: $store.scope(state: \.edit, action: \.edit)) { s in
                EditView(store: s)
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    ForEach(CollectionFeature.SortBy.allCases, id: \.self) { opt in
                        Button {
                            store.send(.sortSelected(opt))
                        } label: {
                            if store.sortBy == opt {
                                Label(opt.rawValue, systemImage: "checkmark")
                            } else {
                                Text(opt.rawValue)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.up.arrow.down").font(.system(size: 11, weight: .semibold))
                        Text(store.sortBy.rawValue).font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(Theme.textS)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Theme.bg2).clipShape(Capsule())
                }
                .buttonStyle(.plain)
                ForEach(genres, id: \.self) { g in
                    Button { store.send(.genreSelected(g)) } label: {
                        Text(g)
                            .font(.system(size: 13, weight: store.genre == g ? .semibold : .regular))
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

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: store.isWishlist ? "heart.slash" : "square.stack.3d.up.slash")
                .font(.system(size: 56)).foregroundStyle(Theme.textT)
            Text(store.isWishlist ? "Wishlist is empty" : "Collection is empty")
                .font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.textS)
            Button { store.send(.addTapped) } label: {
                Label("Add a Record", systemImage: "plus")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(.black)
                    .padding(.horizontal, 24).padding(.vertical, 11)
                    .background(settings.accentColor).clipShape(Capsule())
            }
            .buttonStyle(.plain)
            Spacer()
        }
    }

    @ViewBuilder
    private func ctxMenu(_ rec: Record) -> some View {
        Button { store.send(.recordTapped(rec)) } label: { Label("Open", systemImage: "eye") }
        Button { rec.isWishlist.toggle() } label: {
            Label(rec.isWishlist ? "Move to Collection" : "Move to Wishlist",
                  systemImage: rec.isWishlist ? "square.stack.3d.up" : "heart")
        }
        Divider()
        Button(role: .destructive) { ctx.delete(rec) } label: { Label("Delete", systemImage: "trash") }
    }
}
