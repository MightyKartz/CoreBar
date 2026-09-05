import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings.shared
    private var monitor: SystemMonitor?
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let monitor = SystemMonitor(settings: settings)
        self.monitor = monitor
        statusItemController = StatusItemController(monitor: monitor, settings: settings)
    }
}

@main
struct CoreBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(settings: .shared)
        }
    }
}
