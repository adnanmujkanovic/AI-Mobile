import Foundation
import SwiftData

/// Writes the user's data as CSV files they can open in Numbers or Excel.
@MainActor
enum DataExporter {
    static func export(context: ModelContext) throws -> [URL] {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("FitDrop Export", isDirectory: true)
        try? FileManager.default.removeItem(at: folder)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        func date(_ d: Date?) -> String { d.map { iso.string(from: $0) } ?? "" }
        func number(_ v: Double) -> String { String(format: "%.2f", v) }

        var files: [URL] = []
        func write(_ name: String, header: [String], rows: [[String]]) throws {
            let lines = ([header] + rows).map { $0.map(csvEscape).joined(separator: ",") }
            let url = folder.appendingPathComponent(name)
            try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
            files.append(url)
        }

        let food = try context.fetch(FetchDescriptor<FoodEntry>(sortBy: [SortDescriptor(\.date)]))
        try write("food.csv", header: ["date", "meal", "name", "brand", "amount", "calories", "protein_g", "carbs_g", "fat_g"], rows: food.map {
            [date($0.date), $0.mealType, $0.name, $0.brand, $0.amountLabel, number($0.totalCalories), number($0.totalProtein), number($0.totalCarbs), number($0.totalFat)]
        })

        let weights = try context.fetch(FetchDescriptor<WeightLog>(sortBy: [SortDescriptor(\.date)]))
        try write("weight.csv", header: ["date", "weight_kg", "notes"], rows: weights.map { [date($0.date), number($0.weightKg), $0.notes] })

        let fasts = try context.fetch(FetchDescriptor<FastingSession>(sortBy: [SortDescriptor(\.startTime)]))
        try write("fasting.csv", header: ["start", "end", "planned_hours", "actual_hours", "reached_goal"], rows: fasts.filter { $0.isFinished }.map {
            [date($0.startTime), date($0.endTime), String($0.plannedHours), number($0.actualHours), $0.completed ? "yes" : "no"]
        })

        let workouts = try context.fetch(FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\.date)]))
        try write("workouts.csv", header: ["date", "name", "type", "duration_min", "calories"], rows: workouts.map {
            [date($0.date), $0.workoutName, $0.workoutType, number(Double($0.duration) / 60), String($0.estimatedCalories)]
        })

        let runs = try context.fetch(FetchDescriptor<RunSession>(sortBy: [SortDescriptor(\.date)]))
        try write("runs.csv", header: ["date", "distance_km", "duration_min", "plan_week"], rows: runs.filter { $0.completed }.map {
            [date($0.completedDate ?? $0.date), number($0.distanceKm), String($0.durationMinutes), $0.planWeek > 0 ? String($0.planWeek) : ""]
        })

        let water = try context.fetch(FetchDescriptor<WaterLog>(sortBy: [SortDescriptor(\.date)]))
        try write("water.csv", header: ["date", "ml"], rows: water.map { [date($0.date), String($0.amountMl)] })

        return files
    }

    static func csvEscape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// Deletes every record, returning the app to onboarding.
    static func deleteAll(context: ModelContext) throws {
        try context.delete(model: FoodEntry.self)
        try context.delete(model: SavedFood.self)
        try context.delete(model: WeightLog.self)
        try context.delete(model: WaterLog.self)
        try context.delete(model: FastingSession.self)
        try context.delete(model: WorkoutSession.self)
        try context.delete(model: RunSession.self)
        try context.delete(model: UserProfile.self)
        try context.save()
        NotificationManager.shared.removeAllNotifications()
        FastingLiveActivity.end(finalFast: nil)
    }
}
