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
    var activityMonitor: ActivityMonitor?
    var mainWindow: NSWindow?
    var mainWindowController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Set initial title
        updateStatusBarTitle()

        // Configure button for menu
        if let button = statusItem?.button {
            button.action = #selector(statusBarClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Start monitoring user activity
        activityMonitor = ActivityMonitor { [weak self] activeApp in
            DispatchQueue.main.async {
                AppState.shared.activeApp = activeApp
            }
        }
        activityMonitor?.startMonitoring()

        // Observe app state changes
        setupStateObservers()

        // If already in a room, start heartbeat
        if AppState.shared.status == .inRoom {
            HeartbeatService.shared.start()
        }

        // Show main window if not registered
        if AppState.shared.status == .unregistered {
            showMainWindow()
        }
    }

    func setupStateObservers() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ParticipantsUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateStatusBarTitle()
        }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RoomChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateStatusBarTitle()
        }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("OpenMainWindow"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.showMainWindow()
        }
    }

    @objc func statusBarClicked() {
        showMenu()
    }

    func showMenu() {
        let menu = NSMenu()
        let appState = AppState.shared

        // If not registered, show sign in option
        if appState.status == .unregistered {
            menu.addItem(NSMenuItem(title: "Sign in to Loder", action: #selector(showMainWindow), keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
            statusItem?.menu = menu
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil
            return
        }

        // Current room header
        if let room = appState.currentRoom {
            let roomItem = NSMenuItem(title: "Room: \(room.id)", action: nil, keyEquivalent: "")
            roomItem.isEnabled = false
            menu.addItem(roomItem)

            // Active count
            let activeCount = appState.participants.filter { $0.isOnline && $0.isActive }.count
            let statusItem = NSMenuItem(title: "\(activeCount) active", action: nil, keyEquivalent: "")
            statusItem.isEnabled = false
            menu.addItem(statusItem)

            menu.addItem(NSMenuItem.separator())

            // Open Statistics
            menu.addItem(NSMenuItem(title: "Open Dashboard", action: #selector(showMainWindow), keyEquivalent: "d"))

            menu.addItem(NSMenuItem.separator())

            // Leave room
            menu.addItem(NSMenuItem(title: "Leave Room", action: #selector(leaveRoom), keyEquivalent: ""))
        } else {
            // No room - show options
            menu.addItem(NSMenuItem(title: "Create Room", action: #selector(createRoom), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Join Room...", action: #selector(showMainWindow), keyEquivalent: ""))
        }

        menu.addItem(NSMenuItem.separator())

        // Focus Mode toggle
        let focusItem = NSMenuItem(title: "Focus Mode", action: #selector(toggleFocusMode), keyEquivalent: "")
        focusItem.state = appState.focusMode ? .on : .off
        menu.addItem(focusItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    func updateStatusBarTitle() {
        guard let button = statusItem?.button else { return }

        let appState = AppState.shared

        switch appState.status {
        case .unregistered:
            button.title = "Loder"
            button.image = nil

        case .lobby:
            button.title = "No Room"
            button.image = nil

        case .inRoom:
            if let room = appState.currentRoom {
                let activeCount = appState.participants.filter { $0.isOnline && $0.isActive }.count
                if activeCount > 0 {
                    button.title = "\(room.id) (\(activeCount))"
                } else {
                    button.title = room.id
                }
            } else {
                button.title = "No Room"
            }
            button.image = nil
        }
    }

    @objc func showMainWindow() {
        if mainWindow == nil {
            let contentView = MainWindowView()
                .frame(minWidth: 800, idealWidth: 900, minHeight: 550, idealHeight: 650)
            let hostingController = NSHostingController(rootView: contentView)
            hostingController.view.frame = NSRect(x: 0, y: 0, width: 900, height: 650)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 900, height: 650),
                styleMask: [.borderless, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )

            window.contentViewController = hostingController
            window.isMovableByWindowBackground = false  // Only drag from title bar
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = true
            window.minSize = NSSize(width: 800, height: 550)
            window.setContentSize(NSSize(width: 900, height: 650))
            window.center()
            window.title = "Loder"

            // Show in dock when window is open
            NSApp.setActivationPolicy(.regular)

            mainWindow = window
            mainWindowController = NSWindowController(window: window)
        }

        mainWindowController?.showWindow(nil)
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func createRoom() {
        Task {
            do {
                let roomId = try await RoomService.shared.createRoom(password: nil)
                let room = try await RoomService.shared.getRoom(roomId: roomId)
                await MainActor.run {
                    AppState.shared.setRoom(room)
                    HeartbeatService.shared.start()
                    NotificationCenter.default.post(name: NSNotification.Name("RoomChanged"), object: nil)
                }
            } catch {
                print("Failed to create room: \(error)")
            }
        }
    }

    @objc func leaveRoom() {
        HeartbeatService.shared.stop()
        Task {
            if let roomId = AppState.shared.currentRoom?.id {
                try? await RoomService.shared.leaveRoom(roomId: roomId)
            }
            await MainActor.run {
                AppState.shared.setRoom(nil)
                NotificationCenter.default.post(name: NSNotification.Name("RoomChanged"), object: nil)
            }
        }
    }

    @objc func toggleFocusMode() {
        AppState.shared.setFocusMode(!AppState.shared.focusMode)
    }

    @objc func quit() {
        HeartbeatService.shared.stop()
        activityMonitor?.stopMonitoring()
        NSApplication.shared.terminate(nil)
    }
}
