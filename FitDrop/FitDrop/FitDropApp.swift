import SwiftUI
import SwiftData
import UserNotifications

@main
struct FitDropApp: App {
    @StateObject private var notificationManager = NotificationManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(for: [
                    UserProfile.self,
                    WorkoutSession.self,
                    FoodEntry.self,
                    FastingSession.self,
                    RunSession.self,
                    WeightLog.self
                ])
                .environmentObject(notificationManager)
        }
    }
}
