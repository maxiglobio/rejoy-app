import SwiftUI
import UIKit

/// SF Pro Rounded font helpers (closest to Figma's SF Compact Rounded).
enum AppFont {
    static func rounded(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static let largeTitle = rounded(size: 34, weight: .bold)
    static let title = rounded(size: 28, weight: .bold)
    static let title2 = rounded(size: 22, weight: .bold)
    static let title3 = rounded(size: 20, weight: .semibold)
    static let headline = rounded(size: 17, weight: .semibold)
    static let body = rounded(size: 17, weight: .regular)
    static let callout = rounded(size: 16, weight: .regular)
    static let subheadline = rounded(size: 15, weight: .regular)
    static let footnote = rounded(size: 13, weight: .regular)
    static let caption = rounded(size: 12, weight: .regular)
    static let caption2 = rounded(size: 11, weight: .regular)
}

/// Adaptive colors. Light mode: Dots Platform (Figma). Dark mode: softer grays.
enum AppColors {
    /// Rejoy brand orange — #FE7302. Use everywhere for accent/orange UI.
    static let rejoyOrange = Color(red: 254/255, green: 115/255, blue: 2/255)
    /// Solid darker orange for pressed state (avoids default button opacity revealing views below, e.g. tab bar slot).
    static let rejoyOrangePressed = Color(red: 230/255, green: 102/255, blue: 0/255)
    static let rejoyOrangeUIColor = UIColor(red: 254/255, green: 115/255, blue: 2/255, alpha: 1)

    // MARK: - Dots Platform design tokens (from Figma). Adaptive for dark mode.
    static var dotsMainCardBg: Color {
        Color(uiColor: UIColor(dynamicProvider: { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0.17, green: 0.17, blue: 0.18, alpha: 1)  // #2C2C2E
            }
            return UIColor(red: 246/255, green: 244/255, blue: 241/255, alpha: 1)
        }))
    }
    static var dotsGlassBg: Color {
        Color(uiColor: UIColor(dynamicProvider: { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 0.3)
            }
            return UIColor(red: 236/255, green: 233/255, blue: 228/255, alpha: 0.2)
        }))
    }
    static var dotsSecondaryText: Color {
        Color(uiColor: UIColor(dynamicProvider: { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0.56, green: 0.56, blue: 0.58, alpha: 1)  // #8E8E93
            }
            return UIColor(red: 139/255, green: 132/255, blue: 132/255, alpha: 1)
        }))
    }
    static var dotsStatsText: Color {
        Color(uiColor: UIColor(dynamicProvider: { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0.56, green: 0.56, blue: 0.58, alpha: 1)  // #8E8E93
            }
            return UIColor(red: 107/255, green: 107/255, blue: 111/255, alpha: 1)
        }))
    }
    static var dotsBorder: Color {
        Color(uiColor: UIColor(dynamicProvider: { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0.23, green: 0.23, blue: 0.24, alpha: 1)  // #3A3A3C
            }
            return UIColor(red: 232/255, green: 230/255, blue: 227/255, alpha: 1)
        }))
    }
    static var dotsRejoyDisabledBg: Color {
        Color(uiColor: UIColor(dynamicProvider: { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0.23, green: 0.23, blue: 0.24, alpha: 1)  // #3A3A3C
            }
            return UIColor(red: 243/255, green: 242/255, blue: 240/255, alpha: 1)
        }))
    }
    static var dotsRejoyDisabledText: Color {
        Color(uiColor: UIColor(dynamicProvider: { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0.56, green: 0.56, blue: 0.58, alpha: 1)  // #8E8E93
            }
            return UIColor(red: 161/255, green: 161/255, blue: 166/255, alpha: 1)
        }))
    }
    /// “Rejoy in …” countdown pill border (Figma Dots — #DEDCDA, 1pt).
    static var dotsRejoyCountdownPillBorder: Color {
        Color(uiColor: UIColor(dynamicProvider: { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(white: 1, alpha: 0.14)
            }
            return UIColor(red: 222/255, green: 220/255, blue: 218/255, alpha: 1)  // #DEDCDA
        }))
    }
    static var dotsRejoyPillBg: Color {
        Color(uiColor: UIColor(dynamicProvider: { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 254/255, green: 115/255, blue: 2/255, alpha: 0.25)
            }
            return UIColor(red: 255/255, green: 214/255, blue: 179/255, alpha: 1)
        }))
    }
    static var dotsActiveRowBg: Color {
        Color(uiColor: UIColor(dynamicProvider: { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 254/255, green: 115/255, blue: 2/255, alpha: 0.08)
            }
            return UIColor(red: 254/255, green: 115/255, blue: 2/255, alpha: 0.05)
        }))
    }
    static let dotsActiveRowBorder = Color(red: 255/255, green: 104/255, blue: 0/255)     // #ff6800

    /// Main screen background. Dark: #1C1C1E, Light: #FFFFFF.
    static var background: Color {
        Color(uiColor: UIColor(dynamicProvider: { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
            }
            return .white
        }))
    }

    /// Card/section background. Dark: #2C2C2E, Light: #f3f2f0 (Dots).
    static var cardBackground: Color {
        Color(uiColor: UIColor(dynamicProvider: { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0.17, green: 0.17, blue: 0.18, alpha: 1)
            }
            return UIColor(red: 243/255, green: 242/255, blue: 240/255, alpha: 1)
        }))
    }

    /// Secondary card background (e.g. time picker capsule). Dark: #3A3A3C, Light: #e8e6e3 (Dots).
    static var secondaryFill: Color {
        Color(uiColor: UIColor(dynamicProvider: { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0.23, green: 0.23, blue: 0.24, alpha: 1)
            }
            return UIColor(red: 232/255, green: 230/255, blue: 227/255, alpha: 1)
        }))
    }

    /// Section header / secondary text. Dark: #8E8E93, Light: #8b8484 (Dots).
    static var sectionHeader: Color {
        Color(uiColor: UIColor(dynamicProvider: { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0.56, green: 0.56, blue: 0.58, alpha: 1)
            }
            return UIColor(red: 139/255, green: 132/255, blue: 132/255, alpha: 1)
        }))
    }

    /// Divider between rows. Dark: #3A3A3C, Light: #e8e6e3 (Dots).
    static var rowDivider: Color {
        Color(uiColor: UIColor(dynamicProvider: { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0.23, green: 0.23, blue: 0.24, alpha: 1)
            }
            return UIColor(red: 232/255, green: 230/255, blue: 227/255, alpha: 1)
        }))
    }

    /// Trailing/chevron color. Dark: #8E8E93, Light: #6b6b6f (Dots).
    static var trailing: Color {
        Color(uiColor: UIColor(dynamicProvider: { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0.56, green: 0.56, blue: 0.58, alpha: 1)
            }
            return UIColor(red: 107/255, green: 107/255, blue: 111/255, alpha: 1)
        }))
    }

    /// List row background (grouped style). Dark: #2C2C2E, Light: #f5f5f5 (Dots).
    static var listRowBackground: Color {
        Color(uiColor: UIColor(dynamicProvider: { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0.17, green: 0.17, blue: 0.18, alpha: 1)
            }
            return UIColor(red: 245/255, green: 245/255, blue: 245/255, alpha: 1)
        }))
    }
}
