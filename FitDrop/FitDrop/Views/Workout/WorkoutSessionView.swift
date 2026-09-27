import SwiftUI
import SwiftData

struct WorkoutSessionView: View {
    @ObservedObject var vm: WorkoutViewModel
    let userWeightKg: Double
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showEndDialog = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if vm.sessionCompleted {
                SessionCompletionView(vm: vm) {
                    dismiss()
                }
            } else if vm.selectedTreadmillWorkout != nil {
                TreadmillSessionView(vm: vm, userWeightKg: userWeightKg)
            } else if vm.selectedMatWorkout != nil {
                MatSessionView(vm: vm, userWeightKg: userWeightKg)
            }

            if !vm.sessionCompleted {
                VStack {
                    HStack {
                        CircleIconButton(icon: "xmark", label: "End workout") {
                            showEndDialog = true
                        }
                        Spacer()
                        VStack(spacing: 0) {
                            Text(vm.formattedSessionTime)
                                .font(.system(.title2, design: .monospaced, weight: .semibold))
                                .foregroundColor(.white)
                                .monospacedDigit()
                            if vm.isPaused {
                                Text("PAUSED")
                                    .font(.fdCaption2.weight(.bold))
                                    .foregroundColor(.fdOrange)
                                    .tracking(2)
                            }
                        }
                        Spacer()
                        CircleIconButton(icon: vm.isPaused ? "play.fill" : "pause.fill", label: vm.isPaused ? "Resume" : "Pause") {
                            if vm.isPaused { vm.resumeSession() } else { vm.pauseSession() }
                            Haptics.tap()
                        }
                    }
                    .padding(.horizontal, FDSpacing.lg)
                    .padding(.top, FDSpacing.lg)
                    Spacer()
                }
            }
        }
        .confirmationDialog("End workout?", isPresented: $showEndDialog, titleVisibility: .visible) {
            Button("Save & End") {
                vm.endSession(modelContext: modelContext, userWeightKg: userWeightKg)
            }
            Button("Discard Workout", role: .destructive) {
                vm.cancelSession()
                dismiss()
            }
            Button("Keep Going", role: .cancel) {}
        } message: {
            Text("Saving records \(vm.formattedSessionTime) and the calories for the time you trained.")
        }
        // Keep the screen on while training
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}

struct CircleIconButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundColor(.white)
                .frame(width: 48, height: 48)
                .background(.white.opacity(0.2))
                .clipShape(Circle())
        }
        .accessibilityLabel(label)
    }
}

// MARK: - Treadmill Session

struct TreadmillSessionView: View {
    @ObservedObject var vm: WorkoutViewModel
    let userWeightKg: Double
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: FDSpacing.xl) {
            Spacer()

            if vm.treadmillFinished {
                VStack(spacing: FDSpacing.md) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 64))
                        .foregroundStyle(LinearGradient.fdPrimary)
                    Text("All intervals done!")
                        .font(.fdTitle)
                        .foregroundColor(.white)
                    Text("Walk it out, then save your workout.")
                        .font(.fdSubheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                SessionPrimaryButton(title: "Finish Workout", icon: "checkmark") {
                    vm.endSession(modelContext: modelContext, userWeightKg: userWeightKg)
                }
            } else if let interval = vm.currentInterval {
                VStack(spacing: FDSpacing.sm) {
                    FDBadge(text: interval.zone.rawValue, color: interval.zone.swiftUIColor)
                    Text(interval.name)
                        .font(.fdTitle)
                        .foregroundColor(.white)
                }

                ZStack {
                    Circle()
                        .stroke(interval.zone.swiftUIColor.opacity(0.3), lineWidth: 16)
                        .frame(width: 220, height: 220)
                    Circle()
                        .trim(from: 0, to: interval.durationSeconds > 0
                              ? CGFloat(vm.intervalRemainingSeconds) / CGFloat(interval.durationSeconds)
                              : 0)
                        .stroke(interval.zone.swiftUIColor, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                        .frame(width: 220, height: 220)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.5), value: vm.intervalRemainingSeconds)
                    VStack(spacing: 4) {
                        Text(String(format: "%.1f", interval.speedKmh))
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("km/h")
                            .font(.fdSubheadline)
                            .foregroundColor(.white.opacity(0.7))
                        if interval.incline > 0 {
                            Text("\(Int(interval.incline))% incline")
                                .font(.fdCaption)
                                .foregroundColor(.fdOrange)
                        }
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(interval.name), \(String(format: "%.1f", interval.speedKmh)) kilometers per hour" + (interval.incline > 0 ? ", \(Int(interval.incline)) percent incline" : ""))

                Text(formatSeconds(vm.intervalRemainingSeconds))
                    .font(.system(.largeTitle, design: .monospaced, weight: .medium))
                    .foregroundColor(.white)
                    .monospacedDigit()
                    .accessibilityLabel("\(vm.intervalRemainingSeconds) seconds left in this interval")

                if let next = vm.nextIntervalPreview {
                    Text("Next: \(next.name) · \(String(format: "%.1f", next.speedKmh)) km/h")
                        .font(.fdSubheadline)
                        .foregroundColor(.white.opacity(0.7))
                }

                if let workout = vm.selectedTreadmillWorkout {
                    HStack(spacing: 6) {
                        ForEach(Array(workout.intervals.enumerated()), id: \.element.id) { idx, iv in
                            Circle()
                                .fill(idx < vm.currentIntervalIndex
                                      ? iv.zone.swiftUIColor
                                      : idx == vm.currentIntervalIndex
                                      ? .white
                                      : .white.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .accessibilityLabel("Interval \(vm.currentIntervalIndex + 1) of \(workout.intervals.count)")
                }

                Button {
                    vm.nextInterval()
                } label: {
                    HStack {
                        Text(vm.nextIntervalPreview == nil ? "Finish Intervals" : "Skip Interval")
                        Image(systemName: "forward.fill")
                    }
                    .font(.fdHeadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, FDSpacing.xl)
                    .frame(height: 52)
                    .background(interval.zone.swiftUIColor.opacity(0.3))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(interval.zone.swiftUIColor, lineWidth: 1))
                }
            }

            Spacer()
        }
        .padding(.top, 60)
    }

    func formatSeconds(_ s: Int) -> String {
        String(format: "%02d:%02d", s / 60, s % 60)
    }
}

struct SessionPrimaryButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .font(.fdHeadline)
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.fdGreen)
            .clipShape(RoundedRectangle(cornerRadius: FDRadius.lg))
        }
        .padding(.horizontal, FDSpacing.xl)
    }
}

// MARK: - Mat Session

struct MatSessionView: View {
    @ObservedObject var vm: WorkoutViewModel
    let userWeightKg: Double
    @Environment(\.modelContext) private var modelContext

    static let holdSeconds = 30

    var body: some View {
        VStack(spacing: FDSpacing.xl) {
            Spacer()

            if vm.isResting {
                VStack(spacing: FDSpacing.lg) {
                    Text("REST")
                        .font(.fdTitle2)
                        .foregroundColor(.fdGreen)
                        .tracking(4)

                    ZStack {
                        Circle()
                            .stroke(Color.fdGreen.opacity(0.3), lineWidth: 12)
                            .frame(width: 160, height: 160)
                        Text("\(vm.restRemainingSeconds)")
                            .font(.system(size: 60, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .monospacedDigit()
                    }
                    .accessibilityLabel("\(vm.restRemainingSeconds) seconds of rest left")

                    if let exercise = vm.currentMatExercise {
                        Text("Next: \(exercise.name) · set \(vm.currentSet) of \(exercise.sets)")
                            .font(.fdSubheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Button("Skip Rest") {
                        vm.skipRest()
                        Haptics.tap()
                    }
                    .font(.fdHeadline)
                    .foregroundColor(.fdGreen)
                }
            } else if let exercise = vm.currentMatExercise {
                VStack(spacing: FDSpacing.md) {
                    if let workout = vm.selectedMatWorkout {
                        HStack(spacing: 4) {
                            ForEach(1...exercise.sets, id: \.self) { set in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(set <= vm.currentSet ? Color.fdGreen : Color.white.opacity(0.3))
                                    .frame(height: 6)
                            }
                        }
                        .padding(.horizontal, FDSpacing.xl)

                        Text("Exercise \(vm.currentExerciseIndex + 1) of \(workout.exercises.count)")
                            .font(.fdCaption)
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Image(systemName: exercise.cueIcon)
                        .font(.system(size: 72))
                        .foregroundStyle(LinearGradient.fdPrimary)
                        .padding(FDSpacing.lg)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                        .accessibilityHidden(true)

                    VStack(spacing: FDSpacing.sm) {
                        Text(exercise.name)
                            .font(.fdTitle)
                            .foregroundColor(.white)
                        Text("Set \(vm.currentSet) of \(exercise.sets)")
                            .font(.fdSubheadline)
                            .foregroundColor(.fdGreen)
                        if exercise.reps > 0 {
                            Text("\(exercise.reps) reps")
                                .font(.system(size: 52, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        } else if vm.isHolding {
                            Text("\(vm.holdRemainingSeconds)s")
                                .font(.system(size: 52, weight: .bold, design: .rounded))
                                .foregroundColor(.fdGreen)
                                .monospacedDigit()
                        } else {
                            Button {
                                vm.startHold(seconds: Self.holdSeconds)
                            } label: {
                                Label("Start \(Self.holdSeconds)s hold", systemImage: "timer")
                                    .font(.fdTitle3)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, FDSpacing.lg)
                                    .frame(height: 52)
                                    .background(Color.white.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    Text(exercise.description)
                        .font(.fdSubheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, FDSpacing.xl)

                    SessionPrimaryButton(title: isLastSet ? "Finish Workout" : "Done", icon: "checkmark") {
                        vm.stopHold()
                        vm.completeSet(modelContext: modelContext, userWeightKg: userWeightKg)
                        Haptics.tap()
                    }
                }
            }

            Spacer()
        }
        .padding(.top, 60)
    }

    private var isLastSet: Bool {
        guard let workout = vm.selectedMatWorkout, let exercise = vm.currentMatExercise else { return false }
        return vm.currentExerciseIndex == workout.exercises.count - 1 && vm.currentSet == exercise.sets
    }
}

// MARK: - Completion

struct SessionCompletionView: View {
    @ObservedObject var vm: WorkoutViewModel
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: FDSpacing.xl) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundStyle(LinearGradient.fdPrimary)

            VStack(spacing: FDSpacing.sm) {
                Text("Workout Complete!")
                    .font(.fdLargeTitle)
                    .foregroundColor(.white)
                Text("Great work. Every session counts.")
                    .font(.fdBody)
                    .foregroundColor(.white.opacity(0.7))
            }

            HStack(spacing: FDSpacing.lg) {
                CompletionStat(
                    icon: "clock.fill",
                    value: vm.formattedSessionTime,
                    label: "Duration",
                    color: .fdBlue
                )
                CompletionStat(
                    icon: "flame.fill",
                    value: "~\(vm.totalCaloriesBurned)",
                    label: "Calories",
                    color: .fdOrange
                )
            }

            Spacer()

            Button {
                onDismiss()
            } label: {
                Text("Done")
                    .font(.fdHeadline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(LinearGradient.fdPrimary)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: FDRadius.lg))
            }
            .padding(.horizontal, FDSpacing.xl)
            .padding(.bottom, FDSpacing.xl)
        }
    }
}

struct CompletionStat: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: FDSpacing.sm) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(value)
                .font(.fdTitle2)
                .foregroundColor(.white)
            Text(label)
                .font(.fdCaption)
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(FDSpacing.lg)
        .background(color.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: FDRadius.md))
    }
}
