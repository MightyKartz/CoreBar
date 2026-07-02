import AppKit

enum StatusIconRenderer {
    static var imageSize: NSSize {
        imageSize(forStatusBarThickness: NSStatusBar.system.thickness)
    }

    static func imageSize(forStatusBarThickness statusBarThickness: CGFloat) -> NSSize {
        Layout(statusBarThickness: statusBarThickness).imageSize
    }

    static func image(
        for snapshot: SystemSnapshot,
        statusBarThickness: CGFloat = NSStatusBar.system.thickness,
        appearance: NSAppearance? = nil
    ) -> NSImage {
        guard let appearance else {
            return drawImage(for: snapshot, statusBarThickness: statusBarThickness)
        }

        var image: NSImage!
        appearance.performAsCurrentDrawingAppearance {
            image = drawImage(for: snapshot, statusBarThickness: statusBarThickness)
        }
        return image
    }

    private static func drawImage(for snapshot: SystemSnapshot, statusBarThickness: CGFloat) -> NSImage {
        let layout = Layout(statusBarThickness: statusBarThickness)
        let image = NSImage(size: layout.imageSize)
        image.isTemplate = false

        image.lockFocus()
        defer {
            image.unlockFocus()
        }

        NSColor.clear.setFill()
        NSRect(origin: .zero, size: layout.imageSize).fill()

        for (index, metric) in snapshot.metrics.enumerated() {
            draw(metric: metric, groupOriginX: layout.groupOriginX(for: index), layout: layout)
        }

        return image
    }

    private static func draw(metric: MetricSnapshot, groupOriginX: CGFloat, layout: Layout) {
        let groupWidth = layout.groupWidth(for: metric.kind.index)
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

        drawLabel(for: metric.kind, in: labelRect, layout: layout)
        drawBar(value: metric.value, in: barRect)
    }

    private static func drawLabel(for kind: MetricKind, in rect: NSRect, layout: Layout) {
        let abbreviation = switch kind {
        case .cpu: "CPU"
        case .memory: "MEM"
        case .disk: "DSK"
        }
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

    private static func drawBar(value: Double, in rect: NSRect) {
        let path = NSBezierPath(rect: rect)
        NSColor.labelColor.withAlphaComponent(0.26).setFill()
        path.fill()

        let fillWidth = max(1, rect.width * value.clamped01)
        let fillRect = NSRect(x: rect.minX, y: rect.minY, width: fillWidth, height: rect.height)

        NSGraphicsContext.saveGraphicsState()
        path.addClip()
        NSColor.labelColor.setFill()
        fillRect.fill()
        NSGraphicsContext.restoreGraphicsState()
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

        init(statusBarThickness: CGFloat) {
            let thickness = max(18, statusBarThickness)
            let scale = thickness / 22
            labelFont = NSFont.menuBarFont(ofSize: 8 * scale)
            let attributes: [NSAttributedString.Key: Any] = [.font: labelFont]
            groupWidths = ["CPU", "MEM", "DSK"].map { ceil($0.size(withAttributes: attributes).width) }
            groupOffsets = [0, 26, 55].map { ($0 * scale).rounded() }
            labelHeight = ceil("MEM".size(withAttributes: attributes).height)
            let labelBarGap = max(3, (4 * scale).rounded())
            barHeight = max(2, (3 * scale).rounded())
            barInset = max(1, (1 * scale).rounded())
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
