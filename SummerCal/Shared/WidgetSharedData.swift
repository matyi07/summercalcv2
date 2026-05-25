import Foundation

enum SummerCalWidgetShared {
    static let appGroupIdentifier = "group.com.summercal.v2"
    static let todayEventsKey = "today_events"
    static let appURLScheme = "summercal"
    static let addReceiptURL = URL(string: "\(appURLScheme)://add-expense?camera=1")!
}

struct WidgetEventSnapshot: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let location: String?
    let notes: String?
}

enum WidgetEventStore {
    static func sharedDefaults() -> UserDefaults {
        UserDefaults(suiteName: SummerCalWidgetShared.appGroupIdentifier) ?? .standard
    }

    static func saveTodayEvents(_ events: [WidgetEventSnapshot]) {
        guard let data = try? JSONEncoder().encode(events) else { return }
        sharedDefaults().set(data, forKey: SummerCalWidgetShared.todayEventsKey)
    }

    static func loadTodayEvents() -> [WidgetEventSnapshot] {
        guard let data = sharedDefaults().data(forKey: SummerCalWidgetShared.todayEventsKey),
              let events = try? JSONDecoder().decode([WidgetEventSnapshot].self, from: data) else {
            return []
        }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay.addingTimeInterval(86_400)
        return events
            .filter { $0.startDate >= startOfDay && $0.startDate < endOfDay }
            .sorted { $0.startDate < $1.startDate }
    }
}
