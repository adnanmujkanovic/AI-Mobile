import Foundation
import SwiftData
import Testing
@testable import FitDrop

@MainActor
struct WorkoutTimingTests {
    let vm = WorkoutViewModel()
    let clock = TestClock()

    static let treadmill = TreadmillWorkout(
        name: "Test Run",
        type: .steadyState,
        durationMinutes: 3,
        description: "",
        intervals: [
            WorkoutInterval(name: "Warm-up", durationSeconds: 60, speedKmh: 5, incline: 0, zone: .easy),
            WorkoutInterval(name: "Run", durationSeconds: 120, speedKmh: 8, incline: 0, zone: .tempo),
        ],
        estimatedCaloriesPerKg: 3
    )

    static let mat = MatWorkout(
        name: "Test Mat",
        category: .core,
        exercises: [
            MatExercise(name: "Plank", category: .core, sets: 2, reps: 0, restSeconds: 30, description: "", cueIcon: "figure.core.training"),
            MatExercise(name: "Crunch", category: .core, sets: 1, reps: 10, restSeconds: 30, description: "", cueIcon: "figure.core.training"),
        ],
        estimatedMinutes: 5,
        estimatedCalories: 50
    )

    init() {
        vm.now = { [clock] in clock.date }
    }

    @Test func elapsedAndIntervalFollowTheClock() {
        vm.startTreadmillSession(Self.treadmill)
        clock.advance(45)
        vm.tick()

        #expect(vm.sessionElapsedSeconds == 45)
        #expect(vm.intervalRemainingSeconds == 15)
    }

    @Test func timeWhileSuspendedIsCounted() {
        vm.startTreadmillSession(Self.treadmill)
        // No ticks for 10 minutes, as when the app is in the background
        clock.advance(600)
        vm.tick()

        #expect(vm.sessionElapsedSeconds == 600)
        #expect(vm.intervalRemainingSeconds == 0)
    }

    @Test func pauseFreezesSessionAndInterval() {
        vm.startTreadmillSession(Self.treadmill)
        clock.advance(10)
        vm.pauseSession()
        clock.advance(100)
        vm.tick()

        #expect(vm.isPaused)
        #expect(vm.sessionElapsedSeconds == 10)
        #expect(vm.intervalRemainingSeconds == 50)

        vm.resumeSession()
        clock.advance(5)
        vm.tick()

        #expect(vm.sessionElapsedSeconds == 15)
        #expect(vm.intervalRemainingSeconds == 45)
    }

    @Test func nextIntervalStartsFullCountdown() {
        vm.startTreadmillSession(Self.treadmill)
        clock.advance(20)
        vm.nextInterval()
        clock.advance(30)
        vm.tick()

        #expect(vm.currentIntervalIndex == 1)
        #expect(vm.intervalRemainingSeconds == 90)
        #expect(vm.sessionElapsedSeconds == 50)
    }

    @Test func restCountsDownAndSurvivesPause() throws {
        let context = try Self.makeContext()
        vm.startMatSession(Self.mat)
        vm.completeSet(modelContext: context, userWeightKg: 70)

        #expect(vm.isResting)
        #expect(vm.restRemainingSeconds == 30)

        clock.advance(10)
        vm.tick()
        #expect(vm.restRemainingSeconds == 20)

        vm.pauseSession()
        clock.advance(100)
        vm.resumeSession()
        clock.advance(19)
        vm.tick()
        #expect(vm.isResting)
        #expect(vm.restRemainingSeconds == 1)

        clock.advance(1)
        vm.tick()
        #expect(!vm.isResting)
        #expect(vm.restRemainingSeconds == 0)
    }

    @Test func newRestReplacesRunningRest() throws {
        let context = try Self.makeContext()
        vm.startMatSession(Self.mat)
        vm.completeSet(modelContext: context, userWeightKg: 70) // 30s rest between sets
        clock.advance(20)
        vm.completeSet(modelContext: context, userWeightKg: 70) // 60s rest before next exercise
        clock.advance(10)
        vm.tick()

        #expect(vm.currentExerciseIndex == 1)
        #expect(vm.restRemainingSeconds == 50)
    }

    @Test func endSessionSavesElapsedDuration() throws {
        let context = try Self.makeContext()
        vm.startTreadmillSession(Self.treadmill)
        clock.advance(125)
        vm.endSession(modelContext: context, userWeightKg: 70)

        let saved = try context.fetch(FetchDescriptor<WorkoutSession>())
        #expect(saved.count == 1)
        #expect(saved.first?.duration == 125)
        #expect(saved.first?.completed == true)
        #expect(vm.sessionCompleted)
    }

    private static func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: WorkoutSession.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }
}

@MainActor
final class TestClock {
    var date = Date(timeIntervalSinceReferenceDate: 0)

    func advance(_ seconds: TimeInterval) {
        date.addTimeInterval(seconds)
    }
}
