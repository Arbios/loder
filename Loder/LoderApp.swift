import SwiftUI

@main
struct LoderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var activityMonitor: ClaudeActivityMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Set initial icon
        updateIcon(isActive: false)

        // Create menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Loder - Claude Activity Monitor", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem?.menu = menu

        // Start monitoring
        activityMonitor = ClaudeActivityMonitor { [weak self] isActive in
            DispatchQueue.main.async {
                self?.updateIcon(isActive: isActive)
            }
        }
        activityMonitor?.startMonitoring()
    }

    func updateIcon(isActive: Bool) {
        if let button = statusItem?.button {
            button.image = nil
            button.title = isActive ? "A" : "I"
        }
    }

    @objc func quit() {
        activityMonitor?.stopMonitoring()
        NSApplication.shared.terminate(nil)
    }
}
