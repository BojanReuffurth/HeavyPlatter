import SwiftUI
import SwiftData
import ComposableArchitecture
import AuthenticationServices
import CryptoKit
import MediaPlayer

// MARK: – Spotify app credentials (developer-set, not user-entered)
// 1. Register VinCo at developer.spotify.com (free).
// 2. Add redirect URI: vinco-app://spotify
// 3. Paste your Client ID below — users just tap "Connect with Spotify" in the app.
private let kSpotifyClientId = "72560920d9cd4dcaa0c062ae9db0bead"

// MARK: – Main view

struct SuggestionsView: View {
    @Bindable var store: StoreOf<SuggestionsFeature>
    @Environment(\.modelContext) private var ctx
    @Environment(Settings.self)  private var settings
    @Environment(\.dismiss)      private var dismiss

    @Query private var allRecords: [Record]

    // MARK: Derived collection data

    private var topGenres: [String] {
        var c: [String: Int] = [:]
        allRecords.filter { !$0.isWishlist }.forEach { c[$0.genre, default: 0] += 1 }
        return c.sorted { $0.value > $1.value }.map(\.key).filter { !$0.isEmpty }
    }

    private var topArtists: [String] {
        var c: [String: Int] = [:]
        allRecords.filter { !$0.isWishlist }.forEach { c[$0.artist, default: 0] += 1 }
        return c.sorted { $0.value > $1.value }.map(\.key).filter { !$0.isEmpty }
    }

    private var excludedKeys: Set<String> {
        Set(allRecords.map { "\($0.artist.lowercased())|\($0.album.lowercased())" })
    }

    // MARK: View state
    @State private var addedIds:           Set<String>      = []
    @State private var flippedIds:         Set<String>      = []
    @State private var selectedSuggestion: SuggestedRecord? = nil
    @State private var spotifyAuthError:   String?          = nil
    @State private var isAuthenticatingSpotify              = false
    @State private var pkceVerifier:       String           = ""

    private let cols = [GridItem(.adaptive(minimum: 158), spacing: 12)]

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            ModalNavBar("Suggestions", onClose: { dismiss() }) {
                Button {
                    store.send(.refreshTapped(genres: topGenres, artists: topArtists, excluded: excludedKeys))
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15))
                        .foregroundStyle(store.isLoading ? Theme.textT : settings.accentColor)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(store.isLoading)
            }
            Rectangle().fill(Theme.divide).frame(height: 1)

            providerStrip
            Rectangle().fill(Theme.divide).frame(height: 1)
            if store.isLoading {
                loadingView
            } else if store.suggestions.isEmpty {
                emptyView
            } else {
                suggestionsGrid
            }
        }
        .background(settings.bg0.ignoresSafeArea())
        .task { store.send(.appeared(genres: topGenres, artists: topArtists, excluded: excludedKeys)) }
        .sheet(item: $selectedSuggestion) { suggestion in
            SuggestionDetailSheet(suggestion: suggestion, onAdd: { addToWishlist(suggestion) })
                .environment(settings)
                .preferredColorScheme(settings.preferredScheme)
                .environment(\.font, Theme.courier(14))
        }
        .alert("Spotify Error", isPresented: .constant(spotifyAuthError != nil)) {
            Button("OK") { spotifyAuthError = nil }
        } message: { Text(spotifyAuthError ?? "") }
    }

    // MARK: – Provider strip

    private var providerStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(MusicProvider.allCases, id: \.self) { providerChip($0) }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .background(settings.bg1)
    }

    @ViewBuilder
    private func providerChip(_ provider: MusicProvider) -> some View {
        let enabled   = store.enabledProviders.contains(provider)
        let available = isAvailable(provider)
        Button { handleProviderTap(provider) } label: {
            HStack(spacing: 6) {
                Image(systemName: available ? provider.icon : "lock.fill").font(.system(size: 12))
                Text(provider.displayName)
                    .font(Theme.courier(12, enabled && available ? .semibold : .regular))
                if provider == .spotify && store.spotifyExpired {
                    Text("EXPIRED").font(Theme.courier(8, .bold)).foregroundStyle(.orange)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Color.orange.opacity(0.2)).clipShape(Capsule())
                }
                if isAuthenticatingSpotify && provider == .spotify {
                    ProgressView().scaleEffect(0.7).tint(.white)
                }
            }
            .foregroundStyle(chipForeground(provider: provider, enabled: enabled, available: available))
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(chipBackground(provider: provider, enabled: enabled, available: available))
            .clipShape(Capsule())
            .overlay { if !available { Capsule().stroke(Theme.divide, lineWidth: 1) } }
        }
        .buttonStyle(.plain)
    }

    private func chipForeground(provider: MusicProvider, enabled: Bool, available: Bool) -> Color {
        !available ? Theme.textT : (enabled ? .black : Theme.textS)
    }

    private func chipBackground(provider: MusicProvider, enabled: Bool, available: Bool) -> Color {
        guard available else { return settings.bg2 }
        if enabled {
            switch provider {
            case .collectionDNA: return settings.accentColor
            case .appleMusic:    return Color(hex: "#FC3C44")
            case .spotify:       return Color(hex: "#1DB954")
            }
        }
        return settings.bg2
    }

    private func isAvailable(_ provider: MusicProvider) -> Bool {
        switch provider {
        case .collectionDNA: return true
        case .appleMusic:    return store.appleMusicStatus == .authorized
        case .spotify:       return store.spotifyConnected
        }
    }

    private func handleProviderTap(_ provider: MusicProvider) {
        switch provider {
        case .collectionDNA:
            store.send(.providerToggled(provider, genres: topGenres, artists: topArtists, excluded: excludedKeys))
        case .appleMusic:
            switch store.appleMusicStatus {
            case .authorized:
                store.send(.providerToggled(provider, genres: topGenres, artists: topArtists, excluded: excludedKeys))
            case .denied:
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            case .notDetermined:
                store.send(.requestAppleMusic(genres: topGenres, artists: topArtists, excluded: excludedKeys))
            }
        case .spotify:
            if store.spotifyConnected && !store.spotifyExpired {
                store.send(.providerToggled(provider, genres: topGenres, artists: topArtists, excluded: excludedKeys))
            } else {
                startSpotifyAuth()
            }
        }
    }

    // MARK: – Loading / empty states

    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView().scaleEffect(1.4).tint(settings.accentColor)
            Text("Discovering vinyl…").font(Theme.courier(14)).foregroundStyle(Theme.textT)
            Spacer()
        }
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "waveform.slash").font(.system(size: 52)).foregroundStyle(Theme.textT)
            Text("No suggestions found").font(Theme.courier(16)).foregroundStyle(Theme.textS)
            Text("Try enabling more providers,\nor add records to your collection.")
                .font(Theme.courier(12)).foregroundStyle(Theme.textT).multilineTextAlignment(.center)
            Button {
                store.send(.refreshTapped(genres: topGenres, artists: topArtists, excluded: excludedKeys))
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise").font(Theme.courier(14, .semibold))
                    .foregroundStyle(.black).padding(.horizontal, 24).padding(.vertical, 11)
                    .background(settings.accentColor).clipShape(Capsule())
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: – Suggestions grid

    private var suggestionsGrid: some View {
        ScrollView {
            LazyVGrid(columns: cols, spacing: 12) {
                ForEach(store.suggestions) { suggestionCard($0) }
            }
            .padding(12).padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: – Card (flippable)

    @ViewBuilder
    private func suggestionCard(_ rec: SuggestedRecord) -> some View {
        let isFlipped    = flippedIds.contains(rec.id)
        let alreadyAdded = addedIds.contains(rec.id) || excludedKeys.contains(rec.id)

        ZStack {
            // Front face
            cardFront(rec, alreadyAdded: alreadyAdded)
                .rotation3DEffect(.degrees(isFlipped ? -90 : 0), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 0 : 1)

            // Back face
            cardBack(rec)
                .rotation3DEffect(.degrees(isFlipped ? 0 : 90), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 1 : 0)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: isFlipped)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardR)
                .stroke(alreadyAdded ? Color.green.opacity(0.4) : Color.clear, lineWidth: 1.5)
        )
    }

    // MARK: – Card front

    @ViewBuilder
    private func cardFront(_ rec: SuggestedRecord, alreadyAdded: Bool) -> some View {
        VStack(spacing: 0) {
            // Cover + overlays
            ZStack {
                coverImage(for: rec)
                    .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit).clipped()

                // Bottom gradient
                LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
                    .aspectRatio(1, contentMode: .fit)

                // Bottom-left: album / artist
                VStack {
                    Spacer()
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rec.album).font(Theme.courier(13, .bold)).foregroundStyle(.white).lineLimit(1)
                            Text(rec.artist).font(Theme.courier(11)).foregroundStyle(.white.opacity(0.80)).lineLimit(1)
                        }
                        .padding(10)
                        Spacer()
                    }
                }
            }

            // Meta row
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 3) {
                    if !rec.year.isEmpty {
                        Text(rec.year).font(Theme.courier(10)).foregroundStyle(Theme.textT)
                    }
                    if !rec.genre.isEmpty {
                        Text(rec.genre).font(Theme.courier(10, .semibold)).foregroundStyle(Theme.textS).lineLimit(1)
                    }
                }
                Spacer()
                if alreadyAdded {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 22)).foregroundStyle(.green)
                } else {
                    Button { addToWishlist(rec) } label: {
                        Image(systemName: "heart.badge.plus").font(.system(size: 20)).foregroundStyle(settings.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(settings.bg1)

            providerBadge(rec.provider)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                flippedIds = flippedIds.union([rec.id])
            }
        }
        .background(settings.bg2)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardR))
    }

    // MARK: – Card back (rating)

    @ViewBuilder
    private func cardBack(_ rec: SuggestedRecord) -> some View {
        VStack(spacing: 0) {
            // Info area matching the cover square
            ZStack {
                settings.bg3
                VStack(spacing: 8) {
                    Image(systemName: "star.bubble.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(settings.accentColor.opacity(0.6))
                    Text(rec.album)
                        .font(Theme.courier(14, .bold)).foregroundStyle(Theme.textP)
                        .lineLimit(2).multilineTextAlignment(.center)
                    Text(rec.artist)
                        .font(Theme.courier(11)).foregroundStyle(Theme.textT).lineLimit(1)
                    Text("Rate this suggestion")
                        .font(Theme.courier(10)).foregroundStyle(Theme.textT)
                        .padding(.top, 4)
                }
                .padding(14)
            }
            .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)

            // Thumbs row
            HStack(spacing: 0) {
                // Thumbs UP
                Button {
                    store.send(.thumbsUp(rec))
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) { flippedIds = flippedIds.subtracting([rec.id]) }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "hand.thumbsup.fill").font(.system(size: 22))
                        Text("MORE LIKE THIS").font(Theme.courier(7, .bold)).lineLimit(1)
                    }
                    .foregroundStyle(Color(hex: "#34C759"))
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Color(hex: "#34C759").opacity(0.12))
                }
                .buttonStyle(.plain)

                Rectangle().fill(Theme.divide).frame(width: 1, height: 40)

                // Thumbs DOWN
                Button {
                    store.send(.thumbsDown(rec))
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) { flippedIds = flippedIds.subtracting([rec.id]) }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "hand.thumbsdown.fill").font(.system(size: 22))
                        Text("LESS LIKE THIS").font(Theme.courier(7, .bold)).lineLimit(1)
                    }
                    .foregroundStyle(Color(hex: "#FF3B30"))
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Color(hex: "#FF3B30").opacity(0.12))
                }
                .buttonStyle(.plain)
            }
            .background(settings.bg1)

            // Bottom: flip-back | provider | details
            HStack {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) { flippedIds = flippedIds.subtracting([rec.id]) }
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.textT)
                        .padding(.leading, 10)
                }
                .buttonStyle(.plain)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: rec.provider.icon).font(.system(size: 9))
                    Text(rec.provider.displayName.uppercased()).font(Theme.courier(8, .semibold))
                }
                .foregroundStyle(Theme.textT)
                Spacer()
                Button { selectedSuggestion = rec } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(settings.accentColor)
                        .padding(.trailing, 10)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 5)
            .background(settings.bg1)
        }
        .background(settings.bg2)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardR))
    }

    // MARK: – Cover image

    @ViewBuilder
    private func coverImage(for rec: SuggestedRecord) -> some View {
        // Prefer cover_image (higher-res) over thumb
        let url = rec.coverImageURL.isEmpty ? rec.coverURL : rec.coverImageURL
        if url.isEmpty {
            ZStack { settings.bg3; VinylView(color: Record.randomColor()).padding(28) }
        } else {
            AsyncImage(url: URL(string: url)) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFill()
                case .failure: ZStack { settings.bg3; VinylView(color: Record.randomColor()).padding(28) }
                default: ZStack { settings.bg3; ProgressView().tint(settings.accentColor) }
                }
            }
        }
    }

    private func providerBadge(_ provider: MusicProvider) -> some View {
        HStack(spacing: 4) {
            Image(systemName: provider.icon).font(.system(size: 9))
            Text(provider.displayName.uppercased()).font(Theme.courier(8, .semibold))
        }
        .foregroundStyle(Theme.textT)
        .frame(maxWidth: .infinity).padding(.vertical, 5)
        .background(settings.bg1)
    }

    // MARK: – Add to wishlist

    private func addToWishlist(_ suggestion: SuggestedRecord) {
        let record = Record(
            artist: suggestion.artist, album: suggestion.album,
            year: suggestion.year, genre: suggestion.genre,
            label: "", format: suggestion.vinylFormat,
            country: "", notes: "", condition: "VG", isWishlist: true
        )
        record.discogsId = suggestion.discogsId > 0 ? suggestion.discogsId : nil
        record.coverURL  = suggestion.coverImageURL.isEmpty ? suggestion.coverURL : suggestion.coverImageURL
        ctx.insert(record)

        if !record.coverURL.isEmpty {
            Task {
                guard let url = URL(string: record.coverURL),
                      let (data, _) = try? await URLSession.shared.data(from: url)
                else { return }
                await MainActor.run { record.coverData = data }
            }
        }
        _ = withAnimation(.spring(response: 0.3)) { addedIds.insert(suggestion.id) }
    }

    // MARK: – Spotify PKCE auth

    private func startSpotifyAuth() {
        guard !kSpotifyClientId.isEmpty else {
            spotifyAuthError = "Spotify Client ID not configured. Open SuggestionsView.swift and paste your Client ID into kSpotifyClientId."
            return
        }
        guard !isAuthenticatingSpotify else { return }

        let verifier  = generatePKCEVerifier()
        let challenge = generatePKCEChallenge(from: verifier)
        pkceVerifier  = verifier

        let redirectURI = "vinco-app://spotify"
        guard let enc = redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let authURL = URL(string:
                "https://accounts.spotify.com/authorize?client_id=\(kSpotifyClientId)" +
                "&response_type=code&redirect_uri=\(enc)" +
                "&code_challenge=\(challenge)&code_challenge_method=S256&scope=user-top-read")
        else { return }

        isAuthenticatingSpotify = true

        let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "vinco-app") { callbackURL, error in
            isAuthenticatingSpotify = false
            if let e = error as? ASWebAuthenticationSessionError, e.code == .canceledLogin { return }
            guard let callbackURL,
                  let comps = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                  let code = comps.queryItems?.first(where: { $0.name == "code" })?.value
            else {
                spotifyAuthError = "Spotify login failed. Ensure 'vinco-app://spotify' is a registered redirect URI."
                return
            }
            Task { await exchangeSpotifyCode(code: code, verifier: verifier) }
        }
        session.prefersEphemeralWebBrowserSession = false
        session.presentationContextProvider = SpotifyAuthPresenter.shared
        session.start()
    }

    private func exchangeSpotifyCode(code: String, verifier: String) async {
        guard let url = URL(string: "https://accounts.spotify.com/api/token") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = ["client_id=\(kSpotifyClientId)", "grant_type=authorization_code",
                    "code=\(code)", "redirect_uri=vinco-app://spotify", "code_verifier=\(verifier)"].joined(separator: "&")
        req.httpBody = body.data(using: .utf8)
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let resp = try JSONDecoder().decode(SpotifyTokenResp.self, from: data)
            UserDefaults.standard.set(resp.access_token, forKey: "rb_sp_token")
            UserDefaults.standard.set(Date().timeIntervalSince1970 + Double(resp.expires_in), forKey: "rb_sp_expiry")
            if let rt = resp.refresh_token { UserDefaults.standard.set(rt, forKey: "rb_sp_refresh") }
            await MainActor.run {
                store.send(.spotifyTokenSaved)
                if !store.enabledProviders.contains(.spotify) {
                    store.send(.providerToggled(.spotify, genres: topGenres, artists: topArtists, excluded: excludedKeys))
                } else {
                    store.send(.refreshTapped(genres: topGenres, artists: topArtists, excluded: excludedKeys))
                }
            }
        } catch {
            await MainActor.run { spotifyAuthError = "Token exchange failed. Please try again." }
        }
    }

    private func generatePKCEVerifier() -> String {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
        return String((0..<64).map { _ in chars.randomElement()! })
    }

    private func generatePKCEChallenge(from verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: – Spotify auth presenter

private final class SpotifyAuthPresenter: NSObject, ASWebAuthenticationPresentationContextProviding, @unchecked Sendable {
    static let shared = SpotifyAuthPresenter()
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes  = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap(\.windows)
        // Prefer existing key window, then any window; otherwise create on active scene.
        if let w = windows.first(where: \.isKeyWindow) ?? windows.first { return w }
        let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first!
        return ASPresentationAnchor(windowScene: scene)
    }
}

private nonisolated struct SpotifyTokenResp: Decodable {
    let access_token: String; let expires_in: Int; let refresh_token: String?
}

// MARK: – Suggestion detail sheet

struct SuggestionDetailSheet: View {
    let suggestion: SuggestedRecord
    let onAdd:      () -> Void

    @Environment(Settings.self)  private var settings
    @Environment(\.dismiss)      private var dismiss
    @Environment(\.modelContext) private var ctx

    @Query private var allRecords: [Record]

    @StateObject private var audio           = AudioPlayer()
    @State private var releaseDetail:    DiscogsReleaseDetail? = nil
    @State private var isLoadingDetail:  Bool                  = false
    @State private var iTunesTracks:     [Track]?              = nil

    // Already in collection or wishlist
    private var alreadyHave: Bool {
        allRecords.contains {
            $0.artist.lowercased() == suggestion.artist.lowercased() &&
            $0.album.lowercased()  == suggestion.album.lowercased()
        }
    }

    // Best cover: release detail > cover_image > thumb
    private var bestCoverURL: String {
        if let d = releaseDetail, !d.coverImageURL.isEmpty { return d.coverImageURL }
        if !suggestion.coverImageURL.isEmpty { return suggestion.coverImageURL }
        return suggestion.coverURL
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView {
                VStack(spacing: 0) {
                    coverSection
                    headerSection
                    metaSection
                    if isLoadingDetail {
                        ProgressView().tint(settings.accentColor).padding(.vertical, 24)
                    } else {
                        if let detail = releaseDetail {
                            if !detail.labels.isEmpty || !detail.country.isEmpty {
                                detailInfoSection(detail)
                            }
                            if detail.communityHave > 0 || detail.communityWant > 0 || detail.lowestPrice != nil {
                                marketSection(detail)
                            }
                        }
                        if let iTracks = iTunesTracks, !iTracks.isEmpty {
                            iTunesTracklistSection(iTracks)
                        } else if let detail = releaseDetail, !detail.tracklist.isEmpty {
                            tracklistSection(detail.tracklist)
                        }
                    }
                    ctaSection
                }
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(settings.bg0.ignoresSafeArea())
            .onDisappear { audio.stop() }

            // Floating close button — overlaid on cover, top-left
            // frame(44,44) + .padding(.leading,8) matches ModalNavBar centre-from-edge
            Button { dismiss() } label: {
                Text("✕")
                    .font(Theme.courier(15))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
        }
        .task { await loadDetails() }
    }

    // MARK: Cover

    private var coverSection: some View {
        ZStack(alignment: .bottom) {
            Group {
                if bestCoverURL.isEmpty {
                    ZStack { settings.bg2; VinylView(color: Record.randomColor()).padding(50) }
                } else {
                    AsyncImage(url: URL(string: bestCoverURL)) { phase in
                        switch phase {
                        case .success(let img): img.resizable().scaledToFill()
                        case .failure: ZStack { settings.bg2; VinylView(color: Record.randomColor()).padding(50) }
                        default: ZStack { settings.bg2; ProgressView().tint(settings.accentColor) }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit).clipped()

            LinearGradient(colors: [.clear, settings.bg0], startPoint: .center, endPoint: .bottom)
                .frame(height: 140)
        }
    }

    // MARK: Header (artist / album)

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(suggestion.artist.uppercased())
                .font(Theme.courier(11, .semibold)).foregroundStyle(Theme.textT).tracking(1)
            Text(suggestion.album)
                .font(Theme.courier(22, .bold)).foregroundStyle(Theme.textP)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 14)
    }

    // MARK: Meta pills (year / genre / format)

    private var metaSection: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if !suggestion.year.isEmpty     { metaPill(suggestion.year,        icon: "calendar") }
                    if !suggestion.genre.isEmpty    { metaPill(suggestion.genre,       icon: "music.note") }
                    metaPill(suggestion.vinylFormat, icon: "opticaldisc")
                    // Styles from release detail
                    if let detail = releaseDetail {
                        ForEach(detail.styles.prefix(2), id: \.self) { metaPill($0, icon: "tag") }
                    }
                }
                .padding(.horizontal, 20)
            }

            // Provider row
            HStack(spacing: 6) {
                Image(systemName: suggestion.provider.icon).font(.system(size: 12))
                Text("Suggested via \(suggestion.provider.displayName)").font(Theme.courier(13))
            }
            .foregroundStyle(Theme.textT)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)

            Rectangle().fill(Theme.divide).frame(height: 1).padding(.horizontal, 20)
        }
        .padding(.bottom, 4)
    }

    // MARK: Label / country row

    private func detailInfoSection(_ detail: DiscogsReleaseDetail) -> some View {
        VStack(spacing: 0) {
            if !detail.labels.isEmpty {
                infoRow(label: "LABEL", value: detail.labels.prefix(2).joined(separator: " · "))
            }
            if !detail.country.isEmpty {
                infoRow(label: "COUNTRY", value: detail.country)
            }
            Rectangle().fill(Theme.divide).frame(height: 1).padding(.horizontal, 20).padding(.top, 4)
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(Theme.courier(10, .semibold)).foregroundStyle(Theme.textT).tracking(1).frame(width: 68, alignment: .leading)
            Text(value).font(Theme.courier(13)).foregroundStyle(Theme.textP).lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 20).padding(.vertical, 8)
    }

    // MARK: Market stats

    private func marketSection(_ detail: DiscogsReleaseDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DISCOGS MARKET").font(Theme.courier(10, .semibold)).foregroundStyle(Theme.textT)
                .tracking(1).padding(.horizontal, 20).padding(.top, 14)

            HStack(spacing: 0) {
                if let price = detail.lowestPrice, price > 0 {
                    marketBadge(label: "FROM", value: String(format: "%.2f %@", price, UserDefaults.standard.string(forKey: "rb_currency") ?? ""))
                }
                if detail.communityHave > 0 {
                    marketBadge(label: "HAVE", value: "\(detail.communityHave)")
                }
                if detail.communityWant > 0 {
                    marketBadge(label: "WANT", value: "\(detail.communityWant)")
                }
                if let rating = detail.rating, detail.ratingCount > 0 {
                    marketBadge(label: "RATING", value: String(format: "%.1f (%d)", rating, detail.ratingCount))
                }
            }
            .padding(.horizontal, 20)

            Rectangle().fill(Theme.divide).frame(height: 1).padding(.horizontal, 20).padding(.top, 4)
        }
    }

    private func marketBadge(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label).font(Theme.courier(8, .semibold)).foregroundStyle(Theme.textT)
            Text(value).font(Theme.courier(12, .bold)).foregroundStyle(Theme.textP).lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(settings.bg2)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.trailing, 6)
    }

    // MARK: Tracklist

    private func tracklistSection(_ tracks: [DiscogsTrack]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("TRACKLIST").font(Theme.courier(10, .semibold)).foregroundStyle(Theme.textT)
                .tracking(1).padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 6)

            ForEach(tracks) { track in
                HStack(spacing: 10) {
                    Text(track.position.isEmpty ? "•" : track.position)
                        .font(Theme.courier(11)).foregroundStyle(Theme.textT)
                        .frame(width: 28, alignment: .trailing)
                    Text(track.title)
                        .font(Theme.courier(13)).foregroundStyle(Theme.textP).lineLimit(1)
                    Spacer()
                    if !track.duration.isEmpty {
                        Text(track.duration).font(Theme.courier(11)).foregroundStyle(Theme.textT)
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 6)
                Rectangle().fill(Theme.divide.opacity(0.5)).frame(height: 1).padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: CTA

    private var ctaSection: some View {
        Group {
            if alreadyHave {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 20))
                    Text("Already in your collection or wishlist").font(Theme.courier(14, .semibold))
                }
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity).padding(.vertical, 18)
                .background(Color.green.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 20).padding(.top, 20)
            } else {
                Button {
                    onAdd()
                    dismiss()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "heart.badge.plus").font(.system(size: 18, weight: .semibold))
                        Text("Add to Wishlist").font(Theme.courier(16, .semibold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 18)
                    .background(settings.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: settings.accentColor.opacity(0.35), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20).padding(.top, 20)
            }
        }
    }

    // MARK: Helpers

    private func metaPill(_ text: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10))
            Text(text).font(Theme.courier(12, .semibold))
        }
        .foregroundStyle(Theme.textS)
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(settings.bg2).clipShape(Capsule())
    }

    private func iTunesTracklistSection(_ tracks: [Track]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("TRACKLIST").font(Theme.courier(10, .semibold)).foregroundStyle(Theme.textT)
                .tracking(1).padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 6)

            LazyVStack(spacing: 0) {
                ForEach(Array(tracks.enumerated()), id: \.element.id) { i, t in
                    TrackRow(track: t, index: i,
                             playing: audio.currentURL == t.preview && audio.isPlaying,
                             progress: audio.currentURL == t.preview ? audio.progress : 0) {
                        audio.currentURL == t.preview && audio.isPlaying
                            ? audio.pause() : audio.play(url: t.preview)
                    }
                    if i < tracks.count - 1 {
                        Rectangle().fill(Theme.divide).frame(height: 1).padding(.leading, 52)
                    }
                }
            }
            .background(settings.bg1)
            .clipShape(RoundedRectangle(cornerRadius: Theme.sectR))
            .padding(.horizontal, 14).padding(.bottom, 8)
        }
    }

    private func loadDetails() async {
        guard releaseDetail == nil, iTunesTracks == nil else { return }
        isLoadingDetail = true
        let token     = UserDefaults.standard.string(forKey: "rb_discogs") ?? ""
        let discogsId = suggestion.discogsId

        // Start iTunes fetch concurrently while Discogs fetch runs
        async let iTunesOp = iTunesClient.liveValue.fetch(suggestion.artist, suggestion.album)
        if discogsId > 0 {
            async let discogsOp = fetchDiscogsRelease(id: discogsId, token: token)
            releaseDetail = await discogsOp
        }
        let iResult  = await iTunesOp
        iTunesTracks = iResult.tracks.isEmpty ? nil : iResult.tracks
        isLoadingDetail = false
    }
}
