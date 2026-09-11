//
//  HarborTheme.swift
//  HarborPantry
//
//  Presentation layer — the single source of colour, type and spacing.
//

import SwiftUI

// MARK: - Palette

enum HarborPalette {
    static let oceanBlue = Color(hex: 0x087BC1)
    static let aqua = Color(hex: 0x28D7E5)
    static let deepSea = Color(hex: 0x074B78)
    static let foam = Color(hex: 0xF3FDFF)
    static let sunGold = Color(hex: 0xFFD34F)
    static let coral = Color(hex: 0xFF6B3D)
    static let leaf = Color(hex: 0x4FC66A)
    static let ink = Color(hex: 0x12334A)
}

// MARK: - Semantic colours

/// Semantic roles resolve per colour scheme so the bright harbour look holds up
/// in dark mode without repainting every view.
enum HarborColor {
    static let accent = HarborPalette.oceanBlue
    static let accentSoft = HarborPalette.aqua
    static let highlight = HarborPalette.sunGold
    static let warning = HarborPalette.coral
    static let success = HarborPalette.leaf

    static let background = adaptive(light: HarborPalette.foam, dark: Color(hex: 0x061F31))
    static let surface = adaptive(light: .white, dark: Color(hex: 0x0C2E45))
    static let surfaceRaised = adaptive(light: Color(hex: 0xFAFEFF), dark: Color(hex: 0x113A55))
    static let surfaceSunken = adaptive(light: Color(hex: 0xEAF8FC), dark: Color(hex: 0x092838))

    static let textPrimary = adaptive(light: HarborPalette.ink, dark: Color(hex: 0xEAF7FF))
    static let textSecondary = adaptive(
        light: HarborPalette.ink.opacity(0.62),
        dark: Color(hex: 0xEAF7FF).opacity(0.68)
    )
    static let textOnAccent = Color.white

    static let separator = adaptive(
        light: HarborPalette.deepSea.opacity(0.12),
        dark: Color.white.opacity(0.14)
    )
    static let fieldBackground = adaptive(light: Color(hex: 0xF1FAFD), dark: Color(hex: 0x0A2B40))

    /// Colour used for a freshness bucket. `.review` is amber-coral because the
    /// user's own date has passed — it is never a spoilage claim.
    static func bucket(_ bucket: FreshnessBucket) -> Color {
        switch bucket {
        case .review: return HarborPalette.coral
        case .today: return HarborPalette.sunGold
        case .nextThreeDays: return HarborPalette.oceanBlue
        case .thisWeek: return HarborPalette.aqua
        case .later: return HarborPalette.leaf
        case .missingDate: return adaptive(
            light: HarborPalette.ink.opacity(0.45),
            dark: Color.white.opacity(0.45)
        )
        }
    }

    static func coverage(_ status: CoverageStatus) -> Color {
        switch status {
        case .available: return HarborPalette.leaf
        case .partial: return HarborPalette.sunGold
        case .missing: return HarborPalette.coral
        }
    }

    private static func adaptive(light: Color, dark: Color) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

// MARK: - Gradients

enum HarborGradient {
    static let ocean = LinearGradient(
        colors: [HarborPalette.aqua, HarborPalette.oceanBlue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let deepOcean = LinearGradient(
        colors: [HarborPalette.oceanBlue, HarborPalette.deepSea],
        startPoint: .top,
        endPoint: .bottom
    )

    static let sun = LinearGradient(
        colors: [HarborPalette.sunGold, HarborPalette.coral],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let coral = LinearGradient(
        colors: [Color(hex: 0xFF9366), HarborPalette.coral],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let leaf = LinearGradient(
        colors: [Color(hex: 0x7FE09A), HarborPalette.leaf],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// The glossy top highlight that gives the 3D-cartoon surfaces their shine.
    static let gloss = LinearGradient(
        colors: [Color.white.opacity(0.55), Color.white.opacity(0.0)],
        startPoint: .top,
        endPoint: .bottom
    )

    static var screenBackground: LinearGradient {
        LinearGradient(
            colors: [HarborColor.background, HarborColor.surfaceSunken],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Metrics

enum HarborMetrics {
    static let cardRadius: CGFloat = 22
    static let controlRadius: CGFloat = 14
    static let pillRadius: CGFloat = 999

    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 14
    static let spacingL: CGFloat = 20
    static let spacingXL: CGFloat = 28

    static let minimumTapTarget: CGFloat = 44
}

// MARK: - Typography

enum HarborFont {
    /// Rounded faces echo the soft, glossy illustration style.
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }

    static func title(_ size: CGFloat = 22) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func headline(_ size: CGFloat = 17) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    static func body(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }

    static func caption(_ size: CGFloat = 12.5) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }

    static func numeric(_ size: CGFloat = 17) -> Font {
        .system(size: size, weight: .bold, design: .rounded).monospacedDigit()
    }
}

// MARK: - Helpers

extension Color {
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

extension View {
    /// The soft, low-contrast shadow used on cards and floating controls.
    func harborShadow(strength: Double = 1) -> some View {
        shadow(
            color: HarborPalette.deepSea.opacity(0.10 * strength),
            radius: 14 * strength,
            x: 0,
            y: 6 * strength
        )
    }

    func harborScreenBackground() -> some View {
        background(HarborGradient.screenBackground.ignoresSafeArea())
    }
}
