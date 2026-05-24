import Foundation
import UIKit
import Vision

struct ReceiptExtraction: Codable {
    var merchantName: String?
    var date: String?
    var total: Double?
    var tax: Double?
    var currency: String?
    var lineItems: [String]?
    var category: String?
    var paymentMethod: String?
}

private struct ReceiptScanRequestPayload {
    var messages: [[String: Any]]
    var fallbackText: String?
    var usesImageInput: Bool
}

final class ReceiptScannerService {
    func scanReceipt(imageData: Data, provider: String, apiKey: String, model: String, baseURL: String?) async throws -> ReceiptExtraction {
        let normalizedImageData = try ReceiptImageNormalizer.jpegData(from: imageData)

        guard let url = chatCompletionsURL(provider: provider, baseURL: baseURL) else {
            throw NSError(domain: "ReceiptScanner", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid API URL"])
        }

        let payload = try await requestPayload(
            for: normalizedImageData,
            provider: provider,
            model: model
        )

        var requestBody: [String: Any] = [
            "model": model,
            "messages": payload.messages,
            "max_tokens": 800,
            "temperature": 0.0
        ]
        if shouldRequestJSONMode(provider: provider, model: model, usesImageInput: payload.usesImageInput) {
            requestBody["response_format"] = ["type": "json_object"]
        }
        if provider == "deepSeek" {
            requestBody["thinking"] = ["type": "disabled"]
        }

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

        return try decodeExtraction(from: content, fallbackText: payload.fallbackText)
    }

    private func requestPayload(for imageData: Data, provider: String, model: String) async throws -> ReceiptScanRequestPayload {
        let prompt = receiptExtractionPrompt(inputDescription: "this receipt image")
        let systemMessage: [String: Any] = [
            "role": "system",
            "content": "You extract receipt data. Return only one valid JSON object and no prose."
        ]

        guard supportsImageInput(provider: provider, model: model) else {
            let recognizedText = try await recognizeText(from: imageData)
            let messages: [[String: Any]] = [
                systemMessage,
                [
                    "role": "user",
                    "content": receiptExtractionPrompt(inputDescription: "the OCR text below") + "\n\nOCR text:\n\(recognizedText)"
                ]
            ]
            return ReceiptScanRequestPayload(messages: messages, fallbackText: recognizedText, usesImageInput: false)
        }

        let messages: [[String: Any]] = [
            systemMessage,
            [
                "role": "user",
                "content": [
                    ["type": "text", "text": prompt],
                    ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(imageData.base64EncodedString())", "detail": "high"]]
                ]
            ]
        ]
        return ReceiptScanRequestPayload(messages: messages, fallbackText: nil, usesImageInput: true)
    }

    private func receiptExtractionPrompt(inputDescription: String) -> String {
        """
        You are a receipt scanner. Extract the following information from \(inputDescription).
        Respond ONLY with a valid JSON object, no markdown or explanatory text. Use null for missing fields.
        total and tax must be JSON numbers without currency symbols. lineItems must be an array of strings.
        paymentMethod must be "cash", "card", "transfer", or "direct debit".
        Hungarian payment labels: KÉSZPÉNZ means cash, BANKKÁRTYA means card.
        Categorize using: housing, utilities, food, transport, health, entertainment, shopping, subscription, travel, education, other.

        {
          "merchantName": "Store name",
          "date": "YYYY-MM-DD",
          "total": 0.00,
          "tax": 0.00,
          "currency": "USD",
          "lineItems": ["item1", "item2"],
          "category": "food",
          "paymentMethod": "card"
        }
        """
    }

    private func supportsImageInput(provider: String, model: String) -> Bool {
        let normalizedModel = model.lowercased()

        if provider == "deepSeek" { return false }
        if provider == "anthropic" { return false }
        if normalizedModel.contains("deepseek") { return false }
        if normalizedModel.contains("gpt-3.5") { return false }
        if normalizedModel == "gpt-4" { return false }
        if normalizedModel.contains("o1") { return false }
        if provider == "mistral" {
            return normalizedModel.contains("pixtral") || normalizedModel.contains("vision")
        }
        if provider == "openAI" {
            return normalizedModel.contains("gpt-4o")
                || normalizedModel.contains("gpt-4.1")
                || normalizedModel.contains("gpt-4-turbo")
                || normalizedModel.contains("vision")
        }
        if provider == "google" {
            return normalizedModel.contains("gemini")
        }

        return false
    }

    private func shouldRequestJSONMode(provider: String, model: String, usesImageInput: Bool) -> Bool {
        if usesImageInput { return false }
        let normalizedModel = model.lowercased()

        if provider == "deepSeek" || normalizedModel.contains("deepseek") {
            return true
        }
        if provider == "openAI" {
            return true
        }

        return false
    }

    private func recognizeText(from imageData: Data) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(data: imageData, options: [:])
            try handler.perform([request])

            let lines = (request.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            let text = lines.joined(separator: "\n")
            guard !text.isEmpty else {
                throw NSError(
                    domain: "ReceiptScanner",
                    code: 422,
                    userInfo: [NSLocalizedDescriptionKey: "Could not read text from this receipt photo. Try a clearer, well-lit photo or use an image-capable AI provider."]
                )
            }

            return text
        }.value
    }

    private func decodeExtraction(from content: String, fallbackText: String?) throws -> ReceiptExtraction {
        let cleaned = stripCodeFences(content)
        guard let jsonString = firstJSONObject(in: cleaned),
              let jsonData = jsonString.data(using: .utf8) else {
            if let fallback = heuristicExtraction(from: cleaned) ?? heuristicExtraction(from: fallbackText) {
                return fallback
            }
            throw parseError("AI returned text instead of a JSON receipt object: \(preview(cleaned))")
        }

        do {
            let object = try JSONSerialization.jsonObject(with: jsonData)
            if let dict = object as? [String: Any] {
                return try validated(extraction(from: receiptDictionary(from: dict)), source: jsonString)
            }
            if let array = object as? [[String: Any]], let first = array.first {
                return try validated(extraction(from: receiptDictionary(from: first)), source: jsonString)
            }
            throw parseError("AI returned JSON, but not a receipt object: \(preview(jsonString))")
        } catch let error as NSError where error.domain == "ReceiptScanner" {
            if let fallback = heuristicExtraction(from: cleaned) ?? heuristicExtraction(from: fallbackText) {
                return fallback
            }
            throw error
        } catch {
            if let fallback = heuristicExtraction(from: cleaned) ?? heuristicExtraction(from: fallbackText) {
                return fallback
            }
            throw parseError("AI returned malformed JSON: \(preview(jsonString))")
        }
    }

    private func extraction(from dict: [String: Any]) -> ReceiptExtraction {
        ReceiptExtraction(
            merchantName: optionalString(firstValue(in: dict, keys: ["merchantName", "merchant", "storeName", "vendor", "businessName"])),
            date: normalizedDate(optionalString(firstValue(in: dict, keys: ["date", "receiptDate", "purchaseDate", "transactionDate"])) ?? ""),
            total: optionalDouble(firstValue(in: dict, keys: ["total", "amount", "grandTotal", "totalAmount", "balanceDue", "paid"])),
            tax: optionalDouble(firstValue(in: dict, keys: ["tax", "salesTax", "vat", "taxAmount"])),
            currency: optionalString(firstValue(in: dict, keys: ["currency", "currencyCode"])),
            lineItems: optionalLineItems(firstValue(in: dict, keys: ["lineItems", "items", "products", "charges"])),
            category: normalizedCategory(optionalString(firstValue(in: dict, keys: ["category", "expenseCategory", "purchaseCategory"]))),
            paymentMethod: normalizedPaymentMethod(optionalString(firstValue(in: dict, keys: ["paymentMethod", "payment", "method", "tender", "paymentType", "fizetesiMod"])))
        )
    }

    private func validated(_ extraction: ReceiptExtraction, source: String) throws -> ReceiptExtraction {
        if hasUsableData(extraction) {
            return extraction
        }

        throw parseError("AI JSON did not include recognizable receipt fields: \(preview(source))")
    }

    private func hasUsableData(_ extraction: ReceiptExtraction) -> Bool {
        extraction.merchantName != nil ||
            extraction.date != nil ||
            extraction.total != nil ||
            extraction.tax != nil ||
            extraction.currency != nil ||
            extraction.lineItems?.isEmpty == false ||
            extraction.category != nil ||
            extraction.paymentMethod != nil
    }

    private func heuristicExtraction(from text: String?) -> ReceiptExtraction? {
        guard let text else { return nil }
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return nil }

        let extraction = ReceiptExtraction(
            merchantName: heuristicMerchant(from: lines),
            date: heuristicDate(from: text),
            total: heuristicTotal(from: lines),
            tax: heuristicTax(from: lines),
            currency: heuristicCurrency(from: text),
            lineItems: heuristicLineItems(from: lines),
            category: heuristicCategory(from: text),
            paymentMethod: heuristicPaymentMethod(from: text)
        )

        return hasUsableData(extraction) ? extraction : nil
    }

    private func heuristicMerchant(from lines: [String]) -> String? {
        let blockedTerms = [
            "receipt", "invoice", "total", "subtotal", "tax", "vat", "date",
            "time", "card", "visa", "mastercard", "cash", "change", "amount",
            "auth", "terminal", "approved", "keszpenz", "bankkartya", "kartya"
        ]

        return lines.first { line in
            let lower = normalizedSearchText(line)
            let hasLetter = line.rangeOfCharacter(from: .letters) != nil
            let isBlocked = blockedTerms.contains { lower.contains($0) }
            return hasLetter && !isBlocked && moneyValues(in: line).isEmpty && line.count <= 80
        }
    }

    private func heuristicTotal(from lines: [String]) -> Double? {
        let strongTerms = ["grand total", "amount due", "balance due", "total due", "total", "paid"]
        for term in strongTerms {
            let matches = lines.compactMap { line -> Double? in
                let lower = line.lowercased()
                guard lower.contains(term), !lower.contains("subtotal") else { return nil }
                return moneyValues(in: line).last
            }
            if let value = matches.last, value > 0 {
                return value
            }
        }

        return lines
            .flatMap { moneyValues(in: $0) }
            .filter { $0 > 0 }
            .max()
    }

    private func heuristicTax(from lines: [String]) -> Double? {
        lines.compactMap { line -> Double? in
            let lower = line.lowercased()
            guard lower.contains("tax") || lower.contains("vat") else { return nil }
            return moneyValues(in: line).last
        }.last
    }

    private func heuristicDate(from text: String) -> String? {
        let patterns = [
            #"\b\d{4}\.\s*\d{1,2}\.\s*\d{1,2}\.?\b"#,
            #"\b\d{4}[-/.]\d{1,2}[-/.]\d{1,2}\b"#,
            #"\b\d{1,2}\.\s*\d{1,2}\.\s*\d{2,4}\.?\b"#,
            #"\b\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4}\b"#
        ]

        for pattern in patterns {
            guard let match = firstMatch(pattern: pattern, in: text) else { continue }
            if let normalized = normalizedDate(match) {
                return normalized
            }
            return match
        }

        return nil
    }

    private func normalizedDate(_ value: String) -> String? {
        let normalizedValue = value
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let inputFormats = [
            "yyyy-MM-dd", "yyyy/M/d", "yyyy.M.d",
            "M/d/yyyy", "M-d-yyyy", "M.d.yyyy",
            "d/M/yyyy", "d-M-yyyy", "d.M.yyyy",
            "M/d/yy", "M-d-yy", "M.d.yy",
            "d/M/yy", "d-M-yy", "d.M.yy"
        ]

        for format in inputFormats {
            let parser = DateFormatter()
            parser.locale = Locale(identifier: "en_US_POSIX")
            parser.dateFormat = format
            guard let date = parser.date(from: normalizedValue) else { continue }

            let output = DateFormatter()
            output.locale = Locale(identifier: "en_US_POSIX")
            output.dateFormat = "yyyy-MM-dd"
            return output.string(from: date)
        }

        return nil
    }

    private func heuristicCurrency(from text: String) -> String? {
        let upper = text.uppercased()
        if upper.contains("USD") || text.contains("$") { return "USD" }
        if upper.contains("EUR") || text.contains("€") { return "EUR" }
        if upper.contains("GBP") || text.contains("£") { return "GBP" }
        if upper.range(of: #"\bHUF\b"#, options: .regularExpression) != nil ||
            upper.range(of: #"(?<![A-Z])FT(?![A-Z])"#, options: .regularExpression) != nil {
            return "HUF"
        }
        return nil
    }

    private func heuristicCategory(from text: String) -> String? {
        let lower = normalizedSearchText(text)
        if ["restaurant", "etterem", "cafe", "kave", "coffee", "grocery", "groceries", "elelmiszer", "market", "spar", "tesco", "aldi", "lidl", "abc", "pekseg", "bakery", "food", "dining"].contains(where: { lower.contains($0) }) {
            return "food"
        }
        if ["pharmacy", "gyogyszertar", "patika", "drug", "clinic", "medical"].contains(where: { lower.contains($0) }) {
            return "health"
        }
        if ["fuel", "uzemanyag", "benzinkut", "mol", "shell", "omv", "gas", "parking", "parkolas", "uber", "bolt taxi", "taxi", "busz", "vonat", "train"].contains(where: { lower.contains($0) }) {
            return "transport"
        }
        if ["mozi", "cinema", "movie", "theatre", "theater", "concert", "ticket"].contains(where: { lower.contains($0) }) {
            return "entertainment"
        }
        if ["netflix", "spotify", "subscription", "elofizetes"].contains(where: { lower.contains($0) }) {
            return "subscription"
        }
        if ["hotel", "airline", "flight", "repulo", "travel", "utazas"].contains(where: { lower.contains($0) }) {
            return "travel"
        }
        if ["book", "konyv", "school", "iskola", "education", "oktatas"].contains(where: { lower.contains($0) }) {
            return "education"
        }
        if ["villany", "aram", "water", "viz", "gas bill", "utility", "kozmu"].contains(where: { lower.contains($0) }) {
            return "utilities"
        }
        if ["store", "shop", "retail", "aruhaz", "bolt", "ruha", "clothing", "dm", "rossmann"].contains(where: { lower.contains($0) }) {
            return "shopping"
        }
        return nil
    }

    private func heuristicPaymentMethod(from text: String) -> String? {
        let lower = normalizedSearchText(text)

        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let cardTerms = ["bankkartya", "bank card", "card", "kartya", "visa", "mastercard", "maestro", "contactless", "erinteses", "pos"]
        let cashTerms = ["keszpenz", "cash", "kp"]
        let transferTerms = ["atutalas", "transfer", "bank transfer"]
        let directDebitTerms = ["direct debit", "csoportos beszedes"]

        if paymentLine(in: lines, containsAny: cardTerms, hasPositiveAmount: true) {
            return "card"
        }
        if paymentLine(in: lines, containsAny: cashTerms, hasPositiveAmount: true) {
            return "cash"
        }
        if paymentLine(in: lines, containsAny: transferTerms, hasPositiveAmount: true) {
            return "transfer"
        }
        if paymentLine(in: lines, containsAny: directDebitTerms, hasPositiveAmount: true) {
            return "direct debit"
        }

        if cardTerms.contains(where: { lower.contains($0) }) {
            return "card"
        }
        if cashTerms.contains(where: { lower.contains($0) }) {
            return "cash"
        }
        if transferTerms.contains(where: { lower.contains($0) }) {
            return "transfer"
        }
        if directDebitTerms.contains(where: { lower.contains($0) }) {
            return "direct debit"
        }
        return nil
    }

    private func paymentLine(in lines: [String], containsAny terms: [String], hasPositiveAmount: Bool) -> Bool {
        lines.contains { line in
            let lower = normalizedSearchText(line)
            guard terms.contains(where: { lower.contains($0) }) else { return false }
            if !hasPositiveAmount { return true }
            return moneyValues(in: line).contains { $0 > 0 }
        }
    }

    private func heuristicLineItems(from lines: [String]) -> [String]? {
        let blockedTerms = ["total", "subtotal", "tax", "vat", "change", "balance", "paid", "cash", "keszpenz", "card", "kartya", "bankkartya", "visa", "mastercard", "maestro"]
        let items = lines.compactMap { line -> String? in
            let lower = normalizedSearchText(line)
            guard line.rangeOfCharacter(from: .letters) != nil,
                  !blockedTerms.contains(where: { lower.contains($0) }),
                  !moneyValues(in: line).isEmpty else {
                return nil
            }
            return line
        }
        let limited = Array(items.prefix(12))
        return limited.isEmpty ? nil : limited
    }

    private func moneyValues(in text: String) -> [Double] {
        let pattern = #"(?<!\d)(?:[A-Z]{3}\s*)?[$€£]\s*-?\d+(?:[ .]\d{3})*(?:[.,]\d{2})?|-?\d{1,3}(?:[ .]\d{3})+(?:[.,]\d{2})?\s*(?:HUF|FT|USD|EUR|GBP)?\b|-?\d+(?:[.,]\d{2})\s*(?:HUF|FT|USD|EUR|GBP)?\b|-?\d+\s*(?:HUF|FT|USD|EUR|GBP)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)

        return regex.matches(in: text, range: range).compactMap { match in
            guard let swiftRange = Range(match.range, in: text) else { return nil }
            return optionalDouble(String(text[swiftRange]))
        }
    }

    private func firstMatch(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let swiftRange = Range(match.range, in: text) else {
            return nil
        }
        return String(text[swiftRange])
    }

    private func normalizedSearchText(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "hu_HU"))
            .lowercased()
    }

    private func normalizedCategory(_ value: String?) -> String? {
        guard let value else { return nil }
        let lower = normalizedSearchText(value)
        let allowed = ["housing", "utilities", "food", "transport", "health", "entertainment", "shopping", "subscription", "travel", "education", "other"]
        if allowed.contains(lower) { return lower }
        return heuristicCategory(from: lower)
    }

    private func normalizedPaymentMethod(_ value: String?) -> String? {
        guard let value else { return nil }
        let lower = normalizedSearchText(value)
        if ["cash", "card", "transfer", "direct debit"].contains(lower) {
            return lower
        }
        return heuristicPaymentMethod(from: lower)
    }

    private func receiptDictionary(from dict: [String: Any]) -> [String: Any] {
        let directKeys = ["merchantName", "merchant", "storeName", "total", "amount", "lineItems", "items", "paymentMethod"]
        if firstValue(in: dict, keys: directKeys) != nil {
            return dict
        }

        for key in ["receipt", "data", "result", "extraction"] {
            if let nested = firstValue(in: dict, keys: [key]) as? [String: Any] {
                return nested
            }
        }

        return dict
    }

    private func firstValue(in dict: [String: Any], keys: [String]) -> Any? {
        for key in keys {
            if let value = dict[key], !(value is NSNull) {
                return value
            }
        }

        for key in keys {
            if let match = dict.first(where: { $0.key.lowercased() == key.lowercased() }),
               !(match.value is NSNull) {
                return match.value
            }
        }

        return nil
    }

    private func optionalString(_ value: Any?) -> String? {
        guard let value, !(value is NSNull) else { return nil }
        if let dict = value as? [String: Any] {
            return optionalString(firstValue(in: dict, keys: ["value", "name", "code", "text"]))
        }
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty || trimmed.lowercased() == "null" ? nil : trimmed
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return nil
    }

    private func optionalDouble(_ value: Any?) -> Double? {
        guard let value, !(value is NSNull) else { return nil }
        if let dict = value as? [String: Any] {
            return optionalDouble(firstValue(in: dict, keys: ["amount", "value", "total", "price"]))
        }
        if let double = value as? Double { return double }
        if let int = value as? Int { return Double(int) }
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String {
            let allowed = CharacterSet(charactersIn: "0123456789.,-")
            var cleaned = string
                .components(separatedBy: allowed.inverted)
                .joined()
            guard !cleaned.isEmpty else { return nil }

            if cleaned.contains(","), cleaned.contains(".") {
                let decimalSeparator = (cleaned.lastIndex(of: ",") ?? cleaned.startIndex) > (cleaned.lastIndex(of: ".") ?? cleaned.startIndex) ? "," : "."
                let thousandsSeparator = decimalSeparator == "," ? "." : ","
                cleaned = cleaned.replacingOccurrences(of: thousandsSeparator, with: "")
                cleaned = cleaned.replacingOccurrences(of: decimalSeparator, with: ".")
            } else if cleaned.contains(",") {
                let parts = cleaned.split(separator: ",", omittingEmptySubsequences: false)
                if parts.last?.count == 2 {
                    cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
                } else {
                    cleaned = cleaned.replacingOccurrences(of: ",", with: "")
                }
            }

            return Double(cleaned)
        }
        return nil
    }

    private func optionalLineItems(_ value: Any?) -> [String]? {
        guard let value, !(value is NSNull) else { return nil }

        if let strings = value as? [String] {
            let cleaned = strings
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return cleaned.isEmpty ? nil : cleaned
        }

        if let objects = value as? [[String: Any]] {
            let items = objects.compactMap { item -> String? in
                let name = optionalString(firstValue(in: item, keys: ["name", "description", "item", "title"]))
                let price = optionalDouble(firstValue(in: item, keys: ["price", "amount", "total"]))
                if let name, let price {
                    return "\(name) \(String(format: "%.2f", price))"
                }
                return name
            }
            return items.isEmpty ? nil : items
        }

        if let array = value as? [Any] {
            let items = array.compactMap { item -> String? in
                if let dict = item as? [String: Any] {
                    let name = optionalString(firstValue(in: dict, keys: ["name", "description", "item", "title"]))
                    let price = optionalDouble(firstValue(in: dict, keys: ["price", "amount", "total"]))
                    if let name, let price {
                        return "\(name) \(String(format: "%.2f", price))"
                    }
                    return name
                }
                return optionalString(item)
            }
            return items.isEmpty ? nil : items
        }

        if let string = optionalString(value) {
            let items = string
                .split(whereSeparator: { $0.isNewline })
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return items.isEmpty ? nil : items
        }

        return nil
    }

    private func stripCodeFences(_ content: String) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```") else { return trimmed }

        var lines = trimmed.components(separatedBy: .newlines)
        if lines.first?.hasPrefix("```") == true {
            lines.removeFirst()
        }
        if lines.last?.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("```") == true {
            lines.removeLast()
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func firstJSONObject(in text: String) -> String? {
        var start: String.Index?
        var depth = 0
        var inString = false
        var isEscaped = false
        var index = text.startIndex

        while index < text.endIndex {
            let char = text[index]

            if inString {
                if isEscaped {
                    isEscaped = false
                } else if char == "\\" {
                    isEscaped = true
                } else if char == "\"" {
                    inString = false
                }
            } else {
                if char == "\"" {
                    inString = true
                } else if char == "{" {
                    if depth == 0 {
                        start = index
                    }
                    depth += 1
                } else if char == "}" {
                    depth -= 1
                    if depth == 0, let start {
                        return String(text[start...index])
                    }
                    if depth < 0 {
                        depth = 0
                        start = nil
                    }
                }
            }

            index = text.index(after: index)
        }

        return nil
    }

    private func parseError(_ message: String) -> NSError {
        NSError(domain: "ReceiptScanner", code: 500, userInfo: [NSLocalizedDescriptionKey: message])
    }

    private func preview(_ text: String) -> String {
        String(text.replacingOccurrences(of: "\n", with: " ").prefix(220))
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
