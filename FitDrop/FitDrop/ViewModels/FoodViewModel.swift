import SwiftUI
import SwiftData

@MainActor
class FoodViewModel: ObservableObject {
    @Published var searchQuery: String = ""
    @Published var searchResults: [OFFProduct] = []
    @Published var isSearching: Bool = false
    @Published var scannedProduct: OFFProduct? = nil
    @Published var editingEntry: FoodEntryDraft? = nil
    @Published var errorMessage: String? = nil
    @Published var selectedDate: Date = Date()
    @Published var selectedMealType: String = MealType.suggested().rawValue

    private var searchTask: Task<Void, Never>? = nil

    struct FoodEntryDraft {
        enum Basis { case per100g, perServing }

        var name: String
        var brand: String
        // Nutrition for one unit: 100 g, or one serving
        var calories: Double
        var protein: Double
        var carbs: Double
        var fat: Double
        var fiber: Double
        var basis: Basis
        /// Grams when `basis` is per 100 g, servings otherwise
        var quantity: Double
        /// Label for one serving when `basis` is per serving, e.g. "slice"
        var servingLabel: String
        /// Grams in the product's typical serving, for the quick-pick chip
        var typicalServingG: Double?
        var barcode: String
        var mealType: String
        /// The log entry being edited, if any
        var existingEntryID: PersistentIdentifier?

        init(from product: OFFProduct, mealType: String) {
            self.name = product.displayName
            self.brand = product.displayBrand
            self.calories = product.nutriments?.energyKcal100g ?? 0
            self.protein = product.nutriments?.proteins100g ?? 0
            self.carbs = product.nutriments?.carbohydrates100g ?? 0
            self.fat = product.nutriments?.fat100g ?? 0
            self.fiber = product.nutriments?.fiber100g ?? 0
            self.basis = .per100g
            self.typicalServingG = product.servingGrams
            self.quantity = product.servingGrams ?? 100
            self.servingLabel = "serving"
            self.barcode = product.code ?? ""
            self.mealType = mealType
        }

        init(name: String, mealType: String) {
            self.name = name
            self.brand = ""
            self.calories = 0
            self.protein = 0
            self.carbs = 0
            self.fat = 0
            self.fiber = 0
            self.basis = .perServing
            self.quantity = 1
            self.servingLabel = "serving"
            self.typicalServingG = nil
            self.barcode = ""
            self.mealType = mealType
        }

        init(entry: FoodEntry) {
            self.init(
                name: entry.name, brand: entry.brand,
                calories: entry.calories, protein: entry.protein, carbs: entry.carbs, fat: entry.fat, fiber: entry.fiber,
                unit: entry.servingDescription, amount: entry.servingAmount,
                barcode: entry.barcode, mealType: entry.mealType
            )
            self.existingEntryID = entry.persistentModelID
        }

        init(saved: SavedFood, mealType: String) {
            self.init(
                name: saved.name, brand: saved.brand,
                calories: saved.calories, protein: saved.protein, carbs: saved.carbs, fat: saved.fat, fiber: saved.fiber,
                unit: saved.servingDescription, amount: saved.defaultAmount,
                barcode: saved.barcode, mealType: mealType
            )
        }

        private init(
            name: String, brand: String,
            calories: Double, protein: Double, carbs: Double, fat: Double, fiber: Double,
            unit: String, amount: Double, barcode: String, mealType: String
        ) {
            self.name = name
            self.brand = brand
            self.calories = calories
            self.protein = protein
            self.carbs = carbs
            self.fat = fat
            self.fiber = fiber
            if FoodEntry.isPer100gUnit(unit) {
                self.basis = .per100g
                self.quantity = amount * 100
            } else {
                self.basis = .perServing
                self.quantity = amount
            }
            self.servingLabel = FoodEntry.isPer100gUnit(unit) ? "serving" : unit
            self.typicalServingG = nil
            self.barcode = barcode
            self.mealType = mealType
        }

        /// Multiplier applied to the per-unit nutrition values
        var multiplier: Double {
            switch basis {
            case .per100g: return max(0, quantity) / 100
            case .perServing: return max(0, quantity)
            }
        }

        var unitDescription: String {
            switch basis {
            case .per100g: return "100g"
            case .perServing: return servingLabel.trimmingCharacters(in: .whitespaces).isEmpty ? "serving" : servingLabel
            }
        }

        var totalCalories: Double { calories * multiplier }
        var totalProtein: Double { protein * multiplier }
        var totalCarbs: Double { carbs * multiplier }
        var totalFat: Double { fat * multiplier }

        var isValid: Bool {
            !name.trimmingCharacters(in: .whitespaces).isEmpty && quantity > 0 && calories >= 0
        }
    }

    // MARK: - Search

    func searchFood() {
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        guard query.count >= 2 else { return }
        searchTask?.cancel()
        isSearching = true
        errorMessage = nil
        searchTask = Task {
            do {
                let results = try await OpenFoodFactsService.shared.searchProducts(query: query)
                guard !Task.isCancelled else { return }
                self.searchResults = results
                if results.isEmpty {
                    self.errorMessage = "No results for \"\(query)\". Try a simpler name, or enter it manually."
                }
            } catch {
                guard !Task.isCancelled else { return }
                self.errorMessage = error.localizedDescription
                self.searchResults = []
            }
            self.isSearching = false
        }
    }

    func clearSearch() {
        searchTask?.cancel()
        searchQuery = ""
        searchResults = []
        errorMessage = nil
        isSearching = false
    }

    // MARK: - Barcode

    func handleBarcode(_ barcode: String) {
        isSearching = true
        errorMessage = nil
        Task {
            do {
                let product = try await OpenFoodFactsService.shared.fetchProduct(barcode: barcode)
                self.scannedProduct = product
                self.editingEntry = FoodEntryDraft(from: product, mealType: selectedMealType)
            } catch {
                self.errorMessage = error.localizedDescription
                var draft = FoodEntryDraft(name: "", mealType: selectedMealType)
                draft.barcode = barcode
                self.pendingManualDraftForBarcode = draft
            }
            self.isSearching = false
        }
    }

    /// Offered after a failed barcode lookup so the user can enter the product manually.
    @Published var pendingManualDraftForBarcode: FoodEntryDraft? = nil

    func selectProduct(_ product: OFFProduct) {
        editingEntry = FoodEntryDraft(from: product, mealType: selectedMealType)
    }

    func startManualEntry() {
        editingEntry = FoodEntryDraft(name: "", mealType: selectedMealType)
    }

    func startEditing(_ entry: FoodEntry) {
        editingEntry = FoodEntryDraft(entry: entry)
    }

    func startFromSaved(_ saved: SavedFood) {
        editingEntry = FoodEntryDraft(saved: saved, mealType: selectedMealType)
    }

    func startFromRecent(_ entry: FoodEntry) {
        var draft = FoodEntryDraft(entry: entry)
        draft.existingEntryID = nil
        draft.mealType = selectedMealType
        editingEntry = draft
    }

    // MARK: - Log Food

    /// Saves the draft as a new entry, or updates the entry it was opened from.
    @discardableResult
    func save(_ draft: FoodEntryDraft, modelContext: ModelContext) -> FoodEntry? {
        guard draft.isValid else { return nil }
        let entry: FoodEntry
        if let id = draft.existingEntryID, let existing = modelContext.model(for: id) as? FoodEntry {
            entry = existing
        } else {
            entry = FoodEntry(name: "", calories: 0, protein: 0, carbs: 0, fat: 0)
            entry.date = logDate(for: selectedDate)
            modelContext.insert(entry)
        }
        entry.name = draft.name.trimmingCharacters(in: .whitespaces)
        entry.brand = draft.brand.trimmingCharacters(in: .whitespaces)
        entry.calories = draft.calories
        entry.protein = draft.protein
        entry.carbs = draft.carbs
        entry.fat = draft.fat
        entry.fiber = draft.fiber
        entry.servingDescription = draft.unitDescription
        entry.servingSizeG = draft.basis == .per100g ? 100 : 0
        entry.servingAmount = draft.multiplier
        entry.barcode = draft.barcode
        entry.mealType = draft.mealType
        modelContext.saveOrLog()
        HealthKitManager.shared.saveFood(entry)
        editingEntry = nil
        scannedProduct = nil
        Haptics.success()
        return entry
    }

    /// Logs a calories-only entry, for when the user just knows the number.
    func quickAdd(calories: Double, protein: Double, name: String, mealType: String, modelContext: ModelContext) -> FoodEntry? {
        guard calories > 0 else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let entry = FoodEntry(
            name: trimmed.isEmpty ? "Quick add" : trimmed,
            calories: calories,
            protein: max(0, protein),
            carbs: 0,
            fat: 0,
            servingDescription: "serving",
            mealType: mealType
        )
        entry.servingSizeG = 0
        entry.date = logDate(for: selectedDate)
        modelContext.insert(entry)
        modelContext.saveOrLog()
        HealthKitManager.shared.saveFood(entry)
        Haptics.success()
        return entry
    }

    /// Relogs a previous entry to the selected day with the same amount.
    func relog(_ source: FoodEntry, mealType: String, modelContext: ModelContext) -> FoodEntry {
        let entry = FoodEntry(
            name: source.name, brand: source.brand,
            calories: source.calories, protein: source.protein, carbs: source.carbs, fat: source.fat, fiber: source.fiber,
            servingSizeG: source.servingSizeG, servingDescription: source.servingDescription,
            servingAmount: source.servingAmount, barcode: source.barcode, mealType: mealType
        )
        entry.date = logDate(for: selectedDate)
        modelContext.insert(entry)
        modelContext.saveOrLog()
        HealthKitManager.shared.saveFood(entry)
        return entry
    }

    func relog(_ saved: SavedFood, mealType: String, modelContext: ModelContext) -> FoodEntry {
        let entry = FoodEntry(
            name: saved.name, brand: saved.brand,
            calories: saved.calories, protein: saved.protein, carbs: saved.carbs, fat: saved.fat, fiber: saved.fiber,
            servingSizeG: saved.servingSizeG, servingDescription: saved.servingDescription,
            servingAmount: saved.defaultAmount, barcode: saved.barcode, mealType: mealType
        )
        entry.date = logDate(for: selectedDate)
        modelContext.insert(entry)
        modelContext.saveOrLog()
        HealthKitManager.shared.saveFood(entry)
        Haptics.success()
        return entry
    }

    /// Copies one meal from the day before the selected day. Returns how many entries were copied.
    @discardableResult
    func copyMealFromPreviousDay(_ meal: MealType, all entries: [FoodEntry], modelContext: ModelContext) -> Int {
        guard let previousDay = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) else { return 0 }
        let source = entriesForDate(previousDay, all: entries).filter { $0.mealType == meal.rawValue }
        for entry in source {
            _ = relog(entry, mealType: meal.rawValue, modelContext: modelContext)
        }
        if !source.isEmpty { Haptics.success() }
        return source.count
    }

    func delete(_ entry: FoodEntry, modelContext: ModelContext) {
        HealthKitManager.shared.deleteFood(id: entry.id)
        modelContext.delete(entry)
        modelContext.saveOrLog()
    }

    /// Entries logged for today use the current time; entries for past days use noon of that day.
    func logDate(for day: Date, now: Date = Date()) -> Date {
        let calendar = Calendar.current
        if calendar.isDate(day, inSameDayAs: now) { return now }
        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
    }

    // MARK: - Favorites

    func isFavorite(_ entry: FoodEntry, saved: [SavedFood]) -> Bool {
        saved.contains { $0.matchKey == entry.matchKey }
    }

    func toggleFavorite(_ entry: FoodEntry, saved: [SavedFood], modelContext: ModelContext) {
        let matches = saved.filter { $0.matchKey == entry.matchKey }
        if matches.isEmpty {
            modelContext.insert(SavedFood(from: entry))
        } else {
            matches.forEach { modelContext.delete($0) }
        }
        modelContext.saveOrLog()
        Haptics.selection()
    }

    // MARK: - Daily Stats

    func dailyStats(entries: [FoodEntry]) -> (calories: Double, protein: Double, carbs: Double, fat: Double) {
        Self.totals(for: entriesForDate(selectedDate, all: entries))
    }

    static func totals(for entries: [FoodEntry]) -> (calories: Double, protein: Double, carbs: Double, fat: Double) {
        (
            calories: entries.reduce(0) { $0 + $1.totalCalories },
            protein: entries.reduce(0) { $0 + $1.totalProtein },
            carbs: entries.reduce(0) { $0 + $1.totalCarbs },
            fat: entries.reduce(0) { $0 + $1.totalFat }
        )
    }

    func entriesForDate(_ date: Date, all entries: [FoodEntry]) -> [FoodEntry] {
        entries.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    /// Most recently logged distinct foods, newest first.
    static func recentFoods(from entries: [FoodEntry], limit: Int = 12) -> [FoodEntry] {
        var seen = Set<String>()
        var result: [FoodEntry] = []
        for entry in entries.sorted(by: { $0.date > $1.date }) where seen.insert(entry.matchKey).inserted {
            result.append(entry)
            if result.count == limit { break }
        }
        return result
    }
}

extension MealType {
    /// The meal a user is most likely logging at this time of day.
    static func suggested(at date: Date = Date()) -> MealType {
        switch Calendar.current.component(.hour, from: date) {
        case 4..<11: return .breakfast
        case 11..<15: return .lunch
        case 17..<22: return .dinner
        default: return .snack
        }
    }
}

extension ModelContext {
    /// Saves, logging instead of silently dropping any error.
    func saveOrLog(file: StaticString = #fileID, line: UInt = #line) {
        do {
            try save()
        } catch {
            print("SwiftData save failed at \(file):\(line): \(error)")
        }
    }
}
