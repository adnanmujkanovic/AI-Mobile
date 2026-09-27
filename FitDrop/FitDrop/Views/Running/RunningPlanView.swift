import SwiftUI
import SwiftData

struct RunningPlanView: View {
    @StateObject private var vm = RunningPlanViewModel()
    @Query private var runSessions: [RunSession]
    @Environment(\.modelContext) private var modelContext
    @State private var showLogRun = false
    @State private var sessionToUndo: RunPlanSession? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FDSpacing.lg) {
                    RunningStatsHeader(vm: vm, runSessions: runSessions)
                        .padding(.horizontal, FDSpacing.md)

                    if let next = vm.nextSession(allSessions: runSessions) {
                        UpNextRunCard(session: next) {
                            vm.completeSession(next, modelContext: modelContext)
                        }
                        .padding(.horizontal, FDSpacing.md)
                    } else {
                        PlanCompleteCard()
                            .padding(.horizontal, FDSpacing.md)
                    }

                    // Overall Progress
                    VStack(alignment: .leading, spacing: FDSpacing.sm) {
                        Text("4-WEEK PLAN PROGRESS")
                            .font(.fdCaption)
                            .foregroundColor(.fdSecondaryLabel)
                            .tracking(1)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.fdSecondaryLabel.opacity(0.15))
                                Capsule()
                                    .fill(LinearGradient.fdPrimary)
                                    .frame(width: geo.size.width * vm.overallProgress(allSessions: runSessions))
                                    .animation(.easeInOut, value: vm.overallProgress(allSessions: runSessions))
                            }
                        }
                        .frame(height: 10)
                        HStack {
                            Text("\(Int(vm.overallProgress(allSessions: runSessions) * 100))% complete")
                                .font(.fdCaption)
                                .foregroundColor(.fdGreen)
                            Spacer()
                            let all = RunningPlanData.plan.flatMap { $0.sessions }
                            Text("\(all.filter { vm.isSessionCompleted($0, allSessions: runSessions) }.count) / \(all.count) sessions")
                                .font(.fdCaption)
                                .foregroundColor(.fdSecondaryLabel)
                        }
                    }
                    .padding(FDSpacing.md)
                    .fdCard()
                    .padding(.horizontal, FDSpacing.md)

                    RunningCalendarView(completedDays: vm.completedDays(allSessions: runSessions))
                        .padding(.horizontal, FDSpacing.md)

                    ForEach(RunningPlanData.plan) { week in
                        WeekPlanCard(
                            week: week,
                            vm: vm,
                            allSessions: runSessions,
                            isExpanded: (vm.expandedWeek ?? vm.currentWeek(allSessions: runSessions)) == week.weekNumber
                        ) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                let current = vm.expandedWeek ?? vm.currentWeek(allSessions: runSessions)
                                vm.expandedWeek = current == week.weekNumber ? 0 : week.weekNumber
                            }
                        } onSessionTap: { session in
                            if vm.isSessionCompleted(session, allSessions: runSessions) {
                                sessionToUndo = session
                            } else {
                                vm.completeSession(session, modelContext: modelContext)
                            }
                        }
                        .padding(.horizontal, FDSpacing.md)
                    }

                    let custom = vm.customRuns(allSessions: runSessions)
                    if !custom.isEmpty {
                        OtherRunsCard(runs: custom) { run in
                            modelContext.delete(run)
                            modelContext.saveOrLog()
                        }
                        .padding(.horizontal, FDSpacing.md)
                    }

                    Spacer(minLength: FDSpacing.xl)
                }
                .padding(.vertical, FDSpacing.md)
            }
            .background(Color.fdGroupedBackground)
            .navigationTitle("Running")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showLogRun = true
                    } label: {
                        Label("Log Run", systemImage: "plus.circle.fill")
                            .foregroundColor(.fdGreen)
                    }
                }
            }
            .sheet(isPresented: $showLogRun) {
                LogRunView { distance, minutes, date in
                    vm.logCustomRun(distanceKm: distance, durationMinutes: minutes, date: date, modelContext: modelContext)
                }
            }
            .confirmationDialog(
                "Mark as not done?",
                isPresented: Binding(get: { sessionToUndo != nil }, set: { if !$0 { sessionToUndo = nil } }),
                titleVisibility: .visible
            ) {
                Button("Mark Not Done", role: .destructive) {
                    if let session = sessionToUndo {
                        vm.uncompleteSession(session, allSessions: runSessions, modelContext: modelContext)
                    }
                    sessionToUndo = nil
                }
                Button("Cancel", role: .cancel) { sessionToUndo = nil }
            }
        }
    }
}

// MARK: - Up Next

struct UpNextRunCard: View {
    let session: RunPlanSession
    let onComplete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: FDSpacing.md) {
            HStack {
                Text("UP NEXT · WEEK \(session.week)")
                    .font(.fdCaption)
                    .foregroundColor(.white.opacity(0.8))
                    .tracking(1)
                Spacer()
                FDBadge(text: session.sessionType.rawValue, color: .white)
            }
            HStack(alignment: .firstTextBaseline, spacing: FDSpacing.md) {
                Text(String(format: "%.1f km", session.distanceKm))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("~\(session.durationMinutes) min · \(session.paceZone.speedKmh)")
                    .font(.fdSubheadline)
                    .foregroundColor(.white.opacity(0.85))
            }
            .foregroundColor(.white)
            Text(session.description)
                .font(.fdSubheadline)
                .foregroundColor(.white.opacity(0.9))
            Button(action: onComplete) {
                Label("Mark as Done", systemImage: "checkmark.circle.fill")
                    .font(.fdHeadline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(.white)
                    .foregroundColor(.fdGreen)
                    .clipShape(RoundedRectangle(cornerRadius: FDRadius.md))
            }
        }
        .padding(FDSpacing.md)
        .background(LinearGradient.fdPrimary)
        .clipShape(RoundedRectangle(cornerRadius: FDRadius.card))
    }
}

struct PlanCompleteCard: View {
    var body: some View {
        HStack(spacing: FDSpacing.md) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 36))
                .foregroundColor(.fdYellow)
            VStack(alignment: .leading, spacing: 4) {
                Text("Plan complete!")
                    .font(.fdTitle3)
                Text("You finished all 4 weeks. Keep logging runs with the + button to stay consistent.")
                    .font(.fdSubheadline)
                    .foregroundColor(.fdSecondaryLabel)
            }
        }
        .padding(FDSpacing.md)
        .fdCard()
    }
}

// MARK: - Stats Header

struct RunningStatsHeader: View {
    @ObservedObject var vm: RunningPlanViewModel
    let runSessions: [RunSession]

    var body: some View {
        HStack(spacing: FDSpacing.sm) {
            FDStatCard(
                title: "Streak",
                value: "\(vm.runningStreak(allSessions: runSessions))",
                unit: "wks",
                icon: "flame.fill",
                color: .fdOrange
            )
            FDStatCard(
                title: "Distance",
                value: String(format: "%.1f", vm.totalDistanceRun(allSessions: runSessions)),
                unit: "km",
                icon: "figure.run",
                color: .fdBlue
            )
            FDStatCard(
                title: "Runs",
                value: "\(runSessions.filter { $0.completed }.count)",
                unit: "total",
                icon: "checkmark.circle.fill",
                color: .fdGreen
            )
        }
    }
}

// MARK: - Calendar

struct RunningCalendarView: View {
    let completedDays: Set<Date>
    @State private var month = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()

    private var calendar: Calendar { Calendar.current }

    var daysInMonth: [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: month) }
    }

    /// Blank cells before the 1st, respecting the locale's first weekday
    var leadingBlanks: Int {
        guard let first = daysInMonth.first else { return 0 }
        return (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
    }

    var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    var runsThisMonth: Int {
        daysInMonth.filter { completedDays.contains($0) }.count
    }

    var isCurrentMonth: Bool { calendar.isDate(month, equalTo: Date(), toGranularity: .month) }

    var body: some View {
        VStack(alignment: .leading, spacing: FDSpacing.sm) {
            HStack {
                Button {
                    month = calendar.date(byAdding: .month, value: -1, to: month) ?? month
                } label: {
                    Image(systemName: "chevron.left").foregroundColor(.fdGreen)
                }
                .accessibilityLabel("Previous month")
                Text(month.formatted(.dateTime.month(.wide).year()))
                    .font(.fdHeadline)
                Button {
                    month = calendar.date(byAdding: .month, value: 1, to: month) ?? month
                } label: {
                    Image(systemName: "chevron.right").foregroundColor(isCurrentMonth ? .fdTertiaryLabel : .fdGreen)
                }
                .disabled(isCurrentMonth)
                .accessibilityLabel("Next month")
                Spacer()
                Text("\(runsThisMonth) run days")
                    .font(.fdSubheadline)
                    .foregroundColor(.fdGreen)
            }
            .buttonStyle(.plain)

            HStack(spacing: 4) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, d in
                    Text(d)
                        .font(.fdCaption2)
                        .foregroundColor(.fdSecondaryLabel)
                        .frame(maxWidth: .infinity)
                }
            }

            let cells = leadingBlanks + daysInMonth.count
            let rows = (cells + 6) / 7
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { col in
                        let idx = row * 7 + col - leadingBlanks
                        if idx >= 0 && idx < daysInMonth.count {
                            let date = daysInMonth[idx]
                            CalendarCell(
                                day: idx + 1,
                                isCompleted: completedDays.contains(date),
                                isToday: calendar.isDateInToday(date),
                                isPast: date < Date()
                            )
                        } else {
                            Color.clear.frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
            }
        }
        .padding(FDSpacing.md)
        .fdCard()
    }
}

struct CalendarCell: View {
    let day: Int
    let isCompleted: Bool
    let isToday: Bool
    let isPast: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isCompleted ? Color.fdGreen : isToday ? Color.fdBlue.opacity(0.2) : Color.clear)
            Text("\(day)")
                .font(.fdCaption)
                .foregroundColor(isCompleted ? .white : isToday ? .fdBlue : isPast ? .fdSecondaryLabel : .fdLabel)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("\(day)" + (isCompleted ? ", ran" : ""))
    }
}

// MARK: - Other Runs

struct OtherRunsCard: View {
    let runs: [RunSession]
    let onDelete: (RunSession) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: FDSpacing.sm) {
            Text("OTHER RUNS")
                .font(.fdCaption)
                .foregroundColor(.fdSecondaryLabel)
                .tracking(1)
            ForEach(runs.prefix(10)) { run in
                HStack {
                    Image(systemName: "figure.run")
                        .foregroundColor(.fdBlue)
                    Text((run.completedDate ?? run.date).formatted(date: .abbreviated, time: .omitted))
                        .font(.fdSubheadline)
                    Spacer()
                    Text(String(format: "%.1f km · %d min", run.distanceKm, run.durationMinutes))
                        .font(.fdSubheadline)
                        .foregroundColor(.fdSecondaryLabel)
                    Menu {
                        Button("Delete", role: .destructive) { onDelete(run) }
                    } label: {
                        Image(systemName: "ellipsis").foregroundColor(.fdSecondaryLabel).frame(width: 30, height: 30)
                    }
                }
            }
        }
        .padding(FDSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fdCard()
    }
}

struct LogRunView: View {
    let onSave: (Double, Int, Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var distance: Double? = 5
    @State private var minutes: Int? = 35
    @State private var date = Date()

    var pace: String? {
        guard let distance, let minutes, distance > 0, minutes > 0 else { return nil }
        let secondsPerKm = Double(minutes * 60) / distance
        return String(format: "%d:%02d /km", Int(secondsPerKm) / 60, Int(secondsPerKm) % 60)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Distance")
                        Spacer()
                        TextField("5", value: $distance, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("km").foregroundColor(.fdSecondaryLabel)
                    }
                    HStack {
                        Text("Duration")
                        Spacer()
                        TextField("35", value: $minutes, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                        Text("min").foregroundColor(.fdSecondaryLabel)
                    }
                    DatePicker("When", selection: $date, in: ...Date())
                } footer: {
                    if let pace { Text("Average pace \(pace)") }
                }
            }
            .navigationTitle("Log a Run")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(distance ?? 0, minutes ?? 0, date)
                        dismiss()
                    }
                    .disabled((distance ?? 0) <= 0 || (minutes ?? 0) <= 0)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Week Plan Card

struct WeekPlanCard: View {
    let week: RunWeek
    @ObservedObject var vm: RunningPlanViewModel
    let allSessions: [RunSession]
    let isExpanded: Bool
    let onToggle: () -> Void
    let onSessionTap: (RunPlanSession) -> Void

    var completed: Int { vm.completedSessionsForWeek(week.weekNumber, allSessions: allSessions) }
    var total: Int { vm.totalSessionsForWeek(week.weekNumber) }
    var weekProgress: Double { total > 0 ? Double(completed) / Double(total) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button(action: onToggle) {
                HStack(spacing: FDSpacing.md) {
                    ZStack {
                        Circle()
                            .stroke(Color.fdGreen.opacity(0.3), lineWidth: 2)
                            .frame(width: 44, height: 44)
                        if weekProgress >= 1.0 {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(.fdGreen)
                        } else {
                            Text("\(week.weekNumber)")
                                .font(.fdHeadline)
                                .foregroundColor(.fdGreen)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(week.title)
                            .font(.fdHeadline)
                            .foregroundColor(.fdLabel)
                        Text(week.focus)
                            .font(.fdCaption)
                            .foregroundColor(.fdSecondaryLabel)
                            .lineLimit(1)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(completed)/\(total)")
                            .font(.fdSubheadline)
                            .foregroundColor(.fdGreen)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.fdSecondaryLabel)
                    }
                }
                .padding(FDSpacing.md)
            }
            .buttonStyle(.plain)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.fdSecondaryLabel.opacity(0.15))
                    Rectangle()
                        .fill(LinearGradient.fdPrimary)
                        .frame(width: geo.size.width * weekProgress)
                        .animation(.easeInOut, value: weekProgress)
                }
            }
            .frame(height: 3)

            // Sessions (expanded)
            if isExpanded {
                VStack(spacing: FDSpacing.sm) {
                    ForEach(week.sessions) { session in
                        RunSessionRow(
                            session: session,
                            isCompleted: vm.isSessionCompleted(session, allSessions: allSessions)
                        ) {
                            onSessionTap(session)
                        }
                    }
                }
                .padding(FDSpacing.md)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .fdCard()
        .fdShadow(radius: 4)
    }
}

// MARK: - Run Session Row

struct RunSessionRow: View {
    let session: RunPlanSession
    let isCompleted: Bool
    let onComplete: () -> Void

    var body: some View {
        HStack(spacing: FDSpacing.md) {
            // Complete button
            Button(action: onComplete) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isCompleted ? .fdGreen : .fdTertiaryLabel)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isCompleted ? "Completed. Double tap to mark not done" : "Mark as done")

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: FDSpacing.sm) {
                    FDBadge(text: session.paceZone.rawValue, color: session.paceZone.swiftUIColor)
                    FDBadge(text: session.sessionType.rawValue, color: .fdSecondaryLabel)
                }
                Text(session.description)
                    .font(.fdCaption)
                    .foregroundColor(.fdSecondaryLabel)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f km", session.distanceKm))
                    .font(.fdSubheadline)
                    .foregroundColor(.fdLabel)
                Text("\(session.durationMinutes) min")
                    .font(.fdCaption)
                    .foregroundColor(.fdSecondaryLabel)
                Text(session.paceZone.speedKmh)
                    .font(.fdCaption2)
                    .foregroundColor(session.paceZone.swiftUIColor)
            }
        }
        .padding(.vertical, FDSpacing.sm)
        .padding(.horizontal, FDSpacing.md)
        .background(isCompleted ? Color.fdGreen.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: FDRadius.sm))
    }
}
