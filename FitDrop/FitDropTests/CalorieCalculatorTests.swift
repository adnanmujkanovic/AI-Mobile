import Foundation
import Testing
@testable import FitDrop

struct CalorieCalculatorTests {
    private func daysFromNow(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: Date())!
    }

    @Test func deficitIsCappedAt750() {
        // Female, 100 kg, 170 cm, 30 y: BMR = 1000 + 1062.5 − 150 − 161 = 1751.5
        let tdee = 1751.5 * ActivityLevel.moderatelyActive.multiplier
        let target = CalorieCalculator.calculateDailyTarget(
            currentWeight: 100,
            goalWeight: 60,
            goalDate: daysFromNow(60),
            activityLevel: ActivityLevel.moderatelyActive.rawValue
        )

        #expect(target == Int(tdee - 750))
    }

    @Test func smallGoalUsesProportionalDeficit() {
        // 1 kg over 77 days = 100 kcal/day
        let tdee = 1751.5 * ActivityLevel.sedentary.multiplier
        let target = CalorieCalculator.calculateDailyTarget(
            currentWeight: 100,
            goalWeight: 99,
            goalDate: daysFromNow(77),
            activityLevel: ActivityLevel.sedentary.rawValue
        )

        #expect(abs(target - Int(tdee - 100)) <= 3)
    }

    @Test func targetNeverDropsBelow1200() {
        let target = CalorieCalculator.calculateDailyTarget(
            currentWeight: 45,
            goalWeight: 35,
            goalDate: daysFromNow(30),
            activityLevel: ActivityLevel.sedentary.rawValue
        )

        #expect(target == 1200)
    }
}
