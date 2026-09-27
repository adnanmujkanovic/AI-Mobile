import Foundation
import SwiftData
import Testing
@testable import FitDrop

@MainActor
struct RunningPlanTests {
    let context: ModelContext
    let vm = RunningPlanViewModel()

    init() throws {
        context = try TestSupport.makeContext()
    }

    private var runs: [RunSession] { (try? context.fetch(FetchDescriptor<RunSession>())) ?? [] }

    @Test func nextSessionFollowsCompletion() throws {
        let first = try #require(RunningPlanData.plan.first?.sessions.first)
        #expect(vm.nextSession(allSessions: runs)?.sessionNumber == first.sessionNumber)
        #expect(vm.currentWeek(allSessions: runs) == 1)

        vm.completeSession(first, modelContext: context)
        #expect(vm.isSessionCompleted(first, allSessions: runs))
        #expect(vm.nextSession(allSessions: runs)?.sessionNumber == first.sessionNumber + 1)
    }

    @Test func uncompletingRemovesTheRun() throws {
        let first = try #require(RunningPlanData.plan.first?.sessions.first)
        vm.completeSession(first, modelContext: context)
        vm.uncompleteSession(first, allSessions: runs, modelContext: context)

        #expect(!vm.isSessionCompleted(first, allSessions: runs))
        #expect(runs.isEmpty)
    }

    @Test func customRunsDontAffectPlanProgress() {
        vm.logCustomRun(distanceKm: 7.5, durationMinutes: 45, date: Date(), modelContext: context)

        #expect(vm.overallProgress(allSessions: runs) == 0)
        #expect(vm.customRuns(allSessions: runs).count == 1)
        #expect(vm.totalDistanceRun(allSessions: runs) == 7.5)
        #expect(vm.runningStreak(allSessions: runs) == 1)
    }

    @Test func invalidCustomRunIsIgnored() {
        vm.logCustomRun(distanceKm: 0, durationMinutes: 30, date: Date(), modelContext: context)
        #expect(runs.isEmpty)
    }
}
