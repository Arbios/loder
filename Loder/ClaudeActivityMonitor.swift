import Foundation

class ClaudeActivityMonitor {
    private var timer: Timer?
    private var onStatusChange: (Bool) -> Void
    private var wasActive = false
    private var inactiveCount = 0
    private let inactiveThreshold = 3
    private var lastBytes: Int64 = 0

    init(onStatusChange: @escaping (Bool) -> Void) {
        self.onStatusChange = onStatusChange
    }

    func startMonitoring() {
        // Initial reading
        lastBytes = getCurrentBytes()

        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.checkActivity()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func checkActivity() {
        let currentBytes = getCurrentBytes()
        let delta = currentBytes - lastBytes
        lastBytes = currentBytes

        // Active if more than 50 bytes transferred
        let isActive = delta > 50

        if isActive {
            inactiveCount = 0
            if !wasActive {
                wasActive = true
                onStatusChange(true)
            }
        } else {
            inactiveCount += 1
            if inactiveCount >= inactiveThreshold && wasActive {
                wasActive = false
                onStatusChange(false)
            }
        }
    }

    private func getCurrentBytes() -> Int64 {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", """
            nettop -P -L 1 -x 2>/dev/null | grep -Ei 'claude' | awk -F',' '{sum += $5 + $6} END {print sum+0}'
            """]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()

            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "0"
            return Int64(output) ?? 0
        } catch {
            return 0
        }
    }
}
