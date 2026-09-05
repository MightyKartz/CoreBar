import SwiftUI

struct MetricTileView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) private var envReduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let metric: MetricSnapshot
    let history: [Double]
    let usesThresholdColors: Bool

    private var motionReduced: Bool { envReduceMotion }

    private var accent: Color {
        DesignTokens.accent(for: metric.level, kind: metric.kind, usesThresholdColors: usesThresholdColors)
    }

    var body: some View {
        tileBody
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: DesignTokens.tileMinHeight, alignment: .topLeading)
            .background(tileBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.tileCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.tileCornerRadius, style: .continuous)
                    .strokeBorder(tileStroke, lineWidth: 0.5)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(AppText.metricTitle(metric.kind)), \(metric.value.percentText), \(detailText)\(totalCapacityText.map { ", \($0)" } ?? "")")
            .accessibilityHint(metric.kind == .cpu ? AppText.recentSamplesHint : "")
    }

    private var tileBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                iconBadge
                Spacer(minLength: 4)
                Text(metric.value.percentText)
                    .font(.system(size: 22, weight: .semibold).monospacedDigit())
                    .foregroundStyle(valueColor)
                    .contentTransition(motionReduced ? .identity : .numericText(value: metric.value))
                    .animation(DesignTokens.valueAnimation(reduceMotion: motionReduced), value: metric.value)
            }

            Text(AppText.metricTitle(metric.kind))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(detailText)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let totalCapacityText {
                    Text(totalCapacityText)
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                }
            }
            .foregroundStyle(.secondary)
            .padding(.top, 3)

            Spacer(minLength: 10)

            metricVisualization
        }
    }

    /// Use one supporting visual per metric instead of repeating the same value
    /// as a number, trend, and progress bar in every tile.
    @ViewBuilder
    private var metricVisualization: some View {
        switch metric.kind {
        case .cpu:
            MetricSparklineView(
                values: history,
                color: accent,
                showsArea: true
            )
            .frame(height: 28)
        case .memory, .disk:
            MetricProgressBar(value: metric.value, color: accent)
        case .network:
            EmptyView()
        }
    }

    private var iconBadge: some View {
        Image(systemName: symbolName)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(accent)
            .frame(width: DesignTokens.iconContainer, height: DesignTokens.iconContainer)
            .background(accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private var symbolName: String {
        switch metric.kind {
        case .cpu: "cpu"
        case .memory: "memorychip"
        case .disk: "internaldrive"
        case .network: "waveform.path.ecg"
        }
    }

    private var detailText: String {
        switch metric.kind {
        case .cpu:
            let cores = metric.coreCount ?? 0
            return "\(AppText.currentLoad) · \(cores) \(AppText.cores)"
        case .memory:
            guard let used = metric.usedBytes else {
                return AppText.waiting
            }
            return "\(AppText.used) \(used.memoryByteText)"
        case .disk:
            guard let free = metric.freeBytes else {
                return AppText.waiting
            }
            return "\(AppText.free) \(free.byteText)"
        case .network:
            return ""
        }
    }

    private var totalCapacityText: String? {
        guard let total = metric.totalBytes else { return nil }
        switch metric.kind {
        case .memory: return "\(AppText.totalCapacity) \(total.memoryByteText)"
        case .disk: return "\(AppText.totalCapacity) \(total.byteText)"
        case .cpu, .network: return nil
        }
    }

    private var valueColor: Color {
        guard usesThresholdColors else {
            return .primary
        }
        switch metric.level {
        case .normal: return .primary
        case .warning, .critical: return accent
        }
    }

    @ViewBuilder
    private var tileBackground: some View {
        if reduceTransparency || colorSchemeContrast == .increased {
            Color(nsColor: .controlBackgroundColor)
        } else {
            DesignTokens.surfaceFill(colorScheme: colorScheme)
        }
    }

    private var tileStroke: Color {
        if colorSchemeContrast == .increased {
            return Color.primary.opacity(0.28)
        }
        return DesignTokens.surfaceStroke(colorScheme: colorScheme)
    }
}

struct NetworkTileView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) private var envReduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let network: NetworkSnapshot
    let history: [Double]
    let usesThresholdColors: Bool

    private var motionReduced: Bool { envReduceMotion }

    private var accent: Color {
        DesignTokens.accent(for: .normal, kind: .network, usesThresholdColors: usesThresholdColors)
    }

    private var totalRate: Double {
        network.downloadBytesPerSecond + network.uploadBytesPerSecond
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: DesignTokens.iconContainer, height: DesignTokens.iconContainer)
                    .background(accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                Spacer(minLength: 4)

                Text(totalRate.byteRateText)
                    .font(.system(size: 15, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.primary)
                    .contentTransition(motionReduced ? .identity : .numericText(value: totalRate))
                    .animation(DesignTokens.valueAnimation(reduceMotion: motionReduced), value: totalRate)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            HStack {
                Text(AppText.metricTitle(.network))
                    .font(.system(size: 12, weight: .semibold))
                Spacer(minLength: 4)
                Text(AppText.combinedTraffic)
                    .font(.system(size: 12))
            }
            .foregroundStyle(.secondary)
            .padding(.top, 10)

            VStack(spacing: 3) {
                rateRow(title: AppText.download, value: network.downloadBytesPerSecond)
                rateRow(title: AppText.upload, value: network.uploadBytesPerSecond)
            }
            .padding(.top, 6)

            Spacer(minLength: 8)

            MetricSparklineView(
                values: history,
                color: accent,
                fixedRange: 0...MetricSparklineView.rollingUpperBound(for: history),
                showsArea: true,
                historyDescription: AppText.networkHistoryHint
            )
            .frame(height: 28)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: DesignTokens.tileMinHeight, alignment: .topLeading)
        .background(tileBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.tileCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.tileCornerRadius, style: .continuous)
                .strokeBorder(tileStroke, lineWidth: 0.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(AppText.metricTitle(.network)), \(AppText.combinedTraffic) \(totalRate.byteRateText), \(AppText.download) \(network.downloadBytesPerSecond.byteRateText), \(AppText.upload) \(network.uploadBytesPerSecond.byteRateText)")
        .accessibilityHint(AppText.networkHistoryHint)
    }

    private func rateRow(title: String, value: Double) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text(value.byteRateText)
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundStyle(.primary)
                .contentTransition(motionReduced ? .identity : .numericText(value: value))
                .animation(DesignTokens.valueAnimation(reduceMotion: motionReduced), value: value)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
    }

    @ViewBuilder
    private var tileBackground: some View {
        if reduceTransparency || colorSchemeContrast == .increased {
            Color(nsColor: .controlBackgroundColor)
        } else {
            DesignTokens.surfaceFill(colorScheme: colorScheme)
        }
    }

    private var tileStroke: Color {
        if colorSchemeContrast == .increased {
            return Color.primary.opacity(0.28)
        }
        return DesignTokens.surfaceStroke(colorScheme: colorScheme)
    }
}
