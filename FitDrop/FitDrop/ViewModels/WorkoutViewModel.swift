import SwiftUI
import SwiftData
import AVFoundation

@MainActor
class WorkoutViewModel: ObservableObject {
    // Library
    @Published var selectedTab: WorkoutTab = .treadmill
    @Published var selectedTreadmillWorkout: TreadmillWorkout? = nil
    @Published var selectedMatWorkout: MatWorkout? = nil

    // Active session
    @Published var isSessionActive: Bool = false
    @Published var sessionElapsedSeconds: Int = 0
    @Published var currentIntervalIndex: Int = 0
    @Published var intervalRemainingSeconds: Int = 0
    @Published var currentExerciseIndex: Int = 0
    @Published var currentSet: Int = 1
    @Published var isResting: Bool = false
    @Published var restRemainingSeconds: Int = 0
    @Published var sessionCompleted: Bool = false
    @Published var totalCaloriesBurned: Int = 0

    private var sessionTimer: Timer? = nil
    private var restTimer: Timer? = nil
    private var audioPlayer: AVAudioPlayer? = nil

    enum WorkoutTab { case treadmill, mat }

    // MARK: - Session Control

    func startTreadmillSession(_ workout: TreadmillWorkout) {
        selectedTreadmillWorkout = workout
        resetSession()
        isSessionActive = true
        startSessionTimer()
        startCurrentInterval()
    }

    func startMatSession(_ workout: MatWorkout) {
        selectedMatWorkout = workout
        resetSession()
        isSessionActive = true
        startSessionTimer()
    }

    func pauseSession() {
        sessionTimer?.invalidate()
        restTimer?.invalidate()
    }

    func resumeSession() {
        startSessionTimer()
    }

    func endSession(modelContext: ModelContext, userWeightKg: Double) {
        sessionTimer?.invalidate()
        restTimer?.invalidate()
        isSessionActive = false

        let calories: Int
        if let tw = selectedTreadmillWorkout {
            calories = Int(Double(tw.estimatedCalories) * (userWeightKg / 70.0))
        } else if let mw = selectedMatWorkout {
            calories = Int(Double(mw.estimatedCalories) * (userWeightKg / 70.0))
        } else {
            calories = 200
        }
        totalCaloriesBurned = calories

        let name = selectedTreadmillWorkout?.name ?? selectedMatWorkout?.name ?? "Workout"
        let type = selectedTreadmillWorkout != nil ? "treadmill" : "mat"
        let session = WorkoutSession(
            workoutName: name,
            workoutType: type,
            duration: sessionElapsedSeconds,
            estimatedCalories: calories
        )
        session.completed = true
        modelContext.insert(session)
        try? modelContext.save()
        sessionCompleted = true
    }

    // MARK: - Treadmill Intervals

    private func startCurrentInterval() {
        guard let workout = selectedTreadmillWorkout,
              currentIntervalIndex < workout.intervals.count else {
            return
        }
        intervalRemainingSeconds = workout.intervals[currentIntervalIndex].durationSeconds
    }

    func nextInterval() {
        guard let workout = selectedTreadmillWorkout else { return }
        if currentIntervalIndex < workout.intervals.count - 1 {
            currentIntervalIndex += 1
            startCurrentInterval()
        }
    }

    var currentInterval: WorkoutInterval? {
        guard let workout = selectedTreadmillWorkout,
              currentIntervalIndex < workout.intervals.count else { return nil }
        return workout.intervals[currentIntervalIndex]
    }

    var treadmillSessionProgress: Double {
        guard let workout = selectedTreadmillWorkout else { return 0 }
        let total = workout.intervals.reduce(0) { $0 + $1.durationSeconds }
        return total > 0 ? Double(sessionElapsedSeconds) / Double(total) : 0
    }

    // MARK: - Mat Exercise

    func completeSet(modelContext: ModelContext, userWeightKg: Double) {
        guard let workout = selectedMatWorkout else { return }
        let exercise = workout.exercises[currentExerciseIndex]
        if currentSet < exercise.sets {
            currentSet += 1
            startRest(seconds: exercise.restSeconds)
        } else if currentExerciseIndex < workout.exercises.count - 1 {
            currentExerciseIndex += 1
            currentSet = 1
            startRest(seconds: 60)
        } else {
            endSession(modelContext: modelContext, userWeightKg: userWeightKg)
        }
    }

    var currentMatExercise: MatExercise? {
        guard let workout = selectedMatWorkout,
              currentExerciseIndex < workout.exercises.count else { return nil }
        return workout.exercises[currentExerciseIndex]
    }

    var matSessionProgress: Double {
        guard let workout = selectedMatWorkout else { return 0 }
        let totalSets = workout.exercises.reduce(0) { $0 + $1.sets }
        let completedSets = workout.exercises.prefix(currentExerciseIndex).reduce(0) { $0 + $1.sets } + (currentSet - 1)
        return totalSets > 0 ? Double(completedSets) / Double(totalSets) : 0
    }

    // MARK: - Rest Timer

    private func startRest(seconds: Int) {
        isResting = true
        restRemainingSeconds = seconds
        restTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.restRemainingSeconds > 0 {
                    self.restRemainingSeconds -= 1
                    if self.restRemainingSeconds == 0 {
                        self.isResting = false
                        self.restTimer?.invalidate()
                        self.playAudioCue()
                    }
                }
            }
        }
    }

    // MARK: - Session Timer

    private func startSessionTimer() {
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.sessionElapsedSeconds += 1
                if self.intervalRemainingSeconds > 0 {
                    self.intervalRemainingSeconds -= 1
                }
            }
        }
    }

    private func resetSession() {
        sessionElapsedSeconds = 0
        currentIntervalIndex = 0
        intervalRemainingSeconds = 0
        currentExerciseIndex = 0
        currentSet = 1
        isResting = false
        restRemainingSeconds = 0
        sessionCompleted = false
        totalCaloriesBurned = 0
    }

    var formattedSessionTime: String {
        let h = sessionElapsedSeconds / 3600
        let m = (sessionElapsedSeconds % 3600) / 60
        let s = sessionElapsedSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Audio Cue

    private func playAudioCue() {
        AudioServicesPlaySystemSound(1016) // system "tweet" sound
    }
}

import AudioToolbox
