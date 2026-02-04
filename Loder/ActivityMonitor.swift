import Foundation
import AppKit

class ActivityMonitor {
    private var timer: Timer?
    private var onStatusChange: (String?) -> Void  // nil = idle, String = app name
    private var lastActiveApp: String?
    private var idleStartTime: Date?
    private let idleThreshold: TimeInterval = 5.0

    init(onStatusChange: @escaping (String?) -> Void) {
        self.onStatusChange = onStatusChange
    }

    func startMonitoring() {
        print("[Loder] Started activity monitoring")

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkActivity()
        }
        RunLoop.main.add(timer!, forMode: .common)

        // Initial check
        checkActivity()
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func checkActivity() {
        let idleTime = getSystemIdleTime()
        let frontApp = getFrontmostAppName()

        // Check if user is idle (no input for 5+ seconds)
        if idleTime >= idleThreshold {
            if lastActiveApp != nil {
                lastActiveApp = nil
                print("[Loder] User is idle (\(Int(idleTime))s)")
                onStatusChange(nil)
            }
        } else {
            // User is active - show frontmost app
            if lastActiveApp != frontApp {
                lastActiveApp = frontApp
                print("[Loder] Active in: \(frontApp ?? "Unknown")")
                onStatusChange(frontApp)
            }
        }
    }

    private func getSystemIdleTime() -> TimeInterval {
        var iterator: io_iterator_t = 0
        var entry: io_registry_entry_t = 0

        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOHIDSystem"), &iterator) == KERN_SUCCESS else {
            return 0
        }

        defer { IOObjectRelease(iterator) }

        entry = IOIteratorNext(iterator)
        guard entry != 0 else { return 0 }

        defer { IOObjectRelease(entry) }

        var unmanagedDict: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(entry, &unmanagedDict, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = unmanagedDict?.takeRetainedValue() as? [String: Any],
              let idleTime = dict["HIDIdleTime"] as? Int64 else {
            return 0
        }

        // HIDIdleTime is in nanoseconds
        return TimeInterval(idleTime) / 1_000_000_000
    }

    private func getFrontmostAppName() -> String? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        // Use localized name or bundle name
        if let name = frontApp.localizedName {
            return name
        }

        return frontApp.bundleIdentifier?.components(separatedBy: ".").last
    }
}
