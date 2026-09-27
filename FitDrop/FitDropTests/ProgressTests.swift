import Foundation
import SwiftData
import Testing
@testable import FitDrop

struct StreakTests {
    let now = TestSupport.day(0, hour: 15)

    @Test func countsConsecutiveDaysEndingToday() {
        let dates = [0, -1, -2, -4].map { TestSupport.day($0, from: now) }
        #expect(Streaks.consecutiveDays(dates, now: now) == 3)
    }

    @Test func streakEndingYesterdayStillCounts() {
        let dates = [-1, -2].map { TestSupport.day($0, from: now) }
        #expect(Streaks.consecutiveDays(dates, now: now) == 2)
    }

    @Test func gapBeforeYesterdayBreaksStreak() {
        let dates = [-2, -3].map { TestSupport.day($0, from: now) }
        #expect(Streaks.consecutiveDays(dates, now: now) == 0)
    }

    @Test func multipleEntriesPerDayCountOnce() {
        let dates = [TestSupport.day(0, hour: 8, from: now), TestSupport.day(0, hour: 20, from: now), TestSupport.day(-1, from: now)]
        #expect(Streaks.consecutiveDays(dates, now: now) == 2)
    }

    @Test func countsConsecutiveWeeks() {
        let dates = [0, -7, -14, -28].map { TestSupport.day($0, from: now) }
        #expect(Streaks.consecutiveWeeks(dates, now: now) == 3)
        #expect(Streaks.consecutiveWeeks([], now: now) == 0)
    }
}

struct TargetTests {
    @Test func maleFloorIs1500() {
        let target = CalorieCalculator.calculateDailyTarget(
            currentWeight: 50, goalWeight: 40, goalDate: Date().addingTimeInterval(30 * 86400),
            activityLevel: "sedentary", heightCm: 160, age: 60, isMale: true
        )
        #expect(target == 1500)
    }

    @Test func goalAboveCurrentMeansMaintenanceNotSurplus() {
        let tdee = ((10 * 70.0) + (6.25 * 170) - (5 * 30) - 161) * ActivityLevel.sedentary.multiplier
        let target = CalorieCalculator.calculateDailyTarget(
            currentWeight: 70, goalWeight: 75, goalDate: Date().addingTimeInterval(90 * 86400),
            activityLevel: "sedentary"
        )
        #expect(target == Int(tdee))
    }

    @Test func proteinAndWaterDefaults() {
        #expect(CalorieCalculator.proteinTarget(goalWeightKg: 70) == 112)
        #expect(CalorieCalculator.waterTarget(weightKg: 80) == 2750)
        #expect(CalorieCalculator.waterTarget(weightKg: 30) == 1500)
        #expect(CalorieCalculator.waterTarget(weightKg: 200) == 4000)
    }

    @Test func profileUsesCustomValuesWhenSet() {
        let profile = UserProfile(name: "A", currentWeight: 90, goalWeight: 75, goalDate: Date().addingTimeInterval(120 * 86400), activityLevel: "lightly_active", sex: .male, age: 40, heightCm: 180)
        #expect(profile.effectiveProteinGoalG == 120)
        profile.proteinGoalG = 150
        profile.waterGoalMl = 3000
        #expect(profile.effectiveProteinGoalG == 150)
        #expect(profile.effectiveWaterGoalMl == 3000)

        let automatic = profile.dailyCalorieTarget
        profile.useCustomCalorieTarget = true
        profile.dailyCalorieTarget = 2100
        profile.currentWeight = 85
        profile.recalculateCalorieTarget()
        #expect(profile.dailyCalorieTarget == 2100)
        #expect(automatic != 2100)
    }

    @Test func profileRecordsStartWeightAndSexAffectsTarget() {
        let date = Date().addingTimeInterval(120 * 86400)
        let female = UserProfile(name: "F", currentWeight: 80, goalWeight: 70, goalDate: date, activityLevel: "sedentary", sex: .female, age: 35, heightCm: 170)
        let male = UserProfile(name: "M", currentWeight: 80, goalWeight: 70, goalDate: date, activityLevel: "sedentary", sex: .male, age: 35, heightCm: 170)
        #expect(female.startWeight == 80)
        // Mifflin-St Jeor adds 166 kcal to BMR for men, before the activity multiplier
        #expect(male.dailyCalorieTarget > female.dailyCalorieTarget)
    }
}

@MainActor
struct WeightTests {
    let context: ModelContext
    let vm = DashboardViewModel()

    init() throws {
        context = try TestSupport.makeContext()
    }

    private func makeProfile() -> UserProfile {
        let profile = UserProfile(name: "A", currentWeight: 90, goalWeight: 80, goalDate: Date().addingTimeInterval(200 * 86400), activityLevel: "sedentary")
        context.insert(profile)
        return profile
    }

    @Test func loggingWeightUpdatesProfileAndTarget() throws {
        let profile = makeProfile()
        let before = profile.dailyCalorieTarget
        vm.weightInput = "86,5"

        let log = try #require(vm.logWeight(modelContext: context, profile: profile, existingLogs: []))

        #expect(log.weightKg == 86.5)
        #expect(profile.currentWeight == 86.5)
        // Less left to lose by the same date means a smaller deficit, so the target is recalculated
        let expected = CalorieCalculator.calculateDailyTarget(
            currentWeight: 86.5, goalWeight: 80, goalDate: profile.goalDate, activityLevel: "sedentary"
        )
        #expect(profile.dailyCalorieTarget == expected)
        #expect(profile.dailyCalorieTarget != before)
        #expect(vm.weightInput.isEmpty)
    }

    @Test func rejectsImplausibleWeights() {
        let profile = makeProfile()
        vm.weightInput = "5"
        #expect(vm.logWeight(modelContext: context, profile: profile, existingLogs: []) == nil)
        vm.weightInput = "abc"
        #expect(vm.logWeight(modelContext: context, profile: profile, existingLogs: []) == nil)
    }

    @Test func backdatedWeightDoesNotReplaceNewerOne() throws {
        let profile = makeProfile()
        let recent = WeightLog(date: Date(), weightKg: 88)
        context.insert(recent)
        vm.weightInput = "91"
        vm.weightDate = TestSupport.day(-3)
        _ = vm.logWeight(modelContext: context, profile: profile, existingLogs: [recent])

        #expect(profile.currentWeight == 88)
    }

    @Test func deletingLatestWeightFallsBackToPrevious() throws {
        let profile = makeProfile()
        let older = WeightLog(date: TestSupport.day(-2), weightKg: 89)
        let newest = WeightLog(date: Date(), weightKg: 87)
        context.insert(older)
        context.insert(newest)
        profile.currentWeight = 87

        vm.deleteWeight(newest, allLogs: [older, newest], profile: profile, modelContext: context)

        #expect(profile.currentWeight == 89)
        #expect(try context.fetchCount(FetchDescriptor<WeightLog>()) == 1)
    }

    @Test func projectsGoalDateFromTrend() throws {
        let now = Date()
        // Losing 0.1 kg per day for 20 days: 90 → 88
        let logs = (0...20).map { WeightLog(date: now.addingTimeInterval(Double($0 - 20) * 86400), weightKg: 90 - Double($0) * 0.1) }
        let date = try #require(DashboardViewModel.projectedGoalDate(logs: logs, goalWeight: 85, now: now))
        let days = date.timeIntervalSince(now) / 86400

        #expect(abs(days - 30) < 1)
        #expect(abs((DashboardViewModel.weeklyRate(logs: logs, now: now) ?? 0) + 0.7) < 0.01)
    }

    @Test func noProjectionWhenGainingOrTooFewLogs() {
        let now = Date()
        let gaining = (0...10).map { WeightLog(date: now.addingTimeInterval(Double($0 - 10) * 86400), weightKg: 80 + Double($0) * 0.1) }
        #expect(DashboardViewModel.projectedGoalDate(logs: gaining, goalWeight: 75, now: now) == nil)
        #expect(DashboardViewModel.projectedGoalDate(logs: Array(gaining.prefix(2)), goalWeight: 75, now: now) == nil)
    }

    @Test func waterAddAndUndo() throws {
        vm.addWater(250, modelContext: context)
        vm.addWater(500, modelContext: context)
        var logs = try context.fetch(FetchDescriptor<WaterLog>())
        #expect(logs.reduce(0) { $0 + $1.amountMl } == 750)

        vm.undoLastWater(todayLogs: logs, modelContext: context)
        logs = try context.fetch(FetchDescriptor<WaterLog>())
        #expect(logs.count == 1)
    }
}

@MainActor
struct ExportTests {
    @Test func escapesCSVFields() {
        #expect(DataExporter.csvEscape("plain") == "plain")
        #expect(DataExporter.csvEscape("a,b") == "\"a,b\"")
        #expect(DataExporter.csvEscape("say \"hi\"") == "\"say \"\"hi\"\"\"")
    }

    @Test func exportsOneFilePerDataType() throws {
        let context = try TestSupport.makeContext()
        context.insert(FoodEntry(name: "Soup, tomato", calories: 80, protein: 2, carbs: 10, fat: 3))
        context.insert(WeightLog(date: Date(), weightKg: 80))
        try context.save()

        let files = try DataExporter.export(context: context)
        #expect(files.map(\.lastPathComponent).sorted() == ["fasting.csv", "food.csv", "runs.csv", "water.csv", "weight.csv", "workouts.csv"])
        let food = try String(contentsOf: try #require(files.first { $0.lastPathComponent == "food.csv" }), encoding: .utf8)
        #expect(food.contains("\"Soup, tomato\""))
    }
}
