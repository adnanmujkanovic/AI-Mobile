import ActivityKit
import Foundation

/// Shared between the app, which starts the Live Activity, and the widget extension, which draws it.
struct FastingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Start time shifted by pauses, so a timer counting from here shows fasting time
        var effectiveStart: Date
        var goalDate: Date
        var plannedHours: Int
        var isPaused: Bool
        /// Fasting time frozen at the moment of pausing or ending
        var frozenElapsed: TimeInterval
        var hasEnded: Bool
    }

    var fastID: String
}

extension FastingActivityAttributes.ContentState {
    var progressAtFreeze: Double {
        let goal = Double(plannedHours) * 3600
        return goal > 0 ? min(1, frozenElapsed / goal) : 0
    }

    static func formatElapsed(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}
