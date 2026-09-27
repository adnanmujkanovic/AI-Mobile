import SwiftUI
import SwiftData

struct FastingView: View {
    @StateObject private var vm = FastingViewModel()
    @Query(sort: \FastingSession.startTime, order: .reverse) private var sessions: [FastingSession]
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext

    @State private var selectedProtocol: FastingViewModel.FastingProtocol = .sixteen_eight
    @State private var showHistory = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FDSpacing.lg) {
                    if let active = sessions.first(where: { $0.isActive }) {
                        ActiveFastView(fast: active, vm: vm)
                            .padding(.horizontal, FDSpacing.md)
                    } else {
                        StartFastCard(
                            vm: vm,
                            selectedProtocol: $selectedProtocol,
                            profile: profiles.first
                        ) { hours, start in
                            vm.startFast(plannedHours: hours, startTime: start, modelContext: modelContext, profile: profiles.first)
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

                    Text("Fasting isn't right for everyone. If you're pregnant, diabetic, have a history of eating disorders or take medication, talk to your doctor first.")
                        .font(.fdCaption2)
                        .foregroundColor(.fdTertiaryLabel)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, FDSpacing.xl)

                    Spacer(minLength: FDSpacing.xl)
                }
                .padding(.vertical, FDSpacing.md)
            }
            .background(Color.fdGroupedBackground)
            .navigationTitle("Fasting")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.fdGreen)
                    }
                    .accessibilityLabel("Fasting history")
                }
            }
            .sheet(isPresented: $showHistory) {
                FastingHistoryView(vm: vm, profile: profiles.first)
            }
            .onAppear {
                vm.loadActiveFast(from: sessions)
                if let profile = profiles.first {
                    selectedProtocol = FastingViewModel.FastingProtocol(rawValue: profile.fastingProtocol) ?? .sixteen_eight
                }
            }
            .onChange(of: sessions.first(where: { $0.isActive })?.id) {
                vm.loadActiveFast(from: sessions)
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
    @State private var showEditStart = false
    @State private var showEditGoal = false

    var goalReached: Bool { vm.elapsedSeconds >= Double(fast.plannedHours) * 3600 }

    var body: some View {
        VStack(spacing: FDSpacing.lg) {
            // Stage badge
            HStack {
                Image(systemName: vm.currentStage.icon)
                    .foregroundColor(vm.currentStage.swiftUIColor)
                Text(fast.isPaused ? "Paused" : vm.currentStage.rawValue)
                    .font(.fdHeadline)
                    .foregroundColor(vm.currentStage.swiftUIColor)
            }
            .padding(.horizontal, FDSpacing.md)
            .padding(.vertical, FDSpacing.xs)
            .background(vm.currentStage.swiftUIColor.opacity(0.15))
            .clipShape(Capsule())

            // Timer arc
            ZStack {
                Circle()
                    .stroke(Color.fdSecondaryLabel.opacity(0.15), lineWidth: 20)
                    .frame(width: 240, height: 240)

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

                VStack(spacing: FDSpacing.xs) {
                    Text(vm.formattedElapsed)
                        .font(.system(size: 40, weight: .bold, design: .monospaced))
                        .foregroundColor(.fdLabel)
                        .minimumScaleFactor(0.7)
                        .accessibilityLabel("Time fasted: \(vm.formattedElapsed)")
                    Text("fasted")
                        .font(.fdCaption)
                        .foregroundColor(.fdSecondaryLabel)
                        .accessibilityHidden(true)
                    Divider().frame(width: 60)
                    if goalReached {
                        Label("Goal reached", systemImage: "checkmark.seal.fill")
                            .font(.fdSubheadline.weight(.semibold))
                            .foregroundColor(.fdGreen)
                    } else {
                        Text(vm.formattedRemaining)
                            .font(.system(size: 22, weight: .semibold, design: .monospaced))
                            .foregroundColor(.fdSecondaryLabel)
                            .accessibilityLabel("Time remaining: \(vm.formattedRemaining)")
                        Text("to go")
                            .font(.fdCaption2)
                            .foregroundColor(.fdTertiaryLabel)
                            .accessibilityHidden(true)
                    }
                }
            }

            // Start and goal times
            HStack(spacing: FDSpacing.md) {
                TimeChip(title: "Started", time: fast.startTime, icon: "pencil") { showEditStart = true }
                TimeChip(title: fast.isPaused ? "Goal (paused)" : "Goal · \(fast.plannedHours)h", time: fast.goalDate, icon: "pencil") { showEditGoal = true }
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

                if goalReached {
                    ActionButton(icon: "checkmark.circle.fill", label: "End Fast", color: .fdGreen) {
                        vm.completeFast(modelContext: modelContext)
                    }
                } else {
                    ActionButton(icon: "xmark.circle.fill", label: "Break Fast", color: .fdRed) {
                        showBreakAlert = true
                    }
                }
            }

            FastingMilestones(fast: fast, elapsedHours: vm.elapsedSeconds / 3600)
        }
        .padding(FDSpacing.md)
        .fdCard()
        .fdShadow()
        .alert("Break Fast?", isPresented: $showBreakAlert) {
            Button("Keep Fasting", role: .cancel) {}
            Button("Break Fast", role: .destructive) {
                vm.breakFast(modelContext: modelContext)
            }
        } message: {
            Text("You've fasted for \(FastingViewModel.formatHours(vm.elapsedSeconds / 3600)) of \(fast.plannedHours)h. It will be saved in your history.")
        }
        .sheet(isPresented: $showEditStart) {
            EditFastStartView(start: fast.startTime) { newStart in
                vm.updateStartTime(newStart, modelContext: modelContext)
            }
        }
        .sheet(isPresented: $showEditGoal) {
            EditFastGoalView(hours: fast.plannedHours) { hours in
                vm.updatePlannedHours(hours, modelContext: modelContext)
            }
        }
    }
}

struct TimeChip: View {
    let title: String
    let time: Date
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.fdCaption)
                    .foregroundColor(.fdSecondaryLabel)
                HStack(spacing: 4) {
                    Text(Self.label(for: time))
                        .font(.fdHeadline)
                        .foregroundColor(.fdLabel)
                    Image(systemName: icon)
                        .font(.caption2)
                        .foregroundColor(.fdGreen)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, FDSpacing.sm)
            .background(Color.fdSecondaryLabel.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: FDRadius.md))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Double tap to edit")
    }

    static func label(for date: Date) -> String {
        let time = date.formatted(date: .omitted, time: .shortened)
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return time }
        if calendar.isDateInYesterday(date) { return "Yest. \(time)" }
        if calendar.isDateInTomorrow(date) { return "Tmrw. \(time)" }
        return date.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }
}

struct EditFastStartView: View {
    @State var start: Date
    let onSave: (Date) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        "Started",
                        selection: $start,
                        in: Date().addingTimeInterval(-72 * 3600)...Date(),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.graphical)
                } footer: {
                    Text("Forgot to start the timer? Set when you actually had your last meal.")
                }
            }
            .navigationTitle("Edit Start Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(start)
                        dismiss()
                    }
                }
            }
        }
    }
}

struct EditFastGoalView: View {
    @State var hours: Int
    let onSave: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $hours, in: 1...72) {
                        HStack {
                            Text("Fasting goal")
                            Spacer()
                            Text("\(hours) hours")
                                .font(.fdHeadline)
                                .foregroundColor(.fdGreen)
                        }
                    }
                } footer: {
                    Text("Changing the goal keeps your current progress.")
                }
            }
            .navigationTitle("Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(hours)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
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
        (16, "Autophagy", .autophagy),
        (18, "Deep Fast", .deepFast)
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
    let onStart: (Int, Date) -> Void

    @State private var customHours: Int = 16
    @State private var startedEarlier = false
    @State private var startTime = Date()

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
                        Haptics.selection()
                    }
                }
            }

            // Custom hours stepper
            if selectedProtocol == .custom {
                HStack {
                    Text("Fasting hours:")
                        .font(.fdSubheadline)
                    Spacer()
                    Stepper("\(customHours)h", value: $customHours, in: 12...72)
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
                Text(plannedHours < 24 ? "Eating window: \(24 - plannedHours) hours" : "Extended fast: \(plannedHours) hours")
                    .font(.fdSubheadline)
                Spacer()
            }
            .padding(FDSpacing.sm)
            .background(Color.fdGreen.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: FDRadius.sm))

            Toggle(isOn: $startedEarlier.animation()) {
                Text("I started earlier")
                    .font(.fdSubheadline)
            }
            .tint(.fdGreen)
            if startedEarlier {
                DatePicker(
                    "Last meal",
                    selection: $startTime,
                    in: Date().addingTimeInterval(-72 * 3600)...Date(),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .font(.fdSubheadline)
            }

            FDPrimaryButton("Start Fasting", icon: "moon.fill") {
                onStart(plannedHours, startedEarlier ? startTime : Date())
                startedEarlier = false
                startTime = Date()
            }
        }
        .padding(FDSpacing.md)
        .fdCard()
        .fdShadow()
        .onAppear {
            if let profile, FastingViewModel.FastingProtocol(rawValue: profile.fastingProtocol) == .custom {
                customHours = profile.fastingDuration
            }
        }
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
        sessions.filter { $0.isFinished }.prefix(3).map { $0 }
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
                Text("Your finished fasts will appear here.")
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
                if session.completed {
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
