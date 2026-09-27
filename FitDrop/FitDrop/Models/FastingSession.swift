import Foundation
import SwiftData

@Model
final class FastingSession {
    var id: UUID = UUID()
    var startTime: Date = Date()
    var endTime: Date? = nil
    var plannedHours: Int = 16
    var actualHours: Double = 0.0
    var completed: Bool = false
    var brokenEarly: Bool = false
    var isActive: Bool = false
    var isPaused: Bool = false
    var pausedAt: Date? = nil
    var totalPausedSeconds: Double = 0.0

    init(startTime: Date, plannedHours: Int) {
        self.id = UUID()
        self.startTime = startTime
        self.plannedHours = plannedHours
        self.actualHours = 0.0
        self.completed = false
        self.brokenEarly = false
        self.isActive = true
        self.isPaused = false
        self.totalPausedSeconds = 0.0
    }

    var elapsedSeconds: Double {
        guard isActive || completed else { return 0 }
        let end = endTime ?? Date()
        let raw = end.timeIntervalSince(startTime)
        var paused = totalPausedSeconds
        // Include the pause in progress, which isn't folded into totalPausedSeconds until resume
        if isPaused, let pausedAt {
            paused += max(0, end.timeIntervalSince(pausedAt))
        }
        return max(0, raw - paused)
    }

    var elapsedHours: Double {
        elapsedSeconds / 3600.0
    }

    var remainingSeconds: Double {
        let target = Double(plannedHours) * 3600
        return max(0, target - elapsedSeconds)
    }

    /// Ends the fast, folding any in-progress pause into the paused total.
    func end(at end: Date = Date()) {
        if isPaused, let pausedAt {
            totalPausedSeconds += max(0, end.timeIntervalSince(pausedAt))
            isPaused = false
            self.pausedAt = nil
        }
        endTime = end
        actualHours = elapsedHours
        completed = actualHours >= Double(plannedHours)
        brokenEarly = !completed
        isActive = false
    }

    var isFinished: Bool { !isActive && endTime != nil }

    var progressFraction: Double {
        let target = Double(plannedHours) * 3600
        return min(1.0, elapsedSeconds / target)
    }

    /// Start time shifted by all pauses, so `now - effectiveStart` is the fasting time.
    var effectiveStart: Date {
        startTime.addingTimeInterval(totalPausedSeconds)
    }

    /// When the planned duration is reached, assuming no further pauses.
    var goalDate: Date {
        effectiveStart.addingTimeInterval(Double(plannedHours) * 3600)
    }

    var goalReached: Bool { elapsedSeconds >= Double(plannedHours) * 3600 }

    var fastingStage: FastingStage {
        FastingStage.forHours(elapsedHours)
    }
}

enum FastingStage: String, CaseIterable {
    case digestion = "Digestion"
    case fatBurning = "Fat Burning Begins"
    case glucoseDepletion = "Glucose Depletion"
    case ketosis = "Ketosis Zone"
    case autophagy = "Autophagy"
    case deepFast = "Deep Fast"

    var hoursRange: String {
        switch self {
        case .digestion: return "0–4 h"
        case .fatBurning: return "4–8 h"
        case .glucoseDepletion: return "8–12 h"
        case .ketosis: return "12–16 h"
        case .autophagy: return "16–18 h"
        case .deepFast: return "18+ h"
        }
    }

    var description: String {
        switch self {
        case .digestion: return "Your body is digesting your last meal and storing energy."
        case .fatBurning: return "Glucose stores are lowering. Fat burning is starting."
        case .glucoseDepletion: return "Liver glycogen is nearly depleted. Fat is primary fuel."
        case .ketosis: return "Your body has entered fat-burning ketosis mode."
        case .autophagy: return "Cellular clean-up (autophagy) is now active."
        case .deepFast: return "Deep metabolic reset. Maximum autophagy and fat burning."
        }
    }

    var icon: String {
        switch self {
        case .digestion: return "fork.knife"
        case .fatBurning: return "flame.fill"
        case .glucoseDepletion: return "bolt.fill"
        case .ketosis: return "star.fill"
        case .autophagy: return "arrow.clockwise.circle.fill"
        case .deepFast: return "moon.stars.fill"
        }
    }

    var colorName: String {
        switch self {
        case .digestion: return "blue"
        case .fatBurning: return "orange"
        case .glucoseDepletion: return "yellow"
        case .ketosis: return "green"
        case .autophagy: return "purple"
        case .deepFast: return "indigo"
        }
    }
    
    /// Helper function to get stage for a given number of hours
    static func forHours(_ hours: Double) -> FastingStage {
        if hours < 4 { return .digestion }
        if hours < 8 { return .fatBurning }
        if hours < 12 { return .glucoseDepletion }
        if hours < 16 { return .ketosis }
        if hours < 18 { return .autophagy }
        return .deepFast
    }
}
