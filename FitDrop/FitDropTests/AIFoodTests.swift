import Foundation
import SwiftData
import Testing
import UIKit
@testable import FitDrop

struct AIFoodAnalyzerTests {
    private func body(of request: URLRequest) throws -> [String: Any] {
        let data = try #require(request.httpBody)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test func requestUsesMessagesAPIWithImageAndSchema() throws {
        let request = try AIFoodAnalyzer.makeRequest(imageJPEG: Data([0xFF, 0xD8]), description: "pola porcije", apiKey: "sk-ant-test")

        #expect(request.url?.absoluteString == "https://api.anthropic.com/v1/messages")
        #expect(request.value(forHTTPHeaderField: "x-api-key") == "sk-ant-test")
        #expect(request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        #expect(request.value(forHTTPHeaderField: "anthropic-beta") == "server-side-fallback-2026-07-01")

        let json = try body(of: request)
        #expect(json["model"] as? String == "claude-opus-5")
        #expect(json["fallbacks"] as? String == "default")
        let output = try #require(json["output_config"] as? [String: Any])
        let format = try #require(output["format"] as? [String: Any])
        #expect(format["type"] as? String == "json_schema")

        let message = try #require((json["messages"] as? [[String: Any]])?.first)
        let content = try #require(message["content"] as? [[String: Any]])
        #expect(content.first?["type"] as? String == "image")
        #expect((content.last?["text"] as? String)?.contains("pola porcije") == true)
    }

    @Test func textOnlyRequestHasNoImageBlock() throws {
        let json = try body(of: AIFoodAnalyzer.makeRequest(imageJPEG: nil, description: "burek sa mesom", apiKey: "k"))
        let content = try #require(((json["messages"] as? [[String: Any]])?.first)?["content"] as? [[String: Any]])
        #expect(content.count == 1)
        #expect(content.first?["type"] as? String == "text")
    }

    @Test func schemaObjectsDisallowExtraProperties() {
        let schema = AIFoodAnalyzer.outputSchema
        #expect(schema["additionalProperties"] as? Bool == false)
        let items = (schema["properties"] as? [String: Any])?["items"] as? [String: Any]
        let item = items?["items"] as? [String: Any]
        #expect(item?["additionalProperties"] as? Bool == false)
    }

    @Test func parsesAnswerAfterThinkingBlock() throws {
        let answer = #"{"meal_description":"Ćevapi u lepinji","items":[{"name":"Ćevapi","estimated_grams":200,"calories":520,"protein_g":36,"carbs_g":2,"fat_g":40,"confidence":"high"},{"name":"Lepinja (somun)","estimated_grams":120,"calories":330,"protein_g":10,"carbs_g":66,"fat_g":2,"confidence":"medium"}],"notes":"Assumed 10 pieces."}"#
        let response: [String: Any] = [
            "stop_reason": "end_turn",
            "content": [["type": "thinking", "thinking": ""], ["type": "text", "text": answer]],
        ]
        let estimate = try AIFoodAnalyzer.parseResponse(try JSONSerialization.data(withJSONObject: response))

        #expect(estimate.items.count == 2)
        #expect(estimate.items[0].name == "Ćevapi")
        #expect(estimate.totalCalories == 850)
        #expect(estimate.notes == "Assumed 10 pieces.")
    }

    @Test func refusalIsReportedNotParsed() throws {
        let response: [String: Any] = ["stop_reason": "refusal", "content": []]
        #expect(throws: AIFoodError.refused) {
            try AIFoodAnalyzer.parseResponse(try JSONSerialization.data(withJSONObject: response))
        }
    }

    @Test func truncatedOrEmptyAnswersFail() throws {
        let truncated: [String: Any] = ["stop_reason": "max_tokens", "content": [["type": "text", "text": "{\"meal"]]]
        #expect(throws: AIFoodError.unreadableResponse) {
            try AIFoodAnalyzer.parseResponse(try JSONSerialization.data(withJSONObject: truncated))
        }
        let empty: [String: Any] = ["stop_reason": "end_turn", "content": [["type": "text", "text": #"{"meal_description":"","items":[],"notes":"No food visible."}"#]]]
        #expect(throws: AIFoodError.noFoodFound) {
            try AIFoodAnalyzer.parseResponse(try JSONSerialization.data(withJSONObject: empty))
        }
    }

    @Test func readsAPIErrorMessage() {
        let data = Data(#"{"type":"error","error":{"type":"invalid_request_error","message":"bad image"}}"#.utf8)
        #expect(AIFoodAnalyzer.errorMessage(from: data) == "bad image")
    }

    @Test func downscalesLargePhotos() throws {
        let big = UIGraphicsImageRenderer(size: CGSize(width: 4000, height: 3000)).image { ctx in
            UIColor.orange.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 4000, height: 3000))
        }
        let data = try #require(AIFoodAnalyzer.preparedJPEG(from: big))
        let decoded = try #require(UIImage(data: data))
        #expect(max(decoded.size.width * decoded.scale, decoded.size.height * decoded.scale) <= 1568)
    }

    @Test func missingKeyThrowsBeforeNetwork() async {
        await #expect(throws: AIFoodError.missingAPIKey) {
            try await AIFoodAnalyzer().analyze(image: nil, description: "soup", apiKey: "")
        }
    }
}

struct AIFoodItemTests {
    let item = AIFoodItem(name: "Burek", estimatedGrams: 200, calories: 600, proteinG: 20, carbsG: 50, fatG: 36, confidence: "medium")

    @Test func scalesPortion() {
        let half = item.scaled(toGrams: 100)
        #expect(half.calories == 300)
        #expect(half.fatG == 18)
        #expect(half.id == item.id)
    }

    @Test func convertsToPer100g() {
        #expect(item.per100g.calories == 300)
        #expect(item.per100g.protein == 10)
    }
}

@MainActor
struct AIFoodLoggingTests {
    @Test func logsItemsAsEditablePer100gEntries() throws {
        let context = try TestSupport.makeContext()
        let vm = FoodViewModel()
        let items = [
            AIFoodItem(name: "Burek", estimatedGrams: 250, calories: 750, proteinG: 25, carbsG: 62, fatG: 45, confidence: "medium"),
            AIFoodItem(name: "Jogurt", estimatedGrams: 200, calories: 120, proteinG: 7, carbsG: 9, fatG: 6, confidence: "high"),
        ]

        let entries = vm.logAIItems(items, mealType: "Lunch", modelContext: context)

        #expect(entries.count == 2)
        let burek = try #require(entries.first)
        #expect(burek.amountLabel == "250 g")
        #expect(abs(burek.totalCalories - 750) < 0.001)
        #expect(burek.brand == "AI estimate")
        #expect(try context.fetchCount(FetchDescriptor<FoodEntry>()) == 2)
    }
}
