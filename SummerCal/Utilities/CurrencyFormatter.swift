import Foundation

enum CurrencyFormatter {
    static var numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        return f
    }()
    
    static func format(_ amount: Double, currency: String = "USD") -> String {
        numberFormatter.currencyCode = currency
        return numberFormatter.string(from: NSNumber(value: amount)) ?? "$\(String(format: "%.2f", amount))"
    }
    
    static func formatCompact(_ amount: Double, currency: String = "USD") -> String {
        if amount >= 1000 {
            numberFormatter.currencyCode = currency
            let k = amount / 1000
            let symbol = numberFormatter.currencySymbol ?? "$"
            return "\(symbol)\(String(format: "%.1f", k))K"
        }
        return format(amount, currency: currency)
    }
    
    static func parse(_ string: String) -> Double {
        let cleaned = string.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
        return Double(cleaned) ?? 0
    }
}
