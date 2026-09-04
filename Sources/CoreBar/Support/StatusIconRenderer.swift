import AppKit

enum StatusIconRenderer {
    static var imageSize: NSSize {
        imageSize(forStatusBarThickness: NSStatusBar.system.thickness)
    }

    static func imageSize(
        forStatusBarThickness statusBarThickness: CGFloat,
        visibleKinds: [MetricKind] = [.cpu, .memory, .disk]
    ) -> NSSize {
        Layout(statusBarThickness: statusBarThickness, labels: labels(for: visibleKinds)).imageSize
    }

    static func image(
        for snapshot: SystemSnapshot,
        visibleKinds: [MetricKind] = [.cpu, .memory, .disk],
        usesThresholdColors: Bool = false,
        differentiatesWithoutColor: Bool = false,
        statusBarThickness: CGFloat = NSStatusBar.system.thickness,
        appearance: NSAppearance? = nil
    ) -> NSImage {
        guard let appearance else {
            return drawImage(
                for: snapshot,
                visibleKinds: visibleKinds,
                usesThresholdColors: usesThresholdColors,
                differentiatesWithoutColor: differentiatesWithoutColor,
                statusBarThickness: statusBarThickness
            )
        }

        var image: NSImage!
        appearance.performAsCurrentDrawingAppearance {
            image = drawImage(
                for: snapshot,
                visibleKinds: visibleKinds,
                usesThresholdColors: usesThresholdColors,
                differentiatesWithoutColor: differentiatesWithoutColor,
                statusBarThickness: statusBarThickness
            )
        }
        return image
    }

    private static func drawImage(
        for snapshot: SystemSnapshot,
        visibleKinds: [MetricKind],
        usesThresholdColors: Bool,
        differentiatesWithoutColor: Bool,
        statusBarThickness: CGFloat
    ) -> NSImage {
        let metrics = visibleKinds.compactMap { snapshot.metric(for: $0) }
        let displayLabels = metrics.map {
            statusLabel(
                for: $0.kind,
                level: $0.level,
                differentiatesWithoutColor: differentiatesWithoutColor
            )
        }
        let layout = Layout(statusBarThickness: statusBarThickness, labels: displayLabels)
        let image = NSImage(size: layout.imageSize)
        image.isTemplate = false

        image.lockFocus()
        defer {
            image.unlockFocus()
        }

        NSColor.clear.setFill()
        NSRect(origin: .zero, size: layout.imageSize).fill()

        for (index, metric) in metrics.enumerated() {
            draw(
                metric: metric,
                displayLabel: displayLabels[index],
                displayIndex: index,
                groupOriginX: layout.groupOriginX(for: index),
                layout: layout,
                usesThresholdColors: usesThresholdColors
            )
        }

        return image
    }

    private static func draw(
        metric: MetricSnapshot,
        displayLabel: String,
        displayIndex: Int,
        groupOriginX: CGFloat,
        layout: Layout,
        usesThresholdColors: Bool
    ) {
        let groupWidth = layout.groupWidth(for: displayIndex)
        let groupRect = NSRect(x: groupOriginX, y: 0, width: groupWidth, height: layout.imageSize.height)
        let labelRect = NSRect(
            x: groupRect.minX,
            y: layout.labelY,
            width: groupWidth,
            height: layout.labelHeight
        )
        let barRect = NSRect(
            x: groupRect.minX + layout.barInset,
            y: layout.barY,
            width: max(1, groupWidth - layout.barInset * 2),
            height: layout.barHeight
        )

        drawLabel(displayLabel, in: labelRect, layout: layout)
        drawBar(value: metric.value, level: metric.level, usesThresholdColors: usesThresholdColors, in: barRect)
    }

    private static func drawLabel(_ abbreviation: String, in rect: NSRect, layout: Layout) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: layout.labelFont,
            .foregroundColor: NSColor.labelColor
        ]
        let textSize = abbreviation.size(withAttributes: attributes)
        let textRect = NSRect(
            x: rect.minX,
            y: rect.midY - textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        )

        abbreviation.draw(in: textRect, withAttributes: attributes)
    }

    /// Pure color selection for menu-bar bars (unit-tested).
    static func barColor(level: HealthLevel, usesThresholdColors: Bool) -> NSColor {
        DesignTokens.nsBarColor(level: level, usesThresholdColors: usesThresholdColors)
    }

    private static func drawBar(value: Double, level: HealthLevel, usesThresholdColors: Bool, in rect: NSRect) {
        let track = NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2)
        NSColor.labelColor.withAlphaComponent(0.18).setFill()
        track.fill()

        let fillWidth = max(1, rect.width * value.clamped01)
        let fillRect = NSRect(x: rect.minX, y: rect.minY, width: fillWidth, height: rect.height)
        let fill = NSBezierPath(roundedRect: fillRect, xRadius: rect.height / 2, yRadius: rect.height / 2)

        NSGraphicsContext.saveGraphicsState()
        track.addClip()
        barColor(level: level, usesThresholdColors: usesThresholdColors).setFill()
        fill.fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func label(for kind: MetricKind) -> String {
        switch kind {
        case .cpu: "CPU"
        case .memory: "MEM"
        case .disk: "DSK"
        case .network: "NET"
        }
    }

    /// Adds a compact shape/glyph only when macOS asks the UI not to rely on
    /// color. The base labels stay unchanged in the default menu-bar layout.
    static func statusLabel(
        for kind: MetricKind,
        level: HealthLevel,
        differentiatesWithoutColor: Bool
    ) -> String {
        let base = label(for: kind)
        guard differentiatesWithoutColor else { return base }

        switch level {
        case .normal: return base
        case .warning: return "\(base)△"
        case .critical: return "\(base)!"
        }
    }

    private static func labels(for kinds: [MetricKind]) -> [String] {
        let labels = kinds.map(label)
        return labels.isEmpty ? ["CPU"] : labels
    }

    private struct Layout {
        let imageSize: NSSize
        let labelFont: NSFont
        let labelHeight: CGFloat
        let labelY: CGFloat
        let barHeight: CGFloat
        let barInset: CGFloat
        let barY: CGFloat
        private let groupWidths: [CGFloat]
        private let groupOffsets: [CGFloat]

        init(statusBarThickness: CGFloat, labels: [String]) {
            let thickness = max(18, statusBarThickness)
            let scale = thickness / 22
            // Preview density: ~8pt labels, ~2.5pt capsule bars, compact inter-group gap.
            labelFont = NSFont.systemFont(ofSize: 8 * scale, weight: .semibold)
            let attributes: [NSAttributedString.Key: Any] = [.font: labelFont]
            groupWidths = labels.map { max(18 * scale, ceil($0.size(withAttributes: attributes).width)) }
            if labels == ["CPU", "MEM", "DSK"] {
                groupOffsets = [0, 26, 55].map { ($0 * scale).rounded() }
            } else {
                var nextOffset: CGFloat = 0
                let gap = max(8, (8 * scale).rounded())
                groupOffsets = groupWidths.map { width in
                    defer {
                        nextOffset += width + gap
                    }
                    return nextOffset
                }
            }
            labelHeight = ceil((labels.max(by: { $0.count < $1.count }) ?? "MEM").size(withAttributes: attributes).height)
            let labelBarGap = max(2.5, (3 * scale).rounded())
            barHeight = max(2.5, (2.5 * scale).rounded())
            barInset = max(0.5, (0.5 * scale).rounded())
            let contentHeight = labelHeight + labelBarGap + barHeight
            let topPadding = max(0, (thickness - contentHeight) / 2)
            barY = topPadding
            labelY = barY + barHeight + labelBarGap
            let width = zip(groupOffsets, groupWidths).map(+).max() ?? 0
            imageSize = NSSize(width: ceil(width), height: thickness)
        }

        func groupOriginX(for index: Int) -> CGFloat {
            guard groupOffsets.indices.contains(index) else {
                return groupOffsets.last ?? 0
            }
            return groupOffsets[index]
        }

        func groupWidth(for index: Int) -> CGFloat {
            guard groupWidths.indices.contains(index) else {
                return groupWidths.last ?? 0
            }
            return groupWidths[index]
        }
    }
}
