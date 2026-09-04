import AppKit
import ServiceManagement
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings.shared
    private var monitor: SystemMonitor?
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let monitor = SystemMonitor(settings: settings)
        self.monitor = monitor
        statusItemController = StatusItemController(monitor: monitor, settings: settings)
    }
}

@main
struct CoreBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(settings: .shared)
        }
    }
}

struct SettingsView: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @ObservedObject var settings: AppSettings

    static let contentSize = NSSize(width: 400, height: 480)

    var body: some View {
        SettingsForm(settings: settings, compact: false)
            .padding(16)
            .frame(width: Self.contentSize.width, height: Self.contentSize.height, alignment: .topLeading)
            .background {
                if reduceTransparency || colorSchemeContrast == .increased {
                    Color(nsColor: .windowBackgroundColor)
                } else {
                    VisualEffectBackground(material: .sidebar)
                }
            }
    }
}

/// Settings UI aligned with the glass panel language.
/// - `compact: true` denser rows for floating panel.
/// - `flat: true` continuous list style — section titles only, no grouped cell backgrounds.
struct SettingsForm: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ObservedObject var settings: AppSettings
    var compact: Bool = false
    var flat: Bool = false

    private var groupSpacing: CGFloat { compact ? (flat ? 8 : 6) : 14 }
    private var rowHeight: CGFloat { compact ? 30 : 44 }
    private var groupTitleSize: CGFloat { compact ? 10 : 11 }
    private var rowTitleSize: CGFloat { compact ? 12 : 13 }
    private var horizontalPad: CGFloat { flat ? 0 : (compact ? 10 : 14) }
    private var groupRadius: CGFloat { compact ? 12 : DesignTokens.settingsGroupRadius }

    var body: some View {
        let content = VStack(alignment: .leading, spacing: groupSpacing) {
            settingsGroup(title: AppText.general) {
                settingsRow(title: AppText.launchAtLogin) {
                    Toggle("", isOn: launchAtLoginBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }

                settingsRow(title: AppText.refreshInterval) {
                    SettingsSegmentedControl(
                        options: [
                            (1.0, AppText.seconds(1)),
                            (2.0, AppText.seconds(2)),
                            (5.0, AppText.seconds(5)),
                            (10.0, AppText.seconds(10))
                        ],
                        selection: refreshIntervalBinding,
                        compact: compact
                    )
                    .frame(maxWidth: compact ? 188 : 210)
                }

            }

            settingsGroup(title: AppText.visibleMetrics) {
                settingsToggle("CPU", isOn: $settings.showCPU)
                    .disabled(settings.showCPU && enabledMenuMetricCount == 1)
                settingsToggle(AppText.metricTitle(.memory), isOn: $settings.showMemory)
                    .disabled(settings.showMemory && enabledMenuMetricCount == 1)
                settingsToggle(AppText.metricTitle(.disk), isOn: $settings.showDisk)
                    .disabled(settings.showDisk && enabledMenuMetricCount == 1)
                settingsToggle(AppText.networkPanelOnly, isOn: $settings.showNetwork)
            }

            settingsGroup(title: AppText.appearance) {
                settingsRow(title: AppText.colorScheme) {
                    SettingsSegmentedControl(
                        options: AppearanceMode.allCases.map { ($0, $0.title) },
                        selection: $settings.appearanceMode,
                        compact: compact
                    )
                    .frame(maxWidth: compact ? 200 : 220)
                }

                settingsRow(title: AppText.thresholdColors) {
                    Toggle("", isOn: $settings.useThresholdColors)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }

                if !compact {
                    Text(AppText.thresholdColorsHint)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, horizontalPad)
                        .padding(.bottom, 8)
                }

                settingsRow(title: AppText.panelStyle) {
                    SettingsSegmentedControl(
                        options: PanelStyle.allCases.map { ($0, $0.title) },
                        selection: $settings.panelStyle,
                        compact: compact
                    )
                    .frame(maxWidth: compact ? 180 : 200)
                }
            }

            if let loginItemError = settings.loginItemError {
                Text(loginItemError)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DesignTokens.red)
                    .textSelection(.enabled)
                    .padding(.horizontal, 4)
            }
        }

        // In-panel: no ScrollView so everything stays visible at overview size.
        if compact {
            content
        } else {
            ScrollView {
                content.padding(.bottom, 12)
            }
        }
    }

    private func settingsGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 6) {
            Text(title)
                .font(.system(size: groupTitleSize, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)
                .padding(.horizontal, flat ? 0 : 4)

            if flat {
                // Classic: continuous list surface, no inset cards / cells.
                VStack(spacing: 0) {
                    content()
                }
            } else {
                VStack(spacing: 0) {
                    content()
                }
                .background {
                    RoundedRectangle(cornerRadius: groupRadius, style: .continuous)
                        .fill(
                            reduceTransparency || colorSchemeContrast == .increased
                                ? Color(nsColor: .controlBackgroundColor)
                                : DesignTokens.surfaceFillStrong(colorScheme: colorScheme)
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: groupRadius, style: .continuous)
                        .strokeBorder(
                            colorSchemeContrast == .increased
                                ? Color.primary.opacity(0.28)
                                : DesignTokens.surfaceStroke(colorScheme: colorScheme),
                            lineWidth: colorSchemeContrast == .increased ? 1 : 0.5
                        )
                }
                .clipShape(RoundedRectangle(cornerRadius: groupRadius, style: .continuous))
            }
        }
    }

    private func settingsRow<Content: View>(title: String, @ViewBuilder trailing: () -> Content) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: rowTitleSize, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 6)
            trailing()
        }
        .padding(.horizontal, horizontalPad)
        .frame(minHeight: rowHeight)
    }

    private func settingsToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        settingsRow(title: title) {
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }

    private var enabledMenuMetricCount: Int {
        [settings.showCPU, settings.showMemory, settings.showDisk].filter { $0 }.count
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding {
            SMAppService.mainApp.status == .enabled
        } set: { enabled in
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                settings.loginItemError = nil
                settings.objectWillChange.send()
            } catch {
                settings.loginItemError = error.localizedDescription
                settings.objectWillChange.send()
            }
        }
    }

    private var refreshIntervalBinding: Binding<Double> {
        Binding {
            settings.refreshInterval
        } set: { value in
            settings.refreshInterval = value
        }
    }
}

/// Preview segmented: soft track + light active pill.
struct SettingsSegmentedControl<Value: Hashable>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let options: [(Value, String)]
    @Binding var selection: Value
    var compact: Bool = false

    private var usesSolidContrastStyle: Bool {
        reduceTransparency || colorSchemeContrast == .increased
    }

    private var trackFill: Color {
        if usesSolidContrastStyle {
            return Color.primary.opacity(colorScheme == .dark ? 0.18 : 0.12)
        }
        return colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    }

    private var activeFill: Color {
        if usesSolidContrastStyle {
            return Color(nsColor: .windowBackgroundColor)
        }
        return colorScheme == .dark ? Color.white.opacity(0.14) : Color.white.opacity(0.58)
    }

    private var activeStroke: Color {
        if usesSolidContrastStyle {
            return Color.primary.opacity(0.48)
        }
        return colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, item in
                let isSelected = selection == item.0
                Button {
                    selection = item.0
                } label: {
                    Text(item.1)
                        .font(.system(size: compact ? 10.5 : 11.5, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, compact ? 4 : 5)
                        .padding(.horizontal, compact ? 4 : 6)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: compact ? 6 : 7, style: .continuous)
                                    .fill(activeFill)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: compact ? 6 : 7, style: .continuous)
                                            .strokeBorder(
                                                activeStroke,
                                                lineWidth: usesSolidContrastStyle ? 1 : 0.5
                                            )
                                    }
                                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.25 : 0.08), radius: 1.5, y: 0.5)
                            }
                        }
                }
                .buttonStyle(SettingsSegmentedButtonStyle())
            }
        }
        .padding(2)
        .background {
            RoundedRectangle(cornerRadius: compact ? 8 : 9, style: .continuous)
                .fill(trackFill)
        }
    }
}

private struct SettingsSegmentedButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
