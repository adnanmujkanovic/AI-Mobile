import Foundation
import SwiftData
import Testing
@testable import FitDrop

struct OpenFoodFactsDecodingTests {
    @Test func decodesV3ProductWithStringStatus() throws {
        let product = try OpenFoodFactsService.decodeProduct(Data(OFFFixtures.productV3.utf8), barcode: "3017620422003")

        #expect(product.code == "3017620422003")
        #expect(product.displayName.contains("Nutella"))
        #expect(product.displayBrand == "Nutella")
        #expect(product.nutriments?.energyKcal100g == 539)
        #expect(product.nutriments?.proteins100g == 6.3)
    }

    @Test func missingProductThrowsNotFound() {
        #expect(throws: OFFError.self) {
            try OpenFoodFactsService.decodeProduct(Data(OFFFixtures.productMissing.utf8), barcode: "0000000000000")
        }
    }

    @Test func decodesSearchResultsWithoutUnderscoreID() throws {
        let products = try OpenFoodFactsService.decodeSearch(Data(OFFFixtures.search.utf8))

        #expect(products.count == 5)
        #expect(Set(products.map(\.id)).count == products.count)
        #expect(products.allSatisfy { $0.nutriments?.energyKcal100g != nil })
        #expect(products[1].servingGrams == 200)
    }

    @Test func searchDropsDuplicatesAndProductsWithoutCalories() throws {
        let json = #"{"count":"3","products":[{"code":"1","product_name":"A","nutriments":{"energy-kcal_100g":"52"}},{"code":"1","product_name":"A","nutriments":{"energy-kcal_100g":52}},{"code":"2","product_name":"B","nutriments":{}}]}"#
        let products = try OpenFoodFactsService.decodeSearch(Data(json.utf8))

        #expect(products.count == 1)
        #expect(products.first?.nutriments?.energyKcal100g == 52)
    }

    @Test(arguments: [
        ("100 gram", 100.0),
        ("1 portion (30 g)", 30.0),
        ("1 bar (47,5g)", 47.5),
        ("250 ml", 250.0),
        ("2 slices", nil),
    ] as [(String, Double?)])
    func parsesServingGrams(text: String, expected: Double?) {
        #expect(OFFProduct.parseGrams(text) == expected)
    }
}

struct NumberFormattingTests {
    @Test func parsesCommaAndDotDecimals() {
        #expect(NumberFormatting.parseDecimal("72,5") == 72.5)
        #expect(NumberFormatting.parseDecimal(" 80.25 ") == 80.25)
        #expect(NumberFormatting.parseDecimal("") == nil)
        #expect(NumberFormatting.parseDecimal("abc") == nil)
    }

    @Test func amountLabels() {
        #expect(FoodEntry.amountLabel(amount: 1.5, unit: "100g") == "150 g")
        #expect(FoodEntry.amountLabel(amount: 2, unit: "slice") == "2 × slice")
    }
}

@MainActor
struct FoodViewModelTests {
    let context: ModelContext
    let vm = FoodViewModel()

    init() throws {
        context = try TestSupport.makeContext()
    }

    private func product(kcal: Double, protein: Double = 10, serving: Double? = nil) -> OFFProduct {
        OFFProduct(
            code: "123",
            productName: "Oats",
            brands: "Brand, Other",
            nutriments: OFFNutriments(energyKcal100g: kcal, proteins100g: protein, carbohydrates100g: 60, fat100g: 7),
            servingQuantity: serving
        )
    }

    @Test func productDraftUsesGramsAndTypicalServing() {
        var draft = FoodViewModel.FoodEntryDraft(from: product(kcal: 380, serving: 40), mealType: "Breakfast")

        #expect(draft.basis == .per100g)
        #expect(draft.quantity == 40)
        #expect(draft.totalCalories == 152)

        draft.quantity = 150
        #expect(draft.totalCalories == 570)
        #expect(draft.totalProtein == 15)
    }

    @Test func savingStoresMultiplierAndRoundTripsForEditing() throws {
        var draft = FoodViewModel.FoodEntryDraft(from: product(kcal: 380), mealType: "Breakfast")
        draft.quantity = 60
        let entry = try #require(vm.save(draft, modelContext: context))

        #expect(entry.servingDescription == "100g")
        #expect(abs(entry.servingAmount - 0.6) < 0.0001)
        #expect(abs(entry.totalCalories - 228) < 0.001)
        #expect(entry.amountLabel == "60 g")
        #expect(entry.brand == "Brand")

        var edit = FoodViewModel.FoodEntryDraft(entry: entry)
        #expect(edit.basis == .per100g)
        #expect(abs(edit.quantity - 60) < 0.0001)
        edit.quantity = 100
        edit.mealType = "Snack"
        _ = vm.save(edit, modelContext: context)

        let all = try context.fetch(FetchDescriptor<FoodEntry>())
        #expect(all.count == 1)
        #expect(all.first?.mealType == "Snack")
        #expect(abs((all.first?.totalCalories ?? 0) - 380) < 0.001)
    }

    @Test func manualEntryUsesServings() throws {
        var draft = FoodViewModel.FoodEntryDraft(name: "Toast", mealType: "Breakfast")
        draft.calories = 90
        draft.quantity = 2
        draft.servingLabel = "slice"
        let entry = try #require(vm.save(draft, modelContext: context))

        #expect(entry.totalCalories == 180)
        #expect(entry.amountLabel == "2 × slice")
    }

    @Test func invalidDraftIsNotSaved() throws {
        let draft = FoodViewModel.FoodEntryDraft(name: "   ", mealType: "Lunch")
        #expect(vm.save(draft, modelContext: context) == nil)
        #expect(try context.fetchCount(FetchDescriptor<FoodEntry>()) == 0)
    }

    @Test func quickAddLogsCaloriesOnly() throws {
        let entry = try #require(vm.quickAdd(calories: 650, protein: 30, name: "", mealType: "Dinner", modelContext: context))

        #expect(entry.name == "Quick add")
        #expect(entry.totalCalories == 650)
        #expect(entry.totalProtein == 30)
        #expect(vm.quickAdd(calories: 0, protein: 0, name: "x", mealType: "Dinner", modelContext: context) == nil)
    }

    @Test func copiesMealFromPreviousDay() throws {
        vm.selectedDate = TestSupport.day(-1)
        _ = vm.quickAdd(calories: 300, protein: 0, name: "Eggs", mealType: "Breakfast", modelContext: context)
        _ = vm.quickAdd(calories: 100, protein: 0, name: "Coffee", mealType: "Breakfast", modelContext: context)
        _ = vm.quickAdd(calories: 500, protein: 0, name: "Pasta", mealType: "Dinner", modelContext: context)

        vm.selectedDate = Date()
        let all = try context.fetch(FetchDescriptor<FoodEntry>())
        let copied = vm.copyMealFromPreviousDay(.breakfast, all: all, modelContext: context)

        #expect(copied == 2)
        let today = vm.entriesForDate(Date(), all: try context.fetch(FetchDescriptor<FoodEntry>()))
        #expect(today.count == 2)
        #expect(FoodViewModel.totals(for: today).calories == 400)
    }

    @Test func pastDaysAreLoggedAtNoon() {
        let yesterday = TestSupport.day(-1, hour: 22)
        let logged = vm.logDate(for: yesterday)
        #expect(Calendar.current.component(.hour, from: logged) == 12)
        #expect(Calendar.current.isDate(logged, inSameDayAs: yesterday))
    }

    @Test func recentFoodsAreDistinctAndNewestFirst() {
        let old = FoodEntry(name: "Apple", calories: 52, protein: 0, carbs: 14, fat: 0)
        old.date = TestSupport.day(-2)
        let newer = FoodEntry(name: "apple ", calories: 52, protein: 0, carbs: 14, fat: 0)
        newer.date = TestSupport.day(-1)
        let banana = FoodEntry(name: "Banana", calories: 89, protein: 1, carbs: 23, fat: 0)
        banana.date = TestSupport.day(0)

        let recents = FoodViewModel.recentFoods(from: [old, newer, banana])

        #expect(recents.map(\.name) == ["Banana", "apple "])
    }

    @Test func togglingFavoriteAddsAndRemovesSavedFood() throws {
        let entry = try #require(vm.quickAdd(calories: 200, protein: 20, name: "Shake", mealType: "Snack", modelContext: context))

        vm.toggleFavorite(entry, saved: [], modelContext: context)
        let saved = try context.fetch(FetchDescriptor<SavedFood>())
        #expect(saved.count == 1)
        #expect(vm.isFavorite(entry, saved: saved))

        vm.toggleFavorite(entry, saved: saved, modelContext: context)
        #expect(try context.fetchCount(FetchDescriptor<SavedFood>()) == 0)
    }

    @Test func deleteRemovesEntry() throws {
        let entry = try #require(vm.quickAdd(calories: 200, protein: 0, name: "Chips", mealType: "Snack", modelContext: context))
        vm.delete(entry, modelContext: context)
        #expect(try context.fetchCount(FetchDescriptor<FoodEntry>()) == 0)
    }

    @Test(arguments: [(7, MealType.breakfast), (12, .lunch), (16, .snack), (19, .dinner), (23, .snack)])
    func suggestsMealByTimeOfDay(hour: Int, expected: MealType) {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!
        #expect(MealType.suggested(at: date) == expected)
    }
}
