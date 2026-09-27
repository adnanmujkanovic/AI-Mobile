import Foundation
import SwiftData

@Model
final class RunSession {
    var id: UUID = UUID()
    var date: Date = Date()
    var planWeek: Int = 1
    var planDay: Int = 1
    var planSessionIndex: Int = 0
    var distanceKm: Double = 5.0
    var durationMinutes: Int = 35
    var paceZone: String = "easy"
    var completed: Bool = false
    var completedDate: Date? = nil
    var notes: String = ""

    init(planWeek: Int, planDay: Int, planSessionIndex: Int, distanceKm: Double, durationMinutes: Int, paceZone: String) {
        self.id = UUID()
        self.date = Date()
        self.planWeek = planWeek
        self.planDay = planDay
        self.planSessionIndex = planSessionIndex
        self.distanceKm = distanceKm
        self.durationMinutes = durationMinutes
        self.paceZone = paceZone
        self.completed = false
        self.notes = ""
    }
}

@Model
final class WeightLog {
    var id: UUID = UUID()
    var date: Date = Date()
    var weightKg: Double = 0.0
    var notes: String = ""

    init(date: Date, weightKg: Double, notes: String = "") {
        self.id = UUID()
        self.date = date
        self.weightKg = weightKg
        self.notes = notes
    }
}

// MARK: - Running Plan Data

struct RunPlanSession: Identifiable {
    let id = UUID()
    let week: Int
    let dayOfWeek: Int
    let sessionNumber: Int
    let distanceKm: Double
    let durationMinutes: Int
    let paceZone: PaceZone
    let sessionType: RunSessionType
    let description: String
}

enum PaceZone: String, CaseIterable {
    case easy = "Easy"
    case tempo = "Tempo"
    case interval = "Interval"
    case long = "Long"

    var speedKmh: String {
        switch self {
        case .easy: return "6–7 km/h"
        case .tempo: return "8–9 km/h"
        case .interval: return "10–11 km/h"
        case .long: return "5.5–6.5 km/h"
        }
    }

    var color: String {
        switch self {
        case .easy: return "green"
        case .tempo: return "orange"
        case .interval: return "red"
        case .long: return "blue"
        }
    }
}

enum RunSessionType: String {
    case easy = "Easy Run"
    case interval = "Interval"
    case tempo = "Tempo"
    case long = "Long Run"
    case rest = "Rest"
}

struct RunWeek: Identifiable {
    let id = UUID()
    let weekNumber: Int
    let title: String
    let focus: String
    let daysPerWeek: Int
    let sessions: [RunPlanSession]
}

struct RunningPlanData {
    static let plan: [RunWeek] = [
        RunWeek(
            weekNumber: 1,
            title: "Week 1 — Build the Habit",
            focus: "Easy pace 5K runs — build the habit",
            daysPerWeek: 3,
            sessions: [
                RunPlanSession(week: 1, dayOfWeek: 1, sessionNumber: 0, distanceKm: 5.0, durationMinutes: 35, paceZone: .easy, sessionType: .easy, description: "Easy 5K. Run at a comfortable conversational pace. No pressure on speed today."),
                RunPlanSession(week: 1, dayOfWeek: 3, sessionNumber: 1, distanceKm: 5.0, durationMinutes: 34, paceZone: .easy, sessionType: .easy, description: "Another easy 5K. Focus on breathing rhythm and relaxed form."),
                RunPlanSession(week: 1, dayOfWeek: 5, sessionNumber: 2, distanceKm: 5.0, durationMinutes: 33, paceZone: .easy, sessionType: .easy, description: "End-of-week run. Try to feel slightly more comfortable than Monday.")
            ]
        ),
        RunWeek(
            weekNumber: 2,
            title: "Week 2 — Introduce Speed",
            focus: "Introduce 1 interval session",
            daysPerWeek: 4,
            sessions: [
                RunPlanSession(week: 2, dayOfWeek: 1, sessionNumber: 3, distanceKm: 5.0, durationMinutes: 33, paceZone: .easy, sessionType: .easy, description: "Easy 5K to start the week. Legs should feel fresher now."),
                RunPlanSession(week: 2, dayOfWeek: 2, sessionNumber: 4, distanceKm: 4.0, durationMinutes: 28, paceZone: .interval, sessionType: .interval, description: "First interval session! 4×400m at hard pace with 2min recovery walks between. Push yourself."),
                RunPlanSession(week: 2, dayOfWeek: 4, sessionNumber: 5, distanceKm: 5.0, durationMinutes: 32, paceZone: .easy, sessionType: .easy, description: "Easy recovery run. Nice and relaxed after the intervals."),
                RunPlanSession(week: 2, dayOfWeek: 6, sessionNumber: 6, distanceKm: 5.5, durationMinutes: 36, paceZone: .easy, sessionType: .easy, description: "Slightly longer weekend run. Add 500m to your route.")
            ]
        ),
        RunWeek(
            weekNumber: 3,
            title: "Week 3 — Add Tempo",
            focus: "Add tempo run, increase weekly distance",
            daysPerWeek: 4,
            sessions: [
                RunPlanSession(week: 3, dayOfWeek: 1, sessionNumber: 7, distanceKm: 5.0, durationMinutes: 32, paceZone: .easy, sessionType: .easy, description: "Easy 5K opener. Pace should feel comfortable now."),
                RunPlanSession(week: 3, dayOfWeek: 2, sessionNumber: 8, distanceKm: 5.0, durationMinutes: 30, paceZone: .tempo, sessionType: .tempo, description: "Tempo run — comfortably hard. Hold 8–9 km/h for the middle 20 minutes. 5min warm-up/cool-down."),
                RunPlanSession(week: 3, dayOfWeek: 4, sessionNumber: 9, distanceKm: 4.5, durationMinutes: 26, paceZone: .interval, sessionType: .interval, description: "6×400m intervals at 10–11 km/h. 90 second recovery walk between each."),
                RunPlanSession(week: 3, dayOfWeek: 6, sessionNumber: 10, distanceKm: 6.0, durationMinutes: 40, paceZone: .easy, sessionType: .easy, description: "Longest run so far — 6K at easy pace. Take your time.")
            ]
        ),
        RunWeek(
            weekNumber: 4,
            title: "Week 4 — Full Build",
            focus: "One long run (6K+), one interval, structured rest days",
            daysPerWeek: 5,
            sessions: [
                RunPlanSession(week: 4, dayOfWeek: 1, sessionNumber: 11, distanceKm: 5.0, durationMinutes: 30, paceZone: .easy, sessionType: .easy, description: "Week kickoff easy run. Feel the consistency you've built."),
                RunPlanSession(week: 4, dayOfWeek: 2, sessionNumber: 12, distanceKm: 5.0, durationMinutes: 28, paceZone: .tempo, sessionType: .tempo, description: "Tempo effort. Push to sustain 8.5 km/h for 20 continuous minutes."),
                RunPlanSession(week: 4, dayOfWeek: 3, sessionNumber: 13, distanceKm: 4.5, durationMinutes: 25, paceZone: .interval, sessionType: .interval, description: "Intense intervals — 8×400m. You're stronger now. Push each one."),
                RunPlanSession(week: 4, dayOfWeek: 5, sessionNumber: 14, distanceKm: 5.0, durationMinutes: 30, paceZone: .easy, sessionType: .easy, description: "Easy Friday run. Shake out the legs before the big one."),
                RunPlanSession(week: 4, dayOfWeek: 6, sessionNumber: 15, distanceKm: 6.5, durationMinutes: 42, paceZone: .long, sessionType: .long, description: "The long run! 6.5K at comfortable pace. This is your achievement run.")
            ]
        )
    ]
}
