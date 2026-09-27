import SwiftUI
import SwiftData

@MainActor
class OnboardingViewModel: ObservableObject {
    @Published var currentStep: Int = 0
    @Published var name: String = ""
    @Published var sex: Sex = .female
    @Published var age: Int = 30
    @Published var heightCm: String = ""
    @Published var currentWeight: String = ""
    @Published var goalWeight: String = ""
    @Published var goalDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    @Published var activityLevel: ActivityLevel = .lightlyActive
    @Published var isCompleting: Bool = false

    let totalSteps = 5

    var currentWeightDouble: Double? { NumberFormatting.parseDecimal(currentWeight) }
    var goalWeightDouble: Double? { NumberFormatting.parseDecimal(goalWeight) }
    var heightDouble: Double? { NumberFormatting.parseDecimal(heightCm) }

    var isCurrentStepValid: Bool {
        switch currentStep {
        case 0: return !name.trimmingCharacters(in: .whitespaces).isEmpty
        case 1: return heightDouble.map { (100...250).contains($0) } ?? false
        case 2: return weightValidationMessage == nil && currentWeightDouble != nil && goalWeightDouble != nil
        case 3: return goalDate > Date()
        default: return true
        }
    }

    /// Explains why the weights can't be accepted yet, or nil when they're fine.
    var weightValidationMessage: String? {
        guard let cw = currentWeightDouble, let gw = goalWeightDouble else { return nil }
        if !(30...300).contains(cw) || !(30...300).contains(gw) { return "Enter weights between 30 and 300 kg." }
        if gw >= cw { return "Your goal should be below your current weight." }
        if let height = heightDouble, CalorieCalculator.bmi(weightKg: gw, heightCm: height) < 18.5 {
            return "That goal would be underweight for your height (BMI under 18.5). Please choose a healthier goal."
        }
        return nil
    }

    var estimatedCalories: Int {
        guard let cw = currentWeightDouble, let gw = goalWeightDouble else { return 1800 }
        return CalorieCalculator.calculateDailyTarget(
            currentWeight: cw,
            goalWeight: gw,
            goalDate: goalDate,
            activityLevel: activityLevel.rawValue,
            heightCm: heightDouble ?? 170,
            age: age,
            isMale: sex == .male
        )
    }

    var weightToLose: Double {
        max(0, (currentWeightDouble ?? 0) - (goalWeightDouble ?? 0))
    }

    /// kg per week the chosen date would require
    var requiredWeeklyLoss: Double {
        let weeks = max(1, goalDate.timeIntervalSinceNow / (7 * 86400))
        return weightToLose / weeks
    }

    /// A date that needs about 0.5 kg/week, a sustainable pace
    var recommendedGoalDate: Date {
        let weeks = max(4, weightToLose / 0.5)
        return Date().addingTimeInterval(weeks * 7 * 86400)
    }

    func nextStep() {
        guard isCurrentStepValid else { return }
        if currentStep == 2 && goalDate < recommendedGoalDate.addingTimeInterval(-60 * 86400) {
            // Suggest a realistic date instead of the generic 3-month default
            goalDate = recommendedGoalDate
        }
        if currentStep < totalSteps - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep += 1
            }
            Haptics.selection()
        }
    }

    func previousStep() {
        if currentStep > 0 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep -= 1
            }
        }
    }

    func completeOnboarding(modelContext: ModelContext) {
        guard let cw = currentWeightDouble, let gw = goalWeightDouble else { return }
        isCompleting = true
        let profile = UserProfile(
            name: name.trimmingCharacters(in: .whitespaces),
            currentWeight: cw,
            goalWeight: gw,
            goalDate: goalDate,
            activityLevel: activityLevel.rawValue,
            sex: sex,
            age: age,
            heightCm: heightDouble ?? 170
        )
        profile.onboardingCompleted = true
        modelContext.insert(profile)
        modelContext.insert(WeightLog(date: Date(), weightKg: cw))
        modelContext.saveOrLog()
        Haptics.success()

        Task {
            await NotificationManager.shared.requestAuthorization()
            NotificationManager.shared.applyPreferences(from: profile)
        }
        isCompleting = false
    }
}
