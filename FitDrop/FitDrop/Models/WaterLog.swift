import Foundation
import SwiftData

@Model
final class WaterLog {
    var id: UUID = UUID()
    var date: Date = Date()
    var amountMl: Int = 250

    init(date: Date = Date(), amountMl: Int) {
        self.id = UUID()
        self.date = date
        self.amountMl = amountMl
    }
}
