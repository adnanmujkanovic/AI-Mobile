import Foundation
import SwiftData
@testable import FitDrop

enum TestSupport {
    /// A fresh in-memory store with the app's full schema.
    @MainActor
    static func makeContext() throws -> ModelContext {
        let schema = Schema([
            UserProfile.self, WorkoutSession.self, FoodEntry.self, SavedFood.self,
            FastingSession.self, RunSession.self, WeightLog.self, WaterLog.self,
        ])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    static func day(_ offset: Int, hour: Int = 9, from now: Date = Date()) -> Date {
        let start = Calendar.current.startOfDay(for: now)
        let day = Calendar.current.date(byAdding: .day, value: offset, to: start)!
        return Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
    }
}
