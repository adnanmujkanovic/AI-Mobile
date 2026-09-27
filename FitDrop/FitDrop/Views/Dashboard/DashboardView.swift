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
    @Query(sort: \WaterLog.date, order: .reverse) private var waterLogs: [WaterLog]
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.selectTab) private var selectTab
    @EnvironmentObject private var health: HealthKitManager

    @State private var showSettings = false
    @State private var showWeightHistory = false

    var profile: UserProfile? { profiles.first }

    var todayFood: [FoodEntry] { foodEntries.filter { Calendar.current.isDateInToday($0.date) } }
    var todayWater: [WaterLog] { waterLogs.filter { Calendar.current.isDateInToday($0.date) } }

    var todayBurned: Int {
        let logged = workouts
            .filter { $0.completed && Calendar.current.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.estimatedCalories }
        return max(logged, Int(health.todayActiveEnergy))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FDSpacing.md) {
                    GreetingCard(profile: profile)

                    let totals = FoodViewModel.totals(for: todayFood)
                    TodayCaloriesCard(
                        consumed: totals.calories,
                        target: profile?.dailyCalorieTarget ?? 2000,
                        protein: totals.protein,
                        proteinGoal: profile?.effectiveProteinGoalG ?? 100,
                        burned: todayBurned
                    )
                    .onTapGesture { selectTab(.nutrition) }

                    WaterCard(
                        consumedMl: todayWater.reduce(0) { $0 + $1.amountMl },
                        goalMl: profile?.effectiveWaterGoalMl ?? 2000,
                        onAdd: { vm.addWater($0, modelContext: modelContext) },
                        onUndo: { vm.undoLastWater(todayLogs: todayWater, modelContext: modelContext) }
                    )

                    FastingStatusCard(
                        activeFast: fastingSessions.first { $0.isActive },
                        lastFast: fastingSessions.first { $0.isFinished }
                    )
                    .onTapGesture { selectTab(.fasting) }

                    if health.isEnabled {
                        ActivityCard(steps: health.todaySteps, activeEnergy: Int(health.todayActiveEnergy))
                    }

                    WeightCard(
                        vm: vm,
                        weightLogs: weightLogs,
                        profile: profile,
                        onShowHistory: { showWeightHistory = true }
                    )

                    WeeklySummaryCard(stats: vm.weeklyStats(
                        workouts: workouts,
                        foodEntries: foodEntries,
                        runSessions: runSessions,
                        fastingSessions: fastingSessions,
                        calorieTarget: profile?.dailyCalorieTarget ?? 2000
                    ))

                    StreaksCard(
                        runSessions: runSessions,
                        fastingSessions: fastingSessions,
                        weightLogs: weightLogs,
                        foodEntries: foodEntries,
                        vm: vm
                    )

                    Spacer(minLength: FDSpacing.lg)
                }
                .padding(.horizontal, FDSpacing.md)
                .padding(.vertical, FDSpacing.sm)
            }
            .background(Color.fdGroupedBackground)
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .font(.title3)
                            .foregroundColor(.fdGreen)
                    }
                    .accessibilityLabel("Profile and settings")
                }
            }
            .refreshable { await health.refreshToday() }
            .sheet(isPresented: $vm.showWeightEntry) {
                WeightEntrySheet(vm: vm, profile: profile, weightLogs: weightLogs)
            }
            .sheet(isPresented: $showWeightHistory) {
                WeightHistoryView(vm: vm, profile: profile)
            }
            .sheet(isPresented: $showSettings) {
                if let profile {
                    SettingsView(profile: profile)
                }
            }
        }
    }
}

// MARK: - Greeting Card

struct GreetingCard: View {
    let profile: UserProfile?

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 5 { return "Good night" }
        if hour < 12 { return "Good morning" }
        if hour < 17 { return "Good afternoon" }
        return "Good evening"
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting + (profile.map { $0.name.isEmpty ? "" : ", \($0.name)" } ?? ""))
                    .font(.fdTitle2)
                Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.fdSubheadline)
                    .foregroundColor(.fdSecondaryLabel)
            }
            Spacer()
            Image(systemName: "drop.fill")
                .font(.system(size: 32))
                .foregroundStyle(LinearGradient.fdPrimary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, FDSpacing.xs)
    }
}

// MARK: - Calories

struct TodayCaloriesCard: View {
    let consumed: Double
    let target: Int
    let protein: Double
    let proteinGoal: Int
    let burned: Int

    var remaining: Int { target - Int(consumed) }
    var isOver: Bool { remaining < 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: FDSpacing.md) {
            HStack {
                Label("Calories", systemImage: "flame.fill")
                    .font(.fdHeadline)
                    .foregroundColor(.fdLabel)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.fdTertiaryLabel)
            }
            HStack(spacing: FDSpacing.lg) {
                ZStack {
                    FDProgressRing(
                        progress: target > 0 ? consumed / Double(target) : 0,
                        lineWidth: 11,
                        color: isOver ? .fdRed : .fdGreen,
                        backgroundColor: Color.fdSecondaryLabel.opacity(0.15)
                    )
                    .frame(width: 92, height: 92)
                    VStack(spacing: 0) {
                        Text("\(abs(remaining))")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(isOver ? .fdRed : .fdLabel)
                            .monospacedDigit()
                        Text(isOver ? "over" : "left")
                            .font(.fdCaption2)
                            .foregroundColor(.fdSecondaryLabel)
                    }
                }
                VStack(spacing: FDSpacing.sm) {
                    SummaryStat(icon: "fork.knife", label: "Eaten", value: Int(consumed).formatted(), color: .fdGreen)
                    SummaryStat(icon: "target", label: "Goal", value: target.formatted(), color: .fdSecondaryLabel)
                    SummaryStat(icon: "bolt.heart.fill", label: "Protein", value: "\(Int(protein))/\(proteinGoal)g", color: .fdBlue)
                    if burned > 0 {
                        SummaryStat(icon: "flame.fill", label: "Burned", value: burned.formatted(), color: .fdOrange)
                    }
                }
            }
        }
        .padding(FDSpacing.md)
        .fdCard()
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens nutrition")
    }
}

// MARK: - Water

struct WaterCard: View {
    let consumedMl: Int
    let goalMl: Int
    let onAdd: (Int) -> Void
    let onUndo: () -> Void

    var progress: Double { goalMl > 0 ? min(1, Double(consumedMl) / Double(goalMl)) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: FDSpacing.md) {
            HStack {
                Label("Water", systemImage: "drop.fill")
                    .font(.fdHeadline)
                    .foregroundColor(.fdLabel)
                Spacer()
                Text("\(NumberFormatting.liters(fromMl: consumedMl)) / \(NumberFormatting.liters(fromMl: goalMl))")
                    .font(.fdSubheadline)
                    .foregroundColor(consumedMl >= goalMl ? .fdBlue : .fdSecondaryLabel)
                    .monospacedDigit()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.fdBlue.opacity(0.15))
                    Capsule()
                        .fill(LinearGradient(colors: [.fdTeal, .fdBlue], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * progress)
                        .animation(.spring(duration: 0.4), value: progress)
                }
            }
            .frame(height: 10)
            .accessibilityElement()
            .accessibilityLabel("Water")
            .accessibilityValue("\(consumedMl) of \(goalMl) milliliters")

            HStack(spacing: FDSpacing.sm) {
                WaterButton(label: "+250 ml", icon: "cup.and.saucer.fill") { onAdd(250) }
                WaterButton(label: "+500 ml", icon: "waterbottle.fill") { onAdd(500) }
                Button(action: onUndo) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 44, height: 40)
                        .foregroundColor(consumedMl > 0 ? .fdSecondaryLabel : .fdTertiaryLabel)
                        .background(Color.fdSecondaryLabel.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: FDRadius.sm))
                }
                .buttonStyle(.plain)
                .disabled(consumedMl == 0)
                .accessibilityLabel("Undo last water")
            }
        }
        .padding(FDSpacing.md)
        .fdCard()
    }
}

struct WaterButton: View {
    let label: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.fdSubheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .foregroundColor(.fdBlue)
                .background(Color.fdBlue.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: FDRadius.sm))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Fasting Status

struct FastingStatusCard: View {
    let activeFast: FastingSession?
    let lastFast: FastingSession?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            HStack(spacing: FDSpacing.md) {
                if let fast = activeFast {
                    let stage = FastingStage.forHours(fast.elapsedHours)
                    ZStack {
                        FDProgressRing(
                            progress: fast.progressFraction,
                            lineWidth: 6,
                            color: stage.swiftUIColor,
                            backgroundColor: stage.swiftUIColor.opacity(0.15)
                        )
                        Image(systemName: stage.icon)
                            .font(.system(size: 16))
                            .foregroundColor(stage.swiftUIColor)
                    }
                    .frame(width: 52, height: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fast.isPaused ? "Fast paused" : "Fasting · \(stage.rawValue)")
                            .font(.fdHeadline)
                        Text("\(FastingViewModel.formatHours(fast.elapsedHours)) of \(fast.plannedHours)h · goal \(fast.goalDate.formatted(date: .omitted, time: .shortened))")
                            .font(.fdSubheadline)
                            .foregroundColor(.fdSecondaryLabel)
                    }
                } else {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(LinearGradient(colors: [.fdIndigo, .fdPurple], startPoint: .top, endPoint: .bottom))
                        .frame(width: 52, height: 52)
                        .background(Color.fdIndigo.opacity(0.12))
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Not fasting")
                            .font(.fdHeadline)
                        if let last = lastFast {
                            Text("Last fast: \(FastingViewModel.formatHours(last.actualHours)) · \(last.endTime?.formatted(.relative(presentation: .named)) ?? "")")
                                .font(.fdSubheadline)
                                .foregroundColor(.fdSecondaryLabel)
                        } else {
                            Text("Tap to start your first fast")
                                .font(.fdSubheadline)
                                .foregroundColor(.fdSecondaryLabel)
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.fdTertiaryLabel)
            }
        }
        .padding(FDSpacing.md)
        .fdCard()
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens fasting")
    }
}

// MARK: - Activity (Apple Health)

struct ActivityCard: View {
    let steps: Int
    let activeEnergy: Int

    var body: some View {
        HStack(spacing: FDSpacing.sm) {
            FDStatCard(title: "Steps", value: steps.formatted(), unit: "", icon: "figure.walk", color: .fdGreen)
            FDStatCard(title: "Active energy", value: "\(activeEnergy)", unit: "kcal", icon: "flame.fill", color: .fdOrange)
        }
    }
}

// MARK: - Weight

struct WeightCard: View {
    @ObservedObject var vm: DashboardViewModel
    let weightLogs: [WeightLog]
    let profile: UserProfile?
    let onShowHistory: () -> Void

    var current: Double? { weightLogs.first?.weightKg ?? profile?.currentWeight }
    var goal: Double { profile?.goalWeight ?? 0 }
    var start: Double { profile.map { $0.startWeight > 0 ? $0.startWeight : $0.currentWeight } ?? 0 }

    var progressToGoal: Double {
        guard let current, start > goal else { return 0 }
        return min(1, max(0, (start - current) / (start - goal)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FDSpacing.md) {
            HStack {
                Label("Weight", systemImage: "scalemass.fill")
                    .font(.fdHeadline)
                Spacer()
                if weightLogs.count > 1 {
                    Button("History", action: onShowHistory)
                        .font(.fdSubheadline)
                        .foregroundColor(.fdGreen)
                }
                Button {
                    vm.weightInput = current.map { NumberFormatting.decimal($0) } ?? ""
                    vm.showWeightEntry = true
                } label: {
                    Label("Log", systemImage: "plus.circle.fill")
                        .font(.fdSubheadline.weight(.semibold))
                        .foregroundColor(.fdGreen)
                }
                .padding(.leading, FDSpacing.sm)
            }

            if let current {
                HStack(spacing: 0) {
                    WeightStat(value: current, label: "Current", color: .fdLabel)
                    Divider().frame(height: 36)
                    WeightStat(value: start - current, label: start >= current ? "Lost" : "Gained", color: start >= current ? .fdGreen : .fdOrange, signed: false)
                    Divider().frame(height: 36)
                    WeightStat(value: max(0, current - goal), label: "To goal", color: .fdBlue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.fdGreen.opacity(0.15))
                            Capsule()
                                .fill(LinearGradient.fdPrimary)
                                .frame(width: geo.size.width * progressToGoal)
                        }
                    }
                    .frame(height: 8)
                    HStack {
                        Text("\(NumberFormatting.decimal(start)) kg")
                        Spacer()
                        Text("\(Int(progressToGoal * 100))% to goal")
                            .foregroundColor(.fdGreen)
                        Spacer()
                        Text("\(NumberFormatting.decimal(goal)) kg")
                    }
                    .font(.fdCaption)
                    .foregroundColor(.fdSecondaryLabel)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(Int(progressToGoal * 100)) percent of the way to your goal of \(NumberFormatting.decimal(goal)) kilograms")

                if weightLogs.count >= 2 {
                    WeightChart(logs: weightLogs, goalWeight: goal)
                        .frame(height: 150)
                }

                WeightInsight(logs: weightLogs, goal: goal, bmi: profile?.bmi ?? 0)
            } else {
                Text("Log your weight to start tracking progress.")
                    .font(.fdSubheadline)
                    .foregroundColor(.fdSecondaryLabel)
            }
        }
        .padding(FDSpacing.md)
        .fdCard()
    }
}

struct WeightStat: View {
    let value: Double
    let label: String
    let color: Color
    var signed = false

    var body: some View {
        VStack(spacing: 2) {
            Text("\(NumberFormatting.decimal(abs(value))) kg")
                .font(.fdTitle3)
                .foregroundColor(color)
                .monospacedDigit()
            Text(label)
                .font(.fdCaption)
                .foregroundColor(.fdSecondaryLabel)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct WeightInsight: View {
    let logs: [WeightLog]
    let goal: Double
    let bmi: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let rate = DashboardViewModel.weeklyRate(logs: logs) {
                InsightRow(
                    icon: rate <= 0 ? "arrow.down.right" : "arrow.up.right",
                    color: rate <= 0 ? .fdGreen : .fdOrange,
                    text: "\(rate <= 0 ? "Losing" : "Gaining") \(NumberFormatting.decimal(abs(rate), maxFractionDigits: 2)) kg per week (last 4 weeks)"
                )
                if rate < -1.0 {
                    InsightRow(icon: "exclamationmark.triangle.fill", color: .fdOrange, text: "That's faster than the 0.5–1 kg/week usually recommended. Make sure you're eating enough protein.")
                }
            }
            if let date = DashboardViewModel.projectedGoalDate(logs: logs, goalWeight: goal) {
                InsightRow(icon: "flag.checkered", color: .fdBlue, text: "At this pace you'll reach \(NumberFormatting.decimal(goal)) kg around \(date.formatted(.dateTime.month(.abbreviated).day().year()))")
            } else if logs.count < 3 {
                InsightRow(icon: "lightbulb.fill", color: .fdYellow, text: "Weigh in a few times a week, same time of day, to see your trend and goal date.")
            }
            if bmi > 0 {
                InsightRow(icon: "person.fill", color: .fdPurple, text: "BMI \(NumberFormatting.decimal(bmi)) · \(CalorieCalculator.bmiCategory(bmi))")
            }
        }
    }
}

struct InsightRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: FDSpacing.sm) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 16)
            Text(text)
                .font(.fdCaption)
                .foregroundColor(.fdSecondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Weight Chart

struct WeightChart: View {
    let logs: [WeightLog]
    let goalWeight: Double

    var sortedLogs: [WeightLog] { Array(logs.sorted { $0.date < $1.date }.suffix(60)) }

    /// 7-entry moving average, which smooths day-to-day water fluctuations
    var trend: [(date: Date, weight: Double)] {
        let values = sortedLogs
        return values.indices.map { i in
            let window = values[max(0, i - 6)...i]
            return (values[i].date, window.reduce(0) { $0 + $1.weightKg } / Double(window.count))
        }
    }

    var yDomain: ClosedRange<Double> {
        let weights = sortedLogs.map { $0.weightKg } + (goalWeight > 0 ? [goalWeight] : [])
        let low = (weights.min() ?? 60) - 1
        let high = (weights.max() ?? 80) + 1
        return low...max(high, low + 2)
    }

    var body: some View {
        Chart {
            ForEach(sortedLogs) { log in
                PointMark(
                    x: .value("Date", log.date),
                    y: .value("Weight", log.weightKg)
                )
                .foregroundStyle(Color.fdBlue.opacity(0.45))
                .symbolSize(24)
            }

            ForEach(trend, id: \.date) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Trend", point.weight)
                )
                .foregroundStyle(Color.fdBlue)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .interpolationMethod(.monotone)
            }

            if goalWeight > 0 {
                RuleMark(y: .value("Goal", goalWeight))
                    .foregroundStyle(Color.fdGreen)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Goal")
                            .font(.fdCaption2)
                            .foregroundColor(.fdGreen)
                    }
            }
        }
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
            }
        }
        .accessibilityLabel("Weight chart with trend line")
    }
}

// MARK: - Weekly Summary

struct WeeklySummaryCard: View {
    let stats: WeeklyStats

    var body: some View {
        VStack(alignment: .leading, spacing: FDSpacing.md) {
            Label("This Week", systemImage: "calendar")
                .font(.fdHeadline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: FDSpacing.sm) {
                WeeklyStat(icon: "dumbbell.fill", label: "Workouts", value: "\(stats.workoutsCompleted)", color: .fdPurple)
                WeeklyStat(icon: "fork.knife", label: "Avg Calories", value: stats.avgDailyCalories > 0 ? "\(Int(stats.avgDailyCalories))" : "—", color: .fdOrange)
                WeeklyStat(icon: "figure.run", label: "Runs", value: "\(stats.runsCompleted)", color: .fdGreen)
                WeeklyStat(icon: "timer", label: "Avg Fast", value: stats.avgFastingHours > 0 ? String(format: "%.1fh", stats.avgFastingHours) : "—", color: .fdBlue)
            }
        }
        .padding(FDSpacing.md)
        .fdCard()
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
        .accessibilityElement(children: .combine)
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
            Label("Streaks", systemImage: "flame.fill")
                .font(.fdHeadline)
            HStack(spacing: FDSpacing.sm) {
                StreakBadge(
                    icon: "fork.knife",
                    label: "Food log",
                    value: vm.foodLogStreak(entries: foodEntries),
                    unit: "days",
                    color: .fdOrange
                )
                StreakBadge(
                    icon: "timer",
                    label: "Fasting",
                    value: Streaks.consecutiveDays(fastingSessions.filter { $0.completed }.map { $0.endTime ?? $0.startTime }),
                    unit: "days",
                    color: .fdBlue
                )
                StreakBadge(
                    icon: "scalemass.fill",
                    label: "Weigh-in",
                    value: vm.weightStreak(logs: weightLogs),
                    unit: "days",
                    color: .fdPurple
                )
                StreakBadge(
                    icon: "figure.run",
                    label: "Running",
                    value: Streaks.consecutiveWeeks(runSessions.filter { $0.completed }.map { $0.completedDate ?? $0.date }),
                    unit: "weeks",
                    color: .fdGreen
                )
            }
        }
        .padding(FDSpacing.md)
        .fdCard()
    }
}

struct StreakBadge: View {
    let icon: String
    let label: String
    let value: Int
    let unit: String
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
            Text("\(value)")
                .font(.fdTitle3)
                .foregroundColor(.fdLabel)
            Text(label)
                .font(.fdCaption2)
                .foregroundColor(.fdSecondaryLabel)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) streak: \(value) \(unit)")
    }
}

// MARK: - Weight Entry Sheet

struct WeightEntrySheet: View {
    @ObservedObject var vm: DashboardViewModel
    let profile: UserProfile?
    let weightLogs: [WeightLog]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    var parsed: Double? { NumberFormatting.parseDecimal(vm.weightInput) }
    var isValid: Bool { parsed.map { (20...400).contains($0) } ?? false }

    var body: some View {
        NavigationStack {
            VStack(spacing: FDSpacing.lg) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    TextField("0.0", text: $vm.weightInput)
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .keyboardType(.decimalPad)
                        .focused($focused)
                        .multilineTextAlignment(.center)
                        .frame(width: 200)
                    Text("kg")
                        .font(.fdTitle)
                        .foregroundColor(.fdSecondaryLabel)
                }
                .padding(.top, FDSpacing.lg)

                if let parsed, let previous = weightLogs.first?.weightKg, isValid {
                    let diff = parsed - previous
                    Text(diff == 0 ? "Same as last time" : "\(diff < 0 ? "−" : "+")\(NumberFormatting.decimal(abs(diff))) kg since last weigh-in")
                        .font(.fdSubheadline)
                        .foregroundColor(diff <= 0 ? .fdGreen : .fdOrange)
                }

                DatePicker("Date", selection: $vm.weightDate, in: ...Date(), displayedComponents: [.date])
                    .padding(.horizontal, FDSpacing.xl)

                FDPrimaryButton("Save") {
                    if vm.logWeight(modelContext: modelContext, profile: profile, existingLogs: weightLogs) != nil {
                        dismiss()
                    }
                }
                .padding(.horizontal, FDSpacing.xl)
                .disabled(!isValid)
                .opacity(isValid ? 1 : 0.5)

                Text("Tip: weigh yourself in the morning, after the bathroom and before eating.")
                    .font(.fdCaption)
                    .foregroundColor(.fdSecondaryLabel)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, FDSpacing.xl)

                Spacer()
            }
            .navigationTitle("Log Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .onAppear {
            vm.weightDate = Date()
            focused = true
        }
    }
}

// MARK: - Weight History

struct WeightHistoryView: View {
    @ObservedObject var vm: DashboardViewModel
    let profile: UserProfile?
    @Query(sort: \WeightLog.date, order: .reverse) private var logs: [WeightLog]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(logs.enumerated()), id: \.element.id) { index, log in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(log.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.fdSubheadline)
                            if !log.notes.isEmpty {
                                Text(log.notes)
                                    .font(.fdCaption)
                                    .foregroundColor(.fdSecondaryLabel)
                            }
                        }
                        Spacer()
                        if index + 1 < logs.count {
                            let diff = log.weightKg - logs[index + 1].weightKg
                            if abs(diff) >= 0.05 {
                                Text("\(diff < 0 ? "−" : "+")\(NumberFormatting.decimal(abs(diff)))")
                                    .font(.fdCaption)
                                    .foregroundColor(diff < 0 ? .fdGreen : .fdOrange)
                            }
                        }
                        Text("\(NumberFormatting.decimal(log.weightKg)) kg")
                            .font(.fdHeadline)
                            .monospacedDigit()
                            .frame(minWidth: 80, alignment: .trailing)
                    }
                }
                .onDelete { offsets in
                    offsets.map { logs[$0] }.forEach {
                        vm.deleteWeight($0, allLogs: logs, profile: profile, modelContext: modelContext)
                    }
                }
            }
            .navigationTitle("Weight History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
