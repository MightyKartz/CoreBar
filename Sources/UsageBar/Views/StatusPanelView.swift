import AppKit
import SwiftUI

struct StatusPanelView: View {
    @ObservedObject var monitor: SystemMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            VStack(spacing: 12) {
                ForEach(monitor.snapshot.metrics) { metric in
                    MetricRowView(metric: metric, history: monitor.history.values(for: metric.kind))
                }
            }

            Divider()

            HStack {
                Button(AppText.refresh) {
                    monitor.refresh()
                }

                Button(AppText.activityMonitor) {
                    openActivityMonitor()
                }

                Spacer()

                Button(AppText.quit) {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .padding(16)
        .frame(width: 340)
        .background(VisualEffectBackground(material: .popover))
    }

    private var header: some View {
        HStack(spacing: 10) {
            statusIcon

            VStack(alignment: .leading, spacing: 2) {
                Text(monitor.snapshot.overallLevel.title)
                    .font(.headline)
                Text("\(AppText.updated) \(monitor.snapshot.timestamp.shortTimeText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(monitor.snapshot.overallLevel.shortTitle)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .foregroundStyle(monitor.snapshot.overallLevel.color)
                .background(monitor.snapshot.overallLevel.color.opacity(0.14), in: Capsule())
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        let icon = Image(systemName: "gauge.with.dots.needle.67percent")
            .font(.title2)
            .foregroundStyle(monitor.snapshot.overallLevel.color)

        if monitor.snapshot.overallLevel == .normal {
            icon
        } else {
            icon.symbolEffect(.pulse, options: .repeating, value: monitor.snapshot.timestamp)
        }
    }

    private func openActivityMonitor() {
        let url = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}
