import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @ObservedObject var settings: AppSettings

    static let contentSize = NSSize(width: 400, height: 480)

    var body: some View {
        SettingsForm(settings: settings, compact: false)
            .padding(16)
            .frame(width: Self.contentSize.width, height: Self.contentSize.height, alignment: .topLeading)
            .background {
                if colorScheme == .light || reduceTransparency || colorSchemeContrast == .increased {
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
    private var groupTitleSize: CGFloat { compact ? 11 : 12 }
    private var rowTitleSize: CGFloat { compact ? 12 : 13 }
    private var horizontalPad: CGFloat { flat ? 0 : (compact ? 10 : 14) }
    private var groupRadius: CGFloat { compact ? 12 : DesignTokens.settingsGroupRadius }

    var body: some View {
        let content = VStack(alignment: .leading, spacing: groupSpacing) {
            settingsGroup(title: AppText.general) {
                settingsRow(title: AppText.launchAtLogin) {
                    Toggle(AppText.launchAtLogin, isOn: launchAtLoginBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }

                settingsRow(title: AppText.refreshInterval) {
                    SettingsSegmentedControl(
                        title: AppText.refreshInterval,
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
                settingsToggle("CPU", isOn: $settings.showCPU, isMenuMetric: true)
                settingsToggle(AppText.metricTitle(.memory), isOn: $settings.showMemory, isMenuMetric: true)
                settingsToggle(AppText.metricTitle(.disk), isOn: $settings.showDisk, isMenuMetric: true)
                settingsToggle(AppText.networkPanelOnly, isOn: $settings.showNetwork)

                // Keep this explanation present so toggling metrics does not
                // move the appearance controls or the panel's lower edge.
                Text(AppText.minimumMenuMetricHint)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, horizontalPad)
                    .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
            }

            settingsGroup(title: AppText.appearance) {
                settingsRow(title: AppText.colorScheme) {
                    SettingsSegmentedControl(
                        title: AppText.colorScheme,
                        options: AppearanceMode.allCases.map { ($0, $0.title) },
                        selection: $settings.appearanceMode,
                        compact: compact
                    )
                    .frame(maxWidth: compact ? 200 : 220)
                }

                settingsRow(title: AppText.thresholdColors) {
                    Toggle(AppText.thresholdColors, isOn: $settings.useThresholdColors)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .help(AppText.thresholdColorsHint)
                        .accessibilityHint(AppText.thresholdColorsHint)
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
                        title: AppText.panelStyle,
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
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
        }

        // Keep the compact form still when it fits. A long login-item error or
        // larger text can use the same bounded panel without clipping controls.
        Group {
            if compact {
                ViewThatFits(in: .vertical) {
                    content.fixedSize(horizontal: false, vertical: true)
                    ScrollView {
                        content.padding(.bottom, 8)
                    }
                }
            } else {
                ScrollView {
                    content.padding(.bottom, 12)
                }
            }
        }
        // Keep the native switches and segmented pickers neutral in both
        // appearances, without changing the dashboard's semantic colors.
        .tint(Color(nsColor: .systemGray))
        .accentColor(Color(nsColor: .systemGray))
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
                            colorScheme == .light || reduceTransparency || colorSchemeContrast == .increased
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
                .accessibilityHidden(true)
            Spacer(minLength: 6)
            trailing()
        }
        .padding(.horizontal, horizontalPad)
        .frame(minHeight: rowHeight)
    }

    private func settingsToggle(_ title: String, isOn: Binding<Bool>, isMenuMetric: Bool = false) -> some View {
        settingsRow(title: title) {
            let toggle = Toggle(title, isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)

            if isMenuMetric {
                toggle
                    .disabled(isOn.wrappedValue && enabledMenuMetricCount == 1)
                    .help(AppText.minimumMenuMetricHint)
                    .accessibilityHint(AppText.minimumMenuMetricHint)
            } else {
                toggle
            }
        }
        .help(isMenuMetric ? AppText.minimumMenuMetricHint : "")
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

/// Use the native segmented picker for selection, keyboard navigation, and
/// VoiceOver semantics while retaining the form's existing widths and density.
struct SettingsSegmentedControl<Value: Hashable>: View {
    let title: String
    let options: [(Value, String)]
    @Binding var selection: Value
    var compact: Bool = false

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(options, id: \.0) { value, label in
                Text(label).tag(value)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .controlSize(compact ? .small : .regular)
    }
}
