import Foundation

enum CalorieCalculator {
    /// Calculate daily calorie target using Mifflin-St Jeor BMR + TDEE, then apply deficit
    static func calculateDailyTarget(
        currentWeight: Double,
        goalWeight: Double,
        goalDate: Date,
        activityLevel: String,
        heightCm: Double = 170,
        age: Int = 30,
        isMale: Bool = false
    ) -> Int {
        // BMR - Mifflin-St Jeor (using female as default for weight loss context)
        let bmr = isMale
            ? (10 * currentWeight) + (6.25 * heightCm) - (5 * Double(age)) + 5
            : (10 * currentWeight) + (6.25 * heightCm) - (5 * Double(age)) - 161

        // TDEE
        let multiplier = ActivityLevel(rawValue: activityLevel)?.multiplier ?? 1.375
        let tdee = bmr * multiplier

        // Deficit based on weight loss goal and timeline
        let weightDiff = currentWeight - goalWeight
        let daysToGoal = max(30, Calendar.current.dateComponents([.day], from: Date(), to: goalDate).day ?? 90)

        // 1 kg fat ≈ 7700 kcal
        let totalDeficit = weightDiff * 7700
        let dailyDeficit = totalDeficit / Double(daysToGoal)

        // Cap deficit at 750 kcal/day max, min 1200 kcal
        let target = tdee - min(dailyDeficit, 750)
        return max(1200, Int(target))
    }

    static func estimateCaloriesBurned(
        workoutType: String,
        durationMinutes: Int,
        userWeightKg: Double
    ) -> Int {
        // MET values approximation
        let met: Double
        switch workoutType {
        case "treadmill": met = 8.0
        case "mat": met = 5.0
        case "run": met = 9.0
        default: met = 6.0
        }
        // Calories = MET × weight(kg) × duration(hours)
        let calories = met * userWeightKg * (Double(durationMinutes) / 60.0)
        return Int(calories)
    }

    static func bmi(weightKg: Double, heightCm: Double = 170) -> Double {
        let heightM = heightCm / 100.0
        return weightKg / (heightM * heightM)
    }

    static func bmiCategory(_ bmi: Double) -> String {
        switch bmi {
        case ..<18.5: return "Underweight"
        case 18.5..<25: return "Normal"
        case 25..<30: return "Overweight"
        default: return "Obese"
        }
    }
}
