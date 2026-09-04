import AppKit
import Combine
import QuartzCore
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    enum ClickDestination: Equatable {
        case overview
        case contextMenu
    }

    private let monitor: SystemMonitor
    private let settings: AppSettings
    private let statusItem: NSStatusItem
    /// Classic metrics panel.
    private let popover = NSPopover()
    /// Classic settings — same NSPopover chrome as metrics (color + border).
    private let settingsPopover = NSPopover()
    /// System Default uses one stable panel and switches SwiftUI content in place.
    private let systemNavigation = SystemPanelNavigationModel()
    private var systemPanel: NSPanel?
    private var systemPanelEventMonitor: Any?
    private var snapshotCancellable: AnyCancellable?
    private var settingsCancellable: AnyCancellable?
    private lazy var contextMenu: NSMenu = makeContextMenu()
    private var aboutPanel: NSPanel?
    private var aboutPanelLocalEventMonitor: Any?
    private var aboutPanelGlobalEventMonitor: Any?

    init(monitor: SystemMonitor, settings: AppSettings) {
        self.monitor = monitor
        self.settings = settings
        self.statusItem = NSStatusBar.system.statusItem(withLength: StatusIconRenderer.imageSize.width)

        super.init()

        configureButton()
        configurePopover()
        update(with: monitor.snapshot)

        snapshotCancellable = monitor.$snapshot.sink { [weak self] snapshot in
            self?.update(with: snapshot)
        }
        // Prefer publisher of concrete fields so we react after values commit (not objectWillChange).
        settingsCancellable = settings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Defer to next runloop turn so @Published values are already updated.
                DispatchQueue.main.async {
                    self?.refreshOpenSurfaces()
                }
            }
    }

    private func configureButton() {
        guard let button = statusItem.button else {
            return
        }

        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        button.target = self
        // Left-click opens metrics; right-click exposes conventional app commands.
        button.action = #selector(handleStatusItemClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configurePopover() {
        configureSharedPopover(popover, size: StatusPanelView.contentSize(settings: settings), rootView: classicPanelView)
    }

    private func configureSettingsPopover() {
        configureSharedPopover(
            settingsPopover,
            size: Self.settingsPanelSize(settings: settings),
            rootView: settingsPanelView
        )
    }

    private func configureSharedPopover<Content: View>(_ popover: NSPopover, size: NSSize, rootView: Content) {
        popover.behavior = .transient
        popover.animates = true
        popover.appearance = NSApp.appearance
        popover.contentSize = size
        let host = NSHostingController(rootView: rootView)
        host.view.wantsLayer = true
        host.view.layer?.backgroundColor = NSColor.clear.cgColor
        popover.contentViewController = host
    }

    private func update(with snapshot: SystemSnapshot) {
        guard let button = statusItem.button else {
            return
        }

        let image = StatusIconRenderer.image(
            for: snapshot,
            visibleKinds: settings.visibleMenuKinds,
            usesThresholdColors: settings.useThresholdColors,
            differentiatesWithoutColor: NSWorkspace.shared.accessibilityDisplayShouldDifferentiateWithoutColor,
            appearance: button.effectiveAppearance
        )
        statusItem.length = image.size.width
        button.image = image
        var lines = settings.visibleMetrics(from: snapshot)
            .map { "\(AppText.metricTitle($0.kind)): \($0.value.percentText) · \($0.level.title)" }

        if settings.showNetwork {
            lines.append("\(AppText.metricTitle(.network)): \(AppText.download) \(snapshot.network.downloadBytesPerSecond.byteRateText) · \(AppText.upload) \(snapshot.network.uploadBytesPerSecond.byteRateText)")
        }

        button.toolTip = lines.joined(separator: "\n")
    }

    /// Keep open panels sized/presented correctly after settings edits (without recreating hosts needlessly).
    private func refreshOpenSurfaces() {
        update(with: monitor.snapshot)
        // These Popovers receive an explicit appearance when configured, so keep
        // that override synchronized while the user switches appearance in-place.
        popover.appearance = NSApp.appearance
        settingsPopover.appearance = NSApp.appearance

        let style = settings.panelStyle
        let settingsSize = Self.settingsPanelSize(settings: settings)

        // Migrate the currently visible surface if its panel style changed.
        let classicSettingsOpen = settingsPopover.isShown
        let systemOpen = systemPanel?.isVisible == true

        if classicSettingsOpen, style != .classic {
            settingsPopover.performClose(nil)
            openSettingsPanel()
            return
        }
        if systemOpen, style != .controlCenter {
            let destination = systemNavigation.page
            closeSystemPanel()
            if destination == .settings {
                openSettingsPanel()
            } else if let button = statusItem.button {
                toggleMetricsPanel(relativeTo: button)
            }
            return
        }

        if classicSettingsOpen {
            // Resize only — do not replace contentViewController (avoids flicker / entrance re-run).
            settingsPopover.contentSize = settingsSize
        }
        if systemOpen {
            resizeSystemPanel(to: PanelMetricsLayout.systemDefaultPanelSize(settings: settings))
        }

        // --- Metrics ---
        if popover.isShown {
            if style == .classic {
                popover.contentSize = StatusPanelView.contentSize(settings: settings)
            } else {
                popover.performClose(nil)
            }
        }

    }

    // MARK: - Click routing

    @objc
    private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if Self.clickDestination(for: event?.type) == .contextMenu,
           let event {
            showContextMenu(event: event, relativeTo: sender)
            return
        }

        toggleMetricsPanel(relativeTo: sender)
    }

    static func clickDestination(for eventType: NSEvent.EventType?) -> ClickDestination {
        eventType == .rightMouseUp ? .contextMenu : .overview
    }

    private func showContextMenu(event: NSEvent, relativeTo sender: NSStatusBarButton) {
        popover.performClose(nil)
        settingsPopover.performClose(nil)
        closeSystemPanel()
        closeAboutPanel()
        NSMenu.popUpContextMenu(contextMenu, with: event, for: sender)
    }

    private func makeContextMenu() -> NSMenu {
        let menu = NSMenu(title: "CoreBar")
        menu.autoenablesItems = false
        menu.minimumWidth = 210
        menu.addItem(makeMenuItem(
            title: AppText.openCoreBar,
            systemName: "chart.bar.xaxis",
            action: #selector(openOverviewFromMenu(_:))
        ))
        menu.addItem(makeMenuItem(
            title: AppText.settings,
            systemName: "gearshape",
            action: #selector(openSettingsFromMenu(_:)),
            keyEquivalent: ","
        ))
        menu.addItem(makeMenuItem(
            title: AppText.aboutCoreBar,
            systemName: "info.circle",
            action: #selector(openAboutFromMenu(_:))
        ))
        menu.addItem(.separator())
        menu.addItem(makeMenuItem(
            title: AppText.quitCoreBar,
            systemName: "power",
            action: #selector(quitFromMenu(_:)),
            keyEquivalent: "q"
        ))
        return menu
    }

    private func makeMenuItem(
        title: String,
        systemName: String,
        action: Selector,
        keyEquivalent: String = ""
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        if !keyEquivalent.isEmpty {
            item.keyEquivalentModifierMask = [.command]
        }
        if let image = NSImage(systemSymbolName: systemName, accessibilityDescription: title) {
            image.isTemplate = true
            item.image = image
        }
        return item
    }

    @objc
    private func openOverviewFromMenu(_ sender: NSMenuItem) {
        guard let button = statusItem.button else { return }
        closeAboutPanel()
        toggleMetricsPanel(relativeTo: button)
    }

    @objc
    private func openSettingsFromMenu(_ sender: NSMenuItem) {
        closeAboutPanel()
        openSettingsPanel()
    }

    @objc
    private func openAboutFromMenu(_ sender: NSMenuItem) {
        openAboutPanel()
    }

    @objc
    private func quitFromMenu(_ sender: NSMenuItem) {
        NSApp.terminate(nil)
    }

    // MARK: - Metrics panel

    private func toggleMetricsPanel(relativeTo sender: NSStatusBarButton) {
        if settings.panelStyle == .controlCenter {
            settingsPopover.performClose(nil)
            popover.performClose(sender)
            toggleSystemPanel(relativeTo: sender)
            return
        }

        closeSystemPanel()
        settingsPopover.performClose(nil)
        if popover.isShown {
            popover.performClose(sender)
        } else {
            configurePopover()
            monitor.refresh()
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func toggleSystemPanel(relativeTo sender: NSStatusBarButton) {
        if systemPanel?.isVisible == true {
            closeSystemPanel()
            return
        }

        presentSystemPanel(page: .overview, relativeTo: sender)
    }

    private func presentSystemPanel(
        page: SystemPanelNavigationModel.Page,
        relativeTo sender: NSStatusBarButton
    ) {
        if page == .settings {
            systemNavigation.showSettings()
        } else {
            systemNavigation.showOverview()
        }
        monitor.refresh()

        let hostingController = NSHostingController(rootView: systemPanelView)
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor

        let panelSize = PanelMetricsLayout.systemDefaultPanelSize(settings: settings)
        presentFloatingPanel(
            hostingController: hostingController,
            size: panelSize,
            relativeTo: sender,
            store: { [weak self] panel in self?.systemPanel = panel },
            eventMonitor: { [weak self] monitor in self?.systemPanelEventMonitor = monitor },
            onOutsideClick: { [weak self] in self?.closeSystemPanel() }
        )
    }

    private func closeSystemPanel() {
        systemPanel?.close()
        systemPanel = nil

        if let systemPanelEventMonitor {
            NSEvent.removeMonitor(systemPanelEventMonitor)
            self.systemPanelEventMonitor = nil
        }
    }

    // MARK: - Settings

    func openSettingsPanel() {
        guard let button = statusItem.button else {
            return
        }

        if settings.panelStyle == .classic {
            popover.performClose(nil)
            closeSystemPanel()
            if settingsPopover.isShown {
                settingsPopover.performClose(nil)
                return
            }
            configureSettingsPopover()
            settingsPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            settingsPopover.contentViewController?.view.window?.makeKey()
            return
        }

        // System Default settings switch inside the existing floating panel.
        popover.performClose(nil)
        settingsPopover.performClose(nil)

        if systemPanel?.isVisible == true {
            systemNavigation.showSettings()
            systemPanel?.makeKeyAndOrderFront(nil)
            return
        }

        presentSystemPanel(page: .settings, relativeTo: button)
    }

    static func settingsPanelSize(settings: AppSettings) -> NSSize {
        switch settings.panelStyle {
        case .classic:
            PanelMetricsLayout.settingsPanelSize
        case .controlCenter:
            PanelMetricsLayout.systemDefaultPanelSize(settings: settings)
        }
    }

    // MARK: - About

    func openAboutPanel() {
        guard let button = statusItem.button else { return }

        popover.performClose(nil)
        settingsPopover.performClose(nil)
        closeSystemPanel()
        closeAboutPanel()

        let hostingController = NSHostingController(
            rootView: AboutPanelView(close: { [weak self] in self?.closeAboutPanel() })
        )
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor

        let size = AboutPanelView.contentSize
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.title = AppText.aboutCoreBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.level = .popUpMenu
        panel.collectionBehavior = [.transient, .canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentViewController = hostingController
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        panel.setFrameOrigin(panelOrigin(relativeTo: button, size: size))
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }

        aboutPanel = panel
        installAboutPanelEventMonitors(for: panel)
    }

    private func installAboutPanelEventMonitors(for panel: NSPanel) {
        aboutPanelLocalEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self, weak panel] event in
            if let panel, !panel.frame.contains(NSEvent.mouseLocation) {
                Task { @MainActor [weak self] in self?.closeAboutPanel() }
            }
            return event
        }

        aboutPanelGlobalEventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self, weak panel] _ in
            if let panel, !panel.frame.contains(NSEvent.mouseLocation) {
                Task { @MainActor [weak self] in self?.closeAboutPanel() }
            }
        }
    }

    private func closeAboutPanel() {
        if let aboutPanelLocalEventMonitor {
            NSEvent.removeMonitor(aboutPanelLocalEventMonitor)
            self.aboutPanelLocalEventMonitor = nil
        }
        if let aboutPanelGlobalEventMonitor {
            NSEvent.removeMonitor(aboutPanelGlobalEventMonitor)
            self.aboutPanelGlobalEventMonitor = nil
        }

        aboutPanel?.close()
        aboutPanel = nil
    }

    // MARK: - Shared floating panel chrome

    private func presentFloatingPanel(
        hostingController: NSViewController,
        size: NSSize,
        relativeTo sender: NSStatusBarButton,
        store: (NSPanel) -> Void,
        eventMonitor: (Any) -> Void,
        onOutsideClick: @escaping () -> Void
    ) {
        // Drop any previous monitor for this surface before installing a new one.
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.level = .popUpMenu
        panel.collectionBehavior = [.transient, .canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentViewController = hostingController
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        panel.setFrameOrigin(panelOrigin(relativeTo: sender, size: size))
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }

        store(panel)

        let monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { event in
            // Ignore clicks that land inside our floating panel.
            Task { @MainActor in
                if let panel = self.systemPanel,
                   let window = panel as NSWindow?,
                   let eventWindow = event.window,
                   eventWindow == window {
                    return
                }
                // Global monitors often have nil window; use screen location hit-test.
                if let panel = self.systemPanel {
                    let screenPoint = NSEvent.mouseLocation
                    if panel.frame.contains(screenPoint) {
                        return
                    }
                }
                onOutsideClick()
            }
        }
        if let monitor {
            eventMonitor(monitor)
        }
    }

    private func panelOrigin(relativeTo sender: NSStatusBarButton, size: NSSize) -> NSPoint {
        guard let window = sender.window else {
            return .zero
        }

        let buttonFrame = window.convertToScreen(sender.convert(sender.bounds, to: nil))
        let screenFrame = (window.screen ?? NSScreen.main)?.visibleFrame ?? .zero
        let x = min(max(buttonFrame.midX - size.width / 2, screenFrame.minX + 8), screenFrame.maxX - size.width - 8)
        let y = buttonFrame.minY - size.height - 8
        return NSPoint(x: x, y: max(y, screenFrame.minY + 8))
    }

    private var classicPanelView: some View {
        StatusPanelView(
            monitor: monitor,
            settings: settings,
            openSettings: { [weak self] in self?.openSettingsPanel() }
        )
    }

    private var systemPanelView: some View {
        SystemDefaultPanelView(
            monitor: monitor,
            settings: settings,
            navigation: systemNavigation,
            close: { [weak self] in self?.closeSystemPanel() }
        )
    }

    private var settingsPanelView: some View {
        StandaloneSettingsPanelView(
            settings: settings
        )
    }

    private func resizeSystemPanel(to size: NSSize) {
        guard let panel = systemPanel, let button = statusItem.button else {
            return
        }

        panel.setContentSize(size)
        panel.setFrameOrigin(panelOrigin(relativeTo: button, size: size))
    }
}
