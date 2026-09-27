import SwiftUI
import SwiftData

@MainActor
class RunningPlanViewModel: ObservableObject {
    @Published var expandedWeek: Int? = nil

    func completeSession(_ session: RunPlanSession, modelContext: ModelContext) {
        let runSession = RunSession(
            planWeek: session.week,
            planDay: session.dayOfWeek,
            planSessionIndex: session.sessionNumber,
            distanceKm: session.distanceKm,
            durationMinutes: session.durationMinutes,
            paceZone: session.paceZone.rawValue
        )
        runSession.completed = true
        runSession.completedDate = Date()
        modelContext.insert(runSession)
        modelContext.saveOrLog()
        Haptics.success()
        saveToHealth(runSession)
    }

    /// Removes the completion of a plan session, e.g. when it was ticked by mistake.
    func uncompleteSession(_ session: RunPlanSession, allSessions: [RunSession], modelContext: ModelContext) {
        allSessions
            .filter { $0.planSessionIndex == session.sessionNumber }
            .forEach { modelContext.delete($0) }
        modelContext.saveOrLog()
    }

    /// Logs a run that isn't part of the plan.
    func logCustomRun(distanceKm: Double, durationMinutes: Int, date: Date, modelContext: ModelContext) {
        guard distanceKm > 0, durationMinutes > 0 else { return }
        let run = RunSession(
            planWeek: 0,
            planDay: 0,
            planSessionIndex: RunSession.customRunIndex,
            distanceKm: distanceKm,
            durationMinutes: durationMinutes,
            paceZone: PaceZone.easy.rawValue
        )
        run.date = date
        run.completed = true
        run.completedDate = date
        modelContext.insert(run)
        modelContext.saveOrLog()
        Haptics.success()
        saveToHealth(run)
    }

    private func saveToHealth(_ run: RunSession) {
        let end = run.completedDate ?? Date()
        let start = end.addingTimeInterval(-Double(run.durationMinutes) * 60)
        // Running costs roughly 1 kcal per kg per km; use a 70 kg default when weight is unknown
        HealthKitManager.shared.saveWorkout(
            name: "Run",
            isRun: true,
            start: start,
            end: end,
            calories: run.distanceKm * 70,
            distanceKm: run.distanceKm
        )
    }

    func isSessionCompleted(_ session: RunPlanSession, allSessions: [RunSession]) -> Bool {
        allSessions.contains { $0.planSessionIndex == session.sessionNumber && $0.completed }
    }

    func completedSessionsForWeek(_ week: Int, allSessions: [RunSession]) -> Int {
        let weekSessions = RunningPlanData.plan.first { $0.weekNumber == week }?.sessions ?? []
        return weekSessions.filter { isSessionCompleted($0, allSessions: allSessions) }.count
    }

    func totalSessionsForWeek(_ week: Int) -> Int {
        RunningPlanData.plan.first { $0.weekNumber == week }?.sessions.count ?? 0
    }

    func overallProgress(allSessions: [RunSession]) -> Double {
        let all = RunningPlanData.plan.flatMap { $0.sessions }
        let completed = all.filter { isSessionCompleted($0, allSessions: allSessions) }.count
        return all.isEmpty ? 0 : Double(completed) / Double(all.count)
    }

    /// The first plan session not yet done, to highlight as "up next".
    func nextSession(allSessions: [RunSession]) -> RunPlanSession? {
        RunningPlanData.plan.flatMap { $0.sessions }.first { !isSessionCompleted($0, allSessions: allSessions) }
    }

    /// The week containing the next session, expanded by default.
    func currentWeek(allSessions: [RunSession]) -> Int {
        nextSession(allSessions: allSessions)?.week ?? RunningPlanData.plan.last?.weekNumber ?? 1
    }

    func totalDistanceRun(allSessions: [RunSession]) -> Double {
        allSessions.filter { $0.completed }.reduce(0) { $0 + $1.distanceKm }
    }

    /// Consecutive weeks with at least one run. Runs aren't daily, so days would always break.
    func runningStreak(allSessions: [RunSession]) -> Int {
        Streaks.consecutiveWeeks(allSessions.filter { $0.completed }.map { $0.completedDate ?? $0.date })
    }

    func completedDays(allSessions: [RunSession]) -> Set<Date> {
        Set(allSessions.filter { $0.completed }.map { Calendar.current.startOfDay(for: $0.completedDate ?? $0.date) })
    }

    func customRuns(allSessions: [RunSession]) -> [RunSession] {
        allSessions
            .filter { $0.planSessionIndex == RunSession.customRunIndex }
            .sorted { ($0.completedDate ?? $0.date) > ($1.completedDate ?? $1.date) }
    }
}
