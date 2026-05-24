import UIKit; import SwiftUI
enum AppearanceSetup {
    static func apply(accent: String = "#E8A87C") {
        let ac = UIColor(Color(hex: accent))
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = UIColor(Theme.bg1)
        nav.shadowColor = UIColor(Theme.divide)
        nav.titleTextAttributes      = [.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 17, weight: .semibold)]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 32, weight: .bold)]
        let back = UIImage(systemName: "chevron.left")?.withTintColor(.white, renderingMode: .alwaysOriginal)
        nav.setBackIndicatorImage(back, transitionMaskImage: back)
        UINavigationBar.appearance().standardAppearance   = nav
        UINavigationBar.appearance().compactAppearance    = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().tintColor            = ac

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = UIColor(Theme.bg1)
        tab.shadowColor     = UIColor(Theme.divide)
        for style in [tab.stackedLayoutAppearance, tab.inlineLayoutAppearance, tab.compactInlineLayoutAppearance] {
            style.selected.iconColor = ac
            style.selected.titleTextAttributes = [.foregroundColor: ac]
            style.normal.iconColor   = UIColor(Theme.textS)
            style.normal.titleTextAttributes   = [.foregroundColor: UIColor(Theme.textS)]
        }
        UITabBar.appearance().standardAppearance  = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
        UITableView.appearance().backgroundColor  = UIColor(Theme.bg0)
        UITableViewCell.appearance().backgroundColor = UIColor(Theme.bg1)
        UITableView.appearance().separatorColor   = UIColor(Theme.divide)
    }
}
