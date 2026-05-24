import SwiftUI
import Observation

/// App-wide persisted preferences. Injected via .environment(settings).
@Observable final class Settings {
    var schemeKey:    String = UserDefaults.standard.string(forKey: "rb_scheme")   ?? "dark"     { didSet { UserDefaults.standard.set(schemeKey,    forKey: "rb_scheme")   } }
    var accentHex:    String = UserDefaults.standard.string(forKey: "rb_accent")   ?? "#E8A87C"  { didSet { UserDefaults.standard.set(accentHex,    forKey: "rb_accent")   } }
    var layout:       String = UserDefaults.standard.string(forKey: "rb_layout")   ?? "grid"     { didSet { UserDefaults.standard.set(layout,       forKey: "rb_layout")   } }
    var showArtwork:  Bool   = UserDefaults.standard.object(forKey: "rb_artwork")  as? Bool ?? true { didSet { UserDefaults.standard.set(showArtwork, forKey: "rb_artwork") } }
    var discogsToken: String = UserDefaults.standard.string(forKey: "rb_discogs")  ?? ""         { didSet { UserDefaults.standard.set(discogsToken, forKey: "rb_discogs")  } }
    var spotifyId:    String = UserDefaults.standard.string(forKey: "rb_sp_id")    ?? ""         { didSet { UserDefaults.standard.set(spotifyId,    forKey: "rb_sp_id")    } }
    var currency:     String = UserDefaults.standard.string(forKey: "rb_currency") ?? "€"        { didSet { UserDefaults.standard.set(currency,     forKey: "rb_currency") } }
    private var genresJSON:  String = UserDefaults.standard.string(forKey: "rb_genres") ?? "[]"  { didSet { UserDefaults.standard.set(genresJSON,   forKey: "rb_genres")   } }

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
    static let builtIn = ["Rock","Jazz","Blues","Electronic","Hip-Hop","Classical",
                          "Soul","Folk","Pop","Metal","Country","R&B","Punk","Reggae","World","Other"]
    static let conditions = ["M","NM","VG+","VG","G+","G","F","P"]
    static let accents: [(String,String)] = [
        ("Amber","#E8A87C"),("Sky","#7CB8E8"),("Violet","#A87CE8"),("Mint","#7CE8A8"),
        ("Rose","#E87C9A"),("Gold","#E8D87C"),("Teal","#7CE8D8"),("Peach","#E8B07C"),
        ("Plum","#B07CE8"),("Spring","#7CE8B0")
    ]
    static let currencies = ["€","$","£","¥","CHF","kr","₹","R$","₩","A$"]
}
