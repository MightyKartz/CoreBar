import SwiftUI

struct MetricSparklineView: View {
    @Environment(\.colorSchemeContrast) private var contrast
    let values: [Double]
    let color: Color
    var fixedRange: ClosedRange<Double>? = 0...1
    var showsArea: Bool = true
    var historyDescription: String = AppText.recentSamplesHint
    var timestamps: [Date] = []
    var valueKind: MetricKind = .cpu
    var allowsInspection: Bool = false
    var showsGuides: Bool = false
    var secondaryValues: [Double] = []
    var secondaryColor: Color = .cyan
    @State private var inspectedDate: Date?

    var body: some View {
        GeometryReader { proxy in
            let points = Self.points(for: values, in: proxy.size, fixedRange: fixedRange, timestamps: timestamps)
            let secondary = Self.points(for: secondaryValues, in: proxy.size, fixedRange: fixedRange, timestamps: timestamps)
            ZStack {
                if showsGuides {
                    ForEach([0.0, 0.5, 1.0], id: \.self) { fraction in
                        Path { path in
                            let y = 5 + (proxy.size.height - 10) * fraction
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                        }
                        .stroke(Color.primary.opacity(contrast == .increased ? 0.25 : 0.08), lineWidth: DesignTokens.chartGuideWidth)
                    }
                }
                if showsArea, points.count > 1 {
                    SparklineAreaShape(points: points)
                        .fill(color.opacity(0.16))
                }

                if points.count > 1 {
                    SparklineLineShape(points: points)
                        .stroke(
                            color,
                            style: StrokeStyle(lineWidth: DesignTokens.trendLineWidth, lineCap: .round, lineJoin: .round)
                        )
                }
                if secondary.count > 1 {
                    SparklineLineShape(points: secondary)
                        .stroke(secondaryColor, style: StrokeStyle(lineWidth: DesignTokens.trendLineWidth, lineCap: .round, lineJoin: .round, dash: [4, 2]))
                }
                if let last = points.last {
                    Circle().fill(color).frame(width: 4, height: 4).position(last)
                }
                if let index = inspectedIndex, points.indices.contains(index) {
                    inspection(at: points[index], index: index, size: proxy.size)
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                guard allowsInspection, timestamps.count == values.count else { return }
                switch phase {
                case .active(let location):
                    let index = points.indices.min { abs(points[$0].x - location.x) < abs(points[$1].x - location.x) }
                    inspectedDate = index.map { timestamps[$0] }
                case .ended: inspectedDate = nil
                }
            }
        }
        // An active plot already has a sample callout; avoid a second help tag.
        .help(allowsInspection ? "" : historyDescription)
        .focusable(allowsInspection)
        .onMoveCommand { direction in
            guard allowsInspection else { return }
            if direction == .left { moveSelection(by: -1) }
            if direction == .right { moveSelection(by: 1) }
        }
        .onChange(of: timestamps) { _, dates in
            if let inspectedDate, !dates.contains(inspectedDate) { self.inspectedDate = nil }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(chartDescription)
        .accessibilityHint(allowsInspection ? AppText.inspectChartHint : "")
        .accessibilityValue(inspectedIndex.map(sampleDescription) ?? "")
        .accessibilityAdjustableAction { direction in
            guard allowsInspection else { return }
            moveSelection(by: direction == .increment ? 1 : -1)
        }
    }

    private var chartDescription: String {
        let title = secondaryValues.isEmpty
            ? (valueKind == .memory ? AppText.estimatedPressure : AppText.metricTitle(valueKind))
            : "\(AppText.download) / \(AppText.upload)"
        let range = fixedRange ?? 0...max(values.max() ?? 0, 1)
        let lower = valueKind == .network ? range.lowerBound.byteRateText : range.lowerBound.percentText
        let upper = valueKind == .network ? range.upperBound.byteRateText : range.upperBound.percentText
        return "\(title), \(historyDescription), \(AppText.chartRange) \(lower) – \(upper)"
    }

    private var inspectedIndex: Int? {
        guard let inspectedDate else { return nil }
        return timestamps.firstIndex(of: inspectedDate)
    }

    private func moveSelection(by offset: Int) {
        guard timestamps.count == values.count, !values.isEmpty else { return }
        let current = inspectedIndex ?? (offset < 0 ? values.count : -1)
        inspectedDate = timestamps[min(max(0, current + offset), values.count - 1)]
    }

    private func sampleDescription(_ index: Int) -> String {
        guard timestamps.indices.contains(index), values.indices.contains(index) else { return "" }
        let time = timestamps[index].formatted(date: .omitted, time: .standard)
        if secondaryValues.indices.contains(index) {
            return "\(time) · \(AppText.download) \(values[index].byteRateText) · \(AppText.upload) \(secondaryValues[index].byteRateText)"
        }
        let value = valueKind == .network ? values[index].byteRateText : values[index].percentText
        return "\(time) · \(AppText.metricTitle(valueKind)) \(value)"
    }

    private func inspection(at point: CGPoint, index: Int, size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            Path { path in
                path.move(to: CGPoint(x: point.x, y: 0))
                path.addLine(to: CGPoint(x: point.x, y: size.height))
            }
            .stroke(Color.primary.opacity(0.35), style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
            Circle().fill(color).frame(width: 6, height: 6).position(point)
            Text(sampleDescription(index))
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .foregroundStyle(.primary)
                .padding(6)
                .frame(width: min(180, size.width))
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                .offset(x: min(max(0, point.x - 90), max(0, size.width - 180)), y: -26)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
        paddingY: CGFloat = 5,
        timestamps: [Date] = []
    ) -> [CGPoint] {
        guard values.count > 1, size.width > 0, size.height > 0 else {
            return []
        }

        let normalized = normalizedValues(values, fixedRange: fixedRange)
        let usableHeight = max(1, size.height - paddingY * 2)
        let elapsed = timestamps.last.flatMap { last in timestamps.first.map { last.timeIntervalSince($0) } } ?? 0
        let usesTime = timestamps.count == values.count && elapsed > 0 && zip(timestamps, timestamps.dropFirst()).allSatisfy { $0 <= $1 }
        return normalized.enumerated().map { index, value in
            let fraction = usesTime ? timestamps[index].timeIntervalSince(timestamps[0]) / elapsed : Double(index) / Double(values.count - 1)
            let x = size.width * fraction
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
