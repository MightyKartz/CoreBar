import SwiftUI

struct MetricSparklineView: View {
    let values: [Double]
    let level: HealthLevel

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)

            guard values.count > 1 else {
                return
            }

            var path = Path()
            for (index, value) in values.enumerated() {
                let x = rect.minX + rect.width * CGFloat(index) / CGFloat(values.count - 1)
                let y = rect.maxY - rect.height * CGFloat(value.clamped01)
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
