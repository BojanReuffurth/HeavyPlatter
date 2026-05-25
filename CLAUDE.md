# VinCo — Project Instructions

## Stack
- iOS 17+ / Xcode 26.5 / Swift 6.3.2
- SwiftUI + SwiftData + TCA 1.25.5
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` is set globally

## Key Swift 6.3 / TCA Workarounds
- `@Reducer` body must return `some Reducer<State, Action>` (not `some ReducerOf<Self>`)
- Types used in `ForEach($store.collection)` binding pattern need **`nonisolated`** `Equatable`/`Hashable` conformances (see `Track.swift`)
- `@Observable` + UserDefaults `didSet` instead of `ObservableObject` + `@AppStorage`
- Always add `import Foundation` explicitly in feature files

## Workflow Rules (applied in every session — see ~/.claude/CLAUDE.md)
1. Read the whole instruction first.
2. Plan ahead.
3. Ask / suggest alternatives before executing.
4. Ensure no existing functionality is compromised.
