import SwiftUI
import SwiftData

@MainActor
class OnboardingViewModel: ObservableObject {
    @Published var currentStep: Int = 0
    @Published var name: String = ""
    @Published var currentWeight: String = ""
    @Published var goalWeight: String = ""
    @Published var goalDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    @Published var activityLevel: ActivityLevel = .lightlyActive
    @Published var isCompleting: Bool = false

    let totalSteps = 4

    var currentWeightDouble: Double { Double(currentWeight) ?? 0 }
    var goalWeightDouble: Double { Double(goalWeight) ?? 0 }

    var isCurrentStepValid: Bool {
        switch currentStep {
        case 0: return !name.trimmingCharacters(in: .whitespaces).isEmpty
        case 1:
            guard let cw = Double(currentWeight), let gw = Double(goalWeight) else { return false }
            return cw > 0 && gw > 0 && cw > gw
        case 2: return goalDate > Date()
        case 3: return true
        default: return true
        }
    }

    var estimatedCalories: Int {
        guard let cw = Double(currentWeight), let gw = Double(goalWeight), cw > 0, gw > 0 else {
            return 1800
        }
        return CalorieCalculator.calculateDailyTarget(
            currentWeight: cw,
            goalWeight: gw,
            goalDate: goalDate,
            activityLevel: activityLevel.rawValue
        )
    }

    var weightToLose: Double {
        let cw = Double(currentWeight) ?? 0
        let gw = Double(goalWeight) ?? 0
        return max(0, cw - gw)
    }

    func nextStep() {
        if currentStep < totalSteps - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep += 1
            }
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
        guard let cw = Double(currentWeight), let gw = Double(goalWeight) else { return }
        isCompleting = true
        let profile = UserProfile(
            name: name.trimmingCharacters(in: .whitespaces),
            currentWeight: cw,
            goalWeight: gw,
            goalDate: goalDate,
            activityLevel: activityLevel.rawValue
        )
        profile.onboardingCompleted = true
        modelContext.insert(profile)
        // Also insert initial weight log
        let initialWeight = WeightLog(date: Date(), weightKg: cw)
        modelContext.insert(initialWeight)
        try? modelContext.save()

        Task {
            await NotificationManager.shared.requestAuthorization()
            NotificationManager.shared.scheduleFoodLoggingReminder()
            NotificationManager.shared.scheduleWorkoutReminder()
        }
        isCompleting = false
    }
}
