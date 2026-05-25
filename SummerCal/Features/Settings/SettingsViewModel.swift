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
    var moneyEntryPreviewLimit: Int = 5
    var languageCode: String = "en"

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
        moneyEntryPreviewLimit = max(1, s.moneyEntryPreviewLimit ?? 5)
        languageCode = s.languageCode ?? "en"

        apiKey = loadAPIKey(for: s.aiProviderKind) ?? ""
        locationEnabled = s.locationEnabled ?? true
        approximateLocation = s.approximateLocation ?? false
        selectedActivities = Set((s.selectedActivities ?? "indoor,outdoor,productive,social").split(separator: ",").map(String.init).filter { !$0.isEmpty })
        energyLevel = s.energyLevel ?? 3
        budgetPreference = s.budgetPreference ?? "medium"
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
        let previousCurrency = s.currencyCode
        if previousCurrency != currencyCode {
            backfillMissingMoneyCurrencies(previousCurrency: previousCurrency, modelContext: modelContext)
        }

        s.aiProviderKind = aiProviderKind
        s.aiModelName = aiModelName
        s.aiBaseURL = aiBaseURL.isEmpty ? nil : aiBaseURL
        s.aiMaxTokens = maxTokens
        s.currencyCode = currencyCode
        s.monthlyIncomeGoal = monthlyIncomeGoal
        s.moneyEntryPreviewLimit = max(1, moneyEntryPreviewLimit)
        s.languageCode = languageCode
        s.selectedActivities = Array(selectedActivities).joined(separator: ",")
        s.energyLevel = energyLevel
        s.budgetPreference = budgetPreference
        s.locationEnabled = locationEnabled
        s.approximateLocation = approximateLocation
        s.updatedAt = Date()

        if !apiKey.isEmpty {
            saveAPIKey(apiKey, for: aiProviderKind)
        }

        try? modelContext.save()
    }

    private func backfillMissingMoneyCurrencies(previousCurrency: String, modelContext: ModelContext) {
        let incomeEntries = (try? modelContext.fetch(FetchDescriptor<IncomeEntry>())) ?? []
        for entry in incomeEntries where entry.currencyCode == nil {
            entry.currencyCode = previousCurrency
            entry.originalAmount = entry.originalAmount ?? entry.amount
            entry.originalCurrencyCode = entry.originalCurrencyCode ?? previousCurrency
        }

        let expenseEntries = (try? modelContext.fetch(FetchDescriptor<ExpenseEntry>())) ?? []
        for entry in expenseEntries where entry.currencyCode == nil {
            entry.currencyCode = previousCurrency
            entry.originalAmount = entry.originalAmount ?? entry.amount
            entry.originalCurrencyCode = entry.originalCurrencyCode ?? previousCurrency
        }

        let workSessions = (try? modelContext.fetch(FetchDescriptor<WorkSession>())) ?? []
        for session in workSessions where session.currencyCode == nil {
            session.currencyCode = previousCurrency
        }

        let savingsEntries = (try? modelContext.fetch(FetchDescriptor<SavingsEntry>())) ?? []
        for entry in savingsEntries where entry.currencyCode == nil {
            entry.currencyCode = previousCurrency
            entry.originalAmount = entry.originalAmount ?? entry.amount
            entry.originalCurrencyCode = entry.originalCurrencyCode ?? previousCurrency
        }

        let savingsGoals = (try? modelContext.fetch(FetchDescriptor<SavingsGoal>())) ?? []
        for goal in savingsGoals where goal.currencyCode == nil {
            goal.currencyCode = previousCurrency
        }

        let workTypes = (try? modelContext.fetch(FetchDescriptor<WorkType>())) ?? []
        for type in workTypes where type.currencyCode == nil {
            type.currencyCode = previousCurrency
        }
    }

    func testConnection() async {
        isTestingConnection = true
        testConnectionResult = nil

        let baseURL: String
        switch aiProviderKind {
        case "deepSeek":  baseURL = "https://api.deepseek.com"
        case "openAI":    baseURL = "https://api.openai.com"
        case "anthropic": baseURL = "https://api.anthropic.com"
        case "custom":    baseURL = aiBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        default:
            baseURL = aiBaseURL.isEmpty
                ? "https://api.openai.com"
                : aiBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        let urlString = "\(baseURL)/models"

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
            ExpenseEntry.self,
            SavingsEntry.self,
            SavingsGoal.self,
            NotificationLog.self,
            SmartNotificationRule.self,
            UserSettings.self,
            EventNote.self,
            WorkSession.self,
            WorkType.self
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
        try? KeychainStore.shared.saveAPIKey(provider: provider, key: key)
    }

    func loadAPIKey(for provider: String) -> String? {
        try? KeychainStore.shared.readAPIKey(provider: provider)
    }

    func deleteAPIKey(for provider: String) {
        try? KeychainStore.shared.deleteAPIKey(provider: provider)
    }

    private func deleteAllAPIKeys() {
        let providers = ["openAI", "anthropic", "google", "mistral", "deepSeek", "custom"]
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
