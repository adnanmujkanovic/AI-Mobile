import Foundation
import HealthKit

/// Optional two-way sync with Apple Health. Every call is a no-op until the user turns it on.
@MainActor
final class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()

    @Published private(set) var todaySteps: Int = 0
    @Published private(set) var todayActiveEnergy: Double = 0
    @Published private(set) var isEnabled: Bool
    @Published var lastError: String? = nil

    private let store = HKHealthStore()
    private let enabledKey = "healthKitEnabled"

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
    }

    // MARK: - Types

    private var shareTypes: Set<HKSampleType> {
        [
            HKQuantityType(.bodyMass),
            HKQuantityType(.dietaryWater),
            HKQuantityType(.dietaryEnergyConsumed),
            HKQuantityType(.dietaryProtein),
            HKQuantityType(.dietaryCarbohydrates),
            HKQuantityType(.dietaryFatTotal),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKObjectType.workoutType(),
        ]
    }

    private var readTypes: Set<HKObjectType> {
        [
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.bodyMass),
        ]
    }

    // MARK: - Enable / Disable

    /// Asks for permission and turns sync on. Returns whether sync is now on.
    @discardableResult
    func enable() async -> Bool {
        guard isAvailable else {
            lastError = "Apple Health isn't available on this device."
            return false
        }
        do {
            try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
            setEnabled(true)
            await refreshToday()
            return true
        } catch {
            lastError = "Couldn't connect to Apple Health: \(error.localizedDescription)"
            setEnabled(false)
            return false
        }
    }

    func disable() {
        setEnabled(false)
        todaySteps = 0
        todayActiveEnergy = 0
    }

    private func setEnabled(_ value: Bool) {
        isEnabled = value
        UserDefaults.standard.set(value, forKey: enabledKey)
    }

    // MARK: - Reading

    func refreshToday() async {
        guard isEnabled else { return }
        let start = Calendar.current.startOfDay(for: Date())
        todaySteps = Int(await sumToday(.stepCount, unit: .count(), from: start))
        todayActiveEnergy = await sumToday(.activeEnergyBurned, unit: .kilocalorie(), from: start)
    }

    private func sumToday(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, from start: Date) async -> Double {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: nil)
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(identifier), predicate: predicate),
            options: .cumulativeSum
        )
        do {
            return try await descriptor.result(for: store)?.sumQuantity()?.doubleValue(for: unit) ?? 0
        } catch {
            // No data yet, or read access denied: Health doesn't say which, so show nothing
            return 0
        }
    }

    // MARK: - Writing

    func saveWeight(_ log: WeightLog) {
        save(
            [quantitySample(.bodyMass, value: log.weightKg, unit: .gramUnit(with: .kilo), date: log.date, syncID: "weight-\(log.id)")]
        )
    }

    func saveWater(_ log: WaterLog) {
        save(
            [quantitySample(.dietaryWater, value: Double(log.amountMl), unit: .literUnit(with: .milli), date: log.date, syncID: "water-\(log.id)")]
        )
    }

    /// Writes (or overwrites) the energy and macros of one food entry.
    func saveFood(_ entry: FoodEntry) {
        let id = entry.id.uuidString
        let values: [(HKQuantityTypeIdentifier, Double, HKUnit, String)] = [
            (.dietaryEnergyConsumed, entry.totalCalories, .kilocalorie(), "food-energy-\(id)"),
            (.dietaryProtein, entry.totalProtein, .gram(), "food-protein-\(id)"),
            (.dietaryCarbohydrates, entry.totalCarbs, .gram(), "food-carbs-\(id)"),
            (.dietaryFatTotal, entry.totalFat, .gram(), "food-fat-\(id)"),
        ]
        let samples = values.filter { $0.1 > 0 }.map {
            quantitySample($0.0, value: $0.1, unit: $0.2, date: entry.date, syncID: $0.3, metadata: [HKMetadataKeyFoodType: entry.name])
        }
        save(samples)
    }

    func deleteFood(id: UUID) {
        let ids = ["energy", "protein", "carbs", "fat"].map { "food-\($0)-\(id.uuidString)" }
        delete(syncIDs: ids, types: [.dietaryEnergyConsumed, .dietaryProtein, .dietaryCarbohydrates, .dietaryFatTotal])
    }

    func deleteWater(id: UUID) {
        delete(syncIDs: ["water-\(id)"], types: [.dietaryWater])
    }

    func deleteWeight(id: UUID) {
        delete(syncIDs: ["weight-\(id)"], types: [.bodyMass])
    }

    func saveWorkout(name: String, isRun: Bool, start: Date, end: Date, calories: Double, distanceKm: Double? = nil) {
        guard isEnabled, end > start else { return }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = isRun ? .running : .functionalStrengthTraining
        configuration.locationType = .indoor
        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        var samples: [HKSample] = []
        if calories > 0 {
            samples.append(HKQuantitySample(
                type: HKQuantityType(.activeEnergyBurned),
                quantity: HKQuantity(unit: .kilocalorie(), doubleValue: calories),
                start: start, end: end
            ))
        }
        if let distanceKm, distanceKm > 0 {
            samples.append(HKQuantitySample(
                type: HKQuantityType(.distanceWalkingRunning),
                quantity: HKQuantity(unit: .meterUnit(with: .kilo), doubleValue: distanceKm),
                start: start, end: end
            ))
        }
        Task {
            do {
                try await builder.beginCollection(at: start)
                if !samples.isEmpty { try await builder.addSamples(samples) }
                try await builder.addMetadata([HKMetadataKeyWorkoutBrandName: name])
                try await builder.endCollection(at: end)
                _ = try await builder.finishWorkout()
                await refreshToday()
            } catch {
                print("Saving workout to Health failed: \(error)")
            }
        }
    }

    // MARK: - Helpers

    private func quantitySample(
        _ identifier: HKQuantityTypeIdentifier,
        value: Double,
        unit: HKUnit,
        date: Date,
        syncID: String,
        metadata extra: [String: Any] = [:]
    ) -> HKQuantitySample {
        var metadata: [String: Any] = [
            HKMetadataKeySyncIdentifier: syncID,
            // A newer version replaces the old sample with the same sync identifier
            HKMetadataKeySyncVersion: Int(Date().timeIntervalSince1970),
        ]
        metadata.merge(extra) { current, _ in current }
        return HKQuantitySample(
            type: HKQuantityType(identifier),
            quantity: HKQuantity(unit: unit, doubleValue: value),
            start: date,
            end: date,
            metadata: metadata
        )
    }

    private func save(_ samples: [HKSample]) {
        guard isEnabled, !samples.isEmpty else { return }
        store.save(samples) { _, error in
            if let error { print("Saving to Health failed: \(error)") }
        }
    }

    private func delete(syncIDs: [String], types: [HKQuantityTypeIdentifier]) {
        guard isEnabled else { return }
        let predicate = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeySyncIdentifier, allowedValues: syncIDs)
        for type in types {
            store.deleteObjects(of: HKQuantityType(type), predicate: predicate) { _, _, error in
                if let error { print("Deleting from Health failed: \(error)") }
            }
        }
    }
}
