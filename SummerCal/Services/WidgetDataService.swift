import Foundation
import SwiftData
import WidgetKit

enum WidgetDataService {
    static func refreshTodayEvents(modelContext: ModelContext) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let horizon = calendar.date(byAdding: .day, value: 7, to: startOfDay) ?? startOfDay.addingTimeInterval(7 * 86_400)

        let descriptor = FetchDescriptor<CalendarEvent>(
            predicate: #Predicate { event in
                event.startDate >= startOfDay && event.startDate < horizon
            },
            sortBy: [SortDescriptor(\.startDate)]
        )

        let events = ((try? modelContext.fetch(descriptor)) ?? []).map {
            WidgetEventSnapshot(
                id: $0.id.uuidString,
                title: $0.title,
                startDate: $0.startDate,
                endDate: $0.endDate,
                isAllDay: $0.isAllDay,
                location: $0.location,
                notes: $0.notes
            )
        }

        WidgetEventStore.saveTodayEvents(events)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
