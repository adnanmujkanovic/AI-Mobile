import SwiftUI
import SwiftData

@MainActor
class RunningPlanViewModel: ObservableObject {
    @Published var expandedWeek: Int? = 1

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
        try? modelContext.save()
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
        let total = RunningPlanData.plan.flatMap { $0.sessions }.count
        let completed = RunningPlanData.plan.flatMap { $0.sessions }.filter {
            isSessionCompleted($0, allSessions: allSessions)
        }.count
        return total > 0 ? Double(completed) / Double(total) : 0
    }

    func totalDistanceRun(allSessions: [RunSession]) -> Double {
        allSessions.filter { $0.completed }.reduce(0) { $0 + $1.distanceKm }
    }

    func runningStreak(allSessions: [RunSession]) -> Int {
        let completed = allSessions.filter { $0.completed && $0.completedDate != nil }
            .sorted { ($0.completedDate ?? Date()) > ($1.completedDate ?? Date()) }
        var streak = 0
        var checkDate = Calendar.current.startOfDay(for: Date())
        for session in completed {
            let day = Calendar.current.startOfDay(for: session.completedDate ?? session.date)
            if day == checkDate || day == Calendar.current.date(byAdding: .day, value: -1, to: checkDate)! {
                streak += 1
                checkDate = day
            } else {
                break
            }
        }
        return streak
    }

    func completedDates(allSessions: [RunSession]) -> Set<String> {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return Set(allSessions.filter { $0.completed }.compactMap {
            $0.completedDate.map { formatter.string(from: $0) }
        })
    }
}
