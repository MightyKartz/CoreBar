import AppKit
import Combine
import SwiftUI

// MARK: - Panel heights (System Default shares one stable footprint)

@MainActor
enum PanelMetricsLayout {
    static let overviewHeaderHeight: CGFloat = 62

    /// Compact settings form ideal height (title + 3 groups, no scroll).
    static var settingsIdealHeight: CGFloat {
        // Equal vertical insets + 30pt title control + 12pt gap under title.
        let chrome = DesignTokens.panelContentTop + DesignTokens.panelContentBottom + 30 + 12
        // SettingsForm compact flat style: group title ~16, row 30, group gap 8.
        let groupTitle: CGFloat = 16
        let row: CGFloat = 30
        let groupGap: CGFloat = 8
        let general = groupTitle + row * 2
        let metrics = groupTitle + row * 4
        let appearance = groupTitle + row * 3
        let bottomSafety: CGFloat = 8
        return chrome + general + metrics + appearance + groupGap * 2 + bottomSafety
    }

    static func classicIntrinsicHeight(settings: AppSettings) -> CGFloat {
        let metricCount = max(
            1,
            [settings.showCPU, settings.showMemory, settings.showDisk].filter { $0 }.count
                + (settings.showNetwork ? 1 : 0)
        )
        let gapAfterHeader: CGFloat = 12
        // Flat list: no inter-card gaps (only hairline dividers).
        let list = CGFloat(metricCount) * DesignTokens.classicRowMinHeight
        return DesignTokens.panelContentTop + overviewHeaderHeight + gapAfterHeader + list + DesignTokens.panelContentBottom
    }

    static func controlCenterIntrinsicHeight(settings: AppSettings) -> CGFloat {
        let count = max(
            1,
            [settings.showCPU, settings.showMemory, settings.showDisk, settings.showNetwork].filter { $0 }.count
        )
        let rows = CGFloat((count + 1) / 2)
        let gapAfterHeader: CGFloat = 12
        return DesignTokens.panelContentTop + overviewHeaderHeight + gapAfterHeader
            + rows * DesignTokens.tileMinHeight
            + max(0, rows - 1) * DesignTokens.gridSpacing
            + DesignTokens.panelContentBottom
    }

    static func controlCenterPanelSize(settings: AppSettings) -> NSSize {
        systemDefaultPanelSize(settings: settings)
    }

    /// System Default switches between overview and settings in place, so both
    /// surfaces use the larger of their ideal heights. This prevents the metric
    /// grid from being clipped and avoids a visible resize during navigation.
    static func systemDefaultPanelSize(settings: AppSettings) -> NSSize {
        NSSize(
            width: DesignTokens.panelWidth,
            height: max(
                settingsIdealHeight,
                controlCenterIntrinsicHeight(settings: settings)
            )
        )
    }

    static func classicPanelSize(settings: AppSettings) -> NSSize {
        NSSize(
            width: DesignTokens.panelWidth,
            height: classicIntrinsicHeight(settings: settings)
        )
    }

    static var settingsPanelSize: NSSize {
        NSSize(width: DesignTokens.panelWidth, height: settingsIdealHeight)
    }
}

/// Shared overview chrome for Classic and System Default.
/// The first row owns navigation; the second row owns live system status.
struct OverviewPanelHeader: View {
    let timestamp: Date
    let level: HealthLevel
    let metricTitle: String
    let percent: Double
    let usesThresholdColors: Bool
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(AppText.usage)
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(-0.3)

                Spacer(minLength: 8)

                PanelIconButton(
                    systemName: "gearshape",
                    help: AppText.settings,
                    foreground: .secondary,
                    compact: true,
                    action: openSettings
                )
                .keyboardShortcut(",", modifiers: .command)
            }
            .frame(minHeight: 30)

            HStack(spacing: 8) {
                LiveTimestampLabel(timestamp: timestamp)
                    .fixedSize(horizontal: true, vertical: false)

                Spacer(minLength: 8)

                HealthPillView(
                    level: level,
                    metricTitle: metricTitle,
                    percent: percent,
                    usesThresholdColors: usesThresholdColors
                )
                .frame(maxWidth: 170, alignment: .trailing)
            }
        }
    }
}

// MARK: - Classic panel (vertical list, System Default color language)

struct StatusPanelView: View {
    @ObservedObject var monitor: SystemMonitor
    @ObservedObject var settings: AppSettings
    let openSettings: () -> Void

    static func contentSize(settings: AppSettings) -> NSSize {
        PanelMetricsLayout.classicPanelSize(settings: settings)
    }

    var body: some View {
        let metrics = settings.visibleMetrics(from: monitor.snapshot)
        let size = Self.contentSize(settings: settings)
        let networkShown = settings.showNetwork
        let rowCount = metrics.count + (networkShown ? 1 : 0)

        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 4)
                .padding(.bottom, 12)

            // Flat continuous list — no per-row glass cards / “cells”.
            VStack(spacing: 0) {
                ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
                    MetricRowView(
                        metric: metric,
                        history: monitor.history.values(for: metric.kind),
                        usesThresholdColors: settings.useThresholdColors
                    )
                    if index < metrics.count - 1 || networkShown {
                        classicRowDivider
                    }
                }

                if networkShown {
                    NetworkRowView(
                        network: monitor.snapshot.network,
                        history: monitor.history.values(for: .network),
                        usesThresholdColors: settings.useThresholdColors
                    )
                }

                if rowCount == 0 {
                    Text(AppText.noMetrics)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: DesignTokens.classicRowMinHeight, alignment: .leading)
                        .padding(.vertical, 12)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.top, DesignTokens.panelContentTop)
        .padding(.horizontal, DesignTokens.panelContentHorizontal)
        .padding(.bottom, DesignTokens.panelContentBottom)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        // NSPopover owns the outer chrome; fill with light-correct popover material (no second border).
        .background(ClassicPanelBackground(showsBorder: false, cornerRadius: 0))
    }

    private var classicRowDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: 0.5)
            .padding(.leading, DesignTokens.iconContainer + 10)
    }

    private var header: some View {
        OverviewPanelHeader(
            timestamp: monitor.snapshot.timestamp,
            level: monitor.snapshot.overallLevel,
            metricTitle: AppText.metricTitle(monitor.snapshot.headlineMetric.kind),
            percent: monitor.snapshot.headlineMetric.value,
            usesThresholdColors: settings.useThresholdColors,
            openSettings: openSettings
        )
    }
}

// MARK: - System Default panel

@MainActor
final class SystemPanelNavigationModel: ObservableObject {
    enum Page: Equatable {
        case overview
        case settings
    }

    @Published private(set) var page: Page = .overview

    func showOverview() {
        page = .overview
    }

    func showSettings() {
        page = .settings
    }
}

/// One stable floating panel whose SwiftUI content switches in place.
/// AppKit owns the window; SwiftUI owns the navigation state and transition.
struct SystemDefaultPanelView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var monitor: SystemMonitor
    @ObservedObject var settings: AppSettings
    @ObservedObject var navigation: SystemPanelNavigationModel
    let close: () -> Void

    var body: some View {
        let size = PanelMetricsLayout.systemDefaultPanelSize(settings: settings)

        SystemDefaultPanelSurface {
            ZStack {
                if navigation.page == .overview {
                    ControlCenterPanelView(
                        monitor: monitor,
                        settings: settings,
                        openSettings: navigation.showSettings,
                        showsChrome: false
                    )
                    .transition(.opacity)
                } else {
                    StandaloneSettingsPanelView(
                        settings: settings,
                        usesExternalSystemChrome: true
                    )
                    .transition(.opacity)
                }
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
        }
        .animation(.easeOut(duration: reduceMotion ? 0.10 : 0.16), value: navigation.page)
        .onExitCommand(perform: close)
    }
}

struct ControlCenterPanelView: View {
    @ObservedObject var monitor: SystemMonitor
    @ObservedObject var settings: AppSettings
    let openSettings: () -> Void
    var showsChrome: Bool = true

    static func contentSize(settings: AppSettings) -> NSSize {
        // Overview and settings share one stable System Default footprint.
        PanelMetricsLayout.controlCenterPanelSize(settings: settings)
    }

    var body: some View {
        let size = Self.contentSize(settings: settings)
        let metrics = settings.visibleMetrics(from: monitor.snapshot)

        if showsChrome {
            SystemDefaultPanelSurface {
                panelContent(metrics: metrics)
                    .frame(width: size.width, height: size.height, alignment: .topLeading)
            }
        } else {
            panelContent(metrics: metrics)
                .frame(width: size.width, height: size.height, alignment: .topLeading)
        }
    }

    private func panelContent(metrics: [MetricSnapshot]) -> some View {
        // Keep the header and first metric row anchored to the same origin even
        // when the user shows fewer than four metrics.
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 4)
                .padding(.bottom, 12)

            if metrics.isEmpty, !settings.showNetwork {
                Text(AppText.noMetrics)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: DesignTokens.tileMinHeight, alignment: .leading)
            } else {
                adaptiveMetricGrid(metrics: metrics)
            }

            Spacer(minLength: 0)
        }
        .padding(.top, DesignTokens.panelContentTop)
        .padding(.horizontal, DesignTokens.panelContentHorizontal)
        .padding(.bottom, DesignTokens.panelContentBottom)
    }

    private func adaptiveMetricGrid(metrics: [MetricSnapshot]) -> some View {
        let itemCount = metrics.count + (settings.showNetwork ? 1 : 0)
        let rows = AdaptiveMetricGridLayout.rows(for: itemCount)

        return Grid(
            alignment: .leading,
            horizontalSpacing: DesignTokens.gridSpacing,
            verticalSpacing: DesignTokens.gridSpacing
        ) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(row, id: \.self) { index in
                        metricItem(at: index, metrics: metrics)
                            .gridCellColumns(row.count == 1 ? 2 : 1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func metricItem(at index: Int, metrics: [MetricSnapshot]) -> some View {
        if metrics.indices.contains(index) {
            let metric = metrics[index]
            MetricTileView(
                metric: metric,
                history: monitor.history.values(for: metric.kind),
                usesThresholdColors: settings.useThresholdColors
            )
        } else {
            NetworkTileView(
                network: monitor.snapshot.network,
                history: monitor.history.values(for: .network),
                usesThresholdColors: settings.useThresholdColors
            )
        }
    }

    private var header: some View {
        OverviewPanelHeader(
            timestamp: monitor.snapshot.timestamp,
            level: monitor.snapshot.overallLevel,
            metricTitle: AppText.metricTitle(monitor.snapshot.headlineMetric.kind),
            percent: monitor.snapshot.headlineMetric.value,
            usesThresholdColors: settings.useThresholdColors,
            openSettings: openSettings
        )
    }
}

// MARK: - Shared system-default shell (metrics + settings)

/// One adaptive, content-bearing system material shared by overview, settings, and About.
struct SystemDefaultPanelSurface<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DesignTokens.panelCornerRadius, style: .continuous)

        LiquidGlassSurface(
            cornerRadius: DesignTokens.panelCornerRadius,
            material: .popover,
            showsBorder: false
        ) {
            content
        }
        .overlay {
            shape.strokeBorder(
                colorSchemeContrast == .increased
                    ? Color.primary.opacity(0.32)
                    : (colorScheme == .light
                        ? Color(nsColor: .separatorColor)
                        : Color.white.opacity(0.12)),
                lineWidth: colorSchemeContrast == .increased ? 1 : 0.5
            )
        }
        .shadow(
            color: Color.black.opacity(colorScheme == .light ? 0.11 : 0.28),
            radius: 16,
            y: 6
        )
    }
}

// MARK: - Standalone settings (dismiss by clicking outside)

/// Floating settings surface; host closes on outside click.
/// System Default: same size + chrome as ControlCenterPanelView. Classic: same as StatusPanelView popover.
struct StandaloneSettingsPanelView: View {
    @ObservedObject var settings: AppSettings
    var usesExternalSystemChrome: Bool = false

    private var size: NSSize {
        StatusItemController.settingsPanelSize(settings: settings)
    }

    private var isClassic: Bool {
        settings.panelStyle == .classic
    }

    @ViewBuilder
    var body: some View {
        if isClassic {
            panelContent
                // NSPopover draws the outer frame for Classic.
                .background(ClassicPanelBackground(showsBorder: false, cornerRadius: 0))
                .clipShape(Rectangle())
        } else if usesExternalSystemChrome {
            panelContent
        } else {
            SystemDefaultPanelSurface {
                panelContent
            }
        }
    }

    private var panelContent: some View {
        // Top-aligned like the metrics panel (same insets / footprint).
        VStack(alignment: .leading, spacing: 0) {
            Text(AppText.settings)
                .font(.system(size: 17, weight: .semibold))
                .tracking(-0.3)
                .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.bottom, 12)
            .focusSection()

            // Both panel styles use the same continuous settings list.
            SettingsForm(
                settings: settings,
                compact: true,
                flat: true
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .focusSection()

            Spacer(minLength: 0)
        }
        .padding(.top, DesignTokens.panelContentTop)
        .padding(.horizontal, DesignTokens.panelContentHorizontal)
        .padding(.bottom, DesignTokens.panelContentBottom)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

// MARK: - About

struct AboutPanelView: View {
    let close: () -> Void

    static let contentSize = NSSize(width: DesignTokens.panelWidth, height: 292)

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(AppText.version) \(version) (\(build))"
    }

    private var copyrightText: String {
        Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String
            ?? "Copyright © 2026 MightyKartz"
    }

    var body: some View {
        SystemDefaultPanelSurface {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 14) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 58, height: 58)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("CoreBar")
                            .font(.system(size: 20, weight: .semibold))
                            .tracking(-0.35)
                        Text(versionText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    Spacer(minLength: 8)

                    PanelIconButton(
                        systemName: "xmark",
                        help: AppText.close,
                        foreground: .secondary,
                        compact: true,
                        action: close
                    )
                }

                Text(AppText.localOnlyDescription)
                    .font(.system(size: 12.5, weight: .regular))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 16)
                    .padding(.bottom, 14)

                VStack(spacing: 8) {
                    aboutLink(
                        title: AppText.privacyPolicy,
                        systemName: "hand.raised",
                        destination: AppLinks.privacyPolicy
                    )
                    aboutLink(
                        title: AppText.getSupport,
                        systemName: "questionmark.circle",
                        destination: AppLinks.support
                    )
                }

                Spacer(minLength: 12)

                Text(copyrightText)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(20)
            .frame(
                width: Self.contentSize.width,
                height: Self.contentSize.height,
                alignment: .topLeading
            )
        }
        .onExitCommand(perform: close)
    }

    private func aboutLink(title: String, systemName: String, destination: URL) -> some View {
        Link(destination: destination) {
            HStack(spacing: 10) {
                Image(systemName: systemName)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 18)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
            .background(
                Color.primary.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

/// Layout policy for the four optional dashboard metrics.
/// One item spans the panel; three items use a 2 + 1 composition instead of
/// leaving a visually accidental empty tile.
enum AdaptiveMetricGridLayout {
    static func rows(for itemCount: Int) -> [[Int]] {
        let indices = Array(0..<max(0, itemCount))
        guard indices.count > 1 else {
            return indices.isEmpty ? [] : [indices]
        }

        return stride(from: 0, to: indices.count, by: 2).map { start in
            Array(indices[start..<min(start + 2, indices.count)])
        }
    }
}
