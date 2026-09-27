import Foundation
import SwiftData
import Testing
@testable import FitDrop

private let hour: TimeInterval = 3600

struct FastingStageTests {
    @Test(arguments: [
        (0.0, FastingStage.digestion),
        (3.99, .digestion),
        (4.0, .fatBurning),
        (8.0, .glucoseDepletion),
        (12.0, .ketosis),
        (16.0, .autophagy),
        (17.99, .autophagy),
        (18.0, .deepFast),
        (30.0, .deepFast),
    ])
    func stageForHours(hours: Double, expected: FastingStage) {
        #expect(FastingStage.forHours(hours) == expected)
    }
}

struct FastingSessionTests {
    @Test func elapsedExcludesCompletedPauses() {
        let fast = FastingSession(startTime: Date().addingTimeInterval(-2 * hour), plannedHours: 16)
        fast.totalPausedSeconds = 0.5 * hour

        #expect(abs(fast.elapsedHours - 1.5) < 0.01)
    }

    @Test func elapsedExcludesPauseInProgress() {
        let fast = FastingSession(startTime: Date().addingTimeInterval(-3 * hour), plannedHours: 16)
        fast.isPaused = true
        fast.pausedAt = Date().addingTimeInterval(-1 * hour)

        #expect(abs(fast.elapsedHours - 2) < 0.01)
        #expect(abs(fast.remainingSeconds - 14 * hour) < 30)
        #expect(fast.fastingStage == .digestion)
    }

    @Test func endedFastWhilePausedUsesEndTime() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let fast = FastingSession(startTime: start, plannedHours: 16)
        fast.totalPausedSeconds = 1 * hour
        fast.isPaused = true
        fast.pausedAt = start.addingTimeInterval(8 * hour)
        fast.endTime = start.addingTimeInterval(10 * hour)

        // 10h wall clock − 1h earlier pause − 2h open pause
        #expect(fast.elapsedHours == 7)
    }
}

@MainActor
struct FastingViewModelTests {
    let context: ModelContext

    init() throws {
        let container = try ModelContainer(
            for: FastingSession.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
    }

    @Test func breakingPausedFastFoldsPauseIntoTotal() {
        let fast = FastingSession(startTime: Date().addingTimeInterval(-3 * hour), plannedHours: 16)
        fast.isPaused = true
        fast.pausedAt = Date().addingTimeInterval(-1 * hour)
        context.insert(fast)

        let vm = FastingViewModel()
        vm.activeFast = fast
        vm.breakFast(modelContext: context)

        #expect(!fast.isPaused)
        #expect(fast.pausedAt == nil)
        #expect(abs(fast.totalPausedSeconds - hour) < 5)
        #expect(abs(fast.actualHours - 2) < 0.01)
        #expect(fast.brokenEarly)
        #expect(!fast.isActive)
        #expect(vm.activeFast == nil)
    }

    @Test func pauseThenResumeAddsPausedTime() {
        let fast = FastingSession(startTime: Date().addingTimeInterval(-3 * hour), plannedHours: 16)
        context.insert(fast)
        let vm = FastingViewModel()
        vm.activeFast = fast

        vm.pauseFast(modelContext: context)
        fast.pausedAt = Date().addingTimeInterval(-1 * hour) // pretend the pause began an hour ago
        vm.resumeFast(modelContext: context)

        #expect(!fast.isPaused)
        #expect(abs(fast.totalPausedSeconds - hour) < 5)
        #expect(abs(fast.elapsedHours - 2) < 0.01)
    }
}

struct FastingSessionLifecycleTests {
    @Test func endMarksGoalReachedOrBroken() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let done = FastingSession(startTime: start, plannedHours: 16)
        done.end(at: start.addingTimeInterval(16.5 * hour))
        #expect(done.completed && !done.brokenEarly && !done.isActive && done.isFinished)
        #expect(done.actualHours == 16.5)

        let broken = FastingSession(startTime: start, plannedHours: 16)
        broken.end(at: start.addingTimeInterval(10 * hour))
        #expect(!broken.completed && broken.brokenEarly && broken.isFinished)
    }

    @Test func goalDateShiftsWithPauses() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let fast = FastingSession(startTime: start, plannedHours: 16)
        fast.totalPausedSeconds = 2 * hour
        #expect(fast.goalDate == start.addingTimeInterval(18 * hour))
    }

    @Test func startTimeIsClamped() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000_000)
        #expect(FastingViewModel.clampedStart(now.addingTimeInterval(3600), now: now) == now)
        #expect(FastingViewModel.clampedStart(now.addingTimeInterval(-100 * hour), now: now) == now.addingTimeInterval(-72 * hour))
    }

    @Test func formatsHours() {
        #expect(FastingViewModel.formatHours(14.0833) == "14h 4m")
        #expect(FastingViewModel.formatHours(0.5) == "30m")
    }

    @Test(arguments: [(13, FastingViewModel.FastingProtocol.thirteen_eleven), (16, .sixteen_eight), (20, .twenty_four), (36, .custom)])
    func protocolMatchesHours(hours: Int, expected: FastingViewModel.FastingProtocol) {
        #expect(FastingViewModel.FastingProtocol.matching(hours: hours) == expected)
    }
}

@MainActor
struct FastingFlowTests {
    let context: ModelContext
    let vm = FastingViewModel()

    init() throws {
        context = try TestSupport.makeContext()
    }

    @Test func startFastRemembersProtocolOnProfile() throws {
        let profile = UserProfile(name: "A", currentWeight: 80, goalWeight: 70, goalDate: Date().addingTimeInterval(90 * 86400), activityLevel: "sedentary")
        context.insert(profile)
        vm.startFast(plannedHours: 18, startTime: Date().addingTimeInterval(-hour), modelContext: context, profile: profile)
        defer { vm.stopTimer() }

        #expect(profile.fastingDuration == 18)
        #expect(profile.fastingProtocol == "18:6")
        let fast = try #require(vm.activeFast)
        #expect(abs(fast.elapsedHours - 1) < 0.01)
    }

    @Test func editingStartTimeMovesElapsed() throws {
        vm.startFast(plannedHours: 16, modelContext: context)
        defer { vm.stopTimer() }
        vm.updateStartTime(Date().addingTimeInterval(-5 * hour), modelContext: context)

        #expect(abs((vm.activeFast?.elapsedHours ?? 0) - 5) < 0.01)
    }

    @Test func brokenFastsCountInWeeklyAverage() {
        let now = Date()
        let broken = FastingSession(startTime: now.addingTimeInterval(-30 * hour), plannedHours: 16)
        broken.end(at: now.addingTimeInterval(-20 * hour))
        let full = FastingSession(startTime: now.addingTimeInterval(-60 * hour), plannedHours: 16)
        full.end(at: now.addingTimeInterval(-44 * hour))

        #expect(abs(vm.weeklyAverageFastingHours(sessions: [broken, full], now: now) - 13) < 0.01)
    }

    @Test func onlyFastsThatReachTheGoalBuildTheStreak() {
        let now = TestSupport.day(0, hour: 15)
        let yesterday = FastingSession(startTime: TestSupport.day(-2, hour: 20, from: now), plannedHours: 16)
        yesterday.end(at: TestSupport.day(-1, hour: 13, from: now))
        let brokenToday = FastingSession(startTime: TestSupport.day(-1, hour: 20, from: now), plannedHours: 16)
        brokenToday.end(at: TestSupport.day(0, hour: 8, from: now))

        #expect(vm.consecutiveStreak(sessions: [yesterday, brokenToday], profile: nil, now: now) == 1)
    }

    @Test func endFromAnotherScreenFinishesFast() {
        let fast = FastingSession(startTime: Date().addingTimeInterval(-17 * hour), plannedHours: 16)
        context.insert(fast)
        FastingViewModel.end(fast, modelContext: context)

        #expect(fast.completed)
        #expect(!fast.isActive)
    }
}
