import SwiftUI
import SwiftData

struct WorkoutLibraryView: View {
    @StateObject private var vm = WorkoutViewModel()
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext

    @State private var showTreadmillDetail: TreadmillWorkout? = nil
    @State private var showMatDetail: MatWorkout? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FDSpacing.lg) {
                    // Tab Picker
                    Picker("Workout Type", selection: $vm.selectedTab) {
                        Text("Treadmill").tag(WorkoutViewModel.WorkoutTab.treadmill)
                        Text("Mat").tag(WorkoutViewModel.WorkoutTab.mat)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, FDSpacing.md)

                    // Speed Zones Reference (treadmill only)
                    if vm.selectedTab == .treadmill {
                        SpeedZoneReference()
                            .padding(.horizontal, FDSpacing.md)
                    }

                    // Workout Cards
                    if vm.selectedTab == .treadmill {
                        ForEach(WorkoutLibrary.treadmillWorkouts) { workout in
                            TreadmillWorkoutCard(workout: workout) {
                                showTreadmillDetail = workout
                            }
                            .padding(.horizontal, FDSpacing.md)
                        }
                    } else {
                        ForEach(WorkoutLibrary.matWorkouts) { workout in
                            MatWorkoutCard(workout: workout) {
                                showMatDetail = workout
                            }
                            .padding(.horizontal, FDSpacing.md)
                        }
                    }
                }
                .padding(.vertical, FDSpacing.md)
            }
            .navigationTitle("Workout Library")
            .sheet(item: $showTreadmillDetail) { workout in
                TreadmillWorkoutDetailView(workout: workout, vm: vm, userWeight: profiles.first?.currentWeight ?? 70)
                    .environment(\.modelContext, modelContext)
            }
            .sheet(item: $showMatDetail) { workout in
                MatWorkoutDetailView(workout: workout, vm: vm, userWeight: profiles.first?.currentWeight ?? 70)
                    .environment(\.modelContext, modelContext)
            }
        }
    }
}

// MARK: - Speed Zone Reference

struct SpeedZoneReference: View {
    var body: some View {
        VStack(alignment: .leading, spacing: FDSpacing.sm) {
            Text("SPEED ZONES")
                .font(.fdCaption)
                .foregroundColor(.fdSecondaryLabel)
                .tracking(1)
            HStack(spacing: FDSpacing.sm) {
                ForEach([SpeedZone.easy, .tempo, .interval], id: \.rawValue) { zone in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(zone.swiftUIColor)
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(zone.rawValue)
                                .font(.fdCaption2)
                                .foregroundColor(.fdLabel)
                            Text(zone.speedRange)
                                .font(.fdCaption2)
                                .foregroundColor(.fdSecondaryLabel)
                        }
                    }
                    .padding(.horizontal, FDSpacing.sm)
                    .padding(.vertical, FDSpacing.xs)
                    .background(zone.swiftUIColor.opacity(0.12))
                    .clipShape(Capsule())
                    if zone != .interval { Spacer() }
                }
            }
        }
        .padding(FDSpacing.md)
        .fdCard()
    }
}

// MARK: - Treadmill Workout Card

struct TreadmillWorkoutCard: View {
    let workout: TreadmillWorkout
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: FDSpacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: FDSpacing.sm) {
                            Image(systemName: "figure.run")
                                .font(.title3)
                                .foregroundColor(.fdGreen)
                            Text(workout.name)
                                .font(.fdHeadline)
                                .foregroundColor(.fdLabel)
                        }
                        Text(workout.type.rawValue)
                            .font(.fdCaption)
                            .foregroundColor(.fdSecondaryLabel)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundColor(.fdTertiaryLabel)
                }

                Text(workout.description)
                    .font(.fdSubheadline)
                    .foregroundColor(.fdSecondaryLabel)
                    .lineLimit(2)

                HStack(spacing: FDSpacing.md) {
                    WorkoutStat(icon: "clock.fill", value: "\(workout.durationMinutes) min", color: .fdBlue)
                    WorkoutStat(icon: "flame.fill", value: "~\(workout.estimatedCalories) kcal", color: .fdOrange)
                    WorkoutStat(icon: "bolt.fill", value: "\(workout.intervals.count) intervals", color: .fdPurple)
                }

                // Interval strip
                HStack(spacing: 2) {
                    ForEach(workout.intervals) { interval in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(interval.zone.swiftUIColor)
                            .frame(height: 6)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(FDSpacing.md)
            .fdCard()
            .fdShadow(radius: 4)
        }
        .buttonStyle(.plain)
    }
}

struct WorkoutStat: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(value)
                .font(.fdCaption)
                .foregroundColor(.fdSecondaryLabel)
        }
    }
}

// MARK: - Mat Workout Card

struct MatWorkoutCard: View {
    let workout: MatWorkout
    let onTap: () -> Void

    var categoryColor: Color {
        switch workout.category {
        case .core: return .fdOrange
        case .lower: return .fdGreen
        case .upper: return .fdBlue
        case .fullBody: return .fdPurple
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: FDSpacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: FDSpacing.sm) {
                            Image(systemName: "figure.strengthtraining.functional")
                                .font(.title3)
                                .foregroundColor(categoryColor)
                            Text(workout.name)
                                .font(.fdHeadline)
                                .foregroundColor(.fdLabel)
                        }
                        FDBadge(text: workout.category.rawValue, color: categoryColor)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundColor(.fdTertiaryLabel)
                }

                HStack(spacing: FDSpacing.md) {
                    WorkoutStat(icon: "clock.fill", value: "\(workout.estimatedMinutes) min", color: .fdBlue)
                    WorkoutStat(icon: "flame.fill", value: "~\(workout.estimatedCalories) kcal", color: .fdOrange)
                    WorkoutStat(icon: "list.bullet", value: "\(workout.exercises.count) exercises", color: .fdGreen)
                }

                // Exercise pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: FDSpacing.xs) {
                        ForEach(workout.exercises) { ex in
                            Text(ex.name)
                                .font(.fdCaption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(categoryColor.opacity(0.1))
                                .foregroundColor(categoryColor)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(FDSpacing.md)
            .fdCard()
            .fdShadow(radius: 4)
        }
        .buttonStyle(.plain)
    }
}
