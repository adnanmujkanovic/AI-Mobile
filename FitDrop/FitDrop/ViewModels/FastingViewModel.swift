import SwiftUI
import SwiftData

@MainActor
class FastingViewModel: ObservableObject {
    @Published var activeFast: FastingSession? = nil
    @Published var elapsedSeconds: Double = 0
    @Published var isTimerRunning: Bool = false
    @Published var showBreakFastAlert: Bool = false
    @Published var selectedProtocol: FastingProtocol = .sixteen_eight

    private var timer: Timer? = nil

    enum FastingProtocol: String, CaseIterable {
        case sixteen_eight = "16:8"
        case eighteen_six = "18:6"
        case twenty_four = "20:4"
        case custom = "Custom"

        var fastingHours: Int {
            switch self {
            case .sixteen_eight: return 16
            case .eighteen_six: return 18
            case .twenty_four: return 20
            case .custom: return 16
            }
        }

        var eatingHours: Int { 24 - fastingHours }

        var description: String {
            switch self {
            case .sixteen_eight: return "16h fast / 8h eating — most popular protocol"
            case .eighteen_six: return "18h fast / 6h eating — enhanced fat burning"
            case .twenty_four: return "20h fast / 4h eating — advanced protocol"
            case .custom: return "Set your own fasting and eating window"
            }
        }
    }

    // MARK: - Timer

    func startTimer(for fast: FastingSession) {
        activeFast = fast
        isTimerRunning = true
        elapsedSeconds = fast.elapsedSeconds
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let fast = self.activeFast, !fast.isPaused else { return }
                self.elapsedSeconds = fast.elapsedSeconds
            }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        isTimerRunning = false
    }

    // MARK: - Fast Controls

    func startFast(plannedHours: Int, modelContext: ModelContext) {
        let fast = FastingSession(startTime: Date(), plannedHours: plannedHours)
        modelContext.insert(fast)
        try? modelContext.save()
        startTimer(for: fast)
    }

    func pauseFast(modelContext: ModelContext) {
        guard let fast = activeFast, !fast.isPaused else { return }
        fast.isPaused = true
        fast.pausedAt = Date()
        try? modelContext.save()
    }

    func resumeFast(modelContext: ModelContext) {
        guard let fast = activeFast, fast.isPaused, let pausedAt = fast.pausedAt else { return }
        fast.totalPausedSeconds += Date().timeIntervalSince(pausedAt)
        fast.isPaused = false
        fast.pausedAt = nil
        try? modelContext.save()
    }

    func breakFast(modelContext: ModelContext) {
        guard let fast = activeFast else { return }
        finish(fast, at: Date())
        fast.completed = fast.actualHours >= Double(fast.plannedHours)
        fast.brokenEarly = !fast.completed
        fast.isActive = false
        try? modelContext.save()
        stopTimer()
        activeFast = nil
    }

    func completeFast(modelContext: ModelContext) {
        guard let fast = activeFast else { return }
        finish(fast, at: Date())
        fast.completed = true
        fast.brokenEarly = false
        fast.isActive = false
        try? modelContext.save()
        stopTimer()
        activeFast = nil
    }

    /// Stamps the end time and folds any in-progress pause into the paused total.
    private func finish(_ fast: FastingSession, at end: Date) {
        if fast.isPaused, let pausedAt = fast.pausedAt {
            fast.totalPausedSeconds += max(0, end.timeIntervalSince(pausedAt))
            fast.isPaused = false
            fast.pausedAt = nil
        }
        fast.endTime = end
        fast.actualHours = fast.elapsedHours
    }

    // MARK: - Display Helpers

    var formattedElapsed: String {
        formatDuration(elapsedSeconds)
    }

    var formattedRemaining: String {
        guard let fast = activeFast else { return "00:00:00" }
        return formatDuration(fast.remainingSeconds)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let totalSecs = Int(seconds)
        let h = totalSecs / 3600
        let m = (totalSecs % 3600) / 60
        let s = totalSecs % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    var currentStage: FastingStage {
        activeFast?.fastingStage ?? .digestion
    }

    var progressFraction: Double {
        activeFast?.progressFraction ?? 0
    }

    func loadActiveFast(from sessions: [FastingSession]) {
        if let active = sessions.first(where: { $0.isActive }) {
            if activeFast?.id != active.id {
                startTimer(for: active)
            }
        }
    }

    func weeklyAverageFastingHours(sessions: [FastingSession]) -> Double {
        let oneWeekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
        let weekSessions = sessions.filter {
            $0.completed && $0.endTime ?? Date() >= oneWeekAgo
        }
        guard !weekSessions.isEmpty else { return 0 }
        return weekSessions.reduce(0) { $0 + $1.actualHours } / Double(weekSessions.count)
    }

    func consecutiveStreak(sessions: [FastingSession], profile: UserProfile?) -> Int {
        let completed = sessions.filter { $0.completed }.sorted { ($0.endTime ?? $0.startTime) > ($1.endTime ?? $1.startTime) }
        var streak = 0
        var checkDate = Calendar.current.startOfDay(for: Date())
        for session in completed {
            let sessionDay = Calendar.current.startOfDay(for: session.startTime)
            if sessionDay == checkDate || sessionDay == Calendar.current.date(byAdding: .day, value: -1, to: checkDate)! {
                streak += 1
                checkDate = sessionDay
            } else {
                break
            }
        }
        return streak
    }
}
