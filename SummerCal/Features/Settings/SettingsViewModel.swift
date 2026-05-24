import Foundation
import SwiftData
import Security

@Observable
final class SettingsViewModel {
    var settings: UserSettings?

    var aiProviderKind: String = "openAI"
    var aiModelName: String = "gpt-4o"
    var aiBaseURL: String = ""
    var apiKey: String = ""
    var maxTokens: Int = 1024
    var isTestingConnection: Bool = false
    var testConnectionResult: String?

    var locationEnabled: Bool = true
    var approximateLocation: Bool = false

    var selectedActivities: Set<String> = ["indoor", "outdoor", "productive", "social"]
    var energyLevel: Double = 3
    var budgetPreference: String = "medium"

    var currencyCode: String = "USD"
    var monthlyIncomeGoal: Double = 0

    var hasValidAPIKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespaces).isEmpty
    }

    let availableActivities: [(id: String, label: String, icon: String)] = [
        ("indoor", "Indoor", "house"),
        ("outdoor", "Outdoor", "leaf"),
        ("low-cost", "Budget Friendly", "dollarsign.circle"),
        ("productive", "Deep Work", "checkmark.circle"),
        ("social", "Social", "person.2"),
        ("relaxing", "Relaxing", "bed.double"),
        ("fitness", "Fitness", "figure.walk"),
        ("errands", "Errands", "checklist")
    ]

    let budgetOptions = ["low", "medium", "high"]

    func loadSettings(modelContext: ModelContext) {
        settings = UserSettings.current(in: modelContext)
        guard let s = settings else { return }

        aiProviderKind = s.aiProviderKind
        aiModelName = s.aiModelName
        aiBaseURL = s.aiBaseURL ?? ""
        maxTokens = s.aiMaxTokens
        currencyCode = s.currencyCode
        monthlyIncomeGoal = s.monthlyIncomeGoal ?? 0

        apiKey = loadAPIKey(for: s.aiProviderKind) ?? ""
        locationEnabled = true
        approximateLocation = false

        if let activitiesData = try? JSONDecoder().decode([String].self, from: Data("[\"indoor\",\"outdoor\",\"productive\",\"social\"]".utf8)) {
            selectedActivities = Set(activitiesData)
        }
    }

    func saveSettings(modelContext: ModelContext) {
        guard let s = settings else {
            let newSettings = UserSettings.current(in: modelContext)
            applyToSettings(newSettings, modelContext: modelContext)
            return
        }
        applyToSettings(s, modelContext: modelContext)
    }

    private func applyToSettings(_ s: UserSettings, modelContext: ModelContext) {
        s.aiProviderKind = aiProviderKind
        s.aiModelName = aiModelName
        s.aiBaseURL = aiBaseURL.isEmpty ? nil : aiBaseURL
        s.aiMaxTokens = maxTokens
        s.currencyCode = currencyCode
        s.monthlyIncomeGoal = monthlyIncomeGoal
        s.updatedAt = Date()

        if !apiKey.isEmpty {
            saveAPIKey(apiKey, for: aiProviderKind)
        }

        try? modelContext.save()
    }

    func testConnection() async {
        isTestingConnection = true
        testConnectionResult = nil

        let urlString = aiBaseURL.isEmpty
            ? "https://api.openai.com/v1/models"
            : "\(aiBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/models"

        guard let url = URL(string: urlString) else {
            testConnectionResult = "Invalid URL"
            isTestingConnection = false
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    testConnectionResult = "Connection successful"
                } else if httpResponse.statusCode == 401 {
                    testConnectionResult = "Invalid API key"
                } else {
                    testConnectionResult = "Status: \(httpResponse.statusCode)"
                }
            }
        } catch {
            testConnectionResult = error.localizedDescription
        }

        isTestingConnection = false
    }

    func resetAllData(modelContext: ModelContext) {
        let models: [any PersistentModel.Type] = [
            CalendarEvent.self,
            WeatherSnapshot.self,
            PlaceCandidate.self,
            ActivitySuggestion.self,
            EventReminder.self,
            IncomeEntry.self,
            NotificationLog.self,
            SmartNotificationRule.self,
            UserSettings.self,
            EventNote.self,
            WorkSession.self
        ]

        for model in models {
            try? modelContext.delete(model: model)
        }

        let newSettings = UserSettings()
        modelContext.insert(newSettings)
        try? modelContext.save()
        settings = newSettings

        deleteAllAPIKeys()
    }

    func saveAPIKey(_ key: String, for provider: String) {
        let service = "com.summercal.apikey"
        let account = provider
        let data = Data(key.utf8)

        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    func loadAPIKey(for provider: String) -> String? {
        let service = "com.summercal.apikey"
        let account = provider

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func deleteAPIKey(for provider: String) {
        let service = "com.summercal.apikey"
        let account = provider
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func deleteAllAPIKeys() {
        let providers = ["openAI", "anthropic", "google", "mistral", "custom"]
        for provider in providers {
            deleteAPIKey(for: provider)
        }
    }

    var budgetLabel: String {
        switch budgetPreference {
        case "low": return "Low"
        case "medium": return "Medium"
        case "high": return "High"
        default: return "Medium"
        }
    }

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0"
    }

    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
