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
