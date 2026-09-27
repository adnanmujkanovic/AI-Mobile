import SwiftUI
import SwiftData

// MARK: - Treadmill Workout Detail

struct TreadmillWorkoutDetailView: View {
    let workout: TreadmillWorkout
    @ObservedObject var vm: WorkoutViewModel
    let userWeight: Double
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showSession = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FDSpacing.lg) {
                    // Header Card
                    VStack(spacing: FDSpacing.md) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(workout.name)
                                    .font(.fdTitle)
                                Text(workout.type.rawValue)
                                    .font(.fdSubheadline)
                                    .foregroundColor(.fdSecondaryLabel)
                            }
                            Spacer()
                            Image(systemName: "figure.run")
                                .font(.system(size: 40))
                                .foregroundStyle(LinearGradient.fdPrimary)
                        }
                        Text(workout.description)
                            .font(.fdBody)
                            .foregroundColor(.fdSecondaryLabel)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: FDSpacing.lg) {
                            FDStatCard(
                                title: "Duration",
                                value: "\(workout.durationMinutes)",
                                unit: "min",
                                icon: "clock.fill",
                                color: .fdBlue
                            )
                            FDStatCard(
                                title: "Calories",
                                value: "~\(Int(Double(workout.estimatedCalories) * userWeight / 70))",
                                unit: "kcal",
                                icon: "flame.fill",
                                color: .fdOrange
                            )
                        }
                    }
                    .padding(FDSpacing.md)
                    .fdCard()
                    .padding(.horizontal, FDSpacing.md)

                    // Interval Breakdown
                    VStack(alignment: .leading, spacing: FDSpacing.sm) {
                        FDSectionHeader(title: "Interval Breakdown")
                            .padding(.horizontal, FDSpacing.md)

                        ForEach(Array(workout.intervals.enumerated()), id: \.element.id) { idx, interval in
                            IntervalRow(interval: interval, index: idx + 1)
                                .padding(.horizontal, FDSpacing.md)
                        }
                    }

                    // Visual strip
                    VStack(alignment: .leading, spacing: FDSpacing.sm) {
                        Text("INTENSITY MAP")
                            .font(.fdCaption)
                            .foregroundColor(.fdSecondaryLabel)
                            .tracking(1)
                            .padding(.horizontal, FDSpacing.md)
                        HStack(spacing: 2) {
                            ForEach(workout.intervals) { interval in
                                VStack(spacing: 2) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(interval.zone.swiftUIColor)
                                        .frame(
                                            width: .infinity,
                                            height: CGFloat(interval.durationSeconds) / 60
                                        )
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }
                        .frame(height: 60)
                        .padding(.horizontal, FDSpacing.md)
                    }

                    // Start Button
                    FDPrimaryButton("Start Workout", icon: "play.fill") {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            vm.startTreadmillSession(workout)
                            showSession = true
                        }
                    }
                    .padding(.horizontal, FDSpacing.md)
                    .padding(.bottom, FDSpacing.xl)
                }
                .padding(.top, FDSpacing.md)
            }
            .navigationTitle("Workout Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .fullScreenCover(isPresented: $showSession) {
            WorkoutSessionView(vm: vm, userWeightKg: userWeight)
                .environment(\.modelContext, modelContext)
        }
    }
}

struct IntervalRow: View {
    let interval: WorkoutInterval
    let index: Int

    var body: some View {
        HStack(spacing: FDSpacing.md) {
            Text("\(index)")
                .font(.fdCaption)
                .foregroundColor(.fdSecondaryLabel)
                .frame(width: 24)

            Circle()
                .fill(interval.zone.swiftUIColor)
                .frame(width: 10, height: 10)

            Text(interval.name)
                .font(.fdSubheadline)
                .foregroundColor(.fdLabel)

            Spacer()

            Text(interval.zone.speedRange)
                .font(.fdCaption)
                .foregroundColor(.fdSecondaryLabel)

            Text(formatDuration(interval.durationSeconds))
                .font(.fdCaption)
                .foregroundColor(.fdSecondaryLabel)
                .frame(width: 50, alignment: .trailing)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, FDSpacing.md)
        .background(Color.fdSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: FDRadius.sm))
    }

    func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return s == 0 ? "\(m)m" : "\(m)m\(s)s"
    }
}

// MARK: - Mat Workout Detail

struct MatWorkoutDetailView: View {
    let workout: MatWorkout
    @ObservedObject var vm: WorkoutViewModel
    let userWeight: Double
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showSession = false

    var categoryColor: Color {
        switch workout.category {
        case .core: return .fdOrange
        case .lower: return .fdGreen
        case .upper: return .fdBlue
        case .fullBody: return .fdPurple
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FDSpacing.lg) {
                    // Header
                    VStack(spacing: FDSpacing.md) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(workout.name)
                                    .font(.fdTitle)
                                FDBadge(text: workout.category.rawValue, color: categoryColor)
                            }
                            Spacer()
                            Image(systemName: "figure.strengthtraining.functional")
                                .font(.system(size: 40))
                                .foregroundColor(categoryColor)
                        }
                        HStack(spacing: FDSpacing.lg) {
                            FDStatCard(title: "Duration", value: "\(workout.estimatedMinutes)", unit: "min", icon: "clock.fill", color: .fdBlue)
                            FDStatCard(title: "Calories", value: "~\(workout.estimatedCalories)", unit: "kcal", icon: "flame.fill", color: .fdOrange)
                        }
                    }
                    .padding(FDSpacing.md)
                    .fdCard()
                    .padding(.horizontal, FDSpacing.md)

                    // Exercises
                    VStack(alignment: .leading, spacing: FDSpacing.sm) {
                        FDSectionHeader(title: "Exercises")
                            .padding(.horizontal, FDSpacing.md)

                        ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { idx, exercise in
                            ExerciseRow(exercise: exercise, index: idx + 1, color: categoryColor)
                                .padding(.horizontal, FDSpacing.md)
                        }
                    }

                    FDPrimaryButton("Start Workout", icon: "play.fill") {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            vm.startMatSession(workout)
                            showSession = true
                        }
                    }
                    .padding(.horizontal, FDSpacing.md)
                    .padding(.bottom, FDSpacing.xl)
                }
                .padding(.top, FDSpacing.md)
            }
            .navigationTitle("Workout Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .fullScreenCover(isPresented: $showSession) {
            WorkoutSessionView(vm: vm, userWeightKg: userWeight)
                .environment(\.modelContext, modelContext)
        }
    }
}

struct ExerciseRow: View {
    let exercise: MatExercise
    let index: Int
    let color: Color

    var setDescription: String {
        if exercise.reps == 0 {
            return "\(exercise.sets) × 30s"
        }
        return "\(exercise.sets) × \(exercise.reps)"
    }

    var body: some View {
        HStack(spacing: FDSpacing.md) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Text("\(index)")
                    .font(.fdSubheadline)
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.fdSubheadline)
                    .foregroundColor(.fdLabel)
                Text(exercise.description)
                    .font(.fdCaption)
                    .foregroundColor(.fdSecondaryLabel)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(setDescription)
                    .font(.fdSubheadline)
                    .foregroundColor(.fdLabel)
                Text("rest \(exercise.restSeconds)s")
                    .font(.fdCaption)
                    .foregroundColor(.fdSecondaryLabel)
            }
        }
        .padding(FDSpacing.md)
        .fdCard()
    }
}
