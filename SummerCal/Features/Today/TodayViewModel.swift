import SwiftUI
import SwiftData
import CoreLocation

@Observable
final class TodayViewModel {
    var todaysEvents: [CalendarEvent] = []
    var currentEvent: CalendarEvent?
    var nextEvent: CalendarEvent?
    var isFreeDay: Bool = false
    var freeWindows: [DateInterval] = []
    var suggestions: [ActivitySuggestion] = []
    var weather: WeatherSnapshot?
    var hourlyForecast: [WeatherSnapshot] = []
    var monthlyEarnings: Double = 0
    var monthlyGoal: Double?
    var isLoading: Bool = false
    var errorMessage: String?
    var currencyCode: String = "USD"
    var isLoadingSuggestions: Bool = false
    var suggestionError: String?

    var freeDaySummary: String {
        let totalFreeHours = freeWindows.reduce(0.0) { $0 + $1.duration } / 3600.0
        let eventCount = todaysEvents.count

        if eventCount == 0 {
            return "Your day is completely free."
        }

        let morningWindow = freeWindows.filter { w in
            let hour = Calendar.current.component(.hour, from: w.start)
            return hour >= 6 && hour < 12
        }.reduce(0.0) { $0 + $1.duration } / 3600.0

        let afternoonWindow = freeWindows.filter { w in
            let hour = Calendar.current.component(.hour, from: w.start)
            return hour >= 12 && hour < 18
        }.reduce(0.0) { $0 + $1.duration } / 3600.0

        let totalBusyHours = (todaysEvents.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }) / 3600.0

        if totalFreeHours >= 6 {
            if morningWindow >= 2 { return "Free morning — \(Int(morningWindow))h available before your first event." }
            if afternoonWindow >= 2 { return "Open afternoon — \(Int(afternoonWindow))h after your events." }
            return "You have \(Int(totalFreeHours))h of free time today."
        } else if totalFreeHours >= 2 {
            return "Partially busy — \(Int(totalFreeHours))h free between \(eventCount) events."
        } else if eventCount >= 2 && totalFreeHours < 1 {
            return "Busy day — \(eventCount) events, barely any free time."
        } else {
            return "\(eventCount) event\(eventCount > 1 ? "s" : "") today, \(Int(totalBusyHours))h total."
        }
    }

    func loadDay(modelContext: ModelContext) async {
        isLoading = true
        errorMessage = nil

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let allEventsDescriptor = FetchDescriptor<CalendarEvent>(sortBy: [SortDescriptor(\.startDate)])
        if let allEvents = try? modelContext.fetch(allEventsDescriptor) {
            todaysEvents = allEvents.filter { event in
                event.startDate >= startOfDay && event.startDate < endOfDay
            }
        }

        let suggestionDescriptor = FetchDescriptor<ActivitySuggestion>(
            predicate: #Predicate { suggestion in
                suggestion.date >= startOfDay && suggestion.date < endOfDay
            },
            sortBy: [SortDescriptor(\.date)]
        )
        suggestions = (try? modelContext.fetch(suggestionDescriptor)) ?? []

        let weatherDescriptor = FetchDescriptor<WeatherSnapshot>(
            predicate: #Predicate { snapshot in
                snapshot.forecastDate >= startOfDay && snapshot.forecastDate < endOfDay
            },
            sortBy: [SortDescriptor(\.fetchedAt, order: .reverse)]
        )
        var fetchedWeather = (try? modelContext.fetch(weatherDescriptor)) ?? []
        if fetchedWeather.isEmpty {
            let descriptor = FetchDescriptor<WeatherSnapshot>(
                sortBy: [SortDescriptor(\.fetchedAt, order: .reverse)]
            )
            var all = (try? modelContext.fetch(descriptor)) ?? []
            all.sort { $0.fetchedAt > $1.fetchedAt }
            fetchedWeather = all
        }
        weather = fetchedWeather.first

        let hourlyDescriptor = FetchDescriptor<WeatherSnapshot>(
            predicate: #Predicate { $0.forecastDate >= startOfDay },
            sortBy: [SortDescriptor(\.forecastDate)]
        )
        let allSnapshots = (try? modelContext.fetch(hourlyDescriptor)) ?? []
        let todayEnd = endOfDay.addingTimeInterval(3600)
        let filtered = allSnapshots.filter { snap in
            snap.forecastDate >= Date() && snap.forecastDate < todayEnd
        }
        // Deduplicate by normalized hour to prevent copies from multiple weather fetches
        var seen: [Int: WeatherSnapshot] = [:]
        for snap in filtered {
            let hourKey = Int(snap.forecastDate.timeIntervalSince1970 / 3600)
            if let existing = seen[hourKey], existing.fetchedAt >= snap.fetchedAt { continue }
            seen[hourKey] = snap
        }
        hourlyForecast = seen.values.sorted(by: { $0.forecastDate < $1.forecastDate })

        let incomeDescriptor = FetchDescriptor<IncomeEntry>(
            sortBy: [SortDescriptor(\.date)]
        )
        let allIncome = (try? modelContext.fetch(incomeDescriptor)) ?? []
        let sessionDescriptor = FetchDescriptor<WorkSession>(
            sortBy: [SortDescriptor(\.date)]
        )
        let allSessions = (try? modelContext.fetch(sessionDescriptor)) ?? []

        let settings = UserSettings.current(in: modelContext)
        monthlyGoal = settings.monthlyIncomeGoal
        currencyCode = settings.currencyCode
        await calculateMonthlyEarnings(entries: allIncome, sessions: allSessions, targetCurrency: settings.currencyCode)

        detectFreeDay(calendar: calendar, startOfDay: startOfDay, endOfDay: endOfDay)
        findCurrentEvent()
        findNextEvent()
        isLoading = false
    }

    func refreshSuggestions(
        modelContext: ModelContext,
        weather: WeatherSnapshot?,
        location: Coordinate?,
        settings: UserSettings,
        customPreferences: String = ""
    ) async {
        guard let _ = location else {
            await MainActor.run {
                suggestionError = "Suggestions need location access. Enable location in Settings."
                isLoadingSuggestions = false
            }
            return
        }

        guard weather != nil else {
            await MainActor.run {
                suggestionError = "Suggestions need weather data. Pull to refresh to fetch weather."
                isLoadingSuggestions = false
            }
            return
        }

        isLoadingSuggestions = true
        suggestionError = nil

        guard let weather = weather, let location = location else {
            await MainActor.run { isLoadingSuggestions = false }
            return
        }

        let weatherSummary = buildStructuredWeatherSummary(from: weather)

        var nearbyPlaces: [PlaceCandidate] = []
        let placesService = PlacesService(googleApiKey: settings.googlePlacesAPIKey)
        await placesService.searchNearby(query: "point of interest", coordinate: location, radiusMeters: 3000)
        nearbyPlaces = placesService.results

        let dateStr = DateUtils.formattedDayAndDate(Date())
        var preferences = (settings.selectedActivities ?? "")
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if let energy = settings.energyLevel {
            preferences.append("energy level \(Int(energy)) of 5")
        }
        if let budget = settings.budgetPreference, !budget.isEmpty {
            preferences.append("\(budget) budget")
        }
        let trimmedCustomPreferences = customPreferences.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCustomPreferences.isEmpty {
            preferences.append("custom request: \(trimmedCustomPreferences)")
        }
        let prompt = PromptBuilder.buildSmartSuggestionPrompt(
            date: dateStr,
            freeWindows: freeWindows,
            todaysEvents: todaysEvents,
            weatherSummary: weatherSummary,
            nearbyPlaces: nearbyPlaces,
            preferences: preferences
        )

        do {
            let keychain = KeychainStore.shared
            let providerStr = settings.aiProviderKind
            _ = try keychain.readAPIKey(provider: providerStr)

            let router = AIProviderRouter(keychain: keychain)
            let client = try router.client(for: providerStr, settings: settings)
            let config = AIRequestConfig(
                model: settings.aiModelName,
                maxTokens: settings.aiMaxTokens,
                temperature: 0.7,
                baseURL: settings.aiBaseURL
            )
            let messages = [
                AIMessage(role: "system", content: "You are a helpful personal assistant that suggests activities based on context. Respond only with valid JSON."),
                AIMessage(role: "user", content: prompt)
            ]
            let response = try await client.sendChat(messages: messages, config: config)
            let parsed = parseSuggestionJSON(response.content)

            for old in suggestions {
                modelContext.delete(old)
            }
            try? modelContext.save()

            for suggestion in parsed {
                modelContext.insert(suggestion)
            }
            try? modelContext.save()
            suggestions = parsed
        } catch {
            await MainActor.run {
                suggestionError = "Could not generate suggestions: \(error.localizedDescription)"
            }
        }

        await MainActor.run { isLoadingSuggestions = false }
    }

    private func buildStructuredWeatherSummary(from snapshot: WeatherSnapshot) -> String {
        var parts: [String] = []
        parts.append("\(Int(snapshot.temperatureCelsius))°C, \(snapshot.condition)")
        if let feelsLike = snapshot.feelsLikeCelsius {
            parts.append("feels like \(Int(feelsLike))°C")
        }
        parts.append("\(Int(snapshot.precipitationChance * 100))% rain")
        if let wind = snapshot.windSpeedKph {
            parts.append("wind \(Int(wind)) km/h")
        }
        if let humidity = snapshot.humidity {
            parts.append("\(Int(humidity * 100))% humidity")
        }
        if let uv = snapshot.uvIndex {
            parts.append("UV index \(uv)")
        }
        if let cloud = snapshot.cloudCover {
            parts.append("\(Int(cloud))% clouds")
        }
        return parts.joined(separator: ", ")
    }

    private func parseSuggestionJSON(_ content: String) -> [ActivitySuggestion] {
        guard let data = content.data(using: .utf8) else { return [] }
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
            return json.compactMap { item in
                guard let title = item["title"] as? String,
                      let summary = item["summary"] as? String else { return nil }
                return ActivitySuggestion(
                    date: Date(),
                    title: title,
                    summary: summary,
                    category: item["category"] as? String,
                    estimatedDurationMinutes: item["estimatedDurationMinutes"] as? Int,
                    estimatedCostLevel: item["estimatedCostLevel"] as? Int,
                    placeName: item["placeName"] as? String,
                    weatherReason: item["weatherReason"] as? String,
                    aiProvider: "ai"
                )
            }
        } catch {
            return []
        }
    }

    private func detectFreeDay(calendar: Calendar, startOfDay: Date, endOfDay: Date) {
        guard !todaysEvents.isEmpty else {
            isFreeDay = true
            freeWindows = [DateInterval(start: startOfDay, end: endOfDay)]
            return
        }

        var gaps: [DateInterval] = []
        var cursor = startOfDay
        for event in todaysEvents.sorted(by: { $0.startDate < $1.startDate }) {
            if event.startDate > cursor {
                gaps.append(DateInterval(start: cursor, end: event.startDate))
            }
            if event.endDate > cursor {
                cursor = event.endDate
            }
        }
        if cursor < endOfDay {
            gaps.append(DateInterval(start: cursor, end: endOfDay))
        }

        let activeStart = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: startOfDay)!
        let activeEnd = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: startOfDay)!

        let activeGaps = gaps.compactMap { gap -> DateInterval? in
            let start = max(gap.start, activeStart)
            let end = min(gap.end, activeEnd)
            guard end > start else { return nil }
            return DateInterval(start: start, end: end)
        }

        let totalFreeSeconds = activeGaps.reduce(0.0) { $0 + $1.duration }
        let totalActiveSeconds = activeEnd.timeIntervalSince(activeStart)
        let freeRatio = totalActiveSeconds > 0 ? totalFreeSeconds / totalActiveSeconds : 0

        freeWindows = activeGaps
        isFreeDay = freeRatio >= 0.5
    }

    private func findCurrentEvent() {
        let now = Date()
        currentEvent = todaysEvents.first { event in
            event.startDate <= now && event.endDate >= now
        }
    }

    private func findNextEvent() {
        let now = Date()
        nextEvent = todaysEvents
            .filter { $0.startDate > now }
            .min(by: { $0.startDate < $1.startDate })
    }

    private func calculateMonthlyEarnings(entries: [IncomeEntry], sessions: [WorkSession], targetCurrency: String) async {
        let calendar = Calendar.current
        guard let monthStart = calendar.dateInterval(of: .month, for: Date())?.start else {
            monthlyEarnings = 0
            return
        }

        let converter = CurrencyConversionService()
        var entryTotal = 0.0
        for entry in entries where entry.date >= monthStart {
            entryTotal += await convertedAmount(entry.amount, from: entry.currencyCode, to: targetCurrency, converter: converter)
        }

        var sessionTotal = 0.0
        for session in sessions where session.date >= monthStart {
            sessionTotal += await convertedAmount(session.totalEarned, from: session.currencyCode, to: targetCurrency, converter: converter)
        }

        monthlyEarnings = entryTotal + sessionTotal
    }

    private func convertedAmount(_ amount: Double, from sourceCurrency: String?, to targetCurrency: String, converter: CurrencyConversionService) async -> Double {
        let source = converter.normalizedCurrencyCode(sourceCurrency) ?? targetCurrency
        guard source != targetCurrency else { return amount }
        guard let result = try? await converter.convert(amount: amount, from: source, to: targetCurrency) else {
            return amount
        }
        return result.convertedAmount
    }
}
