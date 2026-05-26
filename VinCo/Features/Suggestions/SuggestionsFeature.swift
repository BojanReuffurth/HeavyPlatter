import Foundation
import ComposableArchitecture
import MediaPlayer

@Reducer
struct SuggestionsFeature {

    // MARK: – Apple Music authorization state

    nonisolated enum AppleMusicStatus: Equatable, Sendable {
        case notDetermined, authorized, denied

        nonisolated init(_ raw: MPMediaLibraryAuthorizationStatus) {
            switch raw {
            case .authorized:           self = .authorized
            case .denied, .restricted:  self = .denied
            default:                    self = .notDetermined
            }
        }
    }

    // MARK: – State

    @ObservableState
    struct State: Equatable {
        var suggestions:      [SuggestedRecord]     = []
        var isLoading:        Bool                  = false
        var enabledProviders: Set<MusicProvider>    = [.collectionDNA]
        var refreshSeed:      Int                   = 0
        var appleMusicStatus: AppleMusicStatus      = .notDetermined
        var preferences:      SuggestionPreferences = SuggestionPreferences()
    }

    // MARK: – Action

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case appeared(genres: [String], artists: [String], excluded: Set<String>)
        case refreshTapped(genres: [String], artists: [String], excluded: Set<String>)
        case providerToggled(MusicProvider, genres: [String], artists: [String], excluded: Set<String>)
        case suggestionsLoaded([SuggestedRecord])
        case requestAppleMusic(genres: [String], artists: [String], excluded: Set<String>)
        case appleMusicStatusChanged(AppleMusicStatus)
        /// User liked a suggestion — boosts similar records in future fetches.
        case thumbsUp(SuggestedRecord)
        /// User disliked a suggestion — removes it now, never shows it again.
        case thumbsDown(SuggestedRecord)
    }

    // MARK: – Dependency

    @Dependency(\.suggestions) var suggestionClient

    // MARK: – Reducer

    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {

            case .appeared(let genres, let artists, let excluded):
                state.enabledProviders = loadPersistedProviders()
                state.preferences      = loadPreferences()
                state.appleMusicStatus = AppleMusicStatus(MPMediaLibrary.authorizationStatus())
                guard !state.isLoading, state.suggestions.isEmpty else { return .none }
                state.isLoading = true
                return fetchEffect(state: state, genres: genres, artists: artists, excluded: excluded)

            case .refreshTapped(let genres, let artists, let excluded):
                state.isLoading = true
                state.refreshSeed += 1
                return fetchEffect(state: state, genres: genres, artists: artists, excluded: excluded)

            case .providerToggled(let provider, let genres, let artists, let excluded):
                if state.enabledProviders.contains(provider) {
                    guard state.enabledProviders.count > 1 else { return .none }
                    state.enabledProviders.remove(provider)
                } else {
                    state.enabledProviders.insert(provider)
                }
                persistProviders(state.enabledProviders)
                state.isLoading = true
                return fetchEffect(state: state, genres: genres, artists: artists, excluded: excluded)

            case .suggestionsLoaded(let list):
                state.isLoading = false
                state.suggestions = list
                return .none

            case .requestAppleMusic(let genres, let artists, let excluded):
                return .run { send in
                    let status = await withCheckedContinuation { cont in
                        MPMediaLibrary.requestAuthorization { s in cont.resume(returning: s) }
                    }
                    let mapped = AppleMusicStatus(status)
                    await send(.appleMusicStatusChanged(mapped))
                    if mapped == .authorized {
                        await send(.refreshTapped(genres: genres, artists: artists, excluded: excluded))
                    }
                }

            case .appleMusicStatusChanged(let s):
                state.appleMusicStatus = s
                return .none

            // MARK: Thumbs Up — boost artist + genre for future fetches
            case .thumbsUp(let rec):
                state.preferences.like(artist: rec.artist, genre: rec.genre)
                savePreferences(state.preferences)
                return .none

            // MARK: Thumbs Down — remove immediately, never show again
            case .thumbsDown(let rec):
                state.suggestions.removeAll { $0.id == rec.id }
                state.preferences.dislikedIds.insert(rec.id)
                savePreferences(state.preferences)
                return .none

            case .binding:
                return .none
            }
        }
    }

    // MARK: – Fetch effect

    private func fetchEffect(state: State,
                             genres: [String], artists: [String],
                             excluded: Set<String>) -> Effect<Action> {
        let providers    = state.enabledProviders
        let seed         = state.refreshSeed
        let discogsToken = UserDefaults.standard.string(forKey: "rb_discogs") ?? ""
        let prefs        = state.preferences
        let client       = suggestionClient
        // Merge user-excluded keys with disliked IDs
        let fullExcluded = excluded.union(prefs.dislikedIds)

        return .run { send in
            let req = SuggestionRequest(
                genres: genres, artists: artists, excluded: fullExcluded,
                providers: providers, seed: seed,
                discogsToken: discogsToken,
                likedArtists: prefs.likedArtists, likedGenres: prefs.likedGenres
            )
            let results = await client.suggest(req)
            await send(.suggestionsLoaded(results))
        }
    }

    // MARK: – Provider persistence

    private func loadPersistedProviders() -> Set<MusicProvider> {
        guard let raw = UserDefaults.standard.string(forKey: "rb_providers"),
              let arr = try? JSONDecoder().decode([String].self, from: Data(raw.utf8))
        else { return [.collectionDNA] }
        let set = Set(arr.compactMap { MusicProvider(rawValue: $0) })
        return set.isEmpty ? [.collectionDNA] : set
    }

    private func persistProviders(_ providers: Set<MusicProvider>) {
        guard let data = try? JSONEncoder().encode(providers.map(\.rawValue)),
              let str  = String(data: data, encoding: .utf8)
        else { return }
        UserDefaults.standard.set(str, forKey: "rb_providers")
    }

    // MARK: – Preferences persistence

    private func loadPreferences() -> SuggestionPreferences {
        guard let data = UserDefaults.standard.data(forKey: "rb_sg_prefs"),
              let prefs = try? JSONDecoder().decode(SuggestionPreferences.self, from: data)
        else { return SuggestionPreferences() }
        return prefs
    }

    private func savePreferences(_ prefs: SuggestionPreferences) {
        guard let data = try? JSONEncoder().encode(prefs) else { return }
        UserDefaults.standard.set(data, forKey: "rb_sg_prefs")
    }
}
