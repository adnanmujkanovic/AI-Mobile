import Foundation

enum NumberFormatting {
    /// Parses user input that may use either "." or "," as the decimal separator.
    static func parseDecimal(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        guard !trimmed.isEmpty, let value = Double(trimmed), value.isFinite else { return nil }
        return value
    }

    /// Formats a number without trailing zeros, e.g. 1.5, 2, 0.25.
    static func decimal(_ value: Double, maxFractionDigits: Int = 1) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maxFractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    static func liters(fromMl ml: Int) -> String {
        decimal(Double(ml) / 1000, maxFractionDigits: 2) + " l"
    }
}
