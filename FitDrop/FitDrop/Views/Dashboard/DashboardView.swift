import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @StateObject private var vm = DashboardViewModel()
    @Query(sort: \WeightLog.date, order: .reverse) private var weightLogs: [WeightLog]
    @Query(sort: \WorkoutSession.date, order: .reverse) private var workouts: [WorkoutSession]
    @Query(sort: \FoodEntry.date, order: .reverse) private var foodEntries: [FoodEntry]
    @Query(sort: \RunSession.date, order: .reverse) private var runSessions: [RunSession]
    @Query(sort: \FastingSession.startTime, order: .reverse) private var fastingSessions: [FastingSession]
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext

    var profile: UserProfile? { profiles.first }

    var weeklyStats: WeeklyStats {
        vm.weeklyStats(
            workouts: workouts,
            foodEntries: foodEntries,
            runSessions: runSessions,
            fastingSessions: fastingSessions,
            calorieTarget: profile?.dailyCalorieTarget ?? 2000
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FDSpacing.lg) {
                    // Greeting
                    GreetingCard(profile: profile)
                        .padding(.horizontal, FDSpacing.md)

                    // Today's Summary
                    TodaySummaryCard(
                        foodEntries: foodEntries,
                        calorieTarget: profile?.dailyCalorieTarget ?? 2000
                    )
                    .padding(.horizontal, FDSpacing.md)

                    // Weight Section
                    WeightSection(
                        vm: vm,
                        weightLogs: weightLogs,
                        goalWeight: profile?.goalWeight ?? 60
                    )
                    .padding(.horizontal, FDSpacing.md)

                    // Weekly Summary
                    WeeklySummaryCard(stats: weeklyStats)
                        .padding(.horizontal, FDSpacing.md)

                    // Streaks
                    StreaksCard(
                        runSessions: runSessions,
                        fastingSessions: fastingSessions,
                        weightLogs: weightLogs,
                        foodEntries: foodEntries,
                        vm: vm
                    )
                    .padding(.horizontal, FDSpacing.md)

                    Spacer(minLength: FDSpacing.xl)
                }
                .padding(.vertical, FDSpacing.md)
            }
            .navigationTitle("Dashboard")
            .sheet(isPresented: $vm.showWeightEntry) {
                WeightEntrySheet(vm: vm)
                    .environment(\.modelContext, modelContext)
            }
        }
    }
}

// MARK: - Greeting Card

struct GreetingCard: View {
    let profile: UserProfile?

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        if hour < 17 { return "Good afternoon" }
        return "Good evening"
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting + (profile.map { ", \($0.name)" } ?? "") + "!")
                    .font(.fdTitle2)
                Text(Date(), style: .date)
                    .font(.fdSubheadline)
                    .foregroundColor(.fdSecondaryLabel)
            }
            Spacer()
            Image(systemName: "drop.fill")
                .font(.system(size: 36))
                .foregroundStyle(LinearGradient.fdPrimary)
        }
        .padding(FDSpacing.md)
        .background(LinearGradient.fdPrimary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: FDRadius.card))
    }
}

// MARK: - Today Summary

struct TodaySummaryCard: View {
    let foodEntries: [FoodEntry]
    let calorieTarget: Int

    var todayCalories: Double {
        foodEntries
            .filter { Calendar.current.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.totalCalories }
    }

    var progress: Double { calorieTarget > 0 ? min(1.0, todayCalories / Double(calorieTarget)) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: FDSpacing.md) {
            FDSectionHeader(title: "Today's Calories")
            HStack(spacing: FDSpacing.lg) {
                ZStack {
                    FDProgressRing(progress: progress, lineWidth: 10, color: progress > 1 ? .fdRed : .fdGreen)
                        .frame(width: 80, height: 80)
                    VStack(spacing: 1) {
                        Text("\(Int(todayCalories))")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.fdLabel)
                        Text("kcal")
                            .font(.fdCaption2)
                            .foregroundColor(.fdSecondaryLabel)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    CalorieProgressRow(label: "Consumed", value: Int(todayCalories), color: .fdGreen)
                    CalorieProgressRow(label: "Target", value: calorieTarget, color: .fdSecondaryLabel)
                    CalorieProgressRow(
                        label: todayCalories > Double(calorieTarget) ? "Over" : "Remaining",
                        value: Int(abs(Double(calorieTarget) - todayCalories)),
                        color: todayCalories > Double(calorieTarget) ? .fdRed : .fdOrange
                    )
                }
            }
        }
        .padding(FDSpacing.md)
        .fdCard()
        .fdShadow()
    }
}

struct CalorieProgressRow: View {
    let label: String
    let value: Int
    let color: Color
    var body: some View {
        HStack {
            Text(label)
                .font(.fdSubheadline)
                .foregroundColor(.fdSecondaryLabel)
            Spacer()
            Text("\(value) kcal")
                .font(.fdSubheadline)
                .foregroundColor(color)
        }
    }
}

// MARK: - Weight Section

struct WeightSection: View {
    @ObservedObject var vm: DashboardViewModel
    let weightLogs: [WeightLog]
    let goalWeight: Double

    var currentWeight: Double? { weightLogs.first?.weightKg }

    var body: some View {
        VStack(alignment: .leading, spacing: FDSpacing.md) {
            HStack {
                FDSectionHeader(title: "Weight")
                Spacer()
                Button {
                    vm.showWeightEntry = true
                } label: {
                    Label("Log", systemImage: "plus.circle.fill")
                        .font(.fdSubheadline)
                        .foregroundColor(.fdGreen)
                }
            }

            if weightLogs.count >= 2 {
                WeightChart(logs: weightLogs, goalWeight: goalWeight)
                    .frame(height: 160)
            } else if let w = currentWeight {
                HStack(spacing: FDSpacing.lg) {
                    VStack(spacing: 4) {
                        Text(String(format: "%.1f kg", w))
                            .font(.fdTitle2)
                        Text("Current")
                            .font(.fdCaption)
                            .foregroundColor(.fdSecondaryLabel)
                    }
                    Divider().frame(height: 40)
                    VStack(spacing: 4) {
                        Text(String(format: "%.1f kg", goalWeight))
                            .font(.fdTitle2)
                            .foregroundColor(.fdGreen)
                        Text("Goal")
                            .font(.fdCaption)
                            .foregroundColor(.fdSecondaryLabel)
                    }
                    Divider().frame(height: 40)
                    VStack(spacing: 4) {
                        Text(String(format: "%.1f kg", max(0, w - goalWeight)))
                            .font(.fdTitle2)
                            .foregroundColor(.fdOrange)
                        Text("To go")
                            .font(.fdCaption)
                            .foregroundColor(.fdSecondaryLabel)
                    }
                }
            } else {
                Text("No weight logged yet. Tap + to add your weight.")
                    .font(.fdSubheadline)
                    .foregroundColor(.fdSecondaryLabel)
            }
        }
        .padding(FDSpacing.md)
        .fdCard()
        .fdShadow()
    }
}

// MARK: - Weight Chart

struct WeightChart: View {
    let logs: [WeightLog]
    let goalWeight: Double

    var sortedLogs: [WeightLog] { logs.sorted { $0.date < $1.date }.suffix(30).map { $0 } }

    var body: some View {
        if #available(iOS 17.0, *) {
            Chart {
                ForEach(sortedLogs) { log in
                    LineMark(
                        x: .value("Date", log.date),
                        y: .value("Weight", log.weightKg)
                    )
                    .foregroundStyle(Color.fdBlue)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Date", log.date),
                        y: .value("Weight", log.weightKg)
                    )
                    .foregroundStyle(Color.fdBlue.opacity(0.1))
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", log.date),
                        y: .value("Weight", log.weightKg)
                    )
                    .foregroundStyle(Color.fdBlue)
                    .symbolSize(30)
                }

                // Goal line
                RuleMark(y: .value("Goal", goalWeight))
                    .foregroundStyle(Color.fdGreen)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .annotation(position: .trailing) {
                        Text("Goal")
                            .font(.fdCaption2)
                            .foregroundColor(.fdGreen)
                    }
            }
            .chartYScale(domain: (goalWeight - 2)...(sortedLogs.map { $0.weightKg }.max() ?? goalWeight + 5) + 1)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month())
                }
            }
        } else {
            Text("Weight chart requires iOS 17+")
                .foregroundColor(.fdSecondaryLabel)
        }
    }
}

// MARK: - Weekly Summary

struct WeeklySummaryCard: View {
    let stats: WeeklyStats

    var body: some View {
        VStack(alignment: .leading, spacing: FDSpacing.md) {
            FDSectionHeader(title: "This Week")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: FDSpacing.sm) {
                WeeklyStat(icon: "dumbbell.fill", label: "Workouts", value: "\(stats.workoutsCompleted)", color: .fdPurple)
                WeeklyStat(icon: "fork.knife", label: "Avg Calories", value: stats.avgDailyCalories > 0 ? "\(Int(stats.avgDailyCalories))" : "—", color: .fdOrange)
                WeeklyStat(icon: "figure.run", label: "Runs", value: "\(stats.runsCompleted)", color: .fdGreen)
                WeeklyStat(icon: "timer", label: "Avg Fast", value: stats.avgFastingHours > 0 ? String(format: "%.1fh", stats.avgFastingHours) : "—", color: .fdBlue)
            }
        }
        .padding(FDSpacing.md)
        .fdCard()
        .fdShadow()
    }
}

struct WeeklyStat: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: FDSpacing.sm) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.fdTitle3)
                    .foregroundColor(.fdLabel)
                Text(label)
                    .font(.fdCaption)
                    .foregroundColor(.fdSecondaryLabel)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FDSpacing.sm)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: FDRadius.sm))
    }
}

// MARK: - Streaks Card

struct StreaksCard: View {
    let runSessions: [RunSession]
    let fastingSessions: [FastingSession]
    let weightLogs: [WeightLog]
    let foodEntries: [FoodEntry]
    @ObservedObject var vm: DashboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: FDSpacing.md) {
            FDSectionHeader(title: "Streaks")
            HStack(spacing: FDSpacing.sm) {
                StreakBadge(
                    icon: "figure.run",
                    label: "Running",
                    days: RunningPlanViewModel().runningStreak(allSessions: runSessions),
                    color: .fdGreen
                )
                StreakBadge(
                    icon: "timer",
                    label: "Fasting",
                    days: FastingViewModel().consecutiveStreak(sessions: fastingSessions, profile: nil),
                    color: .fdBlue
                )
                StreakBadge(
                    icon: "scalemass.fill",
                    label: "Weigh-in",
                    days: vm.weightStreak(logs: weightLogs),
                    color: .fdPurple
                )
                StreakBadge(
                    icon: "fork.knife",
                    label: "Food Log",
                    days: vm.foodLogStreak(entries: foodEntries),
                    color: .fdOrange
                )
            }
        }
        .padding(FDSpacing.md)
        .fdCard()
        .fdShadow()
    }
}

struct StreakBadge: View {
    let icon: String
    let label: String
    let days: Int
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
            }
            Text("\(days)")
                .font(.fdTitle3)
                .foregroundColor(.fdLabel)
            Text(label)
                .font(.fdCaption2)
                .foregroundColor(.fdSecondaryLabel)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Weight Entry Sheet

struct WeightEntrySheet: View {
    @ObservedObject var vm: DashboardViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: FDSpacing.xl) {
                VStack(spacing: FDSpacing.sm) {
                    Image(systemName: "scalemass.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(LinearGradient.fdPrimary)
                    Text("Log Your Weight")
                        .font(.fdTitle2)
                    Text(Date(), style: .date)
                        .font(.fdSubheadline)
                        .foregroundColor(.fdSecondaryLabel)
                }
                .padding(.top, FDSpacing.lg)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    TextField("0.0", text: $vm.weightInput)
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .keyboardType(.decimalPad)
                        .focused($focused)
                        .multilineTextAlignment(.center)
                        .frame(width: 180)
                    Text("kg")
                        .font(.fdTitle)
                        .foregroundColor(.fdSecondaryLabel)
                }

                FDPrimaryButton("Save") {
                    vm.logWeight(modelContext: modelContext)
                    dismiss()
                }
                .padding(.horizontal, FDSpacing.xl)
                .disabled(Double(vm.weightInput) == nil)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear { focused = true }
    }
}
