import ActivityKit
import Foundation

/// Mirrors the active fast on the Lock Screen and in the Dynamic Island.
@MainActor
enum FastingLiveActivity {
    static func state(for fast: FastingSession) -> FastingActivityAttributes.ContentState {
        FastingActivityAttributes.ContentState(
            effectiveStart: fast.effectiveStart,
            goalDate: fast.goalDate,
            plannedHours: fast.plannedHours,
            isPaused: fast.isPaused,
            frozenElapsed: fast.elapsedSeconds,
            hasEnded: !fast.isActive
        )
    }

    static func startOrUpdate(for fast: FastingSession) {
        guard fast.isActive else { return }
        let content = ActivityContent(state: state(for: fast), staleDate: nil)
        var matched = false
        for activity in Activity<FastingActivityAttributes>.activities {
            if activity.attributes.fastID == fast.id.uuidString && !matched {
                matched = true
                Task { await activity.update(content) }
            } else {
                Task { await activity.end(nil, dismissalPolicy: .immediate) }
            }
        }
        guard !matched, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        do {
            _ = try Activity.request(
                attributes: FastingActivityAttributes(fastID: fast.id.uuidString),
                content: content
            )
        } catch {
            print("Live Activity request failed: \(error)")
        }
    }

    /// Shows the result briefly, then removes the activity.
    static func end(finalFast fast: FastingSession?) {
        let finalContent = fast.map { ActivityContent(state: state(for: $0), staleDate: nil) }
        for activity in Activity<FastingActivityAttributes>.activities {
            Task {
                await activity.end(finalContent, dismissalPolicy: .after(Date().addingTimeInterval(15 * 60)))
            }
        }
    }

    /// Ends activities still showing a running fast when no fast is active (e.g. ended on another screen).
    static func endOrphans() {
        for activity in Activity<FastingActivityAttributes>.activities where !activity.content.state.hasEnded {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
