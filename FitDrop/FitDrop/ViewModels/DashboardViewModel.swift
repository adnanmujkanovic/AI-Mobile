import SwiftUI
import SwiftData

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var weightInput: String = ""
    @Published var weightNote: String = ""
    @Published var showWeightEntry: Bool = false

    func logWeight(modelContext: ModelContext) {
        guard let weight = Double(weightInput), weight > 0 else { return }
        let log = WeightLog(date: Date(), weightKg: weight, notes: weightNote)
        modelContext.insert(log)
        try? modelContext.save()
        weightInput = ""
        weightNote = ""
        showWeightEntry = false
    }

    func weeklyStats(
        workouts: [WorkoutSession],
        foodEntries: [FoodEntry],
        runSessions: [RunSession],
        fastingSessions: [FastingSession],
        calorieTarget: Int
    ) -> WeeklyStats {
        let startOfWeek = Calendar.current.date(
            from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        ) ?? Date()

        let weekWorkouts = workouts.filter {
            $0.completed && $0.date >= startOfWeek
        }.count

        let weekFoodEntries = foodEntries.filter { $0.date >= startOfWeek }
        let uniqueDays = Set(weekFoodEntries.map { Calendar.current.startOfDay(for: $0.date) }).count
        let avgCalories: Double
        if uniqueDays > 0 {
            let totalCals = weekFoodEntries.reduce(0.0) { $0 + $1.totalCalories }
            let days = max(1, uniqueDays)
            avgCalories = totalCals / Double(days)
        } else {
            avgCalories = 0
        }

        let weekRuns = runSessions.filter {
            $0.completed && ($0.completedDate ?? $0.date) >= startOfWeek
        }.count

        let weekFasts = fastingSessions.filter { $0.completed && $0.startTime >= startOfWeek }
        let avgFasting = weekFasts.isEmpty ? 0.0 : weekFasts.reduce(0.0) { $0 + $1.actualHours } / Double(weekFasts.count)

        return WeeklyStats(
            workoutsCompleted: weekWorkouts,
            avgDailyCalories: avgCalories,
            runsCompleted: weekRuns,
            avgFastingHours: avgFasting
        )
    }

    func weightStreak(logs: [WeightLog]) -> Int {
        let sorted = logs.sorted { $0.date > $1.date }
        var streak = 0
        var checkDate = Calendar.current.startOfDay(for: Date())
        for log in sorted {
            let logDay = Calendar.current.startOfDay(for: log.date)
            if logDay == checkDate {
                streak += 1
                checkDate = Calendar.current.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else if logDay < checkDate {
                break
            }
        }
        return streak
    }

    func foodLogStreak(entries: [FoodEntry]) -> Int {
        let sortedDays = Set(entries.map { Calendar.current.startOfDay(for: $0.date) })
            .sorted(by: >)
        var streak = 0
        var checkDate = Calendar.current.startOfDay(for: Date())
        for day in sortedDays {
            if day == checkDate {
                streak += 1
                checkDate = Calendar.current.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else if day < checkDate {
                break
            }
        }
        return streak
    }

    func projectedWeightLossDate(
        currentWeight: Double,
        goalWeight: Double,
        logs: [WeightLog]
    ) -> Date? {
        guard logs.count >= 2 else { return nil }
        let sorted = logs.sorted { $0.date < $1.date }
        let first = sorted.first!
        let last = sorted.last!
        let daysDiff = Calendar.current.dateComponents([.day], from: first.date, to: last.date).day ?? 1
        guard daysDiff > 0 else { return nil }
        let ratePerDay = (first.weightKg - last.weightKg) / Double(daysDiff)
        guard ratePerDay > 0 else { return nil }
        let remaining = last.weightKg - goalWeight
        let daysRemaining = remaining / ratePerDay
        return Calendar.current.date(byAdding: .day, value: Int(daysRemaining), to: last.date)
    }
}

struct WeeklyStats {
    let workoutsCompleted: Int
    let avgDailyCalories: Double
    let runsCompleted: Int
    let avgFastingHours: Double
}
