import SwiftUI

/// Classic rows stay compact by showing one supporting visual per metric.
enum ClassicMetricVisualization: Equatable {
    case sparkline
    case progress

    init(kind: MetricKind) {
        switch kind {
        case .cpu, .network:
            self = .sparkline
        case .memory, .disk:
            self = .progress
        }
    }
}

/// Classic list row — flat (no per-metric glass “cells”), continuous panel surface.
struct MetricRowView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let metric: MetricSnapshot
    let history: [Double]
    let usesThresholdColors: Bool

    private var accentColor: Color {
        DesignTokens.accent(for: metric.level, kind: metric.kind, usesThresholdColors: usesThresholdColors)
    }

    private var valueColor: Color {
        guard usesThresholdColors else { return .primary }
        switch metric.level {
        case .normal: return .primary
        case .warning, .critical: return accentColor
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 9) {
                ClassicMetricIcon(systemName: symbolName, accent: accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(AppText.metricTitle(metric.kind))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(compactDetailText)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 8)

                Text(metric.value.percentText)
                    .font(.system(size: 18, weight: .semibold).monospacedDigit())
                    .foregroundStyle(valueColor)
                    .contentTransition(reduceMotion ? .identity : .numericText(value: metric.value))
                    .animation(DesignTokens.valueAnimation(reduceMotion: reduceMotion), value: metric.value)
            }

            visualization
        }
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, minHeight: DesignTokens.classicRowMinHeight, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(AppText.metricTitle(metric.kind)), \(metric.value.percentText), \(compactDetailText)")
    }

    @ViewBuilder
    private var visualization: some View {
        switch ClassicMetricVisualization(kind: metric.kind) {
        case .sparkline:
            MetricSparklineView(
                values: history,
                color: accentColor,
                showsArea: false
            )
            .frame(height: 22)
        case .progress:
            MetricProgressBar(
                value: metric.value,
                color: accentColor,
                height: DesignTokens.classicProgressHeight
            )
            .frame(height: 22)
        }
    }

    private var symbolName: String {
        switch metric.kind {
        case .cpu: "cpu"
        case .memory: "memorychip"
        case .disk: "internaldrive"
        case .network: "waveform.path.ecg"
        }
    }

    private var compactDetailText: String {
        switch metric.kind {
        case .cpu:
            let cores = metric.coreCount ?? 0
            return "\(AppText.currentLoad) · \(cores) \(AppText.cores)"
        case .memory:
            guard let used = metric.usedBytes, let total = metric.totalBytes else {
                return AppText.waiting
            }
            return "\(AppText.used) \(used.memoryByteText) / \(total.memoryByteText)"
        case .disk:
            guard let used = metric.usedBytes, let free = metric.freeBytes else {
                return AppText.waiting
            }
            return "\(AppText.used) \(used.byteText) · \(AppText.free) \(free.byteText)"
        case .network:
            return AppText.waiting
        }
    }
}

struct NetworkRowView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let network: NetworkSnapshot
    let history: [Double]
    let usesThresholdColors: Bool

    private var accent: Color {
        DesignTokens.accent(for: .normal, kind: .network, usesThresholdColors: usesThresholdColors)
    }

    private var totalRate: Double {
        network.downloadBytesPerSecond + network.uploadBytesPerSecond
    }

    private var ratesDetail: String {
        "\(AppText.download) \(network.downloadBytesPerSecond.byteRateText) · \(AppText.upload) \(network.uploadBytesPerSecond.byteRateText)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 9) {
                ClassicMetricIcon(systemName: "waveform.path.ecg", accent: accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(AppText.metricTitle(.network))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(ratesDetail)
                        .font(.system(size: 10.5, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: 8)

                Text(totalRate.byteRateText)
                    .font(.system(size: 15, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.primary)
                    .contentTransition(reduceMotion ? .identity : .numericText(value: totalRate))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            MetricSparklineView(
                values: history,
                color: accent,
                fixedRange: nil,
                showsArea: false
            )
            .frame(height: 22)
        }
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, minHeight: DesignTokens.classicRowMinHeight, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(AppText.metricTitle(.network)), \(ratesDetail)")
    }
}

private struct ClassicMetricIcon: View {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    let systemName: String
    let accent: Color

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)

        Image(systemName: systemName)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(accent)
            .frame(width: DesignTokens.classicIconContainer, height: DesignTokens.classicIconContainer)
            .background(accent.opacity(0.09), in: shape)
            .overlay {
                shape.strokeBorder(
                    Color.primary.opacity(colorSchemeContrast == .increased ? 0.22 : 0.05),
                    lineWidth: colorSchemeContrast == .increased ? 1 : 0.5
                )
            }
            .accessibilityHidden(true)
    }
}
