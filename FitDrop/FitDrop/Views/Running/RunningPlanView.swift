import SwiftUI
import SwiftData

struct RunningPlanView: View {
    @StateObject private var vm = RunningPlanViewModel()
    @Query private var runSessions: [RunSession]
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FDSpacing.lg) {
                    // Stats Header
                    RunningStatsHeader(vm: vm, runSessions: runSessions)
                        .padding(.horizontal, FDSpacing.md)

                    // Overall Progress
                    VStack(alignment: .leading, spacing: FDSpacing.sm) {
                        Text("OVERALL PROGRESS")
                            .font(.fdCaption)
                            .foregroundColor(.fdSecondaryLabel)
                            .tracking(1)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.fdSecondaryBackground)
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
                            Text("\(RunningPlanData.plan.flatMap { $0.sessions }.filter { vm.isSessionCompleted($0, allSessions: runSessions) }.count) / \(RunningPlanData.plan.flatMap { $0.sessions }.count) sessions")
                                .font(.fdCaption)
                                .foregroundColor(.fdSecondaryLabel)
                        }
                    }
                    .padding(FDSpacing.md)
                    .fdCard()
                    .padding(.horizontal, FDSpacing.md)

                    // Weekly Calendar
                    RunningCalendarView(completedDates: vm.completedDates(allSessions: runSessions))
                        .padding(.horizontal, FDSpacing.md)

                    // Week Plans
                    ForEach(RunningPlanData.plan) { week in
                        WeekPlanCard(
                            week: week,
                            vm: vm,
                            allSessions: runSessions,
                            isExpanded: vm.expandedWeek == week.weekNumber
                        ) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                vm.expandedWeek = vm.expandedWeek == week.weekNumber ? nil : week.weekNumber
                            }
                        } onComplete: { session in
                            vm.completeSession(session, modelContext: modelContext)
                        }
                        .padding(.horizontal, FDSpacing.md)
                    }

                    Spacer(minLength: FDSpacing.xl)
                }
                .padding(.vertical, FDSpacing.md)
            }
            .navigationTitle("Running Plan")
        }
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
                unit: "days",
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
                title: "Runs Done",
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
    let completedDates: Set<String>
    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var daysInMonth: [Date] {
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let range = calendar.range(of: .day, in: .month, for: now)!
        return range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: start)
        }
    }

    var weekdayOffset: Int {
        let calendar = Calendar.current
        let firstDay = daysInMonth.first!
        return (calendar.component(.weekday, from: firstDay) - 1 + 7) % 7
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FDSpacing.sm) {
            HStack {
                Text(monthName)
                    .font(.fdHeadline)
                Spacer()
                Text("\(completedDates.count) runs")
                    .font(.fdSubheadline)
                    .foregroundColor(.fdGreen)
            }

            // Day headers
            HStack(spacing: 4) {
                ForEach(["S","M","T","W","T","F","S"], id: \.self) { d in
                    Text(d)
                        .font(.fdCaption2)
                        .foregroundColor(.fdSecondaryLabel)
                        .frame(maxWidth: .infinity)
                }
            }

            // Days grid
            let cells = weekdayOffset + daysInMonth.count
            let rows = (cells + 6) / 7
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { col in
                        let idx = row * 7 + col - weekdayOffset
                        if idx >= 0 && idx < daysInMonth.count {
                            let date = daysInMonth[idx]
                            let dateStr = formatter.string(from: date)
                            let isCompleted = completedDates.contains(dateStr)
                            let isToday = Calendar.current.isDateInToday(date)
                            let isPast = date < Date()
                            CalendarCell(
                                day: idx + 1,
                                isCompleted: isCompleted,
                                isToday: isToday,
                                isPast: isPast
                            )
                        } else {
                            Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
            }
        }
        .padding(FDSpacing.md)
        .fdCard()
    }

    var monthName: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: Date())
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
    }
}

// MARK: - Week Plan Card

struct WeekPlanCard: View {
    let week: RunWeek
    @ObservedObject var vm: RunningPlanViewModel
    let allSessions: [RunSession]
    let isExpanded: Bool
    let onToggle: () -> Void
    let onComplete: (RunPlanSession) -> Void

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
                    Rectangle().fill(Color.fdSeparator)
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
                            if !vm.isSessionCompleted(session, allSessions: allSessions) {
                                onComplete(session)
                            }
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
            .disabled(isCompleted)

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
