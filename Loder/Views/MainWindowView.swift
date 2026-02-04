import SwiftUI
import Charts

struct MainWindowView: View {
    @ObservedObject var appState = AppState.shared
    @State private var refreshTimer: Timer?

    var body: some View {
        ZStack {
            // Animated background
            AnimatedWaveBackground()

            // Glass container
            VStack(spacing: 0) {
                // Custom title bar
                TitleBarView()

                // Content based on state
                Group {
                    switch appState.status {
                    case .unregistered:
                        RegistrationView()
                    case .lobby:
                        LobbyWindowView()
                    case .inRoom:
                        RoomDashboardView()
                    }
                }
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .ignoresSafeArea()
        .onAppear {
            startAutoRefresh()
        }
        .onDisappear {
            stopAutoRefresh()
        }
    }

    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            NotificationCenter.default.post(name: NSNotification.Name("RefreshStats"), object: nil)
        }
    }

    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

// MARK: - Title Bar
struct TitleBarView: View {
    var body: some View {
        DraggableArea {
            HStack {
                // Traffic light buttons
                HStack(spacing: 8) {
                    WindowButton(color: .red, action: { closeWindow() })
                    WindowButton(color: .yellow, action: { minimizeWindow() })
                    WindowButton(color: .green, action: { })
                }
                .padding(.leading, 12)

                Spacer()

                Text("Loder")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)

                Spacer()

                // Placeholder for symmetry
                HStack(spacing: 8) {
                    Color.clear.frame(width: 12, height: 12)
                    Color.clear.frame(width: 12, height: 12)
                    Color.clear.frame(width: 12, height: 12)
                }
                .padding(.trailing, 12)
            }
            .frame(height: 38)
            .background(Color.black.opacity(0.1))
        }
    }

    private func closeWindow() {
        NSApp.keyWindow?.close()
        NSApp.setActivationPolicy(.accessory)
    }

    private func minimizeWindow() {
        NSApp.keyWindow?.miniaturize(nil)
    }
}

// MARK: - Draggable Area for Title Bar
struct DraggableArea<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(WindowDragArea())
    }
}

struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = DragView()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

class DragView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

struct WindowButton: View {
    let color: Color
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 12, height: 12)
            .opacity(isHovered ? 1.0 : 0.8)
            .onHover { isHovered = $0 }
            .onTapGesture { action() }
    }
}

// MARK: - Animated Background
struct AnimatedWaveBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.08, blue: 0.15),
                Color(red: 0.05, green: 0.05, blue: 0.1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Lobby Window View
struct LobbyWindowView: View {
    @ObservedObject var appState = AppState.shared
    @State private var roomCode = UserDefaults.standard.string(forKey: "com.loder.lastRoomCode") ?? ""
    @State private var roomPassword = ""
    @State private var isJoining = false
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showPasswordField = false
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            // User header
            HStack(spacing: 12) {
                AvatarView(userId: appState.currentUser?.id, size: 48, avatarPath: appState.currentUser?.avatarPath)

                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.currentUser?.name ?? appState.currentUser?.email ?? "User")
                        .font(.headline)
                    if let email = appState.currentUser?.email {
                        Text(email)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()
                .background(Color.white.opacity(0.1))

            // Main content
            VStack(spacing: 24) {
                Spacer()

                // Create room
                VStack(spacing: 12) {
                    Button(action: createRoom) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text(isCreating ? "Creating..." : "Create New Room")
                        }
                        .frame(maxWidth: 280)
                        .frame(height: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isCreating || isJoining)
                }

                // Divider
                HStack {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 1)
                    Text("or join existing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 1)
                }
                .padding(.horizontal, 40)

                // Join room
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        TextField("Room code", text: $roomCode)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 160)
                            .textCase(.uppercase)
                            .onChange(of: roomCode) { newValue in
                                roomCode = String(newValue.uppercased().prefix(7))
                                UserDefaults.standard.set(roomCode, forKey: "com.loder.lastRoomCode")
                                showPasswordField = false
                            }

                        Button(action: checkAndJoinRoom) {
                            Text(isJoining ? "..." : "Join")
                                .frame(width: 60)
                        }
                        .buttonStyle(.bordered)
                        .disabled(roomCode.count < 7 || isJoining || isCreating)
                    }

                    if showPasswordField {
                        HStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.orange)
                            SecureField("Password", text: $roomPassword)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 140)
                            Button("Join") {
                                joinWithPassword()
                            }
                            .buttonStyle(.bordered)
                            .disabled(roomPassword.isEmpty || isJoining)
                        }
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                Spacer()
            }
            .padding(20)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    private func createRoom() {
        isCreating = true
        errorMessage = nil

        Task {
            do {
                let roomId = try await RoomService.shared.createRoom(password: nil)
                let room = try await RoomService.shared.getRoom(roomId: roomId)
                await MainActor.run {
                    appState.setRoom(room)
                    HeartbeatService.shared.start()
                    NotificationCenter.default.post(name: NSNotification.Name("RoomChanged"), object: nil)
                    isCreating = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to create room"
                    isCreating = false
                }
            }
        }
    }

    private func checkAndJoinRoom() {
        isJoining = true
        errorMessage = nil

        Task {
            do {
                let check = try await RoomService.shared.checkRoom(roomId: roomCode)
                if check.hasPassword == true {
                    await MainActor.run {
                        showPasswordField = true
                        isJoining = false
                    }
                    return
                }

                try await RoomService.shared.joinRoom(roomId: roomCode)
                let room = try await RoomService.shared.getRoom(roomId: roomCode)
                await MainActor.run {
                    appState.setRoom(room)
                    HeartbeatService.shared.start()
                    NotificationCenter.default.post(name: NSNotification.Name("RoomChanged"), object: nil)
                    isJoining = false
                }
            } catch RoomError.passwordRequired {
                await MainActor.run {
                    showPasswordField = true
                    isJoining = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Room not found"
                    isJoining = false
                }
            }
        }
    }

    private func joinWithPassword() {
        isJoining = true
        errorMessage = nil

        Task {
            do {
                try await RoomService.shared.joinRoom(roomId: roomCode, password: roomPassword)
                let room = try await RoomService.shared.getRoom(roomId: roomCode)
                await MainActor.run {
                    appState.setRoom(room)
                    HeartbeatService.shared.start()
                    NotificationCenter.default.post(name: NSNotification.Name("RoomChanged"), object: nil)
                    isJoining = false
                    roomPassword = ""
                    showPasswordField = false
                }
            } catch RoomError.wrongPassword {
                await MainActor.run {
                    errorMessage = "Wrong password"
                    isJoining = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to join room"
                    isJoining = false
                }
            }
        }
    }
}

// MARK: - Room Dashboard View
struct RoomDashboardView: View {
    @ObservedObject var appState = AppState.shared
    @State private var stats: RoomStats?
    @State private var selectedMember: MemberStats?
    @State private var showSettings = false

    var body: some View {
        HStack(spacing: 0) {
            // Members sidebar
            VStack(spacing: 0) {
                // Room header - clickable to show team overview
                VStack(alignment: .leading, spacing: 4) {
                    Text("Room")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(appState.currentRoom?.id ?? "")
                        .font(.title2)
                        .fontWeight(.bold)
                        .fontDesign(.monospaced)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(selectedMember == nil ? Color.white.opacity(0.05) : Color.clear)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedMember = nil  // Deselect to show team overview
                }

                Divider()
                    .background(Color.white.opacity(0.1))

                // Members list
                ScrollView {
                    LazyVStack(spacing: 4) {
                        if let stats = stats {
                            ForEach(stats.members, id: \.id) { member in
                                MemberRow(member: member, isSelected: selectedMember?.id == member.id)
                                    .onTapGesture {
                                        // Toggle selection - click again to deselect
                                        if selectedMember?.id == member.id {
                                            selectedMember = nil
                                        } else {
                                            selectedMember = member
                                        }
                                    }
                            }
                        }
                    }
                    .padding(8)
                }

                Divider()
                    .background(Color.white.opacity(0.1))

                // Bottom actions
                HStack {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)

                    Spacer()

                    Button("Leave") {
                        leaveRoom()
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(12)
            }
            .frame(width: 200)
            .background(Color.black.opacity(0.2))

            // Main content
            VStack {
                if let member = selectedMember {
                    MemberDetailView(member: member)
                } else {
                    RoomOverviewView(stats: stats) { member in
                        selectedMember = member
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { loadStats() }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshStats"))) { _ in
            loadStats()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    private func loadStats() {
        guard let roomId = appState.currentRoom?.id else { return }
        Task {
            do {
                let newStats = try await RoomService.shared.getStats(roomId: roomId)
                await MainActor.run {
                    self.stats = newStats
                }
            } catch {
                print("Failed to load stats: \(error)")
            }
        }
    }

    private func leaveRoom() {
        HeartbeatService.shared.stop()
        Task {
            if let roomId = appState.currentRoom?.id {
                try? await RoomService.shared.leaveRoom(roomId: roomId)
            }
            await MainActor.run {
                appState.setRoom(nil)
                NotificationCenter.default.post(name: NSNotification.Name("RoomChanged"), object: nil)
            }
        }
    }
}

// MARK: - Member Row
struct MemberRow: View {
    let member: MemberStats
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            // Avatar
            ZStack {
                AvatarView(userId: member.id, size: 36, avatarPath: member.avatarPath)

                // Online indicator
                if member.isOnline == true {
                    Circle()
                        .fill(member.isActive ? Color.green : Color.orange)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.black.opacity(0.3), lineWidth: 1))
                        .offset(x: 12, y: 12)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(member.name ?? "User")
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)

                if member.isOnline == true {
                    Text(member.currentApp ?? "Idle")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Offline")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(8)
        .background(isSelected ? Color.white.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Member Detail View
struct MemberDetailView: View {
    let member: MemberStats

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack(spacing: 16) {
                    AvatarView(userId: member.id, size: 64, avatarPath: member.avatarPath)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(member.name ?? "User")
                            .font(.title2)
                            .fontWeight(.semibold)

                        HStack(spacing: 8) {
                            Circle()
                                .fill((member.isOnline == true) ? (member.isActive ? Color.green : Color.orange) : Color.gray)
                                .frame(width: 8, height: 8)
                            Text((member.isOnline == true) ? (member.currentApp ?? "Idle") : "Offline")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // Total time today
                    VStack(alignment: .trailing) {
                        Text(member.formattedTime)
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("today")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Hourly Activity Chart
                if let hourlyActivity = member.hourlyActivity, !hourlyActivity.isEmpty {
                    ActivityChartView(hourlyActivity: hourlyActivity, title: "Activity Today")
                }

                // Top Apps
                VStack(alignment: .leading, spacing: 12) {
                    Text("Top Apps Today")
                        .font(.headline)

                    if member.topApps.isEmpty {
                        Text("No activity recorded")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        ForEach(Array(member.topApps.prefix(5).enumerated()), id: \.offset) { index, app in
                            HStack {
                                Text("\(index + 1)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 20)

                                Text(app.name)
                                    .font(.body)

                                Spacer()

                                // Progress bar
                                let maxSeconds = member.topApps.first?.totalSeconds ?? 1
                                let progress = Double(app.totalSeconds) / Double(maxSeconds)
                                GeometryReader { geo in
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.accentColor.opacity(0.3))
                                        .frame(width: geo.size.width * progress)
                                }
                                .frame(width: 80, height: 6)

                                Text(formatDuration(app.totalSeconds))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 60, alignment: .trailing)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding()
                .background(Color.black.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Spacer(minLength: 20)
            }
            .padding()
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else if secs > 0 {
            return "\(secs)s"
        } else {
            return "0s"
        }
    }
}

// MARK: - Activity Chart View
struct ActivityChartView: View {
    let hourlyActivity: [String: Int]
    let title: String

    var chartData: [(hour: Int, minutes: Int)] {
        (0..<24).map { hour in
            let key = String(format: "%02d", hour)
            let seconds = hourlyActivity[key] ?? 0
            return (hour: hour, minutes: seconds / 60)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            Chart(chartData, id: \.hour) { item in
                AreaMark(
                    x: .value("Hour", item.hour),
                    y: .value("Minutes", item.minutes)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.5), Color.accentColor.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Hour", item.hour),
                    y: .value("Minutes", item.minutes)
                )
                .foregroundStyle(Color.accentColor)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
            .chartXScale(domain: 0...23)
            .chartXAxis {
                AxisMarks(values: [0, 6, 12, 18, 23]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let hour = value.as(Int.self) {
                            Text(hourLabel(hour))
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let minutes = value.as(Int.self) {
                            Text("\(minutes)m")
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 150)
        }
        .padding()
        .background(Color.black.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func hourLabel(_ hour: Int) -> String {
        switch hour {
        case 0: return "12am"
        case 6: return "6am"
        case 12: return "12pm"
        case 18: return "6pm"
        case 23: return "11pm"
        default: return "\(hour)"
        }
    }
}

// MARK: - Room Overview View
struct RoomOverviewView: View {
    let stats: RoomStats?
    let onSelectMember: (MemberStats) -> Void

    // Aggregate hourly activity from all members
    var teamHourlyActivity: [String: Int] {
        guard let stats = stats else { return [:] }
        var aggregated: [String: Int] = [:]
        for member in stats.members {
            if let hourly = member.hourlyActivity {
                for (hour, seconds) in hourly {
                    aggregated[hour, default: 0] += seconds
                }
            }
        }
        return aggregated
    }

    var totalTeamTime: Int {
        stats?.members.reduce(0) { $0 + $1.totalSeconds } ?? 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let stats = stats {
                    // Summary cards
                    HStack(spacing: 16) {
                        StatCard(title: "Members", value: "\(stats.members.count)", icon: "person.2.fill")
                        StatCard(title: "Online", value: "\(stats.members.filter { $0.isOnline == true }.count)", icon: "circle.fill", iconColor: .green)
                        StatCard(title: "Total Time", value: formatDuration(totalTeamTime), icon: "clock.fill", iconColor: .blue)
                    }
                    .padding(.horizontal)
                    .padding(.top)

                    // Members grid with activity
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Team Members")
                            .font(.headline)

                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
                            ForEach(stats.members, id: \.id) { member in
                                MemberActivityCard(member: member)
                                    .onTapGesture {
                                        onSelectMember(member)
                                    }
                            }
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // Team Activity Chart
                    if !teamHourlyActivity.isEmpty {
                        ActivityChartView(hourlyActivity: teamHourlyActivity, title: "Team Activity Today")
                            .padding(.horizontal)
                    }

                    // Top apps chart (bar chart)
                    if !stats.topApps.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Top Apps - Team")
                                .font(.headline)

                            Chart(Array(stats.topApps.prefix(6)), id: \.appName) { app in
                                BarMark(
                                    x: .value("Minutes", app.totalSeconds / 60),
                                    y: .value("App", app.appName)
                                )
                                .foregroundStyle(Color.accentColor.gradient)
                                .cornerRadius(4)
                                .annotation(position: .trailing, alignment: .leading, spacing: 4) {
                                    Text(formatDuration(app.totalSeconds))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .chartXAxis {
                                AxisMarks { value in
                                    AxisGridLine()
                                    AxisValueLabel {
                                        if let minutes = value.as(Int.self) {
                                            Text("\(minutes)m")
                                                .font(.caption2)
                                        }
                                    }
                                }
                            }
                            .chartYAxis {
                                AxisMarks { _ in
                                    AxisValueLabel()
                                        .font(.caption)
                                }
                            }
                            .frame(height: CGFloat(min(stats.topApps.count, 6) * 40))
                        }
                        .padding()
                        .background(Color.black.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 20)
                } else {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else if secs > 0 {
            return "\(secs)s"
        } else {
            return "0s"
        }
    }
}

// MARK: - Member Activity Card
struct MemberActivityCard: View {
    let member: MemberStats
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Avatar with status
            ZStack(alignment: .bottomTrailing) {
                AvatarView(userId: member.id, size: 44, avatarPath: member.avatarPath)

                // Status indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Color.black.opacity(0.3), lineWidth: 1.5))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(member.name ?? "User")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    if member.isOnline == true {
                        Text(member.currentApp ?? "Idle")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("Offline")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // Time today
                Text(member.formattedTime)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.accentColor)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(isHovered ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onHover { isHovered = $0 }
    }

    var statusColor: Color {
        if member.isOnline == true {
            return member.isActive ? .green : .orange
        }
        return .gray
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    var iconColor: Color = .accentColor

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)

            Text(value)
                .font(.title)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.black.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @ObservedObject var appState = AppState.shared
    @Environment(\.dismiss) var dismiss
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding()

            Divider()

            // User info
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    AvatarView(userId: appState.currentUser?.id, size: 60, avatarPath: appState.currentUser?.avatarPath)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(appState.currentUser?.name ?? "User")
                            .font(.headline)
                        if let email = appState.currentUser?.email {
                            Text(email)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()
                }
                .padding()
                .background(Color.black.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Focus Mode
                Toggle(isOn: Binding(
                    get: { appState.focusMode },
                    set: { appState.setFocusMode($0) }
                )) {
                    VStack(alignment: .leading) {
                        Text("Focus Mode")
                            .font(.body)
                        Text("Hide your status from others")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Spacer()

                // Logout
                Button(action: { logout() }) {
                    Text("Sign Out")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                // Delete account
                Button(action: { showDeleteConfirm = true }) {
                    Text("Delete Account")
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .frame(width: 350, height: 400)
        .alert("Delete Account?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { deleteAccount() }
        } message: {
            Text("This action cannot be undone. Your data will be anonymized.")
        }
    }

    private func logout() {
        HeartbeatService.shared.stop()
        appState.logout()
        dismiss()
    }

    private func deleteAccount() {
        guard let userId = appState.currentUser?.id else { return }

        Task {
            do {
                try await UserService.shared.deleteAccount(userId: userId)
                await MainActor.run {
                    HeartbeatService.shared.stop()
                    appState.logout()
                    dismiss()
                }
            } catch {
                print("Failed to delete account: \(error)")
            }
        }
    }
}
