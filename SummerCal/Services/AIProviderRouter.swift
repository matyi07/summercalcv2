import Foundation

struct AIMessage: Codable {
    var role: String
    var content: String
}

struct AIRequestConfig: Codable {
    var model: String
    var maxTokens: Int
    var temperature: Double
    var baseURL: String?
}

struct AIResponse: Codable {
    var content: String
    var finishReason: String?
    var tokenUsage: Int?
}

protocol AIProviderClient {
    var providerName: String { get }
    func sendChat(messages: [AIMessage], config: AIRequestConfig) async throws -> AIResponse
}

enum AIProviderKind: String, Codable, CaseIterable {
    case openAI, claude, deepSeek, openAICompatible

    var displayName: String {
        switch self {
        case .openAI: "OpenAI"
        case .claude: "Claude"
        case .deepSeek: "DeepSeek"
        case .openAICompatible: "OpenAI Compatible"
        }
    }

    var defaultModel: String {
        switch self {
        case .openAI: "gpt-4o"
        case .claude: "claude-3-5-sonnet-latest"
        case .deepSeek: "deepseek-v4-pro"
        case .openAICompatible: "gpt-4o"
        }
    }

    /// Maps AISettingsView provider string to AIProviderKind.
    /// Settings uses: openAI, anthropic, google, mistral, deepSeek, custom
    static func fromSettings(_ rawValue: String) -> AIProviderKind? {
        switch rawValue {
        case "openAI": return .openAI
        case "deepSeek": return .deepSeek
        case "anthropic": return .claude
        case "custom", "google", "mistral": return .openAICompatible
        default: return AIProviderKind(rawValue: rawValue)
        }
    }
}

final class OpenAIClient: AIProviderClient {
    let providerName = "OpenAI"
    private let apiKey: String

    init(apiKey: String) { self.apiKey = apiKey }

    func sendChat(messages: [AIMessage], config: AIRequestConfig) async throws -> AIResponse {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": config.model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "max_tokens": config.maxTokens,
            "temperature": config.temperature
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        if let error = json?["error"] as? [String: Any], let message = error["message"] as? String {
            throw NSError(domain: "OpenAI", code: 400, userInfo: [NSLocalizedDescriptionKey: message])
        }

        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        let content = message?["content"] as? String ?? ""
        let usage = json?["usage"] as? [String: Any]
        let tokens = usage?["total_tokens"] as? Int

        return AIResponse(content: content, finishReason: choices?.first?["finish_reason"] as? String, tokenUsage: tokens)
    }
}

final class ClaudeClient: AIProviderClient {
    let providerName = "Claude"
    private let apiKey: String

    init(apiKey: String) { self.apiKey = apiKey }

    func sendChat(messages: [AIMessage], config: AIRequestConfig) async throws -> AIResponse {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let systemMessages = messages.filter { $0.role == "system" }.map { ["type": "text", "text": $0.content] }
        let chatMessages = messages.filter { $0.role != "system" }.map { ["role": $0.role, "content": $0.content] }

        var body: [String: Any] = [
            "model": config.model,
            "max_tokens": config.maxTokens,
            "messages": chatMessages
        ]
        if !systemMessages.isEmpty {
            let systemText = systemMessages.compactMap { $0["text"] as? String }.joined(separator: "\n")
            body["system"] = systemText
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        if let error = json?["error"] as? [String: Any], let message = error["message"] as? String {
            throw NSError(domain: "Claude", code: 400, userInfo: [NSLocalizedDescriptionKey: message])
        }

        let contentBlocks = json?["content"] as? [[String: Any]]
        let textContent = contentBlocks?.compactMap { block -> String? in
            if block["type"] as? String == "text" { return block["text"] as? String }
            return nil
        }.joined(separator: "\n") ?? ""

        let usage = json?["usage"] as? [String: Any]
        let tokens = usage?["input_tokens"] as? Int

        return AIResponse(content: textContent, finishReason: json?["stop_reason"] as? String, tokenUsage: tokens)
    }
}

final class DeepSeekClient: AIProviderClient {
    let providerName = "DeepSeek"
    private let apiKey: String

    init(apiKey: String) { self.apiKey = apiKey }

    func sendChat(messages: [AIMessage], config: AIRequestConfig) async throws -> AIResponse {
        let url = URL(string: "https://api.deepseek.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": config.model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "max_tokens": config.maxTokens,
            "temperature": config.temperature
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        if let error = json?["error"] as? [String: Any], let message = error["message"] as? String {
            throw NSError(domain: "DeepSeek", code: 400, userInfo: [NSLocalizedDescriptionKey: message])
        }

        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        let content = message?["content"] as? String ?? ""
        let usage = json?["usage"] as? [String: Any]
        let tokens = usage?["total_tokens"] as? Int

        return AIResponse(content: content, finishReason: choices?.first?["finish_reason"] as? String, tokenUsage: tokens)
    }
}

final class OpenAICompatibleClient: AIProviderClient {
    var providerName: String { "OpenAI Compatible (\(baseURL.host ?? ""))" }
    private let apiKey: String
    private let baseURL: URL

    init(apiKey: String, config: AIRequestConfig) {
        self.apiKey = apiKey
        self.baseURL = URL(string: config.baseURL ?? "https://api.openai.com")!
    }

    func sendChat(messages: [AIMessage], config: AIRequestConfig) async throws -> AIResponse {
        let url = baseURL.appendingPathComponent("v1/chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": config.model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "max_tokens": config.maxTokens,
            "temperature": config.temperature
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        let content = message?["content"] as? String ?? ""
        let usage = json?["usage"] as? [String: Any]
        let tokens = usage?["total_tokens"] as? Int

        return AIResponse(content: content, finishReason: choices?.first?["finish_reason"] as? String, tokenUsage: tokens)
    }
}

final class AIProviderRouter {
    private let keychain: KeychainStore

    init(keychain: KeychainStore = .shared) { self.keychain = keychain }

    func client(for settingsProvider: String, settings: UserSettings) throws -> AIProviderClient {
        guard let provider = AIProviderKind.fromSettings(settingsProvider) else {
            throw NSError(domain: "AI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unknown AI provider: \(settingsProvider)"])
        }
        let apiKey = try keychain.readAPIKey(provider: settingsProvider)
        switch provider {
        case .openAI: return OpenAIClient(apiKey: apiKey)
        case .claude: return ClaudeClient(apiKey: apiKey)
        case .deepSeek: return DeepSeekClient(apiKey: apiKey)
        case .openAICompatible:
            let baseURL = resolveBaseURL(for: settingsProvider, settings: settings)
            let model = settings.aiModelName.isEmpty ? AIProviderKind.openAICompatible.defaultModel : settings.aiModelName
            let config = AIRequestConfig(
                model: model,
                maxTokens: settings.aiMaxTokens,
                temperature: 0.7,
                baseURL: baseURL
            )
            return OpenAICompatibleClient(apiKey: apiKey, config: config)
        }
    }

    private func resolveBaseURL(for settingsProvider: String, settings: UserSettings) -> String {
        switch settingsProvider {
        case "google": return "https://generativelanguage.googleapis.com/v1beta/openai"
        case "mistral": return "https://api.mistral.ai"
        case "custom": return settings.aiBaseURL ?? "https://api.openai.com"
        default: return settings.aiBaseURL ?? "https://api.openai.com"
        }
    }
}
