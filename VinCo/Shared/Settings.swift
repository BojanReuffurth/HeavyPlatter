import SwiftUI
import Observation

// MARK: – Theme palette
// Each palette owns absolute bg colors + whether it implies light or dark scheme.
struct ThemePalette: Equatable {
    let name:    String
    let isLight: Bool   // true → forces .light ColorScheme; false → .dark
    let bg0: Color
    let bg1: Color
    let bg2: Color
    let bg3: Color

    static let presets: [ThemePalette] = [
        // ── Dark ──────────────────────────────────────────────────────────
        ThemePalette(name: "Default",  isLight: false,
                     bg0: Color(hex: "#0A0A0A"), bg1: Color(hex: "#111111"),
                     bg2: Color(hex: "#1C1C1C"), bg3: Color(hex: "#272727")),
        ThemePalette(name: "OLED",     isLight: false,
                     bg0: Color(hex: "#000000"), bg1: Color(hex: "#080808"),
                     bg2: Color(hex: "#121212"), bg3: Color(hex: "#1A1A1A")),
        ThemePalette(name: "Warm",     isLight: false,
                     bg0: Color(hex: "#0D0907"), bg1: Color(hex: "#161009"),
                     bg2: Color(hex: "#211813"), bg3: Color(hex: "#2B211B")),
        ThemePalette(name: "Midnight", isLight: false,
                     bg0: Color(hex: "#07091A"), bg1: Color(hex: "#0D1124"),
                     bg2: Color(hex: "#141B33"), bg3: Color(hex: "#1C2542")),
        ThemePalette(name: "Forest",   isLight: false,
                     bg0: Color(hex: "#070D09"), bg1: Color(hex: "#0C1510"),
                     bg2: Color(hex: "#131E16"), bg3: Color(hex: "#1B2B1D")),
        // ── Light ─────────────────────────────────────────────────────────
        ThemePalette(name: "Paper",    isLight: true,
                     bg0: Color(hex: "#F5F5F5"), bg1: Color(hex: "#FFFFFF"),
                     bg2: Color(hex: "#EBEBEB"), bg3: Color(hex: "#DEDEDE")),
        ThemePalette(name: "Cream",    isLight: true,
                     bg0: Color(hex: "#F7F3ED"), bg1: Color(hex: "#FEFAF5"),
                     bg2: Color(hex: "#EDE9E2"), bg3: Color(hex: "#E2DDD5")),
        ThemePalette(name: "Slate",    isLight: true,
                     bg0: Color(hex: "#EAF0F5"), bg1: Color(hex: "#F5F9FC"),
                     bg2: Color(hex: "#DCE6EE"), bg3: Color(hex: "#CCDAEB")),
        ThemePalette(name: "Sand",     isLight: true,
                     bg0: Color(hex: "#F5EFE6"), bg1: Color(hex: "#FBF7F0"),
                     bg2: Color(hex: "#EBE4D8"), bg3: Color(hex: "#E0D6C5")),
        ThemePalette(name: "Sepia",    isLight: true,
                     bg0: Color(hex: "#F4ECD8"), bg1: Color(hex: "#FBF6EC"),
                     bg2: Color(hex: "#EDE4D0"), bg3: Color(hex: "#E0D6BE")),
    ]
    static var `default`: ThemePalette { presets[0] }
    static var dark:  [ThemePalette] { presets.filter { !$0.isLight } }
    static var light: [ThemePalette] { presets.filter {  $0.isLight } }
}

/// App-wide persisted preferences. Injected via .environment(settings).
@Observable final class Settings {
    var paletteKey:    String = UserDefaults.standard.string(forKey: "rb_palette")     ?? "Default"  { didSet { UserDefaults.standard.set(paletteKey,    forKey: "rb_palette")     } }
    var accentHex:     String = UserDefaults.standard.string(forKey: "rb_accent")      ?? "#E8A87C"  { didSet { UserDefaults.standard.set(accentHex,     forKey: "rb_accent")      } }
    var iconAccentHex: String = UserDefaults.standard.string(forKey: "rb_icon_accent") ?? "#E8A87C"  { didSet { UserDefaults.standard.set(iconAccentHex, forKey: "rb_icon_accent") } }
    var layout:        String = UserDefaults.standard.string(forKey: "rb_layout")      ?? "grid"     { didSet { UserDefaults.standard.set(layout,        forKey: "rb_layout")      } }
    var showArtwork:   Bool   = UserDefaults.standard.object(forKey: "rb_artwork")     as? Bool ?? true  { didSet { UserDefaults.standard.set(showArtwork,   forKey: "rb_artwork")   } }
    var discogsToken:  String = UserDefaults.standard.string(forKey: "rb_discogs")     ?? ""         { didSet { UserDefaults.standard.set(discogsToken,  forKey: "rb_discogs")     } }
    var currency:      String = UserDefaults.standard.string(forKey: "rb_currency")    ?? "CHF"      { didSet { UserDefaults.standard.set(currency,      forKey: "rb_currency")    } }
    var username:      String = UserDefaults.standard.string(forKey: "rb_username")    ?? ""         { didSet { UserDefaults.standard.set(username,      forKey: "rb_username")    } }
    var isPublic:      Bool   = UserDefaults.standard.object(forKey: "rb_public")      as? Bool ?? false { didSet { UserDefaults.standard.set(isPublic,   forKey: "rb_public")    } }

    // MARK: – Header visibility toggles
    var showValueBar:    Bool = UserDefaults.standard.object(forKey: "rb_show_valuebar") as? Bool ?? true  { didSet { UserDefaults.standard.set(showValueBar,    forKey: "rb_show_valuebar") } }
    var showSuggestions: Bool = UserDefaults.standard.object(forKey: "rb_show_suggest") as? Bool ?? true  { didSet { UserDefaults.standard.set(showSuggestions, forKey: "rb_show_suggest")  } }
    var showStatsBtn:    Bool = UserDefaults.standard.object(forKey: "rb_show_statsbtn")as? Bool ?? true  { didSet { UserDefaults.standard.set(showStatsBtn,    forKey: "rb_show_statsbtn") } }

    private var genresJSON: String = UserDefaults.standard.string(forKey: "rb_genres") ?? "[]"          { didSet { UserDefaults.standard.set(genresJSON, forKey: "rb_genres") } }
    private var pinnedJSON: String = UserDefaults.standard.string(forKey: "rb_pinned") ?? "[\"value\"]" { didSet { UserDefaults.standard.set(pinnedJSON, forKey: "rb_pinned") } }

    var pinnedStats: Set<String> {
        get { Set((try? JSONDecoder().decode([String].self, from: Data(pinnedJSON.utf8))) ?? ["value"]) }
        set { pinnedJSON = (try? String(data: JSONEncoder().encode(Array(newValue)), encoding: .utf8)) ?? "[\"value\"]" }
    }
    var customGenres: [String] {
        get { (try? JSONDecoder().decode([String].self, from: Data(genresJSON.utf8))) ?? [] }
        set { genresJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "[]" }
    }
    var allGenres: [String] {
        var g = Settings.builtIn
        for x in customGenres where !g.contains(x) { g.append(x) }
        return g
    }

    var accentColor: Color { Color(hex: accentHex) }

    // MARK: – Palette-aware background colors (absolute — the palette owns the color)
    private var _palette: ThemePalette {
        ThemePalette.presets.first { $0.name == paletteKey } ?? .default
    }
    var bg0: Color { _palette.bg0 }
    var bg1: Color { _palette.bg1 }
    var bg2: Color { _palette.bg2 }
    var bg3: Color { _palette.bg3 }

    /// ColorScheme is fully determined by the active palette's isLight flag.
    var preferredScheme: ColorScheme? { _palette.isLight ? .light : .dark }

    // MARK: – Currency helpers
    var currencyCode: String { Self.code(for: currency) }
    static func code(for symbol: String) -> String {
        switch symbol {
        case "CHF": return "CHF"; case "€": return "EUR"
        case "$":   return "USD"; case "£": return "GBP"
        default:    return "EUR"
        }
    }

    // MARK: – Static data
    static let builtIn    = ["Rock","Jazz","Blues","Electronic","Hip-Hop","Classical",
                             "Soul","Folk","Pop","Metal","Country","R&B","Punk","Reggae","World","Other"]
    static let conditions = ["M","NM","VG+","VG","G+","G","F","P"]
    static let rpms       = ["33⅓","45","78"]
    static let currencies = ["CHF","€","$","£"]
    static let accents: [(String,String)] = [
        ("Amber","#E8A87C"),("Sky","#7CB8E8"),("Violet","#A87CE8"),("Mint","#7CE8A8"),
        ("Rose","#E87C9A"),("Lemon","#E8D87C"),("Coral","#E87C7C"),("Teal","#5ECFCF"),
        ("Indigo","#6674E8"),("Peach","#FFB085"),("Lime","#A8E87C"),("Lavender","#C9B0F0"),
        ("Crimson","#E84444"),("Turquoise","#44C8B4"),("Gold","#F0C844"),("Silver","#B0BCC8")
    ]
}
