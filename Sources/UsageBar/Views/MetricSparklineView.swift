import SwiftUI

struct MetricSparklineView: View {
    let values: [Double]
    let level: HealthLevel

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 0, dy: 5)

            guard values.count > 1 else {
                return
            }

            let low = values.min() ?? 0
            let high = values.max() ?? 1
            let range = high - low
            var path = Path()
            for (index, value) in values.enumerated() {
                let x = rect.minX + rect.width * CGFloat(index) / CGFloat(values.count - 1)
                let normalized = range > 0.02 ? (value.clamped01 - low) / range : 0.5
                let y = rect.maxY - rect.height * CGFloat(normalized.clamped01)
                let point = CGPoint(x: x, y: y)

                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }

            context.stroke(path, with: .color(accentColor.opacity(0.82)), lineWidth: 2)
        }
        .accessibilityLabel("60 second history")
    }

    private var accentColor: Color {
        switch level {
        case .normal: .green
        case .warning: .orange
        case .critical: .red
        }
    }
}
