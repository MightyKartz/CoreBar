import SwiftUI

struct MetricRowView: View {
    let metric: MetricSnapshot
    let history: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: metric.symbol)
                    .foregroundStyle(metric.level.color)
                    .frame(width: 18)

                Text(AppText.metricTitle(metric.kind))
                    .font(.subheadline.weight(.medium))

                Spacer()

                Text(metric.value.percentText)
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(metric.level.color)
            }

            ProgressView(value: metric.value.clamped01)
                .tint(metric.level.color)

            MetricSparklineView(values: history, level: metric.level)
                .frame(height: 28)

            Text(detailText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var detailText: String {
        switch metric.kind {
        case .cpu:
            let cores = metric.coreCount ?? 0
            return "\(AppText.currentLoad) \(metric.value.percentText) · \(cores) \(AppText.cores)"
        case .memory:
            guard let used = metric.usedBytes, let total = metric.totalBytes else {
                return AppText.waiting
            }
            return "\(AppText.used) \(used.byteText) / \(total.byteText) · \(AppText.pressure) \(metric.level.title)"
        case .disk:
            guard let used = metric.usedBytes, let total = metric.totalBytes, let free = metric.freeBytes else {
                return AppText.waiting
            }
            return "\(AppText.used) \(used.byteText) / \(total.byteText) · \(AppText.free) \(free.byteText)"
        }
    }
}
