import SwiftUI
import Observation

// MARK: – Theme palette (dark-mode background overrides)
struct ThemePalette: Equatable {
    let name:    String
    let bg0Dark: Color
    let bg1Dark: Color
    let bg2Dark: Color
    let bg3Dark: Color

    static let presets: [ThemePalette] = [
        ThemePalette(name: "Default",
                     bg0Dark: Color(hex: "#0A0A0A"), bg1Dark: Color(hex: "#111111"),
                     bg2Dark: Color(hex: "#1C1C1C"), bg3Dark: Color(hex: "#272727")),
        ThemePalette(name: "OLED",
                     bg0Dark: Color(hex: "#000000"), bg1Dark: Color(hex: "#080808"),
                     bg2Dark: Color(hex: "#121212"), bg3Dark: Color(hex: "#1A1A1A")),
        ThemePalette(name: "Warm",
                     bg0Dark: Color(hex: "#0D0907"), bg1Dark: Color(hex: "#161009"),
                     bg2Dark: Color(hex: "#211813"), bg3Dark: Color(hex: "#2B211B")),
        ThemePalette(name: "Midnight",
                     bg0Dark: Color(hex: "#07091A"), bg1Dark: Color(hex: "#0D1124"),
                     bg2Dark: Color(hex: "#141B33"), bg3Dark: Color(hex: "#1C2542")),
        ThemePalette(name: "Forest",
                     bg0Dark: Color(hex: "#070D09"), bg1Dark: Color(hex: "#0C1510"),
                     bg2Dark: Color(hex: "#131E16"), bg3Dark: Color(hex: "#1B2B1D")),
    ]
    static var `default`: ThemePalette { presets[0] }
}

/// App-wide persisted preferences. Injected via .environment(settings).
@Observable final class Settings {
    var schemeKey:    String = UserDefaults.standard.string(forKey: "rb_scheme")      ?? "dark"     { didSet { UserDefaults.standard.set(schemeKey,    forKey: "rb_scheme")      } }
    var paletteKey:   String = UserDefaults.standard.string(forKey: "rb_palette")     ?? "Default"  { didSet { UserDefaults.standard.set(paletteKey,   forKey: "rb_palette")     } }
    var accentHex:    String = UserDefaults.standard.string(forKey: "rb_accent")      ?? "#E8A87C"  { didSet { UserDefaults.standard.set(accentHex,    forKey: "rb_accent")      } }
    var iconAccentHex: String = UserDefaults.standard.string(forKey: "rb_icon_accent") ?? "#E8A87C" { didSet { UserDefaults.standard.set(iconAccentHex, forKey: "rb_icon_accent") } }
    var layout:       String = UserDefaults.standard.string(forKey: "rb_layout")      ?? "grid"     { didSet { UserDefaults.standard.set(layout,       forKey: "rb_layout")      } }
    var showArtwork:  Bool   = UserDefaults.standard.object(forKey: "rb_artwork")     as? Bool ?? true { didSet { UserDefaults.standard.set(showArtwork, forKey: "rb_artwork")  } }
    var discogsToken: String = UserDefaults.standard.string(forKey: "rb_discogs")     ?? ""         { didSet { UserDefaults.standard.set(discogsToken, forKey: "rb_discogs")     } }
    var spotifyId:    String = UserDefaults.standard.string(forKey: "rb_sp_id")       ?? ""         { didSet { UserDefaults.standard.set(spotifyId,    forKey: "rb_sp_id")       } }
    var currency:     String = UserDefaults.standard.string(forKey: "rb_currency")    ?? "CHF"      { didSet { UserDefaults.standard.set(currency,     forKey: "rb_currency")    } }
    var username:     String = UserDefaults.standard.string(forKey: "rb_username")    ?? ""         { didSet { UserDefaults.standard.set(username,     forKey: "rb_username")    } }
    var isPublic:     Bool   = UserDefaults.standard.object(forKey: "rb_public")      as? Bool ?? false { didSet { UserDefaults.standard.set(isPublic,  forKey: "rb_public")    } }
    private var genresJSON:  String = UserDefaults.standard.string(forKey: "rb_genres") ?? "[]"    { didSet { UserDefaults.standard.set(genresJSON,   forKey: "rb_genres")      } }
    private var pinnedJSON:  String = UserDefaults.standard.string(forKey: "rb_pinned") ?? "[\"value\"]" { didSet { UserDefaults.standard.set(pinnedJSON, forKey: "rb_pinned") } }

    /// Keys that are pinned to the home header.
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

    var preferredScheme: ColorScheme? {
        switch schemeKey { case "light": return .light; case "dark": return .dark; default: return nil }
    }

    // MARK: – Palette-aware adaptive background colors
    private var _palette: ThemePalette {
        ThemePalette.presets.first { $0.name == paletteKey } ?? .default
    }
    var bg0: Color { Color(light: Color(hex: "#F2F2F7"), dark: _palette.bg0Dark) }
    var bg1: Color { Color(light: Color(hex: "#FFFFFF"), dark: _palette.bg1Dark) }
    var bg2: Color { Color(light: Color(hex: "#E8E8ED"), dark: _palette.bg2Dark) }
    var bg3: Color { Color(light: Color(hex: "#D8D8DD"), dark: _palette.bg3Dark) }

    // MARK: – Currency helpers
    /// ISO-4217 code for the currently selected currency symbol.
    var currencyCode: String { Self.code(for: currency) }

    static func code(for symbol: String) -> String {
        switch symbol {
        case "CHF": return "CHF"
        case "€":   return "EUR"
        case "$":   return "USD"
        case "£":   return "GBP"
        default:    return "EUR"
        }
    }

    // MARK: – Static data
    static let builtIn = ["Rock","Jazz","Blues","Electronic","Hip-Hop","Classical",
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
