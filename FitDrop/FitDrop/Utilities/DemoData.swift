#if DEBUG
import Foundation
import SwiftData

/// Debug-only sample data for screenshots and manual testing.
/// Launch with `-FitDropDemo YES` (and optionally `-FitDropTab fasting`) to use it.
@MainActor
enum DemoData {
    static var isRequested: Bool { UserDefaults.standard.bool(forKey: "FitDropDemo") }

    static var initialTab: AppTab? {
        switch UserDefaults.standard.string(forKey: "FitDropTab") {
        case "nutrition": return .nutrition
        case "fasting": return .fasting
        case "workouts": return .workouts
        case "running": return .running
        case "today": return .today
        default: return nil
        }
    }

    /// `-FitDropReset YES` wipes everything first, e.g. for UI tests of onboarding.
    static func resetIfRequested(_ context: ModelContext) {
        guard UserDefaults.standard.bool(forKey: "FitDropReset") else { return }
        try? DataExporter.deleteAll(context: context)
    }

    static func seedIfNeeded(_ context: ModelContext) {
        guard isRequested, (try? context.fetchCount(FetchDescriptor<UserProfile>())) == 0 else { return }
        let calendar = Calendar.current
        let now = Date()
        func daysAgo(_ d: Int, hour: Int = 8) -> Date {
            let day = calendar.date(byAdding: .day, value: -d, to: calendar.startOfDay(for: now))!
            return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
        }

        let profile = UserProfile(
            name: "Adnan", currentWeight: 84.2, goalWeight: 78,
            goalDate: calendar.date(byAdding: .month, value: 3, to: now)!,
            activityLevel: ActivityLevel.moderatelyActive.rawValue, sex: .male, age: 34, heightCm: 182
        )
        profile.startWeight = 87.5
        profile.onboardingCompleted = true
        context.insert(profile)

        // A realistic, noisy downward trend
        let noise = [0.3, -0.2, 0.1, 0.4, -0.3, 0.0, 0.2, -0.1, 0.3, -0.2, 0.1, 0.0, -0.3, 0.2]
        for (i, d) in stride(from: 28, through: 0, by: -2).enumerated() {
            let weight = 87.5 - Double(28 - d) * 0.118 + noise[i % noise.count]
            context.insert(WeightLog(date: daysAgo(d, hour: 7), weightKg: (weight * 10).rounded() / 10))
        }

        let foods: [(String, String, Double, Double, Double, Double, Double, String)] = [
            ("Greek Yogurt 2%", "Fage", 73, 10, 3.6, 2, 2.0, "Breakfast"),
            ("Rolled Oats", "", 379, 13, 67, 6.5, 0.5, "Breakfast"),
            ("Chicken Breast", "", 165, 31, 0, 3.6, 1.8, "Lunch"),
            ("Brown Rice, cooked", "", 123, 2.7, 26, 1, 1.5, "Lunch"),
            ("Apple", "", 52, 0.3, 14, 0.2, 1.8, "Snack"),
        ]
        for day in 0...5 {
            for food in foods where !(day == 0 && food.7 == "Snack") {
                let entry = FoodEntry(
                    name: food.0, brand: food.1, calories: food.2, protein: food.3, carbs: food.4, fat: food.5,
                    servingDescription: "100g", servingAmount: food.6, mealType: food.7
                )
                entry.date = daysAgo(day, hour: food.7 == "Breakfast" ? 12 : food.7 == "Lunch" ? 14 : 17)
                context.insert(entry)
            }
        }
        if let first = try? context.fetch(FetchDescriptor<FoodEntry>()).first {
            context.insert(SavedFood(from: first))
        }

        for amount in [500, 250, 250, 500] { context.insert(WaterLog(date: now, amountMl: amount)) }

        for d in [1, 2, 3, 5, 6] {
            let fast = FastingSession(startTime: daysAgo(d + 1, hour: 20), plannedHours: 16)
            fast.end(at: daysAgo(d + 1, hour: 20).addingTimeInterval(d == 3 ? 13.5 * 3600 : 16.4 * 3600))
            context.insert(fast)
        }
        context.insert(FastingSession(startTime: now.addingTimeInterval(-13.7 * 3600), plannedHours: 16))

        for (d, name, type, minutes, kcal) in [(1, "Interval Blast", "treadmill", 30, 310), (3, "Core Crusher", "mat", 20, 150), (6, "Easy 5K", "treadmill", 40, 380)] {
            let workout = WorkoutSession(workoutName: name, workoutType: type, duration: minutes * 60, estimatedCalories: kcal)
            workout.completed = true
            workout.date = daysAgo(d, hour: 18)
            context.insert(workout)
        }

        for session in RunningPlanData.plan[0].sessions + [RunningPlanData.plan[1].sessions[0]] {
            let run = RunSession(planWeek: session.week, planDay: session.dayOfWeek, planSessionIndex: session.sessionNumber,
                                 distanceKm: session.distanceKm, durationMinutes: session.durationMinutes, paceZone: session.paceZone.rawValue)
            run.completed = true
            run.completedDate = daysAgo(12 - session.sessionNumber * 3, hour: 7)
            context.insert(run)
        }
        context.saveOrLog()
    }
}
#endif
