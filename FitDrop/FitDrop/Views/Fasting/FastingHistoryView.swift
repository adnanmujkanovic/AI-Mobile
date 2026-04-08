import SwiftUI

struct FastingHistoryView: View {
    let sessions: [FastingSession]
    @ObservedObject var vm: FastingViewModel
    let profile: UserProfile?
    @Environment(\.dismiss) private var dismiss

    var completedSessions: [FastingSession] {
        sessions.filter { $0.completed }.sorted { $0.startTime > $1.startTime }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FDSpacing.lg) {
                    // Summary stats
                    HStack(spacing: FDSpacing.sm) {
                        FDStatCard(
                            title: "Total Fasts",
                            value: "\(completedSessions.count)",
                            unit: "",
                            icon: "moon.fill",
                            color: .fdIndigo
                        )
                        FDStatCard(
                            title: "Avg Duration",
                            value: String(format: "%.1f", completedSessions.isEmpty ? 0 : completedSessions.reduce(0) { $0 + $1.actualHours } / Double(completedSessions.count)),
                            unit: "h",
                            icon: "clock.fill",
                            color: .fdBlue
                        )
                        FDStatCard(
                            title: "Streak",
                            value: "\(vm.consecutiveStreak(sessions: sessions, profile: profile))",
                            unit: "days",
                            icon: "flame.fill",
                            color: .fdOrange
                        )
                    }
                    .padding(.horizontal, FDSpacing.md)

                    // Weekly average
                    HStack {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(.fdGreen)
                        Text("Weekly average: \(String(format: "%.1f", vm.weeklyAverageFastingHours(sessions: completedSessions))) hours")
                            .font(.fdSubheadline)
                    }
                    .padding(FDSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fdCard()
                    .padding(.horizontal, FDSpacing.md)

                    // Session List
                    if completedSessions.isEmpty {
                        VStack(spacing: FDSpacing.md) {
                            Image(systemName: "moon.zzz.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.fdTertiaryLabel)
                            Text("No completed fasts yet")
                                .font(.fdTitle3)
                                .foregroundColor(.fdSecondaryLabel)
                            Text("Complete your first fast to see it here.")
                                .font(.fdSubheadline)
                                .foregroundColor(.fdTertiaryLabel)
                        }
                        .padding(FDSpacing.xxl)
                    } else {
                        LazyVStack(spacing: FDSpacing.sm) {
                            ForEach(completedSessions) { session in
                                FastHistoryDetailRow(session: session)
                                    .padding(.horizontal, FDSpacing.md)
                            }
                        }
                    }
                }
                .padding(.vertical, FDSpacing.md)
            }
            .navigationTitle("Fasting History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct FastHistoryDetailRow: View {
    let session: FastingSession

    var completionRate: Double {
        guard session.plannedHours > 0 else { return 0 }
        return min(1.0, session.actualHours / Double(session.plannedHours))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FDSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.startTime, style: .date)
                        .font(.fdSubheadline)
                    Text(session.startTime, style: .time)
                        .font(.fdCaption)
                        .foregroundColor(.fdSecondaryLabel)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(String(format: "%.1f", session.actualHours) + "h")
                            .font(.fdTitle3)
                            .foregroundColor(session.brokenEarly ? .fdOrange : .fdGreen)
                        if !session.brokenEarly {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.fdGreen)
                        }
                    }
                    Text("planned: \(session.plannedHours)h")
                        .font(.fdCaption)
                        .foregroundColor(.fdSecondaryLabel)
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.fdSecondaryBackground)
                    Capsule()
                        .fill(session.brokenEarly ? Color.fdOrange : Color.fdGreen)
                        .frame(width: geo.size.width * completionRate)
                }
            }
            .frame(height: 6)

            // Stage reached
            let stage = FastingSession(startTime: session.startTime, plannedHours: session.plannedHours)
            let stageColor = FastingStage.allCases.last(where: { session.actualHours >= Double($0 == .digestion ? 0 : $0 == .fatBurning ? 4 : $0 == .glucoseDepletion ? 8 : $0 == .ketosis ? 12 : $0 == .autophagy ? 16 : 18) }) ?? .digestion
            HStack {
                Image(systemName: stageColor.icon)
                    .font(.caption)
                    .foregroundColor(stageColor.swiftUIColor)
                Text("Reached: \(stageColor.rawValue)")
                    .font(.fdCaption)
                    .foregroundColor(.fdSecondaryLabel)
            }
        }
        .padding(FDSpacing.md)
        .fdCard()
    }
}

// MARK: - Fasting Notification Settings

struct FastingNotificationSettings: View {
    let profile: UserProfile?
    @Environment(\.dismiss) private var dismiss
    @State private var startHour: Int = 20
    @State private var startMinute: Int = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Fasting Start Time") {
                    DatePicker(
                        "Start Time",
                        selection: Binding(
                            get: {
                                Calendar.current.date(bySettingHour: startHour, minute: startMinute, second: 0, of: Date()) ?? Date()
                            },
                            set: { date in
                                startHour = Calendar.current.component(.hour, from: date)
                                startMinute = Calendar.current.component(.minute, from: date)
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                }

                Section("Notification Reminders") {
                    Label("Fast starts", systemImage: "moon.fill")
                    Label("Eating window opens", systemImage: "sun.max.fill")
                    Label("12h Ketosis milestone", systemImage: "star.fill")
                    Label("16h Autophagy milestone", systemImage: "arrow.clockwise.circle.fill")
                    Label("1h before eating closes", systemImage: "bell.badge.fill")
                }

                Section {
                    Button("Save & Schedule Notifications") {
                        NotificationManager.shared.scheduleFastingNotifications(
                            startHour: startHour,
                            startMinute: startMinute,
                            durationHours: profile?.fastingDuration ?? 16
                        )
                        dismiss()
                    }
                    .foregroundColor(.fdGreen)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear {
            startHour = profile?.fastingStartHour ?? 20
            startMinute = profile?.fastingStartMinute ?? 0
        }
    }
}
