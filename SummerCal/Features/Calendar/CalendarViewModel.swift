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
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth)
        else { return [] }

        let monthStart = monthInterval.start
        let monthEnd = monthInterval.end
        let weekday = calendar.component(.weekday, from: monthStart)
        let leadingEmpty = (weekday - calendar.firstWeekday + 7) % 7

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

    var eventsInCurrentMonth: [CalendarEvent] {
        guard let monthStart = calendar.startOfMonth(for: currentMonth),
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
            return []
        }
        let monthInterval = DateInterval(start: monthStart, end: nextMonth)
        return allEvents.filter { event in
            event.overlaps(monthInterval)
        }.sorted { $0.startDate < $1.startDate }
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
        let interval = dayInterval(for: date)
        return allEvents.contains { $0.overlaps(interval) }
    }

    func hasWorkSession(_ date: Date) -> Bool {
        let day = calendar.startOfDay(for: date)
        return allWorkSessions.contains { calendar.isDate($0.date, inSameDayAs: day) }
    }

    func dayIndicatorColor(_ date: Date) -> Color {
        let day = calendar.startOfDay(for: date)
        let activeStart = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: day)!
        let activeEnd = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: day)!

        let fullDay = dayInterval(for: day)
        let dayEvents = allEvents.filter { $0.overlaps(fullDay) }

        if dayEvents.isEmpty {
            return .green
        }

        let hasBusyDayEvent = dayEvents.contains { event in
            event.isAllDay || (event.startDate <= activeStart && event.endDate >= activeEnd)
        }
        if hasBusyDayEvent {
            return .red
        }

        var gaps: [DateInterval] = []
        var cursor = activeStart
        let sorted = dayEvents.sorted(by: { $0.startDate < $1.startDate })
        for event in sorted where !event.isAllDay {
            let evStart = max(event.startDate, activeStart)
            let evEnd = min(event.endDate, activeEnd)
            if evStart > cursor {
                gaps.append(DateInterval(start: cursor, end: evStart))
            }
            if evEnd > cursor {
                cursor = evEnd
            }
        }
        if cursor < activeEnd {
            gaps.append(DateInterval(start: cursor, end: activeEnd))
        }

        let totalFree = gaps.reduce(0.0) { $0 + $1.duration } / 3600.0
        let totalActive = activeEnd.timeIntervalSince(activeStart) / 3600.0

        if totalActive <= 0 || dayEvents.isEmpty { return .green }
        let freeRatio = totalFree / totalActive

        return freeRatio >= 0.3 ? .yellow : .red
    }

    func updateEventsForSelectedDay() {
        let day = dayInterval(for: selectedDay)
        eventsOnSelectedDay = allEvents.filter { event in
            event.overlaps(day)
        }.sorted { $0.startDate < $1.startDate }
    }

    func refreshEvents(with events: [CalendarEvent]) {
        allEvents = events.sorted { $0.startDate < $1.startDate }
        updateEventsForSelectedDay()
    }

    func refreshWorkSessions(with sessions: [WorkSession]) {
        allWorkSessions = sessions
    }

    private func dayInterval(for date: Date) -> DateInterval {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return DateInterval(start: start, end: end)
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
