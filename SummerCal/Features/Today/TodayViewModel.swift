import SwiftUI
import SwiftData

@Observable
final class TodayViewModel {
    var todaysEvents: [CalendarEvent] = []
    var currentEvent: CalendarEvent?
    var nextEvent: CalendarEvent?
    var isFreeDay: Bool = false
    var freeWindows: [DateInterval] = []
    var suggestions: [ActivitySuggestion] = []
    var weather: WeatherSnapshot?
    var monthlyEarnings: Double = 0
    var monthlyGoal: Double?
    var isLoading: Bool = false
    var errorMessage: String?
    var currencyCode: String = "USD"

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

        let incomeDescriptor = FetchDescriptor<IncomeEntry>(
            sortBy: [SortDescriptor(\.date)]
        )
        let allIncome = (try? modelContext.fetch(incomeDescriptor)) ?? []
        let sessionDescriptor = FetchDescriptor<WorkSession>(
            sortBy: [SortDescriptor(\.date)]
        )
        let allSessions = (try? modelContext.fetch(sessionDescriptor)) ?? []
        calculateMonthlyEarnings(entries: allIncome, sessions: allSessions)

        let settings = UserSettings.current(in: modelContext)
        monthlyGoal = settings.monthlyIncomeGoal
        currencyCode = settings.currencyCode

        detectFreeDay(calendar: calendar, startOfDay: startOfDay, endOfDay: endOfDay)
        findCurrentEvent()
        findNextEvent()
        isLoading = false
    }

    func refreshSuggestions(modelContext: ModelContext) async {
        let service = ActivitySuggestionService()
        let newSuggestions = service.generateQuickIdeas(weather: weather, preferences: [])
        for suggestion in newSuggestions {
            modelContext.insert(suggestion)
        }
        try? modelContext.save()
        suggestions = newSuggestions
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

        let totalFreeSeconds = gaps.reduce(0.0) { $0 + $1.duration }
        let thresholdHours = 4.0
        freeWindows = gaps
        isFreeDay = totalFreeSeconds >= thresholdHours * 3600
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

    private func calculateMonthlyEarnings(entries: [IncomeEntry], sessions: [WorkSession]) {
        let calendar = Calendar.current
        guard let monthStart = calendar.dateInterval(of: .month, for: Date())?.start else {
            monthlyEarnings = 0
            return
        }

        let entryTotal = entries
            .filter { $0.date >= monthStart }
            .reduce(0.0) { $0 + $1.amount }

        let sessionTotal = sessions
            .filter { $0.date >= monthStart }
            .reduce(0.0) { $0 + $1.totalEarned }

        monthlyEarnings = entryTotal + sessionTotal
    }
}
