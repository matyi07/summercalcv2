import SwiftUI
import Foundation

@Observable
final class CalendarViewModel {
    var currentMonth: Date
    var selectedDay: Date
    var eventsOnSelectedDay: [CalendarEvent] = []
    var allEvents: [CalendarEvent] = []
    var allWorkSessions: [WorkSession] = []

    private let calendar = Calendar.current

    init() {
        let now = Date()
        currentMonth = calendar.startOfMonth(for: now) ?? now
        selectedDay = calendar.startOfDay(for: now)
    }

    var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }

    var daysInMonth: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let monthStart = calendar.startOfMonth(for: currentMonth),
              let monthEnd = calendar.endOfMonth(for: currentMonth)
        else { return [] }

        let weekday = calendar.component(.weekday, from: monthStart)
        let leadingEmpty = weekday - calendar.firstWeekday

        var days: [Date] = []
        if leadingEmpty > 0 {
            for dayOffset in 0..<leadingEmpty {
                if let date = calendar.date(byAdding: .day, value: -leadingEmpty + dayOffset, to: monthStart) {
                    days.append(date)
                }
            }
        }

        let dayCount = calendar.dateComponents([.day], from: monthStart, to: monthEnd).day ?? 0
        for dayOffset in 0..<dayCount {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: monthStart) {
                days.append(date)
            }
        }

        let remaining = 7 - (days.count % 7)
        if remaining < 7 {
            for dayOffset in 0..<remaining {
                if let date = calendar.date(byAdding: .day, value: dayOffset, to: monthEnd) {
                    days.append(date)
                }
            }
        }

        return days
    }

    var weekdayHeaders: [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE"
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    func goToPreviousMonth() {
        guard let prev = calendar.date(byAdding: .month, value: -1, to: currentMonth) else { return }
        currentMonth = prev
        selectedDay = calendar.startOfDay(for: prev)
        updateEventsForSelectedDay()
    }

    func goToNextMonth() {
        guard let next = calendar.date(byAdding: .month, value: 1, to: currentMonth) else { return }
        currentMonth = next
        selectedDay = calendar.startOfDay(for: next)
        updateEventsForSelectedDay()
    }

    func selectDay(_ date: Date) {
        selectedDay = calendar.startOfDay(for: date)
        updateEventsForSelectedDay()
    }

    func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    func isCurrentMonth(_ date: Date) -> Bool {
        calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
    }

    func hasEvents(_ date: Date) -> Bool {
        let day = calendar.startOfDay(for: date)
        return allEvents.contains { calendar.isDate($0.startDate, inSameDayAs: day) }
    }

    func hasWorkSession(_ date: Date) -> Bool {
        let day = calendar.startOfDay(for: date)
        return allWorkSessions.contains { calendar.isDate($0.date, inSameDayAs: day) }
    }

    func dayIndicatorColor(_ date: Date) -> Color {
        let events = hasEvents(date)
        let work = hasWorkSession(date)
        if events && work { return .orange }
        if events { return .blue }
        if work { return .green }
        return .clear
    }

    func updateEventsForSelectedDay() {
        let day = calendar.startOfDay(for: selectedDay)
        eventsOnSelectedDay = allEvents.filter { event in
            calendar.isDate(event.startDate, inSameDayAs: day)
        }.sorted { $0.startDate < $1.startDate }
    }

    func refreshEvents(with events: [CalendarEvent]) {
        allEvents = events.sorted { $0.startDate < $1.startDate }
        updateEventsForSelectedDay()
    }

    func refreshWorkSessions(with sessions: [WorkSession]) {
        allWorkSessions = sessions
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date? {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components)
    }

    func endOfMonth(for date: Date) -> Date? {
        guard let start = startOfMonth(for: date) else { return nil }
        return self.date(byAdding: DateComponents(month: 1, day: -1), to: start)
    }
}
