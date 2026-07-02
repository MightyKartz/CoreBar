import AppKit

enum StatusIconRenderer {
    static var imageSize: NSSize {
        imageSize(forStatusBarThickness: NSStatusBar.system.thickness)
    }

    static func imageSize(forStatusBarThickness statusBarThickness: CGFloat) -> NSSize {
        Layout(statusBarThickness: statusBarThickness).imageSize
    }

    static func image(for snapshot: SystemSnapshot, statusBarThickness: CGFloat = NSStatusBar.system.thickness) -> NSImage {
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
            x: groupRect.minX + 1,
            y: layout.barY,
            width: max(1, groupWidth - 2),
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
            x: rect.midX - textSize.width / 2,
            y: rect.midY - textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        )

        abbreviation.draw(in: textRect, withAttributes: attributes)
    }

    private static func drawBar(value: Double, in rect: NSRect) {
        let path = NSBezierPath(rect: rect)
        NSColor.tertiaryLabelColor.withAlphaComponent(0.55).setFill()
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
        let barY: CGFloat
        private let groupWidths: [CGFloat]
        private let groupGap: CGFloat

        init(statusBarThickness: CGFloat) {
            let thickness = max(18, statusBarThickness)
            let defaultFont = NSFont.menuBarFont(ofSize: 0)
            let visualIconHeight = max(14, thickness - 4)
            let labelBarGap: CGFloat = max(2, (visualIconHeight * 0.16).rounded())
            let labelVisualHeight = max(6, ((visualIconHeight - labelBarGap) * 0.5).rounded(.down))
            barHeight = max(3, ((visualIconHeight - labelBarGap) * 0.3).rounded(.down))
            let targetPointSize = defaultFont.pointSize * (labelVisualHeight / defaultFont.capHeight)
            labelFont = NSFont.menuBarFont(ofSize: targetPointSize)
            let attributes: [NSAttributedString.Key: Any] = [.font: labelFont]
            groupWidths = ["CPU", "MEM", "DSK"].map { ceil($0.size(withAttributes: attributes).width) }
            labelHeight = labelVisualHeight
            groupGap = max(6, (thickness * 0.28).rounded())
            let contentHeight = labelHeight + labelBarGap + barHeight
            let topPadding = max(0, ((thickness - contentHeight) / 2).rounded(.down))
            barY = topPadding
            labelY = barY + barHeight + labelBarGap
            imageSize = NSSize(width: groupWidths.reduce(0, +) + groupGap * 2, height: thickness)
        }

        func groupOriginX(for index: Int) -> CGFloat {
            groupWidths.prefix(index).reduce(0, +) + CGFloat(index) * groupGap
        }

        func groupWidth(for index: Int) -> CGFloat {
            guard groupWidths.indices.contains(index) else {
                return groupWidths.last ?? 0
            }
            return groupWidths[index]
        }
    }
}
