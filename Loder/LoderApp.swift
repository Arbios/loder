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

class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var activityMonitor: ActivityMonitor?
    var eventMonitor: Any?
    var avatarCache: [String: NSImage] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Set initial icon based on state
        updateStatusBarIcon()

        // Setup popover
        setupPopover()

        // Configure button
        if let button = statusItem?.button {
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Start monitoring user activity
        activityMonitor = ActivityMonitor { [weak self] activeApp in
            DispatchQueue.main.async {
                AppState.shared.activeApp = activeApp
                self?.updateStatusBarIcon()
            }
        }
        activityMonitor?.startMonitoring()

        // Observe app state changes
        setupStateObservers()

        // If already in a room, start heartbeat
        if AppState.shared.status == .inRoom {
            HeartbeatService.shared.start()
        }
    }

    func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 280, height: 320)
        popover?.behavior = .transient
        popover?.delegate = self
        popover?.contentViewController = NSHostingController(rootView: PopoverContentView())
    }

    func setupStateObservers() {
        // Observe participants changes to update menu bar
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ParticipantsUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadAvatarsAndUpdateIcon()
        }
    }

    @objc func togglePopover() {
        guard let button = statusItem?.button else { return }

        if let popover = popover, popover.isShown {
            popover.performClose(nil)
        } else {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            setupEventMonitor()
        }
    }

    func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if let popover = self?.popover, popover.isShown {
                popover.performClose(nil)
            }
        }
    }

    func popoverDidClose(_ notification: Notification) {
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }

    func loadAvatarsAndUpdateIcon() {
        let participants = AppState.shared.participants

        // Load avatars for all participants
        Task {
            for participant in participants {
                if avatarCache[participant.userId] == nil {
                    if let image = await ImageCache.shared.getImage(for: participant.userId) {
                        await MainActor.run {
                            self.avatarCache[participant.userId] = image
                        }
                    }
                }
            }

            await MainActor.run {
                self.updateStatusBarIcon()
            }
        }
    }

    func updateStatusBarIcon() {
        guard let button = statusItem?.button else { return }

        let appState = AppState.shared

        switch appState.status {
        case .unregistered:
            button.image = nil
            button.title = "🔑"

        case .lobby:
            button.image = nil
            button.title = "zzz"

        case .inRoom:
            // Show only active participants
            let activeParticipants = appState.participants.filter { $0.isOnline && $0.isActive }
            if activeParticipants.isEmpty {
                button.image = nil
                button.title = "zzz"
            } else {
                if let image = MenuBarAvatarRenderer.renderAvatars(
                    participants: activeParticipants,
                    cachedImages: avatarCache
                ) {
                    image.isTemplate = false
                    button.image = image
                    button.title = ""
                } else {
                    button.image = nil
                    button.title = "\(activeParticipants.count)🔥"
                }
            }
        }
    }

    @objc func quit() {
        HeartbeatService.shared.stop()
        activityMonitor?.stopMonitoring()
        NSApplication.shared.terminate(nil)
    }
}
