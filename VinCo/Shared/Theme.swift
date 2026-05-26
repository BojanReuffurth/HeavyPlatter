import SwiftUI

enum Theme {
    // MARK: – Adaptive base colors (used as static fallbacks / UIKit appearance)
    static let bg0    = Color(light: Color(hex: "#F2F2F7"), dark: Color(hex: "#0A0A0A"))
    static let bg1    = Color(light: Color(hex: "#FFFFFF"), dark: Color(hex: "#111111"))
    static let bg2    = Color(light: Color(hex: "#E8E8ED"), dark: Color(hex: "#1C1C1C"))
    static let bg3    = Color(light: Color(hex: "#D8D8DD"), dark: Color(hex: "#272727"))

    // MARK: – Adaptive dividers & text (not palette-dependent)
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

// MARK: – Close button — plain ✕ only, no chrome
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

// MARK: – Modal navigation bar
// Matches standard iOS nav bar: 44 pt tall, title centred, buttons at system inset.
// Replaces NavigationStack toolbars to avoid iOS 26 Liquid Glass chrome.
struct ModalNavBar<T: View>: View {
    let title:   String
    let onClose: () -> Void
    @ViewBuilder let trailing: () -> T
    @Environment(Settings.self) private var settings

    init(_ title: String, onClose: @escaping () -> Void, @ViewBuilder trailing: @escaping () -> T) {
        self.title   = title
        self.onClose = onClose
        self.trailing = trailing
    }

    var body: some View {
        ZStack {
            // Title — always centred across the full bar width
            Text(title)
                .font(Theme.courier(17, .semibold))
                .foregroundStyle(Theme.textP)
                .lineLimit(1)
                .padding(.horizontal, 60) // keep clear of 44 pt buttons + 8 pt inset

            // Leading close + optional trailing action
            HStack(spacing: 0) {
                Button(action: onClose) {
                    Text("✕")
                        .font(Theme.courier(15))
                        .foregroundStyle(Theme.textT)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                trailing()
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 44)
        .background(settings.bg1)
    }
}

extension ModalNavBar where T == EmptyView {
    /// Convenience init for views with no trailing action.
    init(_ title: String, onClose: @escaping () -> Void) {
        self.init(title, onClose: onClose) { EmptyView() }
    }
}

// MARK: – Shared section container (palette-aware)
struct RBSection<C: View>: View {
    @Environment(Settings.self) private var settings
    let title: String?
    @ViewBuilder let content: () -> C
    init(_ title: String? = nil, @ViewBuilder content: @escaping () -> C) {
        self.title = title; self.content = content
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let t = title {
                Text(t.uppercased())
                    .font(Theme.courier(11, .semibold))
                    .foregroundStyle(Theme.textT)
                    .padding(.horizontal, 16).padding(.bottom, 8)
            }
            VStack(spacing: 0) { content() }
                .background(settings.bg1)
                .clipShape(RoundedRectangle(cornerRadius: Theme.sectR))
        }
    }
}

// MARK: – Shared row container (palette-aware)
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

// MARK: – Condition grading guide sheet
struct ConditionGuideView: View {
    @Environment(\.dismiss)  private var dismiss
    @Environment(Settings.self) private var settings

    private let grades: [(String, String, String)] = [
        ("M",   "Mint",           "Perfect, unplayed, completely flawless."),
        ("NM",  "Near Mint",      "Nearly perfect; may have been played once."),
        ("VG+", "Very Good Plus", "Shows light signs of play; minor surface marks."),
        ("VG",  "Very Good",      "Visible marks, plays with some surface noise."),
        ("G+",  "Good Plus",      "Heavily played; noisy throughout."),
        ("G",   "Good",           "Very noisy but plays through without skipping."),
        ("F",   "Fair",           "Very noisy or skips; barely playable."),
        ("P",   "Poor",           "Barely playable or completely unplayable."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ModalNavBar("Condition Guide", onClose: { dismiss() })
            Rectangle().fill(Theme.divide).frame(height: 1)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(grades, id: \.0) { grade, label, desc in
                        VStack(spacing: 0) {
                            HStack(spacing: 14) {
                                Text(grade)
                                    .font(Theme.courier(17, .bold))
                                    .foregroundStyle(settings.accentColor)
                                    .frame(width: 38, alignment: .leading)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(label).font(Theme.courier(14, .semibold)).foregroundStyle(Theme.textP)
                                    Text(desc).font(Theme.courier(12)).foregroundStyle(Theme.textS)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            Rectangle().fill(Theme.divide).frame(height: 1)
                        }
                    }
                }
                .padding(.top, 8)
            }
            .scrollIndicators(.hidden)
            .background(settings.bg0.ignoresSafeArea())
        }
    }
}

// MARK: – Mini vinyl record icon
struct MiniVinylIcon: View {
    var color: Color  = Color(hex: "#E8A87C")
    var size:  CGFloat = 22
    var body: some View {
        ZStack {
            Circle().fill(Color(hex: "#111111")).frame(width: size, height: size)
            ForEach(0 ..< 5, id: \.self) { i in
                Circle()
                    .stroke(Color.white.opacity(0.13), lineWidth: 0.6)
                    .frame(width: size * (0.88 - CGFloat(i) * 0.13),
                           height: size * (0.88 - CGFloat(i) * 0.13))
            }
            Circle().fill(color)
                .frame(width: size * 0.38, height: size * 0.38)
            Circle().fill(Color(hex: "#111111"))
                .frame(width: size * 0.09, height: size * 0.09)
        }
        .frame(width: size, height: size)
    }
}
