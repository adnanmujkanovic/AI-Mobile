import SwiftUI
import SwiftData

@MainActor
class FoodViewModel: ObservableObject {
    @Published var searchQuery: String = ""
    @Published var searchResults: [OFFProduct] = []
    @Published var isSearching: Bool = false
    @Published var isBarcodeScanning: Bool = false
    @Published var scannedProduct: OFFProduct? = nil
    @Published var editingEntry: FoodEntryDraft? = nil
    @Published var errorMessage: String? = nil
    @Published var selectedDate: Date = Date()
    @Published var selectedMealType: String = MealType.lunch.rawValue

    struct FoodEntryDraft {
        var name: String
        var brand: String
        var calories: Double
        var protein: Double
        var carbs: Double
        var fat: Double
        var fiber: Double
        var servingSizeG: Double
        var servingDescription: String
        var servingAmount: Double
        var barcode: String
        var mealType: String

        init(from product: OFFProduct, mealType: String) {
            self.name = product.displayName
            self.brand = product.displayBrand
            self.calories = product.nutriments?.energyKcal100g ?? 0
            self.protein = product.nutriments?.proteins100g ?? 0
            self.carbs = product.nutriments?.carbohydrates100g ?? 0
            self.fat = product.nutriments?.fat100g ?? 0
            self.fiber = product.nutriments?.fiber100g ?? 0
            self.servingSizeG = 100
            self.servingDescription = product.servingSize ?? "100g"
            self.servingAmount = 1.0
            self.barcode = product.id
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
            self.servingSizeG = 100
            self.servingDescription = "100g"
            self.servingAmount = 1.0
            self.barcode = ""
            self.mealType = mealType
        }

        var totalCalories: Double { calories * servingAmount }
        var totalProtein: Double { protein * servingAmount }
        var totalCarbs: Double { carbs * servingAmount }
        var totalFat: Double { fat * servingAmount }
    }

    // MARK: - Search

    func searchFood() {
        guard !searchQuery.isEmpty else { return }
        isSearching = true
        errorMessage = nil
        Task {
            do {
                let results = try await OpenFoodFactsService.shared.searchProducts(query: searchQuery)
                self.searchResults = results
            } catch {
                self.errorMessage = error.localizedDescription
                self.searchResults = []
            }
            self.isSearching = false
        }
    }

    // MARK: - Barcode

    func handleBarcode(_ barcode: String) {
        isBarcodeScanning = false
        isSearching = true
        errorMessage = nil
        Task {
            do {
                let product = try await OpenFoodFactsService.shared.fetchProduct(barcode: barcode)
                self.scannedProduct = product
                self.editingEntry = FoodEntryDraft(from: product, mealType: selectedMealType)
            } catch {
                self.errorMessage = "Product not found: \(error.localizedDescription)"
            }
            self.isSearching = false
        }
    }

    func selectProduct(_ product: OFFProduct) {
        editingEntry = FoodEntryDraft(from: product, mealType: selectedMealType)
    }

    func startManualEntry() {
        editingEntry = FoodEntryDraft(name: "", mealType: selectedMealType)
    }

    // MARK: - Log Food

    func logFood(modelContext: ModelContext) {
        guard let draft = editingEntry else { return }
        let entry = FoodEntry(
            name: draft.name,
            brand: draft.brand,
            calories: draft.calories,
            protein: draft.protein,
            carbs: draft.carbs,
            fat: draft.fat,
            fiber: draft.fiber,
            servingSizeG: draft.servingSizeG,
            servingDescription: draft.servingDescription,
            servingAmount: draft.servingAmount,
            barcode: draft.barcode,
            mealType: draft.mealType
        )
        entry.date = selectedDate
        modelContext.insert(entry)
        try? modelContext.save()
        editingEntry = nil
        scannedProduct = nil
    }

    // MARK: - Daily Stats

    func dailyStats(entries: [FoodEntry]) -> (calories: Double, protein: Double, carbs: Double, fat: Double) {
        let dayEntries = entries.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
        return (
            calories: dayEntries.reduce(0) { $0 + $1.totalCalories },
            protein: dayEntries.reduce(0) { $0 + $1.totalProtein },
            carbs: dayEntries.reduce(0) { $0 + $1.totalCarbs },
            fat: dayEntries.reduce(0) { $0 + $1.totalFat }
        )
    }

    func entriesForDate(_ date: Date, all entries: [FoodEntry]) -> [FoodEntry] {
        entries.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    func isWithinEatingWindow(profile: UserProfile?) -> Bool {
        guard let profile else { return true }
        let now = Date()
        let calendar = Calendar.current
        let startHour = profile.fastingStartHour
        let startMin = profile.fastingStartMinute
        let duration = profile.fastingDuration
        let windowDuration = 24 - duration

        guard let todayStart = calendar.date(
            bySettingHour: startHour, minute: startMin, second: 0, of: now
        ) else { return true }

        // Eating window starts after fasting duration
        var eatStart = todayStart.addingTimeInterval(TimeInterval(duration * 3600))
        if eatStart > now {
            eatStart = eatStart.addingTimeInterval(-86400)
        }
        let eatEnd = eatStart.addingTimeInterval(TimeInterval(windowDuration * 3600))
        return now >= eatStart && now <= eatEnd
    }
}
