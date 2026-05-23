import Foundation

final class FreeDayDetectionService {
    private let calendar = Calendar.current

    func freeWindows(for date: Date, events: [CalendarEvent]) -> [DateInterval] {
        let day = dayInterval(date)
        let busy = events
            .filter { $0.overlaps(day) }
            .map { DateInterval(start: max($0.startDate, day.start), end: min($0.endDate, day.end)) }
            .sorted { $0.start < $1.start }

        return invertBusyIntervals(busy, within: day)
    }

    func shouldNotifyFreeDay(freeWindows: [DateInterval], thresholdHours: Double) -> Bool {
        freeWindows.contains { $0.duration >= thresholdHours * 3600 }
    }

    func largestFreeWindow(for date: Date, events: [CalendarEvent]) -> DateInterval? {
        freeWindows(for: date, events: events).max(by: { $0.duration < $1.duration })
    }

    func notificationBody(for freeWindows: [DateInterval], weather: WeatherSnapshot?) -> String {
        let totalFree = freeWindows.reduce(0.0) { $0 + $1.duration } / 3600.0
        let hours = Int(totalFree)

        if let weather = weather {
            if weather.precipitationChance > 0.5 {
                return "You have about \(hours) free hours today. Rain is likely - indoor ideas: cafe, museum, gym, or focused work."
            } else if weather.temperatureCelsius > 25 {
                return "You have about \(hours) free hours today. Great weather for outdoor activities!"
            } else {
                return "You have about \(hours) free hours today. Want ideas based on weather and nearby places?"
            }
        }
        return "You have about \(hours) free hours today. Want ideas based on weather and places nearby?"
    }

    private func dayInterval(_ date: Date) -> DateInterval {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return DateInterval(start: start, end: end)
    }

    private func invertBusyIntervals(_ intervals: [DateInterval], within container: DateInterval) -> [DateInterval] {
        var free: [DateInterval] = []
        var cursor = container.start

        for interval in intervals {
            if cursor < interval.start {
                free.append(DateInterval(start: cursor, end: interval.start))
            }
            if interval.end > cursor {
                cursor = interval.end
            }
        }

        if cursor < container.end {
            free.append(DateInterval(start: cursor, end: container.end))
        }

        return free
    }
}
