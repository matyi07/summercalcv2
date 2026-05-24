import Foundation
import UIKit

struct ReceiptExtraction: Codable {
    var merchantName: String?
    var date: String?
    var total: Double?
    var tax: Double?
    var currency: String?
    var lineItems: [String]?
    var category: String?
}

final class ReceiptScannerService {
    func scanReceipt(imageData: Data, provider: String, apiKey: String, model: String, baseURL: String?) async throws -> ReceiptExtraction {
        let normalizedImageData = try ReceiptImageNormalizer.jpegData(from: imageData)
        let base64Image = normalizedImageData.base64EncodedString()

        let prompt = """
        You are a receipt scanner. Extract the following information from this receipt image.
        Respond ONLY with a valid JSON object, no other text. Use null for missing fields.

        {
          "merchantName": "Store name",
          "date": "YYYY-MM-DD",
          "total": 0.00,
          "tax": 0.00,
          "currency": "USD",
          "lineItems": ["item1", "item2"],
          "category": "food|transport|shopping|health|utilities|housing|entertainment|other"
        }
        """

        guard let url = chatCompletionsURL(provider: provider, baseURL: baseURL) else {
            throw NSError(domain: "ReceiptScanner", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid API URL"])
        }

        let messages: [[String: Any]] = [
            [
                "role": "user",
                "content": [
                    ["type": "text", "text": prompt],
                    ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64Image)", "detail": "high"]]
                ]
            ]
        ]

        let requestBody: [String: Any] = [
            "model": model,
            "messages": messages,
            "max_tokens": 500,
            "temperature": 0.0
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "ReceiptScanner", code: 500, userInfo: [NSLocalizedDescriptionKey: "No response from server"])
        }

        switch httpResponse.statusCode {
        case 200: break
        case 401, 403:
            throw NSError(domain: "ReceiptScanner", code: 401, userInfo: [NSLocalizedDescriptionKey: "Invalid API key. Check AI Settings."])
        case 429:
            throw NSError(domain: "ReceiptScanner", code: 429, userInfo: [NSLocalizedDescriptionKey: "Rate limited. Try again in a minute."])
        case 400:
            let details = apiErrorMessage(from: data)
            let message = details.map {
                "Receipt scan was rejected by \(providerLabel(provider)) using \(model): \($0)"
            } ?? "Receipt scan was rejected. The app converted the photo to JPEG, so check that \(providerLabel(provider)) model \(model) supports image input."
            throw NSError(domain: "ReceiptScanner", code: 400, userInfo: [NSLocalizedDescriptionKey: message])
        case 404:
            throw NSError(domain: "ReceiptScanner", code: 404, userInfo: [NSLocalizedDescriptionKey: "API endpoint not found. Check the base URL in AI Settings."])
        default:
            throw NSError(domain: "ReceiptScanner", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error (\(httpResponse.statusCode)). Try again later."])
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw NSError(domain: "ReceiptScanner", code: 500, userInfo: [NSLocalizedDescriptionKey: "Unexpected response format"])
        }

        // Strip markdown code fences if present
        let jsonStr = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = jsonStr.data(using: .utf8) else {
            throw NSError(domain: "ReceiptScanner", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to parse AI response"])
        }

        let extraction = try JSONDecoder().decode(ReceiptExtraction.self, from: jsonData)
        return extraction
    }

    private func apiErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String,
           !message.isEmpty {
            return String(message.prefix(240))
        }

        if let message = json["message"] as? String, !message.isEmpty {
            return String(message.prefix(240))
        }

        return nil
    }

    private func chatCompletionsURL(provider: String, baseURL: String?) -> URL? {
        guard let baseURL, !baseURL.isEmpty, provider != "openAI" else {
            return URL(string: "https://api.openai.com/v1/chat/completions")
        }

        let trimmed = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if trimmed.hasSuffix("/chat/completions") {
            return URL(string: trimmed)
        }

        let path: String
        if provider == "google" || trimmed.hasSuffix("/openai") || trimmed.hasSuffix("/v1") {
            path = "chat/completions"
        } else {
            path = "v1/chat/completions"
        }

        return URL(string: "\(trimmed)/\(path)")
    }

    private func providerLabel(_ key: String) -> String {
        switch key {
        case "openAI": return "OpenAI"
        case "deepSeek": return "DeepSeek"
        case "anthropic": return "Anthropic"
        case "custom": return "Custom"
        case "google": return "Google AI"
        case "mistral": return "Mistral"
        default: return key
        }
    }
}
