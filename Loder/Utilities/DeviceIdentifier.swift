import Foundation
import IOKit

class DeviceIdentifier {
    static func getDeviceId() -> String {
        // Try to get hardware UUID
        if let uuid = getHardwareUUID() {
            return uuid
        }

        // Fallback to stored UUID in UserDefaults
        let key = "com.loder.deviceId"
        if let stored = UserDefaults.standard.string(forKey: key) {
            return stored
        }

        // Generate and store new UUID
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }

    private static func getHardwareUUID() -> String? {
        let matchingDict = IOServiceMatching("IOPlatformExpertDevice")
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matchingDict)

        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        let uuidKey = kIOPlatformUUIDKey as CFString
        guard let uuid = IORegistryEntryCreateCFProperty(service, uuidKey, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? String else {
            return nil
        }

        return uuid
    }
}
