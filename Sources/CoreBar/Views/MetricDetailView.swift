import SwiftUI

/// The explicit button provides keyboard/VoiceOver access alongside row clicks.
struct MetricDetailButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DesignTokens.supportingText)
                .frame(width: 20, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(AppText.showDetails)
        .accessibilityLabel(AppText.showDetails)
    }
}

/// Details read the monitor's existing snapshot/history; navigation never samples.
struct MetricDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var monitor: SystemMonitor
    @ObservedObject var settings: AppSettings
    let kind: MetricKind
    let back: () -> Void

    private var metric: MetricSnapshot? { monitor.snapshot.metric(for: kind) }
    private var values: [Double] { monitor.history.values(for: kind) }
    private var accent: Color {
        DesignTokens.accent(for: metric?.level ?? .normal, kind: kind, usesThresholdColors: settings.useThresholdColors)
    }
    private var capacityColor: Color {
        kind == .memory ? DesignTokens.accent(for: .normal, kind: kind, usesThresholdColors: settings.useThresholdColors) : accent
    }
    private var isNetwork: Bool { kind == .network }
    private var downloadColor: Color {
        guard settings.useThresholdColors else { return .primary }
        return colorScheme == .light ? DesignTokens.blue : .cyan
    }
    private var chartValues: [Double] { isNetwork ? monitor.history.download : values }
    private var chartRange: ClosedRange<Double> {
        isNetwork ? 0...MetricSparklineView.rollingUpperBound(for: monitor.history.download + monitor.history.upload) : 0...1
    }
    private var currentValue: Double {
        isNetwork ? monitor.snapshot.network.downloadBytesPerSecond + monitor.snapshot.network.uploadBytesPerSecond : metric?.value ?? 0
    }
    private func valueText(_ value: Double) -> String { isNetwork ? value.byteRateText : value.percentText }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(action: back) { Label(AppText.backToUsage, systemImage: "chevron.left") }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .keyboardShortcut("[", modifiers: .command)
                Spacer(minLength: 8)
                Text(AppText.metricTitle(kind)).font(.system(size: 17, weight: .semibold))
            }
            .frame(minHeight: 30)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    hero
                    trend
                    statistics
                    supportingDetails
                    if kind == .disk { externalDisks }
                    Divider()
                    if kind != .memory {
                        Text(AppText.metricExplanation(kind))
                            .font(.system(size: 12))
                            .foregroundStyle(DesignTokens.supportingText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 6)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.top, DesignTokens.panelContentTop)
        .padding(.horizontal, DesignTokens.panelContentHorizontal)
        .padding(.bottom, DesignTokens.panelContentBottom)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(kind == .memory ? AppText.estimatedPressure : (isNetwork ? AppText.combinedTraffic : AppText.currentLoadFor(kind)))
                .font(.system(size: 12)).foregroundStyle(DesignTokens.supportingText)
            HStack(alignment: .firstTextBaseline) {
                Text(valueText(currentValue))
                    .font(.system(size: isNetwork ? 27 : 32, weight: .semibold).monospacedDigit())
                    .lineLimit(1).minimumScaleFactor(0.8)
                Spacer()
                if let metric {
                    Text(metric.level.title).font(.system(size: 12, weight: .medium)).foregroundStyle(.primary)
                }
            }
            if isNetwork {
                detailRow(AppText.download, monitor.snapshot.network.downloadBytesPerSecond.byteRateText)
                detailRow(AppText.upload, monitor.snapshot.network.uploadBytesPerSecond.byteRateText)
            }
            if kind == .memory {
                Text(AppText.memoryExplanation)
                    .font(.system(size: 11)).foregroundStyle(DesignTokens.supportingText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var trend: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(AppText.recentHistory).font(.system(size: 12, weight: .semibold))
                Spacer(minLength: 4)
                Text(AppText.historySummary(timestamps: monitor.history.timestamps))
                    .font(.system(size: 10)).foregroundStyle(DesignTokens.supportingText)
            }
            HStack {
                Text(valueText(chartRange.upperBound))
                Spacer()
                if isNetwork { Text(AppText.automaticScale) }
            }
            .font(.system(size: 10).monospacedDigit()).foregroundStyle(DesignTokens.supportingText)
            MetricSparklineView(
                values: chartValues,
                color: isNetwork ? downloadColor : accent,
                fixedRange: chartRange,
                showsArea: true,
                historyDescription: AppText.historySummary(timestamps: monitor.history.timestamps),
                timestamps: monitor.history.timestamps,
                valueKind: kind,
                allowsInspection: true,
                showsGuides: true,
                secondaryValues: isNetwork ? monitor.history.upload : [],
                secondaryColor: accent
            )
            .frame(height: 130)
            HStack {
                Text(valueText(0))
                Spacer()
                if let first = monitor.history.timestamps.first {
                    Text(first.formatted(date: .omitted, time: .standard))
                }
                Text("–")
                if let last = monitor.history.timestamps.last {
                    Text(last.formatted(date: .omitted, time: .standard))
                }
            }
            .font(.system(size: 10).monospacedDigit()).foregroundStyle(DesignTokens.supportingText)
            if isNetwork {
                HStack(spacing: 16) {
                    Label {
                        Text(AppText.download).foregroundStyle(DesignTokens.supportingText)
                    } icon: {
                        Image(systemName: "arrow.down").foregroundStyle(downloadColor)
                    }
                    Label {
                        Text(AppText.upload).foregroundStyle(DesignTokens.supportingText)
                    } icon: {
                        Image(systemName: "arrow.up").foregroundStyle(accent)
                    }
                    Text(AppText.uploadDashed).foregroundStyle(DesignTokens.supportingText)
                }
                .font(.system(size: 10))
            }
        }
    }

    private var statistics: some View {
        VStack(alignment: .leading, spacing: 4) {
            if isNetwork {
                Text(AppText.combinedTraffic).font(.system(size: 10)).foregroundStyle(DesignTokens.supportingText)
            }
            HStack(spacing: 16) {
                stat(AppText.recentAverage, values.isEmpty ? nil : values.reduce(0, +) / Double(values.count))
                Divider()
                stat(AppText.recentPeak, values.max())
            }
            .frame(height: 40)
        }
    }

    private func stat(_ title: String, _ value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 11)).foregroundStyle(DesignTokens.supportingText)
            Text(value.map(valueText) ?? "—").font(.system(size: 15, weight: .semibold).monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var supportingDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let metric, let capacity = metric.capacityFraction {
                detailRow(AppText.capacityUsage, capacity.percentText)
                MetricProgressBar(value: capacity, color: capacityColor, thresholds: kind == .disk ? [0.85, 0.95] : [])
                if let used = metric.usedBytes { detailRow(AppText.used, kind == .memory ? used.memoryByteText : used.byteText) }
                if let total = metric.totalBytes { detailRow(AppText.totalCapacity, kind == .memory ? total.memoryByteText : total.byteText) }
                if kind == .disk, let free = metric.freeBytes { detailRow(AppText.free, free.byteText) }
            }
            if kind == .cpu, let cores = metric?.coreCount { detailRow(AppText.cores, "\(cores)") }
            if isNetwork {
                detailRow(AppText.samplingScope, AppText.networkScope)
                detailRow(AppText.refreshInterval, AppText.seconds(settings.refreshInterval))
            } else {
                Text(AppText.thresholdExplanation(kind)).font(.system(size: 11)).foregroundStyle(DesignTokens.supportingText)
            }
        }
    }

    private var externalDisks: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            Text(AppText.externalDisks).font(.system(size: 13, weight: .semibold))
            if monitor.snapshot.externalDisks.isEmpty {
                Text(AppText.noExternalDisks).font(.system(size: 12)).foregroundStyle(DesignTokens.supportingText)
            }
            ForEach(monitor.snapshot.externalDisks) { disk in
                VStack(alignment: .leading, spacing: 6) {
                    Label(disk.name, systemImage: "externaldrive")
                        .font(.system(size: 12, weight: .medium))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(disk.mountPath).font(.system(size: 10)).foregroundStyle(DesignTokens.supportingText)
                        .fixedSize(horizontal: false, vertical: true)
                    if let fraction = disk.usedFraction, let used = disk.usedBytes,
                       let total = disk.totalBytes, let free = disk.freeBytes {
                        detailRow(AppText.capacityUsage, fraction.percentText)
                        MetricProgressBar(value: fraction, color: DesignTokens.accent(
                            for: HealthRules.level(for: fraction, warning: 0.85, critical: 0.95),
                            kind: .disk, usesThresholdColors: settings.useThresholdColors), thresholds: [0.85, 0.95])
                        detailRow(AppText.used, used.byteText)
                        detailRow(AppText.totalCapacity, total.byteText)
                        detailRow(AppText.free, min(free, total).byteText)
                    } else {
                        Text(AppText.capacityUnavailable).font(.system(size: 12)).foregroundStyle(DesignTokens.supportingText)
                    }
                }
                .padding(.vertical, 4)
            }
            Text(AppText.externalDiskHint).font(.system(size: 11)).foregroundStyle(DesignTokens.supportingText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title).foregroundStyle(DesignTokens.supportingText)
            Spacer(minLength: 4)
            Text(value).monospacedDigit().multilineTextAlignment(.trailing)
        }
        .font(.system(size: 12))
        .accessibilityElement(children: .combine)
    }
}
