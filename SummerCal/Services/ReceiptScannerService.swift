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
        let mimeType = detectMimeType(imageData)
        let base64Image = imageData.base64EncodedString()

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

        let urlString: String
        if let baseURL, !baseURL.isEmpty {
            urlString = baseURL.hasSuffix("/") ? "\(baseURL)v1/chat/completions" : "\(baseURL)/v1/chat/completions"
        } else {
            urlString = "https://api.openai.com/v1/chat/completions"
        }

        guard let url = URL(string: urlString) else {
            throw NSError(domain: "ReceiptScanner", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid API URL"])
        }

        let messages: [[String: Any]] = [
            [
                "role": "user",
                "content": [
                    ["type": "text", "text": prompt],
                    ["type": "image_url", "image_url": ["url": "data:\(mimeType);base64,\(base64Image)", "detail": "high"]]
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
            throw NSError(domain: "ReceiptScanner", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid image or unsupported format."])
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

    private func detectMimeType(_ data: Data) -> String {
        if data.count < 4 { return "image/jpeg" }
        let bytes = [UInt8](data.prefix(12))
        // JPEG: FF D8 FF
        if bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF {
            return "image/jpeg"
        }
        // PNG: 89 50 4E 47
        if bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 {
            return "image/png"
        }
        // HEIF/HEIC: ftyp box at offset 4
        if data.count >= 12 && bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70 {
            let subtype = String(bytes: [bytes[8], bytes[9], bytes[10], bytes[11]], encoding: .ascii) ?? ""
            if subtype == "heic" || subtype == "heix" { return "image/heic" }
            if subtype == "heif" || subtype == "heim" || subtype == "heis" || subtype == "hevc" { return "image/heif" }
        }
        return "image/jpeg" // fallback
    }
}
