import Foundation
import UIKit

/// One food Claude found in a photo or description, with its estimated portion.
struct AIFoodItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var estimatedGrams: Double
    var calories: Double
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var confidence: String

    enum CodingKeys: String, CodingKey {
        case name
        case estimatedGrams = "estimated_grams"
        case calories
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case confidence
    }

    /// Nutrition for 100 g, so the amount can be changed after the estimate.
    var per100g: (calories: Double, protein: Double, carbs: Double, fat: Double) {
        let factor = estimatedGrams > 0 ? 100 / estimatedGrams : 0
        return (calories * factor, proteinG * factor, carbsG * factor, fatG * factor)
    }

    /// Scales every value to a new portion size.
    func scaled(toGrams grams: Double) -> AIFoodItem {
        guard estimatedGrams > 0, grams > 0 else { return self }
        let factor = grams / estimatedGrams
        var copy = self
        copy.estimatedGrams = grams
        copy.calories = calories * factor
        copy.proteinG = proteinG * factor
        copy.carbsG = carbsG * factor
        copy.fatG = fatG * factor
        return copy
    }
}

struct AIFoodEstimate: Codable, Equatable {
    var mealDescription: String
    var items: [AIFoodItem]
    var notes: String

    enum CodingKeys: String, CodingKey {
        case mealDescription = "meal_description"
        case items
        case notes
    }

    var totalCalories: Double { items.reduce(0) { $0 + $1.calories } }
}

enum AIFoodError: LocalizedError, Equatable {
    case missingAPIKey
    case invalidAPIKey
    case rateLimited
    case overloaded
    case network(String)
    case refused
    case noFoodFound
    case unreadableResponse
    case server(Int, String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Add your Claude API key in Profile & Settings to use AI food recognition."
        case .invalidAPIKey: return "The Claude API key was rejected. Check it in Profile & Settings."
        case .rateLimited: return "Too many requests right now. Wait a moment and try again."
        case .overloaded: return "Claude is busy right now. Try again in a minute."
        case .network(let message): return "Couldn't reach Claude: \(message)"
        case .refused: return "Claude couldn't analyze this. Try another photo or describe the meal instead."
        case .noFoodFound: return "No food was recognized. Try a closer, well-lit photo, or describe the meal."
        case .unreadableResponse: return "The answer couldn't be read. Please try again."
        case .server(let code, let message): return "Claude returned an error (\(code)): \(message)"
        }
    }
}

/// Identifies foods and estimates portions and nutrition with Claude, from a photo and/or a description.
/// The app has no server, so requests go straight to the Claude API with the user's own key.
struct AIFoodAnalyzer {
    static let apiKeyKeychainKey = "claudeAPIKey"
    static let model = "claude-opus-5"
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    static var storedAPIKey: String? { KeychainStore.string(for: apiKeyKeychainKey) }
    static var isConfigured: Bool { !(storedAPIKey ?? "").isEmpty }

    var session: URLSession = .shared

    static let systemPrompt = """
    You are a nutrition assistant inside a calorie-tracking app. Identify every distinct food and drink \
    in the user's meal and estimate the portion actually present, in grams (use milliliters as grams for drinks), \
    and its calories, protein, carbohydrates and fat for that portion.

    Many users are in Bosnia and Herzegovina and the wider Balkans, so recognize regional dishes by their local \
    names (for example ćevapi, burek, pita krompiruša, sirnica, zeljanica, sogan-dolma, begova čorba, klepe, \
    lepinja/somun, kajmak, ajvar, baklava, tufahija) and use typical local recipes and portion sizes for them. \
    Give each item's name in the language the user wrote in if they wrote any text; otherwise use English \
    with the local name in parentheses where one exists.

    Estimate portion size from visual cues such as plate size, cutlery and hands. Count oil, butter, sauces \
    and dressings you can see or that the dish normally contains, since they add many calories. \
    If something is ambiguous, pick the most likely option, mark confidence as low, and say what you assumed in notes. \
    If there is no food in the photo, return an empty items list and explain in notes. Keep notes to one or two short sentences.
    """

    static let outputSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "meal_description": ["type": "string", "description": "Short name for the whole meal"],
            "items": [
                "type": "array",
                "items": [
                    "type": "object",
                    "properties": [
                        "name": ["type": "string"],
                        "estimated_grams": ["type": "number"],
                        "calories": ["type": "number"],
                        "protein_g": ["type": "number"],
                        "carbs_g": ["type": "number"],
                        "fat_g": ["type": "number"],
                        "confidence": ["type": "string", "enum": ["low", "medium", "high"]],
                    ],
                    "required": ["name", "estimated_grams", "calories", "protein_g", "carbs_g", "fat_g", "confidence"],
                    "additionalProperties": false,
                ],
            ],
            "notes": ["type": "string"],
        ],
        "required": ["meal_description", "items", "notes"],
        "additionalProperties": false,
    ]

    func analyze(image: UIImage?, description: String, apiKey: String? = AIFoodAnalyzer.storedAPIKey) async throws -> AIFoodEstimate {
        guard let apiKey, !apiKey.isEmpty else { throw AIFoodError.missingAPIKey }
        let imageData = image.flatMap { Self.preparedJPEG(from: $0) }
        let request = try Self.makeRequest(imageJPEG: imageData, description: description, apiKey: apiKey)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AIFoodError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw AIFoodError.unreadableResponse }
        switch http.statusCode {
        case 200: return try Self.parseResponse(data)
        case 401, 403: throw AIFoodError.invalidAPIKey
        case 429: throw AIFoodError.rateLimited
        case 529, 503: throw AIFoodError.overloaded
        default: throw AIFoodError.server(http.statusCode, Self.errorMessage(from: data))
        }
    }

    // MARK: - Request

    static func makeRequest(imageJPEG: Data?, description: String, apiKey: String) throws -> URLRequest {
        var content: [[String: Any]] = []
        if let imageJPEG {
            content.append([
                "type": "image",
                "source": ["type": "base64", "media_type": "image/jpeg", "data": imageJPEG.base64EncodedString()],
            ])
        }
        let note = description.trimmingCharacters(in: .whitespacesAndNewlines)
        var text = imageJPEG == nil ? "Estimate the nutrition of this meal." : "Identify the foods in this photo and estimate their nutrition."
        if !note.isEmpty { text += "\n\nThe user says: \(note)" }
        content.append(["type": "text", "text": text])

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 16000,
            "system": systemPrompt,
            // Someone is waiting with the camera open, so keep reasoning moderate
            "output_config": [
                "effort": "medium",
                "format": ["type": "json_schema", "schema": outputSchema],
            ],
            // If a safety classifier wrongly declines, the API retries on its recommended model
            "fallbacks": "default",
            "messages": [["role": "user", "content": content]],
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    /// Downscales to at most 1568 px on the long edge (larger images cost more and aren't more accurate) and encodes JPEG.
    static func preparedJPEG(from image: UIImage, maxDimension: CGFloat = 1568) -> Data? {
        let size = image.size
        let longest = max(size.width, size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }

    // MARK: - Response

    static func parseResponse(_ data: Data) throws -> AIFoodEstimate {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIFoodError.unreadableResponse
        }
        // Check the stop reason before reading content: a refusal may not match the schema
        let stopReason = json["stop_reason"] as? String
        if stopReason == "refusal" { throw AIFoodError.refused }
        if stopReason == "max_tokens" { throw AIFoodError.unreadableResponse }

        // Content can start with thinking blocks; the JSON answer is in the text block
        let blocks = json["content"] as? [[String: Any]] ?? []
        let text = blocks.filter { $0["type"] as? String == "text" }.compactMap { $0["text"] as? String }.joined()
        guard let textData = text.data(using: .utf8),
              var estimate = try? JSONDecoder().decode(AIFoodEstimate.self, from: textData) else {
            throw AIFoodError.unreadableResponse
        }
        estimate.items = estimate.items.filter { $0.estimatedGrams > 0 && $0.calories >= 0 }
        if estimate.items.isEmpty { throw AIFoodError.noFoodFound }
        return estimate
    }

    static func errorMessage(from data: Data) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any],
              let message = error["message"] as? String else {
            return String(data: data, encoding: .utf8) ?? "Unknown error"
        }
        return message
    }
}
