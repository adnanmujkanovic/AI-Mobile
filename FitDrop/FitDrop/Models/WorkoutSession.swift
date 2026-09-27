import Foundation
import SwiftData

@Model
final class WorkoutSession {
    var id: UUID = UUID()
    var date: Date = Date()
    var workoutName: String = ""
    var workoutType: String = "mat"
    var duration: Int = 0
    var estimatedCalories: Int = 0
    var completed: Bool = false
    var notes: String = ""

    init(workoutName: String, workoutType: String, duration: Int, estimatedCalories: Int) {
        self.id = UUID()
        self.date = Date()
        self.workoutName = workoutName
        self.workoutType = workoutType
        self.duration = duration
        self.estimatedCalories = estimatedCalories
        self.completed = false
        self.notes = ""
    }
}

// MARK: - Static Workout Data

struct TreadmillWorkout: Identifiable {
    let id = UUID()
    let name: String
    let type: TreadmillWorkoutType
    let durationMinutes: Int
    let description: String
    let intervals: [WorkoutInterval]
    let estimatedCaloriesPerKg: Double

    var estimatedCalories: Int {
        Int(70 * estimatedCaloriesPerKg)
    }
}

enum TreadmillWorkoutType: String {
    case speedIntervals = "Speed Intervals"
    case steadyState = "Steady State"
    case inclineWalk = "Incline Walk"
}

struct WorkoutInterval: Identifiable {
    let id = UUID()
    let name: String
    let durationSeconds: Int
    let speedKmh: Double
    let incline: Double
    let zone: SpeedZone
}

enum SpeedZone: String, CaseIterable {
    case easy = "Easy"
    case tempo = "Tempo"
    case interval = "Interval"
    case walk = "Walk"
    case rest = "Rest"

    /// 0–1 effort level, used for the height of the intensity map
    var intensity: Double {
        switch self {
        case .rest: return 0.1
        case .walk: return 0.3
        case .easy: return 0.55
        case .tempo: return 0.8
        case .interval: return 1.0
        }
    }

    var speedRange: String {
        switch self {
        case .easy: return "6–7 km/h"
        case .tempo: return "8–9 km/h"
        case .interval: return "10–11 km/h"
        case .walk: return "4–5 km/h"
        case .rest: return "—"
        }
    }

    var color: String {
        switch self {
        case .easy: return "green"
        case .tempo: return "orange"
        case .interval: return "red"
        case .walk: return "blue"
        case .rest: return "gray"
        }
    }
}

struct MatExercise: Identifiable {
    let id = UUID()
    let name: String
    let category: MatExerciseCategory
    let sets: Int
    let reps: Int
    let restSeconds: Int
    let description: String
    let cueIcon: String
}

enum MatExerciseCategory: String {
    case core = "Core"
    case lower = "Lower Body"
    case upper = "Upper Body"
    case fullBody = "Full Body"
}

struct MatWorkout: Identifiable {
    let id = UUID()
    let name: String
    let category: MatExerciseCategory
    let exercises: [MatExercise]
    let estimatedMinutes: Int
    let estimatedCalories: Int
}

// MARK: - Workout Library Data

struct WorkoutLibrary {
    static let treadmillWorkouts: [TreadmillWorkout] = [
        TreadmillWorkout(
            name: "Easy 5K",
            type: .steadyState,
            durationMinutes: 35,
            description: "Comfortable steady-state run at easy pace. Build your base.",
            intervals: [
                WorkoutInterval(name: "Warm-up Walk", durationSeconds: 300, speedKmh: 5.0, incline: 0, zone: .walk),
                WorkoutInterval(name: "Easy Run", durationSeconds: 1800, speedKmh: 6.5, incline: 0, zone: .easy),
                WorkoutInterval(name: "Cool-down Walk", durationSeconds: 300, speedKmh: 4.5, incline: 0, zone: .walk)
            ],
            estimatedCaloriesPerKg: 4.5
        ),
        TreadmillWorkout(
            name: "Interval Blast",
            type: .speedIntervals,
            durationMinutes: 30,
            description: "Alternating high-intensity bursts with recovery walks. Burns maximum calories.",
            intervals: [
                WorkoutInterval(name: "Warm-up", durationSeconds: 300, speedKmh: 5.0, incline: 0, zone: .walk),
                WorkoutInterval(name: "Sprint", durationSeconds: 60, speedKmh: 10.5, incline: 0, zone: .interval),
                WorkoutInterval(name: "Recovery", durationSeconds: 90, speedKmh: 5.5, incline: 0, zone: .walk),
                WorkoutInterval(name: "Sprint", durationSeconds: 60, speedKmh: 10.5, incline: 0, zone: .interval),
                WorkoutInterval(name: "Recovery", durationSeconds: 90, speedKmh: 5.5, incline: 0, zone: .walk),
                WorkoutInterval(name: "Sprint", durationSeconds: 60, speedKmh: 11.0, incline: 0, zone: .interval),
                WorkoutInterval(name: "Recovery", durationSeconds: 90, speedKmh: 5.5, incline: 0, zone: .walk),
                WorkoutInterval(name: "Sprint", durationSeconds: 60, speedKmh: 11.0, incline: 0, zone: .interval),
                WorkoutInterval(name: "Recovery", durationSeconds: 90, speedKmh: 5.5, incline: 0, zone: .walk),
                WorkoutInterval(name: "Sprint", durationSeconds: 60, speedKmh: 10.5, incline: 0, zone: .interval),
                WorkoutInterval(name: "Recovery", durationSeconds: 90, speedKmh: 5.5, incline: 0, zone: .walk),
                WorkoutInterval(name: "Sprint", durationSeconds: 60, speedKmh: 10.5, incline: 0, zone: .interval),
                WorkoutInterval(name: "Cool-down", durationSeconds: 300, speedKmh: 4.5, incline: 0, zone: .walk)
            ],
            estimatedCaloriesPerKg: 5.8
        ),
        TreadmillWorkout(
            name: "Tempo Run",
            type: .steadyState,
            durationMinutes: 28,
            description: "Comfortably hard pace to build speed and endurance.",
            intervals: [
                WorkoutInterval(name: "Warm-up", durationSeconds: 300, speedKmh: 5.5, incline: 0, zone: .walk),
                WorkoutInterval(name: "Tempo Run", durationSeconds: 1200, speedKmh: 8.5, incline: 0, zone: .tempo),
                WorkoutInterval(name: "Easy Jog", durationSeconds: 180, speedKmh: 6.5, incline: 0, zone: .easy),
                WorkoutInterval(name: "Tempo Run", durationSeconds: 600, speedKmh: 8.0, incline: 0, zone: .tempo),
                WorkoutInterval(name: "Cool-down", durationSeconds: 300, speedKmh: 4.5, incline: 0, zone: .walk)
            ],
            estimatedCaloriesPerKg: 5.2
        ),
        TreadmillWorkout(
            name: "Fat Burn Incline Walk",
            type: .inclineWalk,
            durationMinutes: 40,
            description: "High-incline walking targets fat burning without joint stress.",
            intervals: [
                WorkoutInterval(name: "Flat Walk", durationSeconds: 300, speedKmh: 5.0, incline: 0, zone: .walk),
                WorkoutInterval(name: "Incline Walk 6%", durationSeconds: 600, speedKmh: 5.5, incline: 6, zone: .walk),
                WorkoutInterval(name: "Incline Walk 8%", durationSeconds: 600, speedKmh: 5.0, incline: 8, zone: .walk),
                WorkoutInterval(name: "Incline Walk 10%", durationSeconds: 600, speedKmh: 4.5, incline: 10, zone: .walk),
                WorkoutInterval(name: "Incline Walk 8%", durationSeconds: 600, speedKmh: 5.0, incline: 8, zone: .walk),
                WorkoutInterval(name: "Cool-down", durationSeconds: 300, speedKmh: 4.0, incline: 0, zone: .walk)
            ],
            estimatedCaloriesPerKg: 4.2
        ),
        TreadmillWorkout(
            name: "Pyramid Intervals",
            type: .speedIntervals,
            durationMinutes: 35,
            description: "Speed progressively increases then decreases. Great for speed development.",
            intervals: [
                WorkoutInterval(name: "Warm-up", durationSeconds: 300, speedKmh: 5.0, incline: 0, zone: .walk),
                WorkoutInterval(name: "Easy", durationSeconds: 120, speedKmh: 6.5, incline: 0, zone: .easy),
                WorkoutInterval(name: "Tempo", durationSeconds: 120, speedKmh: 8.5, incline: 0, zone: .tempo),
                WorkoutInterval(name: "Interval", durationSeconds: 120, speedKmh: 10.5, incline: 0, zone: .interval),
                WorkoutInterval(name: "Recovery", durationSeconds: 180, speedKmh: 5.5, incline: 0, zone: .walk),
                WorkoutInterval(name: "Interval", durationSeconds: 120, speedKmh: 10.5, incline: 0, zone: .interval),
                WorkoutInterval(name: "Tempo", durationSeconds: 120, speedKmh: 8.5, incline: 0, zone: .tempo),
                WorkoutInterval(name: "Easy", durationSeconds: 120, speedKmh: 6.5, incline: 0, zone: .easy),
                WorkoutInterval(name: "Recovery", durationSeconds: 180, speedKmh: 5.5, incline: 0, zone: .walk),
                WorkoutInterval(name: "Easy", durationSeconds: 120, speedKmh: 7.0, incline: 0, zone: .easy),
                WorkoutInterval(name: "Tempo", durationSeconds: 120, speedKmh: 9.0, incline: 0, zone: .tempo),
                WorkoutInterval(name: "Interval", durationSeconds: 120, speedKmh: 11.0, incline: 0, zone: .interval),
                WorkoutInterval(name: "Cool-down", durationSeconds: 300, speedKmh: 4.5, incline: 0, zone: .walk)
            ],
            estimatedCaloriesPerKg: 5.5
        )
    ]

    static let matWorkouts: [MatWorkout] = [
        MatWorkout(
            name: "Core Crusher",
            category: .core,
            exercises: [
                MatExercise(name: "Plank", category: .core, sets: 3, reps: 0, restSeconds: 30, description: "Hold plank position, body straight. Keep core braced.", cueIcon: "figure.core.training"),
                MatExercise(name: "Dead Bug", category: .core, sets: 3, reps: 10, restSeconds: 30, description: "Extend opposite arm and leg while lower back stays pressed to floor.", cueIcon: "figure.core.training"),
                MatExercise(name: "Russian Twist", category: .core, sets: 3, reps: 20, restSeconds: 30, description: "Seated, feet elevated, rotate torso side to side.", cueIcon: "figure.core.training"),
                MatExercise(name: "Bicycle Crunch", category: .core, sets: 3, reps: 20, restSeconds: 30, description: "Alternate elbow to opposite knee in cycling motion.", cueIcon: "figure.core.training"),
                MatExercise(name: "Mountain Climbers", category: .core, sets: 3, reps: 20, restSeconds: 45, description: "High plank, drive knees to chest alternating rapidly.", cueIcon: "figure.run")
            ],
            estimatedMinutes: 20,
            estimatedCalories: 180
        ),
        MatWorkout(
            name: "Lower Body Burn",
            category: .lower,
            exercises: [
                MatExercise(name: "Bodyweight Squat", category: .lower, sets: 4, reps: 15, restSeconds: 45, description: "Feet shoulder-width apart, squat until thighs are parallel.", cueIcon: "figure.strengthtraining.functional"),
                MatExercise(name: "Reverse Lunge", category: .lower, sets: 3, reps: 12, restSeconds: 45, description: "Step back into lunge, back knee hovers above floor.", cueIcon: "figure.walk"),
                MatExercise(name: "Glute Bridge", category: .lower, sets: 3, reps: 15, restSeconds: 30, description: "Feet flat on floor, drive hips up squeezing glutes at top.", cueIcon: "figure.flexibility"),
                MatExercise(name: "Sumo Squat", category: .lower, sets: 3, reps: 15, restSeconds: 45, description: "Wide stance, toes out, squat deep activating inner thighs.", cueIcon: "figure.strengthtraining.functional"),
                MatExercise(name: "Single-Leg Glute Bridge", category: .lower, sets: 3, reps: 12, restSeconds: 30, description: "One leg extended, drive through planted heel.", cueIcon: "figure.flexibility")
            ],
            estimatedMinutes: 25,
            estimatedCalories: 220
        ),
        MatWorkout(
            name: "Upper Body Strength",
            category: .upper,
            exercises: [
                MatExercise(name: "Push-Up", category: .upper, sets: 4, reps: 10, restSeconds: 60, description: "Hands shoulder-width, lower chest to near floor, press back up.", cueIcon: "figure.strengthtraining.traditional"),
                MatExercise(name: "Wide Push-Up", category: .upper, sets: 3, reps: 10, restSeconds: 45, description: "Hands wider than shoulders, targets chest.", cueIcon: "figure.strengthtraining.traditional"),
                MatExercise(name: "Diamond Push-Up", category: .upper, sets: 3, reps: 8, restSeconds: 45, description: "Hands close together forming diamond, targets triceps.", cueIcon: "figure.strengthtraining.traditional"),
                MatExercise(name: "Pike Push-Up", category: .upper, sets: 3, reps: 8, restSeconds: 60, description: "Hips high, lower head toward floor between hands.", cueIcon: "figure.strengthtraining.traditional"),
                MatExercise(name: "Tricep Dip (Chair)", category: .upper, sets: 3, reps: 12, restSeconds: 45, description: "Hands on chair behind you, lower and press body up.", cueIcon: "figure.strengthtraining.traditional")
            ],
            estimatedMinutes: 22,
            estimatedCalories: 200
        ),
        MatWorkout(
            name: "Full Body Circuit",
            category: .fullBody,
            exercises: [
                MatExercise(name: "Burpee", category: .fullBody, sets: 3, reps: 10, restSeconds: 60, description: "Squat down, jump feet back, push-up, jump feet forward, leap up.", cueIcon: "figure.run"),
                MatExercise(name: "Jump Squat", category: .fullBody, sets: 3, reps: 12, restSeconds: 45, description: "Squat then explode upward, land softly.", cueIcon: "figure.run"),
                MatExercise(name: "Plank to Push-Up", category: .fullBody, sets: 3, reps: 10, restSeconds: 45, description: "From forearm plank, press up to high plank one arm at a time.", cueIcon: "figure.core.training"),
                MatExercise(name: "Lunge Jump", category: .fullBody, sets: 3, reps: 10, restSeconds: 60, description: "Lunge then switch legs in the air.", cueIcon: "figure.run"),
                MatExercise(name: "High Knees", category: .fullBody, sets: 3, reps: 30, restSeconds: 30, description: "Run in place driving knees to hip height.", cueIcon: "figure.run")
            ],
            estimatedMinutes: 25,
            estimatedCalories: 280
        ),
        MatWorkout(
            name: "Glute & Core",
            category: .lower,
            exercises: [
                MatExercise(name: "Glute Bridge Hold", category: .lower, sets: 3, reps: 0, restSeconds: 30, description: "Hold bridge position, squeeze glutes for 30 seconds.", cueIcon: "figure.flexibility"),
                MatExercise(name: "Donkey Kick", category: .lower, sets: 3, reps: 15, restSeconds: 30, description: "On all fours, kick leg back and up, squeeze glute at top.", cueIcon: "figure.flexibility"),
                MatExercise(name: "Fire Hydrant", category: .lower, sets: 3, reps: 15, restSeconds: 30, description: "On all fours, raise knee out to the side.", cueIcon: "figure.flexibility"),
                MatExercise(name: "Plank Hip Dip", category: .core, sets: 3, reps: 20, restSeconds: 30, description: "Forearm plank, rotate hips side to side.", cueIcon: "figure.core.training"),
                MatExercise(name: "Side Plank", category: .core, sets: 3, reps: 0, restSeconds: 30, description: "Hold side plank 30 seconds each side.", cueIcon: "figure.core.training")
            ],
            estimatedMinutes: 22,
            estimatedCalories: 190
        )
    ]
}
