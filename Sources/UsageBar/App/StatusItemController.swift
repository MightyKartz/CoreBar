import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private let monitor: SystemMonitor
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var snapshotCancellable: AnyCancellable?

    init(monitor: SystemMonitor) {
        self.monitor = monitor
        self.statusItem = NSStatusBar.system.statusItem(withLength: StatusIconRenderer.imageSize.width)

        super.init()

        configureButton()
        configurePopover()
        update(with: monitor.snapshot)

        snapshotCancellable = monitor.$snapshot.sink { [weak self] snapshot in
            self?.update(with: snapshot)
        }
    }

    private func configureButton() {
        guard let button = statusItem.button else {
            return
        }

        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 340, height: 230)
        popover.contentViewController = NSHostingController(rootView: StatusPanelView(monitor: monitor))
    }

    private func update(with snapshot: SystemSnapshot) {
        guard let button = statusItem.button else {
            return
        }

        let image = StatusIconRenderer.image(for: snapshot, appearance: button.effectiveAppearance)
        statusItem.length = image.size.width
        button.image = image
        button.toolTip = snapshot.metrics
            .map { "\(AppText.metricTitle($0.kind)): \($0.value.percentText) · \($0.level.title)" }
            .joined(separator: "\n")
    }

    @objc
    private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            monitor.refresh()
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
