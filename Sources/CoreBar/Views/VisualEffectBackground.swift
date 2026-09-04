import AppKit
import SwiftUI

struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var isEmphasized: Bool = true

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = isEmphasized
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
        nsView.isEmphasized = isEmphasized
    }
}

/// Classic surface that lets NSPopover own the material instead of stacking another blur.
struct ClassicPanelBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    /// When true (borderless NSPanel), draw one light system-style edge. Popover already has chrome.
    var showsBorder: Bool = false
    var cornerRadius: CGFloat = 12

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        ZStack {
            if reduceTransparency || colorSchemeContrast == .increased {
                shape.fill(Color(nsColor: .windowBackgroundColor))
            } else if showsBorder {
                // Borderless hosts need exactly one material layer of their own.
                VisualEffectBackground(material: .popover, blendingMode: .behindWindow, isEmphasized: true)

                // A borderless host has no system Popover beneath it, so retain a
                // subtle veil to stabilize foreground contrast.
                shape.fill(
                    colorScheme == .dark
                        ? Color.white.opacity(0.018)
                        : Color.white.opacity(0.12)
                )
                .allowsHitTesting(false)
            } else {
                // NSPopover supplies the material, border, arrow, and shadow.
                Color.clear
            }

            if showsBorder {
                shape.strokeBorder(
                    colorSchemeContrast == .increased
                        ? Color.primary.opacity(0.34)
                        : (colorScheme == .dark
                            ? Color.white.opacity(0.14)
                            : Color.black.opacity(0.12)),
                    lineWidth: colorSchemeContrast == .increased ? 1 : 0.5
                )
            }
        }
        .clipShape(shape)
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.14),
            radius: showsBorder ? 18 : 0,
            y: showsBorder ? 8 : 0
        )
    }
}
