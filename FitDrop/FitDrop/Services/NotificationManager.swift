import Foundation
import UserNotifications

@MainActor
class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var lastError: String? = nil

    private let center = UNUserNotificationCenter.current()
    private let milestoneKey = "fastMilestoneAlertsEnabled"

    /// Whether alerts fire during a fast. Stored here so any screen can schedule without the profile.
    var milestoneAlertsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: milestoneKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: milestoneKey) }
    }

    private override init() {
        super.init()
        center.delegate = self
        Task { await checkStatus() }
    }

    func requestAuthorization() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            authorizationStatus = granted ? .authorized : .denied
            lastError = nil
        } catch {
            print("Notification auth error: \(error)")
            lastError = "Failed to request notification permissions: \(error.localizedDescription)"
            authorizationStatus = .denied
        }
    }

    func checkStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    // Show banners while the app is open, e.g. a milestone reached while looking at the timer
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    // MARK: - Active Fast

    static let activeFastMilestones: [(hours: Int, title: String, body: String)] = [
        (12, "12 hours fasted", "You've reached the ketosis zone. Keep going!"),
        (16, "16 hours fasted", "Autophagy zone reached. Great discipline."),
        (18, "18 hours fasted", "You're in a deep fast now."),
    ]

    /// Schedules one-off alerts for the remaining milestones and the goal of this fast.
    func scheduleActiveFastNotifications(for fast: FastingSession, now: Date = Date()) {
        cancelActiveFastNotifications()
        guard milestoneAlertsEnabled, fast.isActive, !fast.isPaused else { return }

        for milestone in Self.activeFastMilestones where milestone.hours < fast.plannedHours {
            let fireDate = fast.effectiveStart.addingTimeInterval(Double(milestone.hours) * 3600)
            scheduleOnce(id: "fast_active_\(milestone.hours)h", title: milestone.title, body: milestone.body, at: fireDate, now: now)
        }
        scheduleOnce(
            id: "fast_active_goal",
            title: "Fast complete! 🎉",
            body: "You reached your \(fast.plannedHours)-hour goal. End your fast in FitDrop whenever you're ready.",
            at: fast.goalDate,
            now: now
        )
        let oneHourBefore = fast.goalDate.addingTimeInterval(-3600)
        if fast.plannedHours >= 12 {
            scheduleOnce(id: "fast_active_1h_left", title: "1 hour to go", body: "Almost there — your fast finishes in an hour.", at: oneHourBefore, now: now)
        }
    }

    func cancelActiveFastNotifications() {
        let ids = Self.activeFastMilestones.map { "fast_active_\($0.hours)h" } + ["fast_active_goal", "fast_active_1h_left"]
        remove(ids)
    }

    // MARK: - Daily Reminders

    func scheduleFastStartReminder(hour: Int, minute: Int, enabled: Bool) {
        remove(["fast_start_daily"])
        guard enabled else { return }
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        scheduleRepeating(
            id: "fast_start_daily",
            title: "Time to start your fast",
            body: "Tap to start your fasting timer.",
            dateComponents: components
        )
    }

    func scheduleWorkoutReminder(hour: Int = 9, minute: Int = 0, daysOfWeek: [Int] = [2, 4, 6], enabled: Bool = true) {
        remove(workoutIdentifiers)
        guard enabled else { return }

        for day in daysOfWeek {
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            components.weekday = day

            scheduleRepeating(
                id: "workout_\(day)",
                title: "Workout Day",
                body: "Time for your training session. Even 20 minutes counts!",
                dateComponents: components
            )
        }
    }

    func scheduleFoodLoggingReminder(hour: Int = 20, minute: Int = 0, enabled: Bool = true) {
        remove(["food_log_reminder"])
        guard enabled else { return }
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        scheduleRepeating(
            id: "food_log_reminder",
            title: "Did you log today's meals?",
            body: "A quick log keeps your streak going and your numbers accurate.",
            dateComponents: components
        )
    }

    /// Applies every reminder preference from the profile.
    func applyPreferences(from profile: UserProfile) {
        milestoneAlertsEnabled = profile.fastMilestoneAlertsEnabled
        scheduleFoodLoggingReminder(enabled: profile.foodReminderEnabled)
        scheduleWorkoutReminder(enabled: profile.workoutReminderEnabled)
        scheduleFastStartReminder(
            hour: profile.fastingStartHour,
            minute: profile.fastingStartMinute,
            enabled: profile.fastStartReminderEnabled
        )
    }

    func removeAllNotifications() {
        enqueue { UNUserNotificationCenter.current().removeAllPendingNotificationRequests() }
    }

    // MARK: - Helpers

    private var workoutIdentifiers: [String] {
        (1...7).map { "workout_\($0)" }
    }

    private func scheduleOnce(id: String, title: String, body: String, at date: Date, now: Date) {
        let interval = date.timeIntervalSince(now)
        guard interval > 1 else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    private func scheduleRepeating(id: String, title: String, body: String, dateComponents: DateComponents) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    // The notification service can take a long time to answer, so every call runs off the main
    // thread, one after another, keeping removals ordered before the additions that follow them.
    private var pendingWork: Task<Void, Never>? = nil

    private func enqueue(_ work: @escaping @Sendable () async -> Void) {
        let previous = pendingWork
        pendingWork = Task.detached(priority: .utility) {
            await previous?.value
            await work()
        }
    }

    private func add(_ request: UNNotificationRequest) {
        enqueue {
            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                print("Scheduling notification \(request.identifier) failed: \(error)")
            }
        }
    }

    private func remove(_ identifiers: [String]) {
        enqueue { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers) }
    }
}
