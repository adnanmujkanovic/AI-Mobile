import SwiftUI
import SwiftData

struct WorkoutSessionView: View {
    @ObservedObject var vm: WorkoutViewModel
    let userWeightKg: Double
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showEndAlert = false

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

            // Top Bar
            if !vm.sessionCompleted {
                VStack {
                    HStack {
                        Button {
                            showEndAlert = true
                        } label: {
                            Image(systemName: "xmark")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(.white.opacity(0.2))
                                .clipShape(Circle())
                        }
                        Spacer()
                        Text(vm.formattedSessionTime)
                            .font(.system(.title2, design: .monospaced, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        Color.clear.frame(width: 44, height: 44)
                    }
                    .padding(.horizontal, FDSpacing.lg)
                    .padding(.top, FDSpacing.lg)
                    Spacer()
                }
            }
        }
        .alert("End Workout?", isPresented: $showEndAlert) {
            Button("Cancel", role: .cancel) {}
            Button("End Session", role: .destructive) {
                vm.endSession(modelContext: modelContext, userWeightKg: userWeightKg)
            }
        } message: {
            Text("Your progress will be saved.")
        }
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

            if let interval = vm.currentInterval {
                // Zone badge
                VStack(spacing: FDSpacing.sm) {
                    FDBadge(text: interval.zone.rawValue, color: interval.zone.swiftUIColor)
                    Text(interval.name)
                        .font(.fdTitle)
                        .foregroundColor(.white)
                }

                // Speed circle
                ZStack {
                    Circle()
                        .stroke(interval.zone.swiftUIColor.opacity(0.3), lineWidth: 16)
                        .frame(width: 200, height: 200)
                    Circle()
                        .trim(from: 0, to: vm.intervalRemainingSeconds > 0
                              ? CGFloat(vm.intervalRemainingSeconds) / CGFloat(interval.durationSeconds)
                              : 0)
                        .stroke(interval.zone.swiftUIColor, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                        .frame(width: 200, height: 200)
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 4) {
                        Text(String(format: "%.1f", interval.speedKmh))
                            .font(.system(size: 52, weight: .bold, design: .rounded))
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

                // Remaining time
                Text(formatSeconds(vm.intervalRemainingSeconds))
                    .font(.system(.title, design: .monospaced, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))

                // Progress dots
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
                }

                // Next interval button
                Button {
                    vm.nextInterval()
                } label: {
                    HStack {
                        Text("Next Interval")
                        Image(systemName: "arrow.right.circle.fill")
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
    }

    func formatSeconds(_ s: Int) -> String {
        let m = s / 60
        let sec = s % 60
        return String(format: "%02d:%02d", m, sec)
    }
}

// MARK: - Mat Session

struct MatSessionView: View {
    @ObservedObject var vm: WorkoutViewModel
    let userWeightKg: Double
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: FDSpacing.xl) {
            Spacer()

            if vm.isResting {
                // Rest screen
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
                    }

                    if let exercise = vm.currentMatExercise {
                        Text("Next: \(exercise.name)")
                            .font(.fdSubheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            } else if let exercise = vm.currentMatExercise {
                // Exercise screen
                VStack(spacing: FDSpacing.md) {
                    // Set counter
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
                        .font(.system(size: 80))
                        .foregroundStyle(LinearGradient.fdPrimary)
                        .padding(FDSpacing.lg)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())

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
                        } else {
                            Text("30 seconds")
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }

                    Text(exercise.description)
                        .font(.fdSubheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, FDSpacing.xl)

                    Button {
                        vm.completeSet(modelContext: modelContext, userWeightKg: userWeightKg)
                    } label: {
                        HStack {
                            Image(systemName: "checkmark")
                            Text("Done")
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

            Spacer()
        }
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
