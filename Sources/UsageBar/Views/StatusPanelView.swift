import SwiftUI

struct StatusPanelView: View {
    @ObservedObject var monitor: SystemMonitor

    var body: some View {
        ZStack(alignment: .topLeading) {
            header

            ForEach(Array(monitor.snapshot.metrics.enumerated()), id: \.element.id) { index, metric in
                MetricRowView(
                    metric: metric,
                    history: monitor.history.values(for: metric.kind),
                    showsDetail: metric.kind != .disk
                )
                .offset(x: 24, y: 84 + CGFloat(index * 100))
            }
        }
        .frame(width: 340, height: 352, alignment: .topLeading)
        .background(VisualEffectBackground(material: .popover))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.45), lineWidth: 1)
        }
    }

    private var header: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 2) {
                Text(monitor.snapshot.overallLevel.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)

                Text("\(AppText.updated) \(monitor.snapshot.timestamp.shortTimeText)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .offset(x: 24, y: 20)

            Text(badgeText)
                .font(.system(size: 10, weight: .bold))
                .frame(width: 36, height: 20)
                .foregroundStyle(accentColor)
                .background(accentColor.opacity(0.14), in: Capsule())
                .offset(x: 280, y: 20)
        }
        .frame(width: 340, height: 64, alignment: .topLeading)
    }

    private var badgeText: String {
        if AppText.isChinese {
            switch monitor.snapshot.overallLevel {
            case .normal: "良好"
            case .warning: "警戒"
            case .critical: "高压"
            }
        } else {
            monitor.snapshot.overallLevel.shortTitle
        }
    }

    private var accentColor: Color {
        switch monitor.snapshot.overallLevel {
        case .normal: .green
        case .warning: .orange
        case .critical: .red
        }
    }
}
