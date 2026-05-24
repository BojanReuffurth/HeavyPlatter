import SwiftUI

enum Theme {
    static let bg0     = Color(hex: "#0A0A0A")
    static let bg1     = Color(hex: "#111111")
    static let bg2     = Color(hex: "#1C1C1C")
    static let bg3     = Color(hex: "#272727")
    static let divide  = Color.white.opacity(0.07)
    static let textP   = Color.white
    static let textS   = Color.white.opacity(0.55)
    static let textT   = Color.white.opacity(0.28)
    static let cardR:   CGFloat = 14
    static let sectR:   CGFloat = 16

    static func cardGrad()   -> LinearGradient {
        LinearGradient(colors: [.clear, .black.opacity(0.55), .black.opacity(0.82)],
                       startPoint: .top, endPoint: .bottom)
    }
    static func headerGrad() -> LinearGradient {
        LinearGradient(colors: [.clear, .black.opacity(0.85)],
                       startPoint: .center, endPoint: .bottom)
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
