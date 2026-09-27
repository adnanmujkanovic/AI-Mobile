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
        case thirteen_eleven = "13:11"
        case sixteen_eight = "16:8"
        case eighteen_six = "18:6"
        case twenty_four = "20:4"
        case custom = "Custom"

        var fastingHours: Int {
            switch self {
            case .thirteen_eleven: return 13
            case .sixteen_eight: return 16
            case .eighteen_six: return 18
            case .twenty_four: return 20
            case .custom: return 16
            }
        }

        var eatingHours: Int { 24 - fastingHours }

        var description: String {
            switch self {
            case .thirteen_eleven: return "13h fast — a gentle start, overnight plus breakfast later"
            case .sixteen_eight: return "16h fast / 8h eating — the most popular protocol"
            case .eighteen_six: return "18h fast / 6h eating — for experienced fasters"
            case .twenty_four: return "20h fast / 4h eating — advanced"
            case .custom: return "Choose any length from 12 to 72 hours"
            }
        }

        static func matching(hours: Int) -> FastingProtocol {
            allCases.first { $0 != .custom && $0.fastingHours == hours } ?? .custom
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
                guard let self, let fast = self.activeFast else { return }
                self.elapsedSeconds = fast.elapsedSeconds
            }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        isTimerRunning = false
    }

    // MARK: - Fast Controls

    func startFast(plannedHours: Int, startTime: Date = Date(), modelContext: ModelContext, profile: UserProfile? = nil) {
        let fast = FastingSession(startTime: min(startTime, Date()), plannedHours: plannedHours)
        modelContext.insert(fast)
        profile?.fastingDuration = plannedHours
        profile?.eatingWindowDuration = max(0, 24 - plannedHours)
        profile?.fastingProtocol = FastingProtocol.matching(hours: plannedHours).rawValue
        modelContext.saveOrLog()
        startTimer(for: fast)
        Self.refreshReminders(for: fast, profile: profile)
        Haptics.success()
    }

    func pauseFast(modelContext: ModelContext) {
        guard let fast = activeFast, !fast.isPaused else { return }
        fast.isPaused = true
        fast.pausedAt = Date()
        modelContext.saveOrLog()
        elapsedSeconds = fast.elapsedSeconds
        Self.refreshReminders(for: fast, profile: nil)
    }

    func resumeFast(modelContext: ModelContext) {
        guard let fast = activeFast, fast.isPaused, let pausedAt = fast.pausedAt else { return }
        fast.totalPausedSeconds += Date().timeIntervalSince(pausedAt)
        fast.isPaused = false
        fast.pausedAt = nil
        modelContext.saveOrLog()
        Self.refreshReminders(for: fast, profile: nil)
    }

    /// Moves the start of the active fast, e.g. when the user forgot to press Start.
    func updateStartTime(_ newStart: Date, modelContext: ModelContext) {
        guard let fast = activeFast else { return }
        fast.startTime = Self.clampedStart(newStart)
        modelContext.saveOrLog()
        elapsedSeconds = fast.elapsedSeconds
        Self.refreshReminders(for: fast, profile: nil)
    }

    /// Changes the goal of the active fast.
    func updatePlannedHours(_ hours: Int, modelContext: ModelContext) {
        guard let fast = activeFast else { return }
        fast.plannedHours = min(72, max(1, hours))
        modelContext.saveOrLog()
        Self.refreshReminders(for: fast, profile: nil)
    }

    /// A start time can't be in the future or more than three days back.
    nonisolated static func clampedStart(_ date: Date, now: Date = Date()) -> Date {
        min(now, max(now.addingTimeInterval(-72 * 3600), date))
    }

    func breakFast(modelContext: ModelContext) {
        guard let fast = activeFast else { return }
        Self.end(fast, modelContext: modelContext)
        stopTimer()
        activeFast = nil
    }

    func completeFast(modelContext: ModelContext) {
        breakFast(modelContext: modelContext)
    }

    /// Ends a fast from anywhere in the app and clears its reminders and Live Activity.
    static func end(_ fast: FastingSession, modelContext: ModelContext) {
        fast.end()
        modelContext.saveOrLog()
        NotificationManager.shared.cancelActiveFastNotifications()
        FastingLiveActivity.end(finalFast: fast)
        if fast.completed { Haptics.success() }
    }

    private static func refreshReminders(for fast: FastingSession, profile: UserProfile?) {
        NotificationManager.shared.scheduleActiveFastNotifications(for: fast)
        FastingLiveActivity.startOrUpdate(for: fast)
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

    /// e.g. "14h 5m"
    nonisolated static func formatHours(_ hours: Double) -> String {
        let totalMinutes = Int(hours * 60)
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    var currentStage: FastingStage {
        FastingStage.forHours(elapsedSeconds / 3600)
    }

    var progressFraction: Double {
        guard let fast = activeFast, fast.plannedHours > 0 else { return 0 }
        return min(1, elapsedSeconds / (Double(fast.plannedHours) * 3600))
    }

    func loadActiveFast(from sessions: [FastingSession]) {
        if let active = sessions.first(where: { $0.isActive }) {
            if activeFast?.id != active.id {
                startTimer(for: active)
            }
            FastingLiveActivity.startOrUpdate(for: active)
        } else if activeFast != nil {
            stopTimer()
            activeFast = nil
        }
    }

    // MARK: - Stats

    func weeklyAverageFastingHours(sessions: [FastingSession], now: Date = Date()) -> Double {
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        let weekSessions = sessions.filter {
            $0.isFinished && ($0.endTime ?? now) >= oneWeekAgo
        }
        guard !weekSessions.isEmpty else { return 0 }
        return weekSessions.reduce(0) { $0 + $1.actualHours } / Double(weekSessions.count)
    }

    /// Consecutive days, ending today or yesterday, on which a fast reached its goal.
    func consecutiveStreak(sessions: [FastingSession], profile: UserProfile?, now: Date = Date()) -> Int {
        let days = sessions.filter { $0.completed }.map { $0.endTime ?? $0.startTime }
        return Streaks.consecutiveDays(days, now: now)
    }
}
