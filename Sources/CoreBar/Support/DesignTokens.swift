import AppKit
import SwiftUI

/// Shared visual tokens aligned with `docs/ui-ux-preview.html`.
enum DesignTokens {
    static let panelWidth: CGFloat = 372
    /// Classic and System Default share one outer size.
    static let classicPanelWidth: CGFloat = panelWidth
    static let panelCornerRadius: CGFloat = 28
    static let classicCornerRadius: CGFloat = panelCornerRadius
    /// Classic settings (borderless panel) corner — matches macOS menu/popover radius family.
    static let classicSettingsCornerRadius: CGFloat = 12
    /// Shared content insets (classic list + system grid).
    static let panelContentTop: CGFloat = 20
    static let panelContentBottom: CGFloat = 20
    static let panelContentHorizontal: CGFloat = 16
    static let tileCornerRadius: CGFloat = 22
    static let classicRowCornerRadius: CGFloat = 18
    static let settingsGroupRadius: CGFloat = 16
    static let progressHeight: CGFloat = 4
    static let iconContainer: CGFloat = 28
    static let classicIconContainer: CGFloat = 26
    static let classicProgressHeight: CGFloat = 3
    static let tileMinHeight: CGFloat = 132
    /// Compact flat classic list row (one supporting visualization, no card chrome).
    static let classicRowMinHeight: CGFloat = 78
    static let gridSpacing: CGFloat = 10
    static let listSpacing: CGFloat = 10

    /// Lightweight tone layered over the panel's single system material.
    /// These surfaces add hierarchy without stacking another blur effect.
    static func surfaceFill(colorScheme: ColorScheme) -> Color {
        if colorScheme == .dark {
            return Color.white.opacity(0.07)
        }
        return Color.white.opacity(0.38)
    }

    static func surfaceStroke(colorScheme: ColorScheme) -> Color {
        if colorScheme == .dark {
            return Color.white.opacity(0.10)
        }
        return Color.black.opacity(0.06)
    }

    static func surfaceFillStrong(colorScheme: ColorScheme) -> Color {
        if colorScheme == .dark {
            return Color.white.opacity(0.10)
        }
        return Color.white.opacity(0.52)
    }

    static let green = Color(red: 52 / 255, green: 199 / 255, blue: 89 / 255)
    static let orange = Color(red: 255 / 255, green: 159 / 255, blue: 10 / 255)
    static let red = Color(red: 255 / 255, green: 59 / 255, blue: 48 / 255)
    static let blue = Color(red: 10 / 255, green: 132 / 255, blue: 255 / 255)
    static let indigo = Color(red: 94 / 255, green: 92 / 255, blue: 230 / 255)

    static let nsGreen = NSColor(srgbRed: 52 / 255, green: 199 / 255, blue: 89 / 255, alpha: 1)
    static let nsOrange = NSColor(srgbRed: 255 / 255, green: 159 / 255, blue: 10 / 255, alpha: 1)
    static let nsRed = NSColor(srgbRed: 255 / 255, green: 59 / 255, blue: 48 / 255, alpha: 1)

    static func color(for level: HealthLevel) -> Color {
        switch level {
        case .normal: green
        case .warning: orange
        case .critical: red
        }
    }

    static func nsColor(for level: HealthLevel) -> NSColor {
        switch level {
        case .normal: nsGreen
        case .warning: nsOrange
        case .critical: nsRed
        }
    }

    /// Accent for metric chrome. Disk stays blue when healthy to match the preview hierarchy.
    static func accent(
        for level: HealthLevel,
        kind: MetricKind,
        usesThresholdColors: Bool
    ) -> Color {
        guard usesThresholdColors else {
            return Color.primary
        }

        if kind == .disk, level == .normal {
            return blue
        }

        if kind == .network {
            return indigo
        }

        return color(for: level)
    }

    static func nsBarColor(level: HealthLevel, usesThresholdColors: Bool) -> NSColor {
        usesThresholdColors ? nsColor(for: level) : .labelColor
    }

    static var valueAnimation: Animation {
        .easeOut(duration: 0.22)
    }

    /// Numeric/progress transitions respect Reduce Motion (nil disables implicit animation).
    static func valueAnimation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : valueAnimation
    }

    static func reduceMotion(_ environment: Bool) -> Bool {
        environment
    }
}
