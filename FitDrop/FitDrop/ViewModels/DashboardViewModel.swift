import SwiftUI
import SwiftData

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var weightInput: String = ""
    @Published var weightNote: String = ""
    @Published var weightDate: Date = Date()
    @Published var showWeightEntry: Bool = false

    // MARK: - Weight

    /// Parses the input, saves a weight log, and keeps the profile's current weight in sync.
    @discardableResult
    func logWeight(modelContext: ModelContext, profile: UserProfile?, existingLogs: [WeightLog]) -> WeightLog? {
        guard let weight = NumberFormatting.parseDecimal(weightInput), (20...400).contains(weight) else { return nil }
        let date = min(weightDate, Date())
        let log = WeightLog(date: date, weightKg: weight, notes: weightNote)
        modelContext.insert(log)
        Self.syncProfileWeight(profile, logs: existingLogs + [log])
        modelContext.saveOrLog()
        HealthKitManager.shared.saveWeight(log)
        weightInput = ""
        weightNote = ""
        weightDate = Date()
        showWeightEntry = false
        Haptics.success()
        return log
    }

    func deleteWeight(_ log: WeightLog, allLogs: [WeightLog], profile: UserProfile?, modelContext: ModelContext) {
        HealthKitManager.shared.deleteWeight(id: log.id)
        modelContext.delete(log)
        Self.syncProfileWeight(profile, logs: allLogs.filter { $0.id != log.id })
        modelContext.saveOrLog()
    }

    /// The profile's current weight follows the most recent log; the calorie target follows the weight.
    static func syncProfileWeight(_ profile: UserProfile?, logs: [WeightLog]) {
        guard let profile, let latest = logs.max(by: { $0.date < $1.date }) else { return }
        if profile.currentWeight != latest.weightKg {
            profile.currentWeight = latest.weightKg
            profile.recalculateCalorieTarget()
        }
    }

    /// Estimated goal date from a least-squares trend over the last 30 days of weigh-ins.
    static func projectedGoalDate(logs: [WeightLog], goalWeight: Double, now: Date = Date()) -> Date? {
        let windowStart = now.addingTimeInterval(-30 * 86400)
        let recent = logs.filter { $0.date >= windowStart }.sorted { $0.date < $1.date }
        guard recent.count >= 3,
              let first = recent.first, let last = recent.last,
              last.date.timeIntervalSince(first.date) >= 7 * 86400 else { return nil }

        let xs = recent.map { $0.date.timeIntervalSince(first.date) / 86400 }
        let ys = recent.map { $0.weightKg }
        let n = Double(recent.count)
        let meanX = xs.reduce(0, +) / n
        let meanY = ys.reduce(0, +) / n
        let covariance = zip(xs, ys).reduce(0) { $0 + ($1.0 - meanX) * ($1.1 - meanY) }
        let variance = xs.reduce(0) { $0 + ($1 - meanX) * ($1 - meanX) }
        guard variance > 0 else { return nil }
        let slopePerDay = covariance / variance
        // Only project when losing weight toward a lower goal
        guard slopePerDay < -0.005 else { return nil }
        let trendNow = meanY + slopePerDay * (now.timeIntervalSince(first.date) / 86400 - meanX)
        let remaining = trendNow - goalWeight
        guard remaining > 0 else { return nil }
        let days = remaining / -slopePerDay
        guard days < 3 * 365 else { return nil }
        return now.addingTimeInterval(days * 86400)
    }

    /// Weekly change in kg over the last 4 weeks, from the same trend; nil without enough data.
    static func weeklyRate(logs: [WeightLog], now: Date = Date()) -> Double? {
        let recent = logs.filter { $0.date >= now.addingTimeInterval(-28 * 86400) }.sorted { $0.date < $1.date }
        guard recent.count >= 2, let first = recent.first, let last = recent.last else { return nil }
        let days = last.date.timeIntervalSince(first.date) / 86400
        guard days >= 6 else { return nil }
        return (last.weightKg - first.weightKg) / days * 7
    }

    // MARK: - Water

    func addWater(_ ml: Int, modelContext: ModelContext) {
        let log = WaterLog(amountMl: ml)
        modelContext.insert(log)
        modelContext.saveOrLog()
        HealthKitManager.shared.saveWater(log)
        Haptics.tap()
    }

    func undoLastWater(todayLogs: [WaterLog], modelContext: ModelContext) {
        guard let last = todayLogs.max(by: { $0.date < $1.date }) else { return }
        HealthKitManager.shared.deleteWater(id: last.id)
        modelContext.delete(last)
        modelContext.saveOrLog()
        Haptics.selection()
    }

    // MARK: - Weekly Stats

    func weeklyStats(
        workouts: [WorkoutSession],
        foodEntries: [FoodEntry],
        runSessions: [RunSession],
        fastingSessions: [FastingSession],
        calorieTarget: Int,
        now: Date = Date()
    ) -> WeeklyStats {
        let startOfWeek = Calendar.current.dateInterval(of: .weekOfYear, for: now)?.start ?? now

        let weekWorkouts = workouts.filter {
            $0.completed && $0.date >= startOfWeek
        }.count

        let weekFoodEntries = foodEntries.filter { $0.date >= startOfWeek }
        let uniqueDays = Set(weekFoodEntries.map { Calendar.current.startOfDay(for: $0.date) }).count
        let avgCalories = uniqueDays > 0
            ? weekFoodEntries.reduce(0.0) { $0 + $1.totalCalories } / Double(uniqueDays)
            : 0

        let weekRuns = runSessions.filter {
            $0.completed && ($0.completedDate ?? $0.date) >= startOfWeek
        }.count

        let weekFasts = fastingSessions.filter { $0.isFinished && $0.startTime >= startOfWeek }
        let avgFasting = weekFasts.isEmpty ? 0.0 : weekFasts.reduce(0.0) { $0 + $1.actualHours } / Double(weekFasts.count)

        return WeeklyStats(
            workoutsCompleted: weekWorkouts,
            avgDailyCalories: avgCalories,
            runsCompleted: weekRuns,
            avgFastingHours: avgFasting
        )
    }

    func weightStreak(logs: [WeightLog]) -> Int {
        Streaks.consecutiveDays(logs.map { $0.date })
    }

    func foodLogStreak(entries: [FoodEntry]) -> Int {
        Streaks.consecutiveDays(entries.map { $0.date })
    }
}

struct WeeklyStats {
    let workoutsCompleted: Int
    let avgDailyCalories: Double
    let runsCompleted: Int
    let avgFastingHours: Double
}
