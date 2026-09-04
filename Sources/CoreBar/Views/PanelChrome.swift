import AppKit
import SwiftUI

/// Liquid-glass / vibrancy background (macOS 26+ glass, else NSVisualEffectView).
/// - Note: `showsBorder` should be **false** inside `NSPopover` (system already draws a frame);
///   use **true** on borderless `NSPanel` (System Default).
struct LiquidGlassBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    var cornerRadius: CGFloat
    var material: NSVisualEffectView.Material
    var showsBorder: Bool = true

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        ZStack {
            if reduceTransparency {
                shape.fill(Color(nsColor: .windowBackgroundColor))
            } else if #available(macOS 26.0, *) {
                shape
                    .fill(.clear)
                    .glassEffect(.regular, in: shape)
            } else {
                VisualEffectBackground(material: material)
            }

            if showsBorder {
                shape
                    .strokeBorder(
                        Color.primary.opacity(colorSchemeContrast == .increased ? 0.24 : (colorScheme == .dark ? 0.14 : 0.10)),
                        lineWidth: colorSchemeContrast == .increased ? 1 : 0.5
                    )
            }
        }
        .clipShape(shape)
    }
}

struct HealthPillView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    let level: HealthLevel
    let metricTitle: String
    let percent: Double
    let usesThresholdColors: Bool

    private var accent: Color {
        usesThresholdColors ? DesignTokens.color(for: level) : Color.primary
    }

    private var isAlert: Bool {
        level != .normal
    }

    private var foreground: Color {
        isAlert ? accent : .secondary
    }

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                if differentiateWithoutColor {
                    Image(systemName: level.symbol)
                        .font(.system(size: 11, weight: .semibold))
                } else {
                    Circle()
                        .stroke(Color.primary.opacity(0.1), lineWidth: 2.5)
                    Circle()
                        .trim(from: 0, to: CGFloat(percent.clamped01))
                        .stroke(accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(DesignTokens.valueAnimation(reduceMotion: reduceMotion), value: percent)
                }
            }
            .frame(width: 14, height: 14)
            .accessibilityHidden(true)

            displayTitle
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, isAlert ? 10 : 4)
        .padding(.vertical, 6)
        .foregroundStyle(foreground)
        .background {
            if isAlert {
                Capsule()
                    .fill(accent.opacity(0.14))
            }
        }
        .accessibilityLabel("\(AppText.healthPillTitle(level)), \(metricTitle), \(percent.percentText)")
    }

    @ViewBuilder
    private var displayTitle: some View {
        if level == .normal {
            Text(AppText.healthPillFullTitle(level, metricTitle: metricTitle, percent: percent))
        } else {
            ViewThatFits(in: .horizontal) {
                Text(AppText.healthPillFullTitle(level, metricTitle: metricTitle, percent: percent))
                Text(AppText.healthPillCompactTitle(level, metricTitle: metricTitle, percent: percent))
                Text(AppText.healthPillMinimalTitle(level, percent: percent))
            }
        }
    }
}

struct LiveTimestampLabel: View {
    let timestamp: Date

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(DesignTokens.green)
                .frame(width: 6, height: 6)
                .overlay {
                    Circle().stroke(DesignTokens.green.opacity(0.25), lineWidth: 2)
                }
                .frame(width: 16, height: 16)
                .accessibilityHidden(true)

            Text("\(AppText.updated) \(timestamp.shortTimeText)")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .accessibilityLabel("\(AppText.live), \(AppText.updated) \(timestamp.shortTimeText)")
    }
}

struct MetricProgressBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let value: Double
    let color: Color

    var body: some View {
        let displayed = value.clamped01

        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.08))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.82), color],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(displayed > 0.001 ? 2 : 0, proxy.size.width * displayed.clamped01))
                    .animation(DesignTokens.valueAnimation(reduceMotion: reduceMotion), value: displayed)
            }
        }
        .frame(height: DesignTokens.progressHeight)
    }
}

struct PanelIconButton: View {
    let systemName: String
    let help: String
    var foreground: Color = .secondary
    /// Compact header control (settings / quit).
    var compact: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: compact ? 12 : 14, weight: .medium))
                .foregroundStyle(foreground)
                .frame(width: compact ? 30 : 32, height: compact ? 30 : 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(PanelPlainButtonStyle())
        .help(help)
        .accessibilityLabel(help)
    }
}

private struct PanelPlainButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed
                    ? Color.primary.opacity(0.08)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
