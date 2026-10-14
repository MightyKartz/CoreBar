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
    @State private var hoveredDate: Date?
    @State private var keyboardDate: Date?
    @FocusState private var chartHasFocus: Bool

    private var inspectedDate: Date? { hoveredDate ?? keyboardDate }
    private var calloutHeight: CGFloat {
        guard allowsInspection else { return 0 }
        return showsGuides ? DesignTokens.detailInspectionHeight : DesignTokens.overviewInspectionHeight
    }

    var body: some View {
        GeometryReader { proxy in
            let plotSize = CGSize(width: proxy.size.width, height: max(1, proxy.size.height - calloutHeight))
            let points = Self.points(for: values, in: plotSize, fixedRange: fixedRange, timestamps: timestamps)
            let secondary = Self.points(for: secondaryValues, in: plotSize, fixedRange: fixedRange, timestamps: timestamps)
            ZStack {
                if showsGuides {
                    ForEach([0.0, 0.5, 1.0], id: \.self) { fraction in
                        Path { path in
                            let y = 5 + (plotSize.height - 10) * fraction
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: plotSize.width, y: y))
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
                if secondary.count == 1, let point = secondary.first {
                    Circle().stroke(secondaryColor, lineWidth: 1.5).frame(width: 5, height: 5).position(point)
                }
                if let index = inspectedIndex, points.indices.contains(index) {
                    inspection(at: points[index], size: plotSize)
                }
            }
            .frame(width: plotSize.width, height: plotSize.height)
            .offset(y: calloutHeight)
            .overlay(alignment: .topLeading) {
                if let index = inspectedIndex, let sample = inspectionSample(at: index), points.indices.contains(index) {
                    let width = min(showsGuides ? 220.0 : 180.0, proxy.size.width)
                    ChartInspectionCallout(sample: sample, compact: !showsGuides)
                        .frame(width: width, height: calloutHeight - 2)
                        .offset(x: min(max(0, points[index].x - width / 2), max(0, proxy.size.width - width)))
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                guard allowsInspection else { return }
                let candidate: Date?
                switch phase {
                case .active(let location):
                    candidate = Self.nearestSampleDate(at: location.x, points: points, timestamps: timestamps)
                case .ended: candidate = nil
                }
                // Pointer events within the same sample must not republish view state.
                if hoveredDate != candidate { hoveredDate = candidate }
            }
        }
        // An active plot already has a sample callout; avoid a second help tag.
        .help(allowsInspection ? "" : historyDescription)
        .focusable(allowsInspection)
        .focused($chartHasFocus)
        .onChange(of: chartHasFocus) { _, focused in
            if !focused, keyboardDate != nil { keyboardDate = nil }
        }
        .onMoveCommand { direction in
            guard allowsInspection else { return }
            if direction == .left { moveSelection(by: -1) }
            if direction == .right { moveSelection(by: 1) }
        }
        .onChange(of: timestamps) { _, dates in
            if let hoveredDate, !dates.contains(hoveredDate) { self.hoveredDate = nil }
            if let keyboardDate, !dates.contains(keyboardDate) { self.keyboardDate = nil }
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
            ? AppText.inspectionMetricTitle(valueKind)
            : "\(AppText.download) / \(AppText.upload)"
        let range = fixedRange ?? 0...max(values.max() ?? 0, 1)
        let lower = valueKind == .network ? range.lowerBound.byteRateText : range.lowerBound.percentText
        let upper = valueKind == .network ? range.upperBound.byteRateText : range.upperBound.percentText
        return "\(title), \(historyDescription), \(AppText.chartRange) \(lower) – \(upper)"
    }

    private var inspectedIndex: Int? {
        guard timestamps.count == values.count, let inspectedDate else { return nil }
        return timestamps.firstIndex(of: inspectedDate)
    }

    private func moveSelection(by offset: Int) {
        guard timestamps.count == values.count, !values.isEmpty else { return }
        let current = keyboardDate.flatMap { timestamps.firstIndex(of: $0) }
            ?? inspectedIndex ?? (offset < 0 ? values.count : -1)
        let candidate = timestamps[min(max(0, current + offset), values.count - 1)]
        if hoveredDate != nil { hoveredDate = nil }
        if keyboardDate != candidate { keyboardDate = candidate }
    }

    private func inspectionSample(at index: Int) -> ChartInspectionSample? {
        Self.inspectionSample(at: index, values: values, timestamps: timestamps,
                              kind: valueKind, secondaryValues: secondaryValues)
    }

    private func sampleDescription(_ index: Int) -> String {
        inspectionSample(at: index)?.description ?? ""
    }

    static func inspectionSample(at index: Int, values: [Double], timestamps: [Date],
                                 kind: MetricKind, secondaryValues: [Double] = []) -> ChartInspectionSample? {
        guard timestamps.count == values.count, timestamps.indices.contains(index),
              secondaryValues.isEmpty || secondaryValues.count == values.count else { return nil }
        let time = timestamps[index].formatted(date: .omitted, time: .standard)
        let readings: [ChartInspectionValue]
        if kind == .network, secondaryValues.count == values.count {
            readings = [ChartInspectionValue(title: AppText.download, value: values[index].byteRateText),
                        ChartInspectionValue(title: AppText.upload, value: secondaryValues[index].byteRateText)]
        } else {
            readings = [ChartInspectionValue(title: AppText.inspectionMetricTitle(kind),
                                            value: kind == .network ? values[index].byteRateText : values[index].percentText)]
        }
        return ChartInspectionSample(time: time, readings: readings)
    }

    static func nearestSampleDate(at x: CGFloat, points: [CGPoint], timestamps: [Date]) -> Date? {
        guard !points.isEmpty, points.count == timestamps.count else { return nil }
        let index = points.indices.min { abs(points[$0].x - x) < abs(points[$1].x - x) }
        return index.map { timestamps[$0] }
    }

    private func inspection(at point: CGPoint, size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            Path { path in
                path.move(to: CGPoint(x: point.x, y: 0))
                path.addLine(to: CGPoint(x: point.x, y: size.height))
            }
            .stroke(Color.primary.opacity(0.35), style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
            Circle().fill(color).frame(width: 6, height: 6).position(point)
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
        guard !values.isEmpty, size.width > 0, size.height > 0 else {
            return []
        }

        let normalized = normalizedValues(values, fixedRange: fixedRange)
        let usableHeight = max(1, size.height - paddingY * 2)
        let elapsed = timestamps.last.flatMap { last in timestamps.first.map { last.timeIntervalSince($0) } } ?? 0
        let usesTime = timestamps.count == values.count && elapsed > 0 && zip(timestamps, timestamps.dropFirst()).allSatisfy { $0 <= $1 }
        return normalized.enumerated().map { index, value in
            let fraction = values.count == 1 ? 0.5 : (usesTime ? timestamps[index].timeIntervalSince(timestamps[0]) / elapsed : Double(index) / Double(values.count - 1))
            let x = size.width * fraction
            let y = paddingY + usableHeight * (1 - CGFloat(value))
            return CGPoint(x: x, y: y)
        }
    }
}

struct ChartInspectionValue: Equatable {
    let title: String
    let value: String
}

struct ChartInspectionSample: Equatable {
    let time: String
    let readings: [ChartInspectionValue]
    var description: String { ([time] + readings.map { "\($0.title) \($0.value)" }).joined(separator: " · ") }
}

/// A fixed slot keeps sample hints clear of titles and within the chart bounds.
struct ChartInspectionCallout: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    let sample: ChartInspectionSample
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(sample.time).foregroundStyle(DesignTokens.supportingText)
            ForEach(Array(sample.readings.enumerated()), id: \.offset) { _, reading in
                HStack(spacing: 4) {
                    Text(reading.title)
                    Spacer(minLength: 0)
                    Text(reading.value).monospacedDigit()
                }
            }
        }
        .font(.system(size: compact ? 9 : 10, weight: .medium))
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background {
            let shape = RoundedRectangle(cornerRadius: 6)
            if colorScheme == .light || reduceTransparency || contrast == .increased {
                shape.fill(Color(nsColor: .controlBackgroundColor))
            } else {
                shape.fill(.regularMaterial)
            }
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
