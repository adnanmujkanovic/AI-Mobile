import Foundation
import SwiftData

@Model
final class FoodEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    var name: String = ""
    var brand: String = ""
    var calories: Double = 0.0
    var protein: Double = 0.0
    var carbs: Double = 0.0
    var fat: Double = 0.0
    var fiber: Double = 0.0
    var servingSizeG: Double = 100.0
    var servingDescription: String = "100g"
    var servingAmount: Double = 1.0
    var barcode: String = ""
    var mealType: String = "Lunch"

    init(
        name: String,
        brand: String = "",
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        fiber: Double = 0,
        servingSizeG: Double = 100,
        servingDescription: String = "100g",
        servingAmount: Double = 1.0,
        barcode: String = "",
        mealType: String = "Lunch"
    ) {
        self.id = UUID()
        self.date = Date()
        self.name = name
        self.brand = brand
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.servingSizeG = servingSizeG
        self.servingDescription = servingDescription
        self.servingAmount = servingAmount
        self.barcode = barcode
        self.mealType = mealType
    }

    var totalCalories: Double { calories * servingAmount }
    var totalProtein: Double { protein * servingAmount }
    var totalCarbs: Double { carbs * servingAmount }
    var totalFat: Double { fat * servingAmount }
}

enum MealType: String, CaseIterable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case snack = "Snack"

    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.fill"
        case .snack: return "leaf.fill"
        }
    }
}

// MARK: - Open Food Facts Models

/// Only `products` is read; other fields such as `count` arrive as strings or numbers depending on the server.
struct OFFSearchResponse: Codable {
    let products: [OFFProduct]
}

/// v3 product response. `status` is "success"/"failure" in v3 but was 1/0 in v2, so it isn't decoded.
struct OFFProductResponse: Codable {
    let code: String?
    let product: OFFProduct?
}

struct OFFProduct: Codable, Identifiable {
    let code: String?
    let productName: String?
    let brands: String?
    let nutriments: OFFNutriments?
    let servingSize: String?
    let servingQuantity: Double?
    let imageSmallUrl: String?

    init(
        code: String?,
        productName: String?,
        brands: String? = nil,
        nutriments: OFFNutriments? = nil,
        servingSize: String? = nil,
        servingQuantity: Double? = nil,
        imageSmallUrl: String? = nil
    ) {
        self.code = code
        self.productName = productName
        self.brands = brands
        self.nutriments = nutriments
        self.servingSize = servingSize
        self.servingQuantity = servingQuantity
        self.imageSmallUrl = imageSmallUrl
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = try? c.decodeIfPresent(String.self, forKey: .code)
        productName = try? c.decodeIfPresent(String.self, forKey: .productName)
        brands = try? c.decodeIfPresent(String.self, forKey: .brands)
        nutriments = try? c.decodeIfPresent(OFFNutriments.self, forKey: .nutriments)
        servingSize = try? c.decodeIfPresent(String.self, forKey: .servingSize)
        servingQuantity = OFFNutriments.flexibleDouble(c, .servingQuantity)
        imageSmallUrl = try? c.decodeIfPresent(String.self, forKey: .imageSmallUrl)
    }

    var id: String { code ?? FoodEntry.matchKey(name: displayName, brand: displayBrand) }

    var displayName: String {
        let name = productName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "Unknown Product" : name
    }

    var displayBrand: String {
        brands?.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? ""
    }

    /// Grams in one serving, from `serving_quantity` or parsed from text like "1 bar (30 g)".
    var servingGrams: Double? {
        if let servingQuantity, servingQuantity > 0 { return servingQuantity }
        guard let servingSize else { return nil }
        return OFFProduct.parseGrams(servingSize)
    }

    static func parseGrams(_ text: String) -> Double? {
        let pattern = #"(\d+(?:[.,]\d+)?)\s*(grams?|gr|g|ml)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return NumberFormatting.parseDecimal(String(text[range]))
    }

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case brands
        case nutriments
        case servingSize = "serving_size"
        case servingQuantity = "serving_quantity"
        case imageSmallUrl = "image_small_url"
    }
}

struct OFFNutriments: Codable {
    let energyKcal100g: Double?
    let proteins100g: Double?
    let carbohydrates100g: Double?
    let fat100g: Double?
    let fiber100g: Double?

    init(energyKcal100g: Double?, proteins100g: Double? = nil, carbohydrates100g: Double? = nil, fat100g: Double? = nil, fiber100g: Double? = nil) {
        self.energyKcal100g = energyKcal100g
        self.proteins100g = proteins100g
        self.carbohydrates100g = carbohydrates100g
        self.fat100g = fat100g
        self.fiber100g = fiber100g
    }

    // Open Food Facts sometimes sends numbers as strings, so each value is decoded leniently.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        energyKcal100g = Self.flexibleDouble(c, .energyKcal100g)
        proteins100g = Self.flexibleDouble(c, .proteins100g)
        carbohydrates100g = Self.flexibleDouble(c, .carbohydrates100g)
        fat100g = Self.flexibleDouble(c, .fat100g)
        fiber100g = Self.flexibleDouble(c, .fiber100g)
    }

    static func flexibleDouble<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> Double? {
        if let value = try? c.decodeIfPresent(Double.self, forKey: key) { return value }
        if let text = try? c.decodeIfPresent(String.self, forKey: key) { return NumberFormatting.parseDecimal(text) }
        return nil
    }

    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case proteins100g = "proteins_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case fat100g = "fat_100g"
        case fiber100g = "fiber_100g"
    }
}

// MARK: - Saved Foods

/// A favorite food the user can log again with one tap.
@Model
final class SavedFood {
    var id: UUID = UUID()
    var name: String = ""
    var brand: String = ""
    var calories: Double = 0.0
    var protein: Double = 0.0
    var carbs: Double = 0.0
    var fat: Double = 0.0
    var fiber: Double = 0.0
    var servingSizeG: Double = 100.0
    var servingDescription: String = "100g"
    var defaultAmount: Double = 1.0
    var barcode: String = ""
    var createdAt: Date = Date()

    init(from entry: FoodEntry) {
        self.id = UUID()
        self.name = entry.name
        self.brand = entry.brand
        self.calories = entry.calories
        self.protein = entry.protein
        self.carbs = entry.carbs
        self.fat = entry.fat
        self.fiber = entry.fiber
        self.servingSizeG = entry.servingSizeG
        self.servingDescription = entry.servingDescription
        self.defaultAmount = entry.servingAmount
        self.barcode = entry.barcode
        self.createdAt = Date()
    }

    var matchKey: String { FoodEntry.matchKey(name: name, brand: brand) }
    var totalCalories: Double { calories * defaultAmount }
}

extension FoodEntry {
    /// Identifies "the same food" across log entries, ignoring case and spacing.
    static func matchKey(name: String, brand: String) -> String {
        let clean: (String) -> String = { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        return clean(name) + "|" + clean(brand)
    }

    var matchKey: String { FoodEntry.matchKey(name: name, brand: brand) }

    /// True when the nutrition values are per 100 g and the amount is a multiple of 100 g.
    var isPer100g: Bool { FoodEntry.isPer100gUnit(servingDescription) }

    static func isPer100gUnit(_ description: String) -> Bool {
        description.replacingOccurrences(of: " ", with: "").lowercased() == "100g"
    }

    /// Human-readable amount, e.g. "150 g" or "1.5 × slice".
    var amountLabel: String {
        FoodEntry.amountLabel(amount: servingAmount, unit: servingDescription)
    }

    static func amountLabel(amount: Double, unit: String) -> String {
        if isPer100gUnit(unit) {
            return "\(NumberFormatting.decimal(amount * 100, maxFractionDigits: 0)) g"
        }
        return "\(NumberFormatting.decimal(amount, maxFractionDigits: 2)) × \(unit)"
    }
}
