import SwiftUI
import SwiftData
import AVFoundation
import UIKit

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
    @Published var isPaused: Bool = false

    // Timing is derived from dates, so it stays correct while the app is suspended.
    private var ticker: Timer? = nil
    private var runningSince: Date? = nil
    private var accumulatedSeconds: TimeInterval = 0
    private var intervalEndsAt: Date? = nil
    private var restEndsAt: Date? = nil
    /// Clock source; tests replace it to control time.
    var now: () -> Date = Date.init
    private var audioPlayer: AVAudioPlayer? = nil
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    enum WorkoutTab { case treadmill, mat }

    // MARK: - Session Control

    func startTreadmillSession(_ workout: TreadmillWorkout) {
        selectedTreadmillWorkout = workout
        resetSession()
        isSessionActive = true
        beginBackgroundTask()
        startClock()
        startCurrentInterval()
    }

    func startMatSession(_ workout: MatWorkout) {
        selectedMatWorkout = workout
        resetSession()
        isSessionActive = true
        beginBackgroundTask()
        startClock()
    }

    func pauseSession() {
        guard isSessionActive, !isPaused else { return }
        tick()
        if let runningSince {
            accumulatedSeconds += now().timeIntervalSince(runningSince)
        }
        runningSince = nil
        intervalEndsAt = nil
        restEndsAt = nil
        ticker?.invalidate()
        isPaused = true
    }

    func resumeSession() {
        guard isSessionActive, isPaused else { return }
        let now = self.now()
        isPaused = false
        runningSince = now
        if currentInterval != nil, intervalRemainingSeconds > 0 {
            intervalEndsAt = now.addingTimeInterval(TimeInterval(intervalRemainingSeconds))
        }
        if isResting {
            restEndsAt = now.addingTimeInterval(TimeInterval(restRemainingSeconds))
        }
        startTicker()
    }

    func endSession(modelContext: ModelContext, userWeightKg: Double) {
        tick()
        ticker?.invalidate()
        runningSince = nil
        isSessionActive = false
        endBackgroundTask()

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
    
    // MARK: - Background Task Support
    
    private func beginBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }

    // MARK: - Treadmill Intervals

    private func startCurrentInterval() {
        guard let workout = selectedTreadmillWorkout,
              currentIntervalIndex < workout.intervals.count else {
            return
        }
        let duration = workout.intervals[currentIntervalIndex].durationSeconds
        intervalRemainingSeconds = duration
        intervalEndsAt = isPaused ? nil : now().addingTimeInterval(TimeInterval(duration))
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
        restEndsAt = isPaused ? nil : now().addingTimeInterval(TimeInterval(seconds))
    }

    // MARK: - Session Clock

    private func startClock() {
        runningSince = now()
        startTicker()
    }

    private func startTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    /// Recomputes all displayed times from the stored dates.
    func tick() {
        let now = self.now()
        let running = runningSince.map { now.timeIntervalSince($0) } ?? 0
        sessionElapsedSeconds = Int(accumulatedSeconds + running)

        if let intervalEndsAt {
            intervalRemainingSeconds = secondsRemaining(until: intervalEndsAt, from: now)
        }
        if isResting, let restEndsAt {
            restRemainingSeconds = secondsRemaining(until: restEndsAt, from: now)
            if restRemainingSeconds == 0 {
                isResting = false
                self.restEndsAt = nil
                playAudioCue()
            }
        }
    }

    private func secondsRemaining(until end: Date, from now: Date) -> Int {
        max(0, Int(end.timeIntervalSince(now).rounded(.up)))
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
        isPaused = false
        accumulatedSeconds = 0
        runningSince = nil
        intervalEndsAt = nil
        restEndsAt = nil
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
    
    // MARK: - Cleanup
    
    deinit {
        ticker?.invalidate()
        // A background task still open here is ended by its expiration handler.
    }
}

import AudioToolbox
