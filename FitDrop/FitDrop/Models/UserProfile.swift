import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID = UUID()
    var name: String = ""
    var currentWeight: Double = 0.0
    var goalWeight: Double = 0.0
    var goalDate: Date = Date()
    var activityLevel: String = "lightly_active"
    var dailyCalorieTarget: Int = 2000
    var fastingProtocol: String = "16:8"
    var fastingStartHour: Int = 20
    var fastingStartMinute: Int = 0
    var fastingDuration: Int = 16
    var eatingWindowDuration: Int = 8
    var onboardingCompleted: Bool = false
    var createdAt: Date = Date()

    // Body data used by the calorie calculation
    var sex: String = Sex.female.rawValue
    var age: Int = 30
    var heightCm: Double = 170
    var startWeight: Double = 0.0

    // Targets. A zero or false value means "calculated automatically".
    var useCustomCalorieTarget: Bool = false
    var proteinGoalG: Int = 0
    var waterGoalMl: Int = 0

    // Preferences
    var healthKitEnabled: Bool = false
    var foodReminderEnabled: Bool = true
    var workoutReminderEnabled: Bool = true
    var fastStartReminderEnabled: Bool = false
    var fastMilestoneAlertsEnabled: Bool = true

    init(
        name: String,
        currentWeight: Double,
        goalWeight: Double,
        goalDate: Date,
        activityLevel: String,
        sex: Sex = .female,
        age: Int = 30,
        heightCm: Double = 170
    ) {
        self.id = UUID()
        self.name = name
        self.currentWeight = currentWeight
        self.goalWeight = goalWeight
        self.goalDate = goalDate
        self.activityLevel = activityLevel
        self.fastingProtocol = "16:8"
        self.fastingStartHour = 20
        self.fastingStartMinute = 0
        self.fastingDuration = 16
        self.eatingWindowDuration = 8
        self.sex = sex.rawValue
        self.age = age
        self.heightCm = heightCm
        self.startWeight = currentWeight
        self.onboardingCompleted = false
        self.createdAt = Date()
        recalculateCalorieTarget()
    }

    var sexValue: Sex { Sex(rawValue: sex) ?? .female }

    /// Recomputes the calorie target from current body data, unless the user set their own.
    func recalculateCalorieTarget() {
        guard !useCustomCalorieTarget else { return }
        dailyCalorieTarget = CalorieCalculator.calculateDailyTarget(
            currentWeight: currentWeight,
            goalWeight: goalWeight,
            goalDate: goalDate,
            activityLevel: activityLevel,
            heightCm: heightCm,
            age: age,
            isMale: sexValue == .male
        )
    }

    /// Protein target: the user's own value, or 1.6 g per kg of goal weight.
    var effectiveProteinGoalG: Int {
        if proteinGoalG > 0 { return proteinGoalG }
        return CalorieCalculator.proteinTarget(goalWeightKg: goalWeight > 0 ? goalWeight : currentWeight)
    }

    /// Water target: the user's own value, or 35 ml per kg of body weight.
    var effectiveWaterGoalMl: Int {
        if waterGoalMl > 0 { return waterGoalMl }
        return CalorieCalculator.waterTarget(weightKg: currentWeight)
    }

    var bmi: Double { CalorieCalculator.bmi(weightKg: currentWeight, heightCm: heightCm) }
}

enum Sex: String, CaseIterable {
    case female
    case male

    var displayName: String {
        switch self {
        case .female: return "Female"
        case .male: return "Male"
        }
    }
}

enum ActivityLevel: String, CaseIterable {
    case sedentary = "sedentary"
    case lightlyActive = "lightly_active"
    case moderatelyActive = "moderately_active"
    case veryActive = "very_active"

    var displayName: String {
        switch self {
        case .sedentary: return "Sedentary"
        case .lightlyActive: return "Lightly Active"
        case .moderatelyActive: return "Moderately Active"
        case .veryActive: return "Very Active"
        }
    }

    var description: String {
        switch self {
        case .sedentary: return "Little or no exercise"
        case .lightlyActive: return "Light exercise 1-3 days/week"
        case .moderatelyActive: return "Moderate exercise 3-5 days/week"
        case .veryActive: return "Hard exercise 6-7 days/week"
        }
    }

    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .lightlyActive: return 1.375
        case .moderatelyActive: return 1.55
        case .veryActive: return 1.725
        }
    }
}
