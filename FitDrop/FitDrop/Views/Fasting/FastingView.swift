import SwiftUI
import SwiftData

struct FastingView: View {
    @StateObject private var vm = FastingViewModel()
    @Query(sort: \FastingSession.startTime, order: .reverse) private var sessions: [FastingSession]
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext

    @State private var showSettings = false
    @State private var selectedProtocol: FastingViewModel.FastingProtocol = .sixteen_eight
    @State private var showHistory = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FDSpacing.lg) {
                    if let active = sessions.first(where: { $0.isActive }) {
                        ActiveFastView(fast: active, vm: vm)
                            .onAppear { vm.loadActiveFast(from: sessions) }
                            .padding(.horizontal, FDSpacing.md)
                    } else {
                        StartFastCard(
                            vm: vm,
                            selectedProtocol: $selectedProtocol,
                            profile: profiles.first
                        ) { hours in
                            vm.startFast(plannedHours: hours, modelContext: modelContext)
                        }
                        .padding(.horizontal, FDSpacing.md)
                    }

                    // Stage Info
                    FastingStagesCard()
                        .padding(.horizontal, FDSpacing.md)

                    // History
                    FastingHistorySummary(
                        sessions: sessions,
                        vm: vm,
                        profile: profiles.first,
                        showAll: { showHistory = true }
                    )
                    .padding(.horizontal, FDSpacing.md)

                    Spacer(minLength: FDSpacing.xl)
                }
                .padding(.vertical, FDSpacing.md)
            }
            .navigationTitle("Fasting")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.fdGreen)
                    }
                }
            }
            .sheet(isPresented: $showHistory) {
                FastingHistoryView(sessions: sessions, vm: vm, profile: profiles.first)
            }
            .sheet(isPresented: $showSettings) {
                FastingNotificationSettings(profile: profiles.first)
            }
        }
    }
}

// MARK: - Active Fast View

struct ActiveFastView: View {
    let fast: FastingSession
    @ObservedObject var vm: FastingViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var showBreakAlert = false

    var body: some View {
        VStack(spacing: FDSpacing.lg) {
            // Stage badge
            HStack {
                Image(systemName: vm.currentStage.icon)
                    .foregroundColor(vm.currentStage.swiftUIColor)
                Text(vm.currentStage.rawValue)
                    .font(.fdHeadline)
                    .foregroundColor(vm.currentStage.swiftUIColor)
            }
            .padding(.horizontal, FDSpacing.md)
            .padding(.vertical, FDSpacing.xs)
            .background(vm.currentStage.swiftUIColor.opacity(0.15))
            .clipShape(Capsule())

            // Timer arc
            ZStack {
                // Background ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.fdSecondaryBackground, Color.fdSecondaryBackground],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 20
                    )
                    .frame(width: 240, height: 240)

                // Progress arc
                Circle()
                    .trim(from: 0, to: vm.progressFraction)
                    .stroke(
                        AngularGradient(
                            colors: [vm.currentStage.swiftUIColor.opacity(0.6), vm.currentStage.swiftUIColor],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 240, height: 240)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: vm.progressFraction)

                // Center content
                VStack(spacing: FDSpacing.xs) {
                    Text(vm.formattedElapsed)
                        .font(.system(size: 40, weight: .bold, design: .monospaced))
                        .foregroundColor(.fdLabel)
                    Text("elapsed")
                        .font(.fdCaption)
                        .foregroundColor(.fdSecondaryLabel)
                    Divider().frame(width: 60)
                    Text(vm.formattedRemaining)
                        .font(.system(size: 22, weight: .semibold, design: .monospaced))
                        .foregroundColor(.fdSecondaryLabel)
                    Text("remaining")
                        .font(.fdCaption2)
                        .foregroundColor(.fdTertiaryLabel)
                }
            }

            // Stage description
            Text(vm.currentStage.description)
                .font(.fdSubheadline)
                .foregroundColor(.fdSecondaryLabel)
                .multilineTextAlignment(.center)
                .padding(.horizontal, FDSpacing.lg)

            // Control buttons
            HStack(spacing: FDSpacing.md) {
                if fast.isPaused {
                    ActionButton(icon: "play.fill", label: "Resume", color: .fdGreen) {
                        vm.resumeFast(modelContext: modelContext)
                    }
                } else {
                    ActionButton(icon: "pause.fill", label: "Pause", color: .fdOrange) {
                        vm.pauseFast(modelContext: modelContext)
                    }
                }

                ActionButton(icon: "xmark.circle.fill", label: "Break Fast", color: .fdRed) {
                    showBreakAlert = true
                }
            }

            // Progress milestones
            FastingMilestones(fast: fast, elapsedHours: vm.activeFast?.elapsedHours ?? 0)
        }
        .padding(FDSpacing.md)
        .fdCard()
        .fdShadow()
        .alert("Break Fast?", isPresented: $showBreakAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Break Fast", role: .destructive) {
                vm.breakFast(modelContext: modelContext)
            }
        } message: {
            let elapsed = vm.activeFast?.elapsedHours ?? 0
            Text(String(format: "You've fasted for %.1f hours. This will be logged.", elapsed))
        }
    }
}

struct ActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                Text(label)
                    .font(.fdCaption)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .foregroundColor(color)
            .background(color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: FDRadius.md))
        }
    }
}

struct FastingMilestones: View {
    let fast: FastingSession
    let elapsedHours: Double

    let milestones: [(hours: Int, label: String, stage: FastingStage)] = [
        (4, "Fat Burning", .fatBurning),
        (8, "Glucose Depleted", .glucoseDepletion),
        (12, "Ketosis", .ketosis),
        (16, "Autophagy", .autophagy)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: FDSpacing.sm) {
            Text("MILESTONES")
                .font(.fdCaption)
                .foregroundColor(.fdSecondaryLabel)
                .tracking(1)
            ForEach(milestones.filter { $0.hours <= fast.plannedHours }, id: \.hours) { milestone in
                let reached = elapsedHours >= Double(milestone.hours)
                HStack(spacing: FDSpacing.md) {
                    Image(systemName: reached ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(reached ? milestone.stage.swiftUIColor : .fdTertiaryLabel)
                    Text("\(milestone.hours)h — \(milestone.label)")
                        .font(.fdSubheadline)
                        .foregroundColor(reached ? .fdLabel : .fdSecondaryLabel)
                    Spacer()
                    if reached {
                        FDBadge(text: "Reached", color: milestone.stage.swiftUIColor)
                    }
                }
            }
        }
    }
}

// MARK: - Start Fast Card

struct StartFastCard: View {
    @ObservedObject var vm: FastingViewModel
    @Binding var selectedProtocol: FastingViewModel.FastingProtocol
    let profile: UserProfile?
    let onStart: (Int) -> Void

    @State private var customHours: Int = 16

    var plannedHours: Int {
        selectedProtocol == .custom ? customHours : selectedProtocol.fastingHours
    }

    var body: some View {
        VStack(spacing: FDSpacing.lg) {
            VStack(spacing: FDSpacing.sm) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(LinearGradient(colors: [.fdIndigo, .fdPurple], startPoint: .top, endPoint: .bottom))
                Text("Start a Fast")
                    .font(.fdTitle2)
                Text("Choose your fasting protocol")
                    .font(.fdSubheadline)
                    .foregroundColor(.fdSecondaryLabel)
            }

            // Protocol picker
            VStack(spacing: FDSpacing.sm) {
                ForEach(FastingViewModel.FastingProtocol.allCases, id: \.rawValue) { proto in
                    FastingProtocolRow(
                        protocol: proto,
                        isSelected: selectedProtocol == proto
                    ) {
                        selectedProtocol = proto
                    }
                }
            }

            // Custom hours stepper
            if selectedProtocol == .custom {
                HStack {
                    Text("Fasting hours:")
                        .font(.fdSubheadline)
                    Spacer()
                    Stepper("\(customHours)h", value: $customHours, in: 12...23)
                        .labelsHidden()
                    Text("\(customHours)h")
                        .font(.fdHeadline)
                        .foregroundColor(.fdGreen)
                }
                .padding(FDSpacing.md)
                .fdCard()
            }

            // Eating window info
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.fdGreen)
                Text("Eating window: \(24 - plannedHours) hours")
                    .font(.fdSubheadline)
                Spacer()
            }
            .padding(FDSpacing.sm)
            .background(Color.fdGreen.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: FDRadius.sm))

            FDPrimaryButton("Start Fasting", icon: "moon.fill") {
                onStart(plannedHours)
            }
        }
        .padding(FDSpacing.md)
        .fdCard()
        .fdShadow()
    }
}

struct FastingProtocolRow: View {
    let `protocol`: FastingViewModel.FastingProtocol
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: FDSpacing.md) {
                Image(systemName: isSelected ? "record.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .fdGreen : .fdTertiaryLabel)
                VStack(alignment: .leading, spacing: 2) {
                    Text(`protocol`.rawValue)
                        .font(.fdHeadline)
                        .foregroundColor(.fdLabel)
                    Text(`protocol`.description)
                        .font(.fdCaption)
                        .foregroundColor(.fdSecondaryLabel)
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding(FDSpacing.md)
            .background(isSelected ? Color.fdGreen.opacity(0.1) : Color.fdSecondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: FDRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: FDRadius.md)
                    .stroke(isSelected ? Color.fdGreen : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stages Reference Card

struct FastingStagesCard: View {
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: FDSpacing.sm) {
            Button {
                withAnimation { expanded.toggle() }
            } label: {
                HStack {
                    Text("Fasting Stages")
                        .font(.fdHeadline)
                        .foregroundColor(.fdLabel)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.fdSecondaryLabel)
                }
            }
            .buttonStyle(.plain)

            if expanded {
                ForEach(FastingStage.allCases, id: \.rawValue) { stage in
                    HStack(spacing: FDSpacing.md) {
                        Image(systemName: stage.icon)
                            .font(.system(size: 20))
                            .foregroundColor(stage.swiftUIColor)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(stage.rawValue)
                                    .font(.fdSubheadline)
                                FDBadge(text: stage.hoursRange, color: stage.swiftUIColor)
                            }
                            Text(stage.description)
                                .font(.fdCaption)
                                .foregroundColor(.fdSecondaryLabel)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, FDSpacing.xs)
                    if stage != FastingStage.allCases.last {
                        Divider()
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(FDSpacing.md)
        .fdCard()
        .fdShadow(radius: 4)
    }
}

// MARK: - History Summary

struct FastingHistorySummary: View {
    let sessions: [FastingSession]
    @ObservedObject var vm: FastingViewModel
    let profile: UserProfile?
    let showAll: () -> Void

    var completedSessions: [FastingSession] {
        sessions.filter { $0.completed }.prefix(3).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FDSpacing.md) {
            FDSectionHeader(title: "Recent Fasts", action: showAll)

            HStack(spacing: FDSpacing.md) {
                FDStatCard(
                    title: "Streak",
                    value: "\(vm.consecutiveStreak(sessions: sessions, profile: profile))",
                    unit: "days",
                    icon: "flame.fill",
                    color: .fdOrange
                )
                FDStatCard(
                    title: "Avg Fast",
                    value: String(format: "%.1f", vm.weeklyAverageFastingHours(sessions: sessions)),
                    unit: "hours",
                    icon: "timer",
                    color: .fdBlue
                )
            }

            if completedSessions.isEmpty {
                Text("No completed fasts yet.")
                    .font(.fdSubheadline)
                    .foregroundColor(.fdSecondaryLabel)
            } else {
                ForEach(completedSessions) { session in
                    FastHistoryRow(session: session)
                }
            }
        }
        .padding(FDSpacing.md)
        .fdCard()
        .fdShadow()
    }
}

struct FastHistoryRow: View {
    let session: FastingSession

    var body: some View {
        HStack(spacing: FDSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.startTime, style: .date)
                    .font(.fdSubheadline)
                Text(session.startTime, style: .time)
                    .font(.fdCaption)
                    .foregroundColor(.fdSecondaryLabel)
            }
            Spacer()
            HStack(spacing: FDSpacing.sm) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1fh", session.actualHours))
                        .font(.fdHeadline)
                        .foregroundColor(session.brokenEarly ? .fdOrange : .fdGreen)
                    Text("of \(session.plannedHours)h")
                        .font(.fdCaption)
                        .foregroundColor(.fdSecondaryLabel)
                }
                if session.completed && !session.brokenEarly {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.fdGreen)
                } else if session.brokenEarly {
                    FDBadge(text: "Partial", color: .fdOrange)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
