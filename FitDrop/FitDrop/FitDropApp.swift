import SwiftUI
import SwiftData

@main
struct FitDropApp: App {
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var health = HealthKitManager.shared

    static let container: ModelContainer = {
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

    /// Unit tests load the app as their host; they use in-memory stores, so skip the real UI and database.
    static let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        || ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil

    var body: some Scene {
        WindowGroup {
            if Self.isRunningTests {
                Color.clear
            } else {
                RootView()
                    .environmentObject(notificationManager)
                    .environmentObject(health)
                    .modelContainer(Self.container)
            }
        }
    }
}
