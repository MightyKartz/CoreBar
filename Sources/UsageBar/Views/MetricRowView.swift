import SwiftUI

struct MetricRowView: View {
    let metric: MetricSnapshot
    let history: [Double]

    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(alignment: .firstTextBaseline) {
                Text(AppText.metricTitle(metric.kind))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(compactDetailText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Text(metric.value.percentText)
                    .font(.system(size: 13, weight: .bold).monospacedDigit())
                    .foregroundStyle(accentColor)
            }
            .frame(width: 246, height: 16, alignment: .topLeading)
            .offset(y: -4)

            progressBar
                .offset(y: 20)

            MetricSparklineView(values: history, level: metric.level)
                .frame(width: 246, height: 31)
                .offset(y: 32)
        }
        .frame(width: 246, height: 86, alignment: .topLeading)
    }

    private var progressBar: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(.secondary.opacity(0.18))

            Capsule()
                .fill(accentColor)
                .frame(width: 246 * metric.value.clamped01)
        }
        .frame(width: 246, height: 5)
    }

    private var accentColor: Color {
        switch metric.level {
        case .normal: .green
        case .warning: .orange
        case .critical: .red
        }
    }

    private var compactDetailText: String {
        switch metric.kind {
        case .cpu:
            let cores = metric.coreCount ?? 0
            return "\(AppText.currentLoad) \(metric.value.percentText) · \(cores) \(AppText.cores)"
        case .memory:
            guard let used = metric.usedBytes, let total = metric.totalBytes else {
                return AppText.waiting
            }
            return "\(AppText.used) \(used.byteText) / \(total.byteText)"
        case .disk:
            guard let used = metric.usedBytes, let total = metric.totalBytes else {
                return AppText.waiting
            }
            return "\(AppText.used) \(used.byteText) / \(total.byteText)"
        }
    }
}
