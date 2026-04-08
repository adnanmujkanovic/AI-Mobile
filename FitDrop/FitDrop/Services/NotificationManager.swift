import Foundation
import UserNotifications

@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private init() {
        Task { await checkStatus() }
    }

    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            authorizationStatus = granted ? .authorized : .denied
        } catch {
            print("Notification auth error: \(error)")
        }
    }

    func checkStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    // MARK: - Fasting Notifications

    func scheduleFastingNotifications(startHour: Int, startMinute: Int, durationHours: Int) {
        let center = UNUserNotificationCenter.current()

        // Remove old fasting notifications
        center.removePendingNotificationRequests(withIdentifiers: fastingIdentifiers)

        var components = DateComponents()
        components.hour = startHour
        components.minute = startMinute

        // 1. Fasting starts
        scheduleDaily(
            id: "fast_start",
            title: "Fast Starting",
            body: "Your \(durationHours)h fast has begun. Good luck!",
            dateComponents: components,
            sound: .default
        )

        // 2. Eating window opens
        let eatStartComponents = addingHours(durationHours, to: components)
        scheduleDaily(
            id: "fast_eat_open",
            title: "Eating Window Open",
            body: "Your fasting window is complete. You can eat now.",
            dateComponents: eatStartComponents,
            sound: .default
        )

        // 3. 12h milestone
        if durationHours >= 12 {
            let milestone12 = addingHours(12, to: components)
            scheduleDaily(
                id: "fast_12h",
                title: "12 Hours — Ketosis Zone",
                body: "Your body is entering ketosis. Keep going!",
                dateComponents: milestone12,
                sound: .default
            )
        }

        // 4. 16h milestone
        if durationHours >= 16 {
            let milestone16 = addingHours(16, to: components)
            scheduleDaily(
                id: "fast_16h",
                title: "16 Hours — Autophagy Activated",
                body: "Incredible! Autophagy is now active. Your cells are renewing.",
                dateComponents: milestone16,
                sound: .default
            )
        }

        // 5. 1h before eating window closes
        let windowDuration = 24 - durationHours
        if windowDuration > 1 {
            let closeWarning = addingHours(durationHours + windowDuration - 1, to: components)
            scheduleDaily(
                id: "fast_eat_closing",
                title: "Eating Window Closing Soon",
                body: "1 hour left in your eating window.",
                dateComponents: closeWarning,
                sound: .default
            )
        }
    }

    // MARK: - Workout Reminders

    func scheduleWorkoutReminder(hour: Int = 9, minute: Int = 0, daysOfWeek: [Int] = [2, 4, 6]) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: workoutIdentifiers)

        for day in daysOfWeek {
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            components.weekday = day

            scheduleWeekly(
                id: "workout_\(day)",
                title: "Workout Day",
                body: "Time for your scheduled training session. You've got this!",
                dateComponents: components
            )
        }
    }

    // MARK: - Food Logging Reminder

    func scheduleFoodLoggingReminder(hour: Int = 13, minute: Int = 0) {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        scheduleDaily(
            id: "food_log_reminder",
            title: "Log Your Lunch",
            body: "Don't forget to track your food today. Stay on target!",
            dateComponents: components,
            sound: .default
        )
    }

    // MARK: - Running Plan Reminders

    func scheduleRunReminder(for runDate: Date, sessionDescription: String) {
        let content = UNMutableNotificationContent()
        content.title = "Running Day"
        content.body = "Today's run: \(sessionDescription)"
        content.sound = .default

        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: runDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: "run_\(runDate.timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func removeAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: - Helpers

    private var fastingIdentifiers: [String] {
        ["fast_start", "fast_eat_open", "fast_12h", "fast_16h", "fast_eat_closing"]
    }

    private var workoutIdentifiers: [String] {
        (1...7).map { "workout_\($0)" }
    }

    private func scheduleDaily(id: String, title: String, body: String, dateComponents: DateComponents, sound: UNNotificationSound) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func scheduleWeekly(id: String, title: String, body: String, dateComponents: DateComponents) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func addingHours(_ hours: Int, to components: DateComponents) -> DateComponents {
        var result = components
        let baseHour = components.hour ?? 0
        let baseMinute = components.minute ?? 0
        let totalMinutes = baseHour * 60 + baseMinute + hours * 60
        result.hour = (totalMinutes / 60) % 24
        result.minute = totalMinutes % 60
        return result
    }
}
