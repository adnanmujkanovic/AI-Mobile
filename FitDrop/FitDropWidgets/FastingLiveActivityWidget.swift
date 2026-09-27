import ActivityKit
import SwiftUI
import WidgetKit

private let brandGreen = Color(red: 0.18, green: 0.80, blue: 0.44)
private let brandBlue = Color(red: 0.20, green: 0.60, blue: 1.0)
private let brandIndigo = Color(red: 0.35, green: 0.34, blue: 0.84)

struct FastingLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FastingActivityAttributes.self) { context in
            FastingLockScreenView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.75))
                .activitySystemActionForegroundColor(brandGreen)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(state.hasEnded ? "Done" : state.isPaused ? "Paused" : "Fasting")
                    } icon: {
                        Image(systemName: "moon.stars.fill").foregroundColor(brandIndigo)
                    }
                    .font(.caption.weight(.semibold))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Goal \(state.plannedHours)h")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }
                DynamicIslandExpandedRegion(.center) {
                    ElapsedText(state: state)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 4) {
                        FastingProgressBar(state: state)
                        GoalCaption(state: state)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: state.hasEnded ? "checkmark.circle.fill" : "moon.stars.fill")
                    .foregroundColor(state.hasEnded ? brandGreen : brandIndigo)
            } compactTrailing: {
                ElapsedText(state: state, compact: true)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .frame(maxWidth: 56)
                    .foregroundColor(brandGreen)
            } minimal: {
                Image(systemName: "moon.stars.fill")
                    .foregroundColor(brandIndigo)
            }
        }
    }
}

struct FastingLockScreenView: View {
    let state: FastingActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(title, systemImage: state.hasEnded ? "checkmark.seal.fill" : "moon.stars.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(state.hasEnded ? brandGreen : .white)
                Spacer()
                Text("FitDrop")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.6))
            }
            HStack(alignment: .firstTextBaseline) {
                ElapsedText(state: state)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                Spacer()
                GoalCaption(state: state)
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.trailing)
            }
            FastingProgressBar(state: state)
        }
        .padding(16)
    }

    private var title: String {
        if state.hasEnded { return "Fast finished" }
        return state.isPaused ? "Fast paused" : "\(state.plannedHours)h fast"
    }
}

/// Counts up live without app updates; frozen while paused or after the fast ends.
struct ElapsedText: View {
    let state: FastingActivityAttributes.ContentState
    var compact = false

    var body: some View {
        if state.isPaused || state.hasEnded {
            Text(FastingActivityAttributes.ContentState.formatElapsed(state.frozenElapsed))
        } else {
            Text(timerInterval: state.effectiveStart...Date.distantFuture, countsDown: false, showsHours: true)
                .multilineTextAlignment(compact ? .trailing : .leading)
        }
    }
}

struct GoalCaption: View {
    let state: FastingActivityAttributes.ContentState

    var body: some View {
        if state.hasEnded {
            Text("Great work!")
        } else if state.isPaused {
            Text("Resume in FitDrop")
        } else if state.goalDate > Date() {
            Text("Goal at \(state.goalDate, style: .time)")
        } else {
            Text("Goal reached 🎉")
        }
    }
}

struct FastingProgressBar: View {
    let state: FastingActivityAttributes.ContentState

    var body: some View {
        Group {
            if state.isPaused || state.hasEnded || state.goalDate <= state.effectiveStart {
                ProgressView(value: state.hasEnded ? max(state.progressAtFreeze, 0.001) : state.progressAtFreeze)
            } else {
                // Advances on its own between the start and the goal
                ProgressView(timerInterval: state.effectiveStart...state.goalDate, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
            }
        }
        .progressViewStyle(.linear)
        .tint(LinearGradient(colors: [brandGreen, brandBlue], startPoint: .leading, endPoint: .trailing))
    }
}
