import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Design tokens for Rasoi (SPEC §8): warm, clean, Apple-native. System fonts and SF Symbols only,
/// generous whitespace, big tap targets for one-handed kitchen use, full dark-mode support.
enum Theme {
    static let appName = "Rasoi"

    // MARK: - Colour

    /// Saffron — the accent. Matches `AccentColor` in the asset catalog.
    static let saffron = Color(light: 0xE8A33D, dark: 0xF0B45C)
    /// Sage — secondary accent used for "good to go" states (nutrition dots, checked items).
    static let sage = Color(light: 0x7C9A73, dark: 0x93B189)
    /// Cream — the warm app background in light mode; near-black in dark mode.
    static let cream = Color(light: 0xFBF6EC, dark: 0x14120E)
    /// Terracotta — attention without alarm (expiring soon). Never used for "failure".
    static let terracotta = Color(light: 0xC2643F, dark: 0xDD8158)

    /// The screen background.
    static let background = cream
    /// Raised surfaces: cards, sheets, rows.
    static let surface = Color(light: 0xFFFFFF, dark: 0x1F1C17)
    /// A surface resting on top of `surface` (chips, wells, steppers).
    static let surfaceElevated = Color(light: 0xF3EDE1, dark: 0x2A261F)
    /// Hairlines and dividers.
    static let separator = Color(light: 0xE4DACA, dark: 0x38332B)

    static let textPrimary = Color(light: 0x241F17, dark: 0xF6F1E7)
    static let textSecondary = Color(light: 0x6B6151, dark: 0xB6AD9C)

    // MARK: - Metrics

    /// 4-point spacing scale. Use these instead of literals so screens stay in rhythm.
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let small: CGFloat = 8
        static let card: CGFloat = 16
        static let sheet: CGFloat = 24
        static let pill: CGFloat = 999
    }

    /// Minimum tap target. Kitchen use means wet hands and one thumb — never go below this.
    static let minimumTapTarget: CGFloat = 44
    /// Tap target for the primary action on a screen (Cook, Generate week, feedback buttons).
    static let largeTapTarget: CGFloat = 56
}

// MARK: - Card

/// The standard raised container: surface colour, card radius, a soft shadow, generous padding.
struct RasoiCard: ViewModifier {
    var padding: CGFloat = Theme.Spacing.l

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(Theme.separator, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

extension View {
    /// Wraps the view in Rasoi's standard card.
    func rasoiCard(padding: CGFloat = Theme.Spacing.l) -> some View {
        modifier(RasoiCard(padding: padding))
    }
}

// MARK: - Haptics

/// Subtle haptics (SPEC §8). No-ops off-device so tests and previews stay silent.
enum Haptics {
    /// A light tap: checking a grocery item, stepping a quantity.
    static func tap() {
        #if canImport(UIKit) && !targetEnvironment(macCatalyst)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    /// Something completed: week generated, list built, meal logged.
    static func success() {
        #if canImport(UIKit) && !targetEnvironment(macCatalyst)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    /// A selection changed: segmented control, picker.
    static func selection() {
        #if canImport(UIKit) && !targetEnvironment(macCatalyst)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }
}

// MARK: - Colour helper

extension Color {
    /// Builds a colour from light/dark sRGB hex pairs so every token is dark-mode aware.
    init(light: UInt32, dark: UInt32) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
        #else
        self.init(hex: light)
        #endif
    }

    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

#if canImport(UIKit)
extension UIColor {
    fileprivate convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
#endif
