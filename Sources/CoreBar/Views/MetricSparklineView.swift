import SwiftUI

struct MetricSparklineView: View {
    let values: [Double]
    let color: Color
    var fixedRange: ClosedRange<Double>? = 0...1
    var showsArea: Bool = true
    var historyDescription: String = AppText.recentSamplesHint

    var body: some View {
        GeometryReader { proxy in
            let points = Self.points(for: values, in: proxy.size, fixedRange: fixedRange)
            ZStack {
                if showsArea, points.count > 1 {
                    SparklineAreaShape(points: points)
                        .fill(color.opacity(0.16))
                }

                if points.count > 1 {
                    SparklineLineShape(points: points)
                        .stroke(
                            color.opacity(0.88),
                            style: StrokeStyle(lineWidth: 1.75, lineCap: .round, lineJoin: .round)
                        )
                }
            }
        }
        .help(historyDescription)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(historyDescription)
    }

    static func normalizedValues(_ values: [Double], fixedRange: ClosedRange<Double>?) -> [Double] {
        let lower = fixedRange?.lowerBound ?? 0
        let upper = fixedRange?.upperBound ?? max(values.max() ?? 0, 1)
        let span = max(upper - lower, .ulpOfOne)
        return values.map { (($0 - lower) / span).clamped01 }
    }

    /// A stepped ceiling keeps a network chart anchored at zero with headroom,
    /// while avoiding a full-height redraw for every small change in peak rate.
    static func rollingUpperBound(
        for values: [Double],
        minimum: Double = 128 * 1_024
    ) -> Double {
        let peak = max(0, values.max() ?? 0)
        guard peak > 0 else { return minimum }

        let paddedPeak = peak * 1.15
        let magnitude = pow(10, floor(log10(paddedPeak)))
        let normalized = paddedPeak / magnitude
        let roundedStep: Double
        switch normalized {
        case ...1: roundedStep = 1
        case ...2: roundedStep = 2
        case ...5: roundedStep = 5
        default: roundedStep = 10
        }
        return max(minimum, roundedStep * magnitude)
    }

    /// Geometry helper for tests and Canvas drawing.
    static func points(
        for values: [Double],
        in size: CGSize,
        fixedRange: ClosedRange<Double>?,
        paddingY: CGFloat = 5
    ) -> [CGPoint] {
        guard values.count > 1, size.width > 0, size.height > 0 else {
            return []
        }

        let normalized = normalizedValues(values, fixedRange: fixedRange)
        let usableHeight = max(1, size.height - paddingY * 2)
        return normalized.enumerated().map { index, value in
            let x = size.width * CGFloat(index) / CGFloat(values.count - 1)
            let y = paddingY + usableHeight * (1 - CGFloat(value))
            return CGPoint(x: x, y: y)
        }
    }
}

private struct SparklineLineShape: Shape {
    var points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }
}

private struct SparklineAreaShape: Shape {
    var points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first, let last = points.last else { return path }
        path.move(to: CGPoint(x: first.x, y: rect.maxY))
        path.addLine(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.addLine(to: CGPoint(x: last.x, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
