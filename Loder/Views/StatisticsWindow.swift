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

            if isLoading {
                LoadingView()
            } else if let stats = stats {
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        HeaderView(roomId: roomId, period: selectedPeriod, periods: periods) { period in
                            selectedPeriod = period
                            loadStats()
                        }

                        // Top Apps Card
                        if !stats.topApps.isEmpty {
                            TopAppsCard(apps: stats.topApps)
                        }

                        // Member Stats
                        ForEach(stats.members) { member in
                            MemberStatsCard(
                                member: member,
                                isCurrentUser: member.userId == AppState.shared.currentUser?.id,
                                totalRoomSeconds: stats.members.reduce(0) { $0 + $1.totalSeconds }
                            )
                        }

                        // Activity Timeline
                        if !stats.members.isEmpty {
                            ActivityTimelineCard(members: stats.members)
                        }
                    }
                    .padding(20)
                }
            } else {
                Text("No data available")
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .frame(minWidth: 500, minHeight: 600)
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
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Room Statistics")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    Text(roomId)
                        .font(.system(.title3, design: .monospaced))
                        .foregroundColor(.cyan)
                }

                Spacer()

                // Period Selector
                HStack(spacing: 8) {
                    ForEach(periods, id: \.0) { id, label in
                        Button(action: { onPeriodChange(id) }) {
                            Text(label)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(period == id ? .white : .white.opacity(0.6))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(period == id ? Color.cyan.opacity(0.3) : Color.white.opacity(0.1))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - Glass Card Modifier

struct GlassCard: ViewModifier {
    var glowColor: Color = .cyan

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .opacity(0.8)
            )
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: glowColor.opacity(0.2), radius: 20, x: 0, y: 10)
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
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundColor(.cyan)
                Text("Top Apps")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            let totalSeconds = apps.reduce(0) { $0 + $1.totalSeconds }

            ForEach(Array(apps.prefix(5).enumerated()), id: \.element.id) { index, app in
                HStack(spacing: 12) {
                    Circle()
                        .fill(appColors[index % appColors.count])
                        .frame(width: 12, height: 12)
                        .shadow(color: appColors[index % appColors.count].opacity(0.5), radius: 4)

                    Text(app.appName)
                        .foregroundColor(.white)

                    Spacer()

                    Text(app.formattedTime)
                        .foregroundColor(.white.opacity(0.7))
                        .font(.subheadline)

                    // Progress bar
                    let percentage = totalSeconds > 0 ? Double(app.totalSeconds) / Double(totalSeconds) : 0
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.1))
                            .overlay(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
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
                    .frame(width: 80, height: 8)

                    Text("\(Int(percentage * 100))%")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 35, alignment: .trailing)
                }
            }
        }
        .padding(20)
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
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 12) {
                // Avatar with glow
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 50, height: 50)
                        .blur(radius: 10)
                        .opacity(0.5)

                    AsyncImage(url: URL(string: "https://loder.kedicode.cloud/api/v1/users/\(member.userId)/avatar")) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.fill")
                            .foregroundColor(.white)
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(isCurrentUser ? "You" : "Teammate")
                            .font(.headline)
                            .foregroundColor(.white)

                        if isCurrentUser {
                            Text("(you)")
                                .font(.caption)
                                .foregroundColor(.cyan)
                        }
                    }

                    Text(member.formattedTime)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(
                            LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing)
                        )
                }

                Spacer()

                // Percentage of room activity
                if totalRoomSeconds > 0 {
                    let percentage = Double(member.totalSeconds) / Double(totalRoomSeconds) * 100
                    VStack(alignment: .trailing) {
                        Text("\(Int(percentage))%")
                            .font(.title3.weight(.bold))
                            .foregroundColor(.cyan)
                        Text("of room")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }

            // Apps breakdown
            if !member.apps.isEmpty {
                Divider()
                    .background(Color.white.opacity(0.2))

                VStack(spacing: 8) {
                    ForEach(Array(member.apps.prefix(4).enumerated()), id: \.element.id) { index, app in
                        HStack {
                            Circle()
                                .fill(appColors[index % appColors.count])
                                .frame(width: 8, height: 8)

                            Text(app.appName)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))

                            Spacer()

                            Text(app.formattedTime)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
            }
        }
        .padding(20)
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
            .frame(height: 200)

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
        .padding(20)
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
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 700),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Loder Statistics"
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        window.setFrameAutosaveName("StatisticsWindow")
        window.isReleasedWhenClosed = false
        window.delegate = self

        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension StatisticsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
