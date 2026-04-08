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

    init(
        name: String,
        currentWeight: Double,
        goalWeight: Double,
        goalDate: Date,
        activityLevel: String
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
        self.dailyCalorieTarget = CalorieCalculator.calculateDailyTarget(
            currentWeight: currentWeight,
            goalWeight: goalWeight,
            goalDate: goalDate,
            activityLevel: activityLevel
        )
        self.onboardingCompleted = false
        self.createdAt = Date()
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
