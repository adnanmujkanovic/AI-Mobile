import SwiftUI
import SwiftData

@main
struct FitDropApp: App {
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var health = HealthKitManager.shared

    let container: ModelContainer = {
        let schema = Schema([
            UserProfile.self,
            WorkoutSession.self,
            FoodEntry.self,
            SavedFood.self,
            FastingSession.self,
            RunSession.self,
            WeightLog.self,
            WaterLog.self,
        ])
        // SwiftData expects Application Support to exist; on a fresh install it doesn't yet
        try? FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)
        do {
            return try ModelContainer(for: schema)
        } catch {
            fatalError("Couldn't open the FitDrop database: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(notificationManager)
                .environmentObject(health)
        }
        .modelContainer(container)
    }
}
