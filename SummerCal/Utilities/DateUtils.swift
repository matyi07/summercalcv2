import Foundation

enum DateUtils {
    static let calendar = Calendar.current
    
    static func dayInterval(_ date: Date) -> DateInterval {
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            return DateInterval(start: start, end: start.addingTimeInterval(86400))
        }
        return DateInterval(start: start, end: end)
    }
    
    static func invertBusyIntervals(_ busy: [DateInterval], within day: DateInterval) -> [DateInterval] {
        guard !busy.isEmpty else { return [day] }
        var free: [DateInterval] = []
        var cursor = day.start
        for interval in busy {
            if cursor < interval.start {
                free.append(DateInterval(start: cursor, end: interval.start))
            }
            cursor = max(cursor, interval.end)
        }
        if cursor < day.end {
            free.append(DateInterval(start: cursor, end: day.end))
        }
        return free.filter { $0.duration > 60 }
    }
    
    static func isWeekend(_ date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }
    
    static func formattedTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f.string(from: date)
    }
    
    static func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }
    
    static func formattedDayAndDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: date)
    }
    
    static func timeOfDayGreeting() -> String {
        let hour = calendar.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        default: return "Good Evening"
        }
    }
    
    static func daysInMonth(_ date: Date) -> [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: date),
              let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) else {
            return []
        }
        return range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: startOfMonth)
        }
    }
    
    static func monthYearString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }
    
    static func startOfMonth(_ date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }
    
    static func startOfNextMonth(_ date: Date) -> Date {
        calendar.date(byAdding: .month, value: 1, to: startOfMonth(date)) ?? date
    }
    
    static func startOfPreviousMonth(_ date: Date) -> Date {
        calendar.date(byAdding: .month, value: -1, to: startOfMonth(date)) ?? date
    }
    
    static func weekdaySymbols() -> [String] {
        let f = DateFormatter()
        f.locale = Locale.current
        return f.veryShortWeekdaySymbols
    }
}
