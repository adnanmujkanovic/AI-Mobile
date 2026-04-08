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

struct OFFSearchResponse: Codable {
    let products: [OFFProduct]
    let count: Int?
}

struct OFFProductResponse: Codable {
    let product: OFFProduct?
    let status: Int
}

struct OFFProduct: Codable, Identifiable {
    let id: String
    let productName: String?
    let brands: String?
    let nutriments: OFFNutriments?
    let servingSize: String?
    let imageSmallUrl: String?

    var displayName: String {
        productName ?? "Unknown Product"
    }

    var displayBrand: String {
        brands?.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? ""
    }

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case productName = "product_name"
        case brands
        case nutriments
        case servingSize = "serving_size"
        case imageSmallUrl = "image_small_url"
    }
}

struct OFFNutriments: Codable {
    let energyKcal100g: Double?
    let proteins100g: Double?
    let carbohydrates100g: Double?
    let fat100g: Double?
    let fiber100g: Double?

    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case proteins100g = "proteins_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case fat100g = "fat_100g"
        case fiber100g = "fiber_100g"
    }
}
