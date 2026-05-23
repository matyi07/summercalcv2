import Foundation
import SwiftData
import SwiftUI

enum ChatRole: String, Codable {
    case user
    case assistant
    case system
}

struct ChatMessage: Identifiable {
    let id: UUID
    let role: ChatRole
    let content: String
    let timestamp: Date

    init(id: UUID = UUID(), role: ChatRole, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

enum PlannerShortcut: String, CaseIterable, Identifiable {
    case planFreeDay
    case findNearby
    case eventPrep
    case summarizeDay

    var id: String { rawValue }

    var label: String {
        switch self {
        case .planFreeDay: return "Plan my free day"
        case .findNearby: return "Find something nearby"
        case .eventPrep: return "What should I do before my event?"
        case .summarizeDay: return "Summarize my day"
        }
    }

    var icon: String {
        switch self {
        case .planFreeDay: return "calendar.badge.plus"
        case .findNearby: return "mappin.and.ellipse"
        case .eventPrep: return "checklist"
        case .summarizeDay: return "text.alignleft"
        }
    }

    var prompt: String {
        switch self {
        case .planFreeDay: return "Look at my calendar and suggest activities I can do during my free time today. Consider the weather and my preferences."
        case .findNearby: return "Based on my current location and free windows today, find interesting places I can visit nearby."
        case .eventPrep: return "Look at my upcoming events and tell me what I should prepare before each one."
        case .summarizeDay: return "Give me a summary of my day - what I have scheduled, the weather forecast, and any recommendations."
        }
    }
}

struct AIPlannerContext {
    var todaysEvents: [CalendarEvent] = []
    var freeWindows: [DateInterval] = []
    var weatherSummary: String?
    var nearbyPlaces: [PlaceCandidate] = []
    var preferences: UserSettings?

    func buildSystemPrompt() -> String {
        var parts: [String] = []

        parts.append("You are SummerCal, a helpful AI assistant that helps users plan their day. You have access to the user's calendar, weather, and location data.")

        if let settings = preferences {
            parts.append("User's currency: \(settings.currencyCode)")
            parts.append("Monthly income goal: \(String(format: "%.2f", settings.monthlyIncomeGoal ?? 0))")
        }

        if !todaysEvents.isEmpty {
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            parts.append("Today's events:")
            for event in todaysEvents {
                parts.append("- \(event.title) from \(formatter.string(from: event.startDate)) to \(formatter.string(from: event.endDate))\(event.location.map { " at \($0)" } ?? "")")
            }
        }

        if let summary = weatherSummary {
            parts.append("Weather today: \(summary)")
        }

        if !freeWindows.isEmpty {
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            parts.append("Free time windows:")
            for window in freeWindows {
                parts.append("- \(formatter.string(from: window.start)) to \(formatter.string(from: window.end))")
            }
        }

        if !nearbyPlaces.isEmpty {
            parts.append("Nearby places of interest:")
            for place in nearbyPlaces.prefix(10) {
                var line = "- \(place.name)"
                if let rating = place.rating { line += " (★\(String(format: "%.1f", rating)))" }
                if let address = place.address { line += " - \(address)" }
                parts.append(line)
            }
        }

        return parts.joined(separator: "\n")
    }
}

@Observable
final class AIPlannerViewModel {
    var messages: [ChatMessage] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var currentProvider: String = ""

    private let apiService = AIPlannerAPIService()

    func sendMessage(_ text: String, context: AIPlannerContext, modelContext: ModelContext) async {
        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)

        let settings = context.preferences ?? UserSettings.current(in: modelContext)
        currentProvider = settings.aiModelName
        isLoading = true
        errorMessage = nil

        do {
            let systemPrompt = context.buildSystemPrompt()
            let history = messages.map { ($0.role, $0.content) }

            let response = try await apiService.chat(
                userMessage: text,
                systemPrompt: systemPrompt,
                history: history,
                provider: settings.aiProviderKind,
                model: settings.aiModelName,
                baseURL: settings.aiBaseURL
            )

            let assistantMessage = ChatMessage(role: .assistant, content: response, timestamp: Date())
            messages.append(assistantMessage)

            let activity = ActivitySuggestion(
                date: Date(),
                title: "AI Chat Summary",
                summary: response,
                aiProvider: settings.aiProviderKind
            )
            modelContext.insert(activity)
            try? modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func useShortcut(_ shortcut: PlannerShortcut, modelContext: ModelContext) async {
        let settings = UserSettings.current(in: modelContext)

        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        let eventDescriptor = FetchDescriptor<CalendarEvent>(
            predicate: #Predicate { event in
                event.startDate >= today && event.startDate < tomorrow
            },
            sortBy: [SortDescriptor(\.startDate)]
        )
        let todaysEvents = (try? modelContext.fetch(eventDescriptor)) ?? []

        let freeWindows = computeFreeWindows(events: todaysEvents, on: Date())

        let weatherDescriptor = FetchDescriptor<WeatherSnapshot>(
            predicate: #Predicate { snapshot in
                snapshot.forecastDate >= today && snapshot.forecastDate < tomorrow
            },
            sortBy: [SortDescriptor(\.forecastDate)]
        )
        let todayWeather = (try? modelContext.fetch(weatherDescriptor))
        let weatherSummary = todayWeather?.first.map { "\($0.condition), \(Int($0.temperatureCelsius))°C" }

        let placeDescriptor = FetchDescriptor<PlaceCandidate>(sortBy: [SortDescriptor(\.createdAt)])
        let places = (try? modelContext.fetch(placeDescriptor)) ?? []

        let context = AIPlannerContext(
            todaysEvents: todaysEvents,
            freeWindows: freeWindows,
            weatherSummary: weatherSummary,
            nearbyPlaces: places,
            preferences: settings
        )

        await sendMessage(shortcut.prompt, context: context, modelContext: modelContext)
    }

    func clearChat() {
        messages.removeAll()
        errorMessage = nil
    }

    private func computeFreeWindows(events: [CalendarEvent], on date: Date) -> [DateInterval] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

        let sortedEvents = events
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }

        var windows: [DateInterval] = []
        var cursor = max(dayStart, Date())

        for event in sortedEvents {
            let eventStart = max(event.startDate, cursor)
            if eventStart > cursor {
                windows.append(DateInterval(start: cursor, end: min(eventStart, event.startDate)))
            }
            cursor = max(cursor, event.endDate)
        }

        if cursor < dayEnd {
            windows.append(DateInterval(start: cursor, end: min(dayEnd, dayEnd)))
        }

        return windows.filter { $0.duration >= 1200 }
    }
}

private actor AIPlannerAPIService {
    func chat(
        userMessage: String,
        systemPrompt: String,
        history: [(ChatRole, String)],
        provider: String,
        model: String,
        baseURL: String?
    ) async throws -> String {
        let urlString = baseURL ?? "https://api.openai.com/v1/chat/completions"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        var messages: [[String: String]] = []
        messages.append(["role": "system", "content": systemPrompt])
        for (role, content) in history.suffix(10) {
            let roleString: String = switch role {
            case .user: "user"
            case .assistant: "assistant"
            case .system: "system"
            }
            messages.append(["role": roleString, "content": content])
        }

        let requestBody: [String: Any] = [
            "model": model,
            "messages": messages,
            "max_tokens": 1024
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(try await loadAPIKey(for: provider))", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if httpResponse.statusCode == 401 {
            throw NSError(domain: "AIPlanner", code: 401, userInfo: [NSLocalizedDescriptionKey: "Invalid API key. Check your AI settings."])
        }

        if httpResponse.statusCode == 429 {
            throw NSError(domain: "AIPlanner", code: 429, userInfo: [NSLocalizedDescriptionKey: "Rate limited. Try again later."])
        }

        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "AIPlanner", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned status \(httpResponse.statusCode)"])
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String
        else {
            throw NSError(domain: "AIPlanner", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unexpected response format"])
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func loadAPIKey(for provider: String) async throws -> String {
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

        guard status == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8)
        else {
            throw NSError(domain: "AIPlanner", code: 401, userInfo: [NSLocalizedDescriptionKey: "API key not found. Please set it in Settings → AI Configuration."])
        }

        return key
    }
}
