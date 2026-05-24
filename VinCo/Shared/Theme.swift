import SwiftUI

enum Theme {
    // MARK: – Adaptive backgrounds (dark → current, light → iOS-standard grays)
    static let bg0    = Color(light: Color(hex: "#F2F2F7"), dark: Color(hex: "#0A0A0A"))
    static let bg1    = Color(light: Color(hex: "#FFFFFF"), dark: Color(hex: "#111111"))
    static let bg2    = Color(light: Color(hex: "#E8E8ED"), dark: Color(hex: "#1C1C1C"))
    static let bg3    = Color(light: Color(hex: "#D8D8DD"), dark: Color(hex: "#272727"))

    // MARK: – Adaptive dividers & text
    static let divide = Color(light: Color.black.opacity(0.10), dark: Color.white.opacity(0.07))
    static let textP  = Color(light: Color(hex: "#0D0D0D"),     dark: Color.white)
    static let textS  = Color(light: Color.black.opacity(0.55), dark: Color.white.opacity(0.55))
    static let textT  = Color(light: Color.black.opacity(0.35), dark: Color.white.opacity(0.30))

    // MARK: – Courier New font (matches PWA's monospace look)
    static func courier(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        Font.custom("Courier New", size: size).weight(weight)
    }

    // MARK: – Shape constants
    static let cardR:       CGFloat = 14
    static let sectR:       CGFloat = 16
    static let chipRadius:  CGFloat = 20
    static let tabBarHeight: CGFloat = 56

    // MARK: – Gradients (always dark – used over album art / vinyl)
    static func cardGrad() -> LinearGradient {
        LinearGradient(colors: [.clear, .black.opacity(0.55), .black.opacity(0.82)],
                       startPoint: .top, endPoint: .bottom)
    }
    static func headerGrad() -> LinearGradient {
        LinearGradient(colors: [.clear, .black.opacity(0.85)],
                       startPoint: .center, endPoint: .bottom)
    }
}

// MARK: – Subtle close button (non-iOS-standard ✕)
struct CloseButton: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Button { dismiss() } label: {
            Text("✕")
                .font(Theme.courier(15))
                .foregroundStyle(Theme.textT)
        }
        .buttonStyle(.plain)
    }
}

// MARK: – Shared section container
struct RBSection<C: View>: View {
    let title: String?
    @ViewBuilder let content: () -> C
    init(_ title: String? = nil, @ViewBuilder content: @escaping () -> C) {
        self.title = title; self.content = content
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let t = title {
                Text(t.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.textT)
                    .padding(.horizontal, 16).padding(.bottom, 8)
            }
            VStack(spacing: 0) { content() }
                .background(Theme.bg1)
                .clipShape(RoundedRectangle(cornerRadius: Theme.sectR))
        }
    }
}

struct RBRow<C: View>: View {
    var divider: Bool = true
    @ViewBuilder let content: () -> C
    var body: some View {
        VStack(spacing: 0) {
            content().padding(.horizontal, 16).padding(.vertical, 13)
            if divider { Rectangle().fill(Theme.divide).frame(height: 1).padding(.leading, 16) }
        }
    }
}

// MARK: – Mini vinyl record icon (replaces opticaldisc SF symbol)
struct MiniVinylIcon: View {
    var color: Color  = Color(hex: "#E8A87C")
    var size:  CGFloat = 22
    var body: some View {
        ZStack {
            // Vinyl body
            Circle().fill(Color(hex: "#111111")).frame(width: size, height: size)
            // Groove rings (5 rings)
            ForEach(0 ..< 5, id: \.self) { i in
                Circle()
                    .stroke(Color.white.opacity(0.13), lineWidth: 0.6)
                    .frame(width: size * (0.88 - CGFloat(i) * 0.13),
                           height: size * (0.88 - CGFloat(i) * 0.13))
            }
            // Coloured label circle
            Circle().fill(color)
                .frame(width: size * 0.38, height: size * 0.38)
            // Spindle hole
            Circle().fill(Color(hex: "#111111"))
                .frame(width: size * 0.09, height: size * 0.09)
        }
        .frame(width: size, height: size)
    }
}
