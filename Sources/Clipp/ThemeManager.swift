import AppKit
import Combine
import SwiftUI

enum AppTheme: String, CaseIterable {
    case dark, midnight, nord, solarized, dracula

    var label: String {
        switch self {
        case .dark:      return "Dark"
        case .midnight:  return "Midnight"
        case .nord:      return "Nord"
        case .solarized: return "Solarized Dark"
        case .dracula:   return "Dracula"
        }
    }

    var palette: ThemePalette {
        switch self {
        case .dark:
            return ThemePalette(
                background:  Color(nsColor: NSColor(srgbRed: 0.10, green: 0.10, blue: 0.11, alpha: 1)),
                cardFill:    Color(nsColor: NSColor(srgbRed: 0.14, green: 0.14, blue: 0.16, alpha: 1)),
                chromeFill:  Color.white.opacity(0.06),
                border:      Color.white.opacity(0.08),
                accent:      Color(nsColor: NSColor(srgbRed: 0.40, green: 0.60, blue: 1.00, alpha: 1)),
                primaryText: .white,
                secondaryText: Color.white.opacity(0.55)
            )
        case .midnight:
            return ThemePalette(
                background:  Color(nsColor: NSColor(srgbRed: 0.06, green: 0.08, blue: 0.14, alpha: 1)),
                cardFill:    Color(nsColor: NSColor(srgbRed: 0.10, green: 0.13, blue: 0.21, alpha: 1)),
                chromeFill:  Color.white.opacity(0.05),
                border:      Color.white.opacity(0.07),
                accent:      Color(nsColor: NSColor(srgbRed: 0.40, green: 0.85, blue: 0.95, alpha: 1)),
                primaryText: Color(nsColor: NSColor(srgbRed: 0.92, green: 0.95, blue: 1.00, alpha: 1)),
                secondaryText: Color(nsColor: NSColor(srgbRed: 0.60, green: 0.70, blue: 0.85, alpha: 1))
            )
        case .nord:
            // Arctic Ice Studio Nord — polar night base + frost accent
            return ThemePalette(
                background:  Color(nsColor: NSColor(srgbRed: 0.18, green: 0.20, blue: 0.25, alpha: 1)), // nord0
                cardFill:    Color(nsColor: NSColor(srgbRed: 0.23, green: 0.26, blue: 0.32, alpha: 1)), // nord1
                chromeFill:  Color(nsColor: NSColor(srgbRed: 0.26, green: 0.30, blue: 0.37, alpha: 1)), // nord2
                border:      Color(nsColor: NSColor(srgbRed: 0.30, green: 0.34, blue: 0.42, alpha: 1)), // nord3
                accent:      Color(nsColor: NSColor(srgbRed: 0.53, green: 0.75, blue: 0.82, alpha: 1)), // nord8 frost
                primaryText: Color(nsColor: NSColor(srgbRed: 0.93, green: 0.94, blue: 0.95, alpha: 1)), // nord6
                secondaryText: Color(nsColor: NSColor(srgbRed: 0.85, green: 0.87, blue: 0.91, alpha: 1)) // nord4
            )
        case .solarized:
            // Ethan Schoonover Solarized Dark — base03 background, yellow accent
            return ThemePalette(
                background:  Color(nsColor: NSColor(srgbRed: 0.00, green: 0.17, blue: 0.21, alpha: 1)), // base03
                cardFill:    Color(nsColor: NSColor(srgbRed: 0.03, green: 0.21, blue: 0.26, alpha: 1)), // base02
                chromeFill:  Color(nsColor: NSColor(srgbRed: 0.35, green: 0.43, blue: 0.46, alpha: 0.25)),
                border:      Color(nsColor: NSColor(srgbRed: 0.35, green: 0.43, blue: 0.46, alpha: 0.4)), // base01
                accent:      Color(nsColor: NSColor(srgbRed: 0.71, green: 0.54, blue: 0.00, alpha: 1)),  // yellow
                primaryText: Color(nsColor: NSColor(srgbRed: 0.93, green: 0.91, blue: 0.84, alpha: 1)), // base2
                secondaryText: Color(nsColor: NSColor(srgbRed: 0.51, green: 0.58, blue: 0.59, alpha: 1)) // base0
            )
        case .dracula:
            // Dracula palette — soft contrast dark with pink/purple accents
            return ThemePalette(
                background:  Color(nsColor: NSColor(srgbRed: 0.16, green: 0.16, blue: 0.21, alpha: 1)), // #282a36
                cardFill:    Color(nsColor: NSColor(srgbRed: 0.27, green: 0.28, blue: 0.35, alpha: 1)), // #44475a
                chromeFill:  Color.white.opacity(0.06),
                border:      Color.white.opacity(0.08),
                accent:      Color(nsColor: NSColor(srgbRed: 1.00, green: 0.47, blue: 0.78, alpha: 1)), // #ff79c6 pink
                primaryText: Color(nsColor: NSColor(srgbRed: 0.97, green: 0.97, blue: 0.95, alpha: 1)), // #f8f8f2
                secondaryText: Color(nsColor: NSColor(srgbRed: 0.74, green: 0.76, blue: 0.86, alpha: 1)) // #6272a4-ish
            )
        }
    }

    /// All themes are dark-rooted overlays — force dark NSAppearance so system controls match.
    var nsAppearance: NSAppearance? { NSAppearance(named: .darkAqua) }
}

struct ThemePalette {
    let background: Color
    let cardFill: Color
    let chromeFill: Color
    let border: Color
    let accent: Color
    let primaryText: Color
    let secondaryText: Color
}

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    private let defaultsKey = "ClippTheme"

    @Published var theme: AppTheme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: defaultsKey)
            apply()
        }
    }

    private init() {
        let defaults = UserDefaults.standard
        let raw = defaults.string(forKey: defaultsKey)
            ?? defaults.string(forKey: "KakashiTheme")
            ?? AppTheme.dark.rawValue
        self.theme = AppTheme(rawValue: raw) ?? .dark
        apply()
    }

    func apply() {
        NSApp.appearance = theme.nsAppearance
    }
}
