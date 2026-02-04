import SwiftUI
import Charts

struct StatisticsWindow: View {
    let roomId: String
    @State private var stats: RoomStats?
    @State private var isLoading = true
    @State private var selectedPeriod = "today"
    @State private var selectedMember: MemberStats?
    @Environment(\.dismiss) private var dismiss

    let periods = [("today", "Today"), ("week", "Week"), ("all", "All Time")]

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(hex: "1a1a2e"), Color(hex: "16213e"), Color(hex: "0f3460")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom title bar (draggable)
                CustomTitleBar(onClose: {
                    StatisticsWindowController.shared.close()
                }, onSettings: {
                    SettingsWindowController.shared.showSettings()
                })

                if isLoading {
                    Spacer()
                    LoadingView()
                    Spacer()
                } else if let stats = stats {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 24) {
                            // Left column - Top Apps & Period selector
                            VStack(spacing: 20) {
                                // Header with period selector
                                HeaderView(roomId: roomId, period: selectedPeriod, periods: periods) { period in
                                    selectedPeriod = period
                                    loadStats()
                                }

                                // Top Apps Card
                                if !stats.topApps.isEmpty {
                                    TopAppsCard(apps: stats.topApps)
                                }

                                Spacer()
                            }
                            .frame(width: 320)

                            // Middle column - Member Stats
                            VStack(spacing: 16) {
                                Text("Members")
                                    .font(.headline)
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                ForEach(stats.members) { member in
                                    MemberStatsCard(
                                        member: member,
                                        isCurrentUser: member.userId == AppState.shared.currentUser?.id,
                                        totalRoomSeconds: stats.members.reduce(0) { $0 + $1.totalSeconds }
                                    )
                                }

                                Spacer()
                            }
                            .frame(width: 320)

                            // Right column - Activity Timeline
                            VStack(spacing: 16) {
                                if !stats.members.isEmpty {
                                    ActivityTimelineCard(members: stats.members)
                                }

                                Spacer()
                            }
                            .frame(width: 400)
                        }
                        .padding(24)
                    }
                } else {
                    Spacer()
                    Text("No data available")
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                }
            }
        }
        .frame(minWidth: 900, minHeight: 500)
        .onAppear {
            loadStats()
        }
    }

    private func loadStats() {
        isLoading = true
        Task {
            do {
                let result = try await RoomService.shared.getStats(roomId: roomId, period: selectedPeriod)
                await MainActor.run {
                    self.stats = result
                    self.isLoading = false
                }
            } catch {
                print("Failed to load stats: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Custom Title Bar

struct CustomTitleBar: View {
    var onClose: () -> Void
    var onSettings: () -> Void

    var body: some View {
        HStack {
            // Close button (red)
            Button(action: onClose) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Image(systemName: "xmark")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.black.opacity(0.5))
                    )
            }
            .buttonStyle(.plain)
            .help("Close")

            Spacer()

            Text("Loder Statistics")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.8))

            Spacer()

            // Settings button
            Button(action: onSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.3))
        .background(WindowDragArea())
    }
}

// MARK: - Window Drag Area (for frameless window)

struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = DraggableView()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

class DraggableView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

// MARK: - Loading View

struct LoadingView: View {
    @State private var rotation = 0.0

    var body: some View {
        VStack(spacing: 16) {
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(
                    LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 40, height: 40)
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }

            Text("Loading statistics...")
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

// MARK: - Header View

struct HeaderView: View {
    let roomId: String
    let period: String
    let periods: [(String, String)]
    let onPeriodChange: (String) -> Void

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Room Statistics")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                Text(roomId)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.cyan)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Period Selector
            HStack(spacing: 8) {
                ForEach(periods, id: \.0) { id, label in
                    Button(action: { onPeriodChange(id) }) {
                        Text(label)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(period == id ? .white : .white.opacity(0.6))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(period == id ? Color.cyan.opacity(0.3) : Color.white.opacity(0.1))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Glass Card Modifier

struct GlassCard: ViewModifier {
    var glowColor: Color = .cyan

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .opacity(0.8)
            )
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: glowColor.opacity(0.2), radius: 15, x: 0, y: 8)
    }
}

extension View {
    func glassCard(glowColor: Color = .cyan) -> some View {
        modifier(GlassCard(glowColor: glowColor))
    }
}

// MARK: - Top Apps Card

struct TopAppsCard: View {
    let apps: [AppStats]

    private let appColors: [Color] = [.cyan, .purple, .pink, .orange, .green, .yellow, .blue, .red, .mint, .indigo]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundColor(.cyan)
                Text("Top Apps")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            let totalSeconds = apps.reduce(0) { $0 + $1.totalSeconds }

            ForEach(Array(apps.prefix(5).enumerated()), id: \.element.id) { index, app in
                HStack(spacing: 10) {
                    Circle()
                        .fill(appColors[index % appColors.count])
                        .frame(width: 10, height: 10)
                        .shadow(color: appColors[index % appColors.count].opacity(0.5), radius: 3)

                    Text(app.appName)
                        .foregroundColor(.white)
                        .font(.subheadline)
                        .lineLimit(1)

                    Spacer()

                    Text(app.formattedTime)
                        .foregroundColor(.white.opacity(0.7))
                        .font(.caption)

                    // Progress bar
                    let percentage = totalSeconds > 0 ? Double(app.totalSeconds) / Double(totalSeconds) : 0
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.1))
                            .overlay(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(
                                        LinearGradient(
                                            colors: [appColors[index % appColors.count], appColors[index % appColors.count].opacity(0.5)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * percentage)
                            }
                    }
                    .frame(width: 60, height: 6)

                    Text("\(Int(percentage * 100))%")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 30, alignment: .trailing)
                }
            }
        }
        .padding(16)
        .glassCard(glowColor: .purple)
    }
}

// MARK: - Member Stats Card

struct MemberStatsCard: View {
    let member: MemberStats
    let isCurrentUser: Bool
    let totalRoomSeconds: Int

    private let appColors: [Color] = [.cyan, .purple, .pink, .orange, .green, .yellow, .blue, .red]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 10) {
                // Avatar with glow
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 40, height: 40)
                        .blur(radius: 8)
                        .opacity(0.4)

                    AsyncImage(url: URL(string: "https://loder.kedicode.cloud/api/v1/users/\(member.userId)/avatar")) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.fill")
                            .foregroundColor(.white)
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(isCurrentUser ? "You" : "Teammate")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white)

                        if isCurrentUser {
                            Text("(you)")
                                .font(.caption2)
                                .foregroundColor(.cyan)
                        }
                    }

                    Text(member.formattedTime)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(
                            LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing)
                        )
                }

                Spacer()

                // Percentage of room activity
                if totalRoomSeconds > 0 {
                    let percentage = Double(member.totalSeconds) / Double(totalRoomSeconds) * 100
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(percentage))%")
                            .font(.headline)
                            .foregroundColor(.cyan)
                        Text("of room")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }

            // Apps breakdown (compact)
            if !member.apps.isEmpty {
                Divider()
                    .background(Color.white.opacity(0.2))

                HStack(spacing: 12) {
                    ForEach(Array(member.apps.prefix(3).enumerated()), id: \.element.id) { index, app in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(appColors[index % appColors.count])
                                .frame(width: 6, height: 6)

                            Text(app.appName)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                                .lineLimit(1)
                        }
                    }

                    if member.apps.count > 3 {
                        Text("+\(member.apps.count - 3)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
        }
        .padding(14)
        .glassCard(glowColor: isCurrentUser ? .cyan : .purple)
    }
}

// MARK: - Activity Timeline Card

struct ActivityTimelineCard: View {
    let members: [MemberStats]

    private let colors: [Color] = [.cyan, .purple, .pink, .orange, .green]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.xyaxis.line")
                    .foregroundColor(.cyan)
                Text("Activity Timeline (Today)")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            // Chart
            Chart {
                ForEach(Array(members.enumerated()), id: \.element.id) { index, member in
                    let hourlyData = member.hourlyActivity.sorted { Int($0.key) ?? 0 < Int($1.key) ?? 0 }

                    ForEach(hourlyData, id: \.key) { hour, seconds in
                        LineMark(
                            x: .value("Hour", Int(hour) ?? 0),
                            y: .value("Minutes", seconds / 60)
                        )
                        .foregroundStyle(colors[index % colors.count])
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Hour", Int(hour) ?? 0),
                            y: .value("Minutes", seconds / 60)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [colors[index % colors.count].opacity(0.3), colors[index % colors.count].opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: [0, 6, 12, 18, 24]) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.1))
                    AxisValueLabel {
                        if let hour = value.as(Int.self) {
                            Text("\(hour):00")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.1))
                    AxisValueLabel {
                        if let minutes = value.as(Int.self) {
                            Text("\(minutes)m")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
            }
            .frame(height: 180)

            // Legend
            HStack(spacing: 16) {
                ForEach(Array(members.prefix(5).enumerated()), id: \.element.id) { index, member in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(colors[index % colors.count])
                            .frame(width: 8, height: 8)
                        Text(member.userId == AppState.shared.currentUser?.id ? "You" : "User \(index + 1)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
        }
        .padding(16)
        .glassCard(glowColor: .cyan)
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Statistics Window Controller

class StatisticsWindowController: NSObject {
    static let shared = StatisticsWindowController()
    private var window: NSWindow?

    func showStatistics(for roomId: String) {
        if let existingWindow = window {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = StatisticsWindow(roomId: roomId)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 550),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Loder Statistics"
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        window.setFrameAutosaveName("StatisticsWindow")
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.hasShadow = true
        window.minSize = NSSize(width: 800, height: 450)

        // Round corners
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 12
        window.contentView?.layer?.masksToBounds = true

        // Show in dock
        NSApp.setActivationPolicy(.regular)

        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window?.close()
    }
}

extension StatisticsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        window = nil

        // Hide from dock if no other windows
        if NSApp.windows.filter({ $0.isVisible && $0 != notification.object as? NSWindow }).isEmpty {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
