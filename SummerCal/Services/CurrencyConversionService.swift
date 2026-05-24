import Foundation

struct CurrencyConversionResult {
    let originalAmount: Double
    let originalCurrency: String?
    let convertedAmount: Double
    let targetCurrency: String
    let exchangeRate: Double?
    let rateDate: String?

    var converted: Bool {
        guard let originalCurrency else { return false }
        return originalCurrency != targetCurrency && exchangeRate != nil
    }
}

enum CurrencyConversionError: LocalizedError {
    case invalidCurrency(String)
    case unavailable(String, String)

    var errorDescription: String? {
        switch self {
        case .invalidCurrency(let code):
            return "Invalid currency code: \(code)."
        case .unavailable(let from, let to):
            return "Could not convert \(from) to \(to). Check your connection or receipt currency."
        }
    }
}

final class CurrencyConversionService {
    private struct RateResponse: Decodable {
        let date: String?
        let base: String
        let quote: String
        let rate: Double
    }

    func convert(amount: Double, from sourceCurrency: String?, to targetCurrency: String) async throws -> CurrencyConversionResult {
        let target = try normalizedCurrency(targetCurrency)
        guard let sourceCurrency else {
            return CurrencyConversionResult(
                originalAmount: amount,
                originalCurrency: nil,
                convertedAmount: amount,
                targetCurrency: target,
                exchangeRate: nil,
                rateDate: nil
            )
        }

        let source = try normalizedCurrency(sourceCurrency)
        guard source != target else {
            return CurrencyConversionResult(
                originalAmount: amount,
                originalCurrency: source,
                convertedAmount: amount,
                targetCurrency: target,
                exchangeRate: nil,
                rateDate: nil
            )
        }

        guard let url = URL(string: "https://api.frankfurter.dev/v2/rate/\(source)/\(target)") else {
            throw CurrencyConversionError.unavailable(source, target)
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                throw CurrencyConversionError.unavailable(source, target)
            }

            let rateResponse = try JSONDecoder().decode(RateResponse.self, from: data)
            guard rateResponse.rate > 0 else {
                throw CurrencyConversionError.unavailable(source, target)
            }

            return CurrencyConversionResult(
                originalAmount: amount,
                originalCurrency: source,
                convertedAmount: amount * rateResponse.rate,
                targetCurrency: target,
                exchangeRate: rateResponse.rate,
                rateDate: rateResponse.date
            )
        } catch let error as CurrencyConversionError {
            throw error
        } catch {
            throw CurrencyConversionError.unavailable(source, target)
        }
    }

    private func normalizedCurrency(_ value: String) throws -> String {
        let cleaned = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: ".", with: "")

        let mapped: String
        switch cleaned {
        case "FT", "HUF": mapped = "HUF"
        case "$", "US$", "USD": mapped = "USD"
        case "€", "EUR": mapped = "EUR"
        case "£", "GBP": mapped = "GBP"
        default:
            let tokens = cleaned
                .split { !$0.isLetter }
                .map(String.init)
            if tokens.contains("HUF") || tokens.contains("FT") {
                mapped = "HUF"
            } else if tokens.contains("USD") {
                mapped = "USD"
            } else if tokens.contains("EUR") {
                mapped = "EUR"
            } else if tokens.contains("GBP") {
                mapped = "GBP"
            } else if let code = tokens.reversed().first(where: { $0.count == 3 }) {
                mapped = code
            } else {
                mapped = cleaned
            }
        }

        guard mapped.range(of: #"^[A-Z]{3}$"#, options: .regularExpression) != nil else {
            throw CurrencyConversionError.invalidCurrency(value)
        }

        return mapped
    }
}
