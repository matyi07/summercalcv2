import WidgetKit
import SwiftUI

@main
struct SummerCalWidgetBundle: WidgetBundle {
    var body: some Widget {
        AddReceiptWidget()
        TodayEventsWidget()
    }
}

struct AddReceiptWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AddReceiptWidget", provider: AddReceiptProvider()) { entry in
            AddReceiptWidgetView(entry: entry)
        }
        .configurationDisplayName("Add Receipt")
        .description("Open SummerCal directly to the receipt camera.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct AddReceiptEntry: TimelineEntry {
    let date: Date
}

struct AddReceiptProvider: TimelineProvider {
    func placeholder(in context: Context) -> AddReceiptEntry {
        AddReceiptEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (AddReceiptEntry) -> Void) {
        completion(AddReceiptEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AddReceiptEntry>) -> Void) {
        completion(Timeline(entries: [AddReceiptEntry(date: Date())], policy: .never))
    }
}

struct AddReceiptWidgetView: View {
    let entry: AddReceiptEntry

    var body: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(Color.orange.gradient)

            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "camera.viewfinder")
                    .font(.title)
                    .foregroundStyle(.white)

                Text("Add Receipt")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                Text("Open camera")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding()
        }
        .widgetURL(SummerCalWidgetShared.addReceiptURL)
        .containerBackground(Color.orange.gradient, for: .widget)
    }
}

struct TodayEventsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayEventsWidget", provider: TodayEventsProvider()) { entry in
            TodayEventsWidgetView(entry: entry)
        }
        .configurationDisplayName("Today's Events")
        .description("See the next events scheduled for today.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct TodayEventsEntry: TimelineEntry {
    let date: Date
    let events: [WidgetEventSnapshot]
}

struct TodayEventsProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEventsEntry {
        TodayEventsEntry(
            date: Date(),
            events: [
                WidgetEventSnapshot(
                    id: UUID().uuidString,
                    title: "Team meeting",
                    startDate: Date().addingTimeInterval(1800),
                    endDate: Date().addingTimeInterval(5400),
                    isAllDay: false,
                    location: "Office",
                    notes: nil
                )
            ]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEventsEntry) -> Void) {
        completion(TodayEventsEntry(date: Date(), events: WidgetEventStore.loadTodayEvents()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEventsEntry>) -> Void) {
        let events = WidgetEventStore.loadTodayEvents()
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [TodayEventsEntry(date: Date(), events: events)], policy: .after(nextRefresh)))
    }
}

struct TodayEventsWidgetView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    let entry: TodayEventsEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Today", systemImage: "calendar")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                Spacer()
                Text(entry.date, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if entry.events.isEmpty {
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Image(systemName: "checkmark.circle")
                        .font(.title2)
                        .foregroundStyle(.green)
                    Text("No events")
                        .font(.headline)
                    Text("Your day is clear.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                ForEach(entry.events.prefix(maxRows), id: \.id) { event in
                    eventRow(event)
                }
                Spacer(minLength: 0)
            }
        }
        .padding()
        .containerBackground(.background, for: .widget)
        .widgetURL(URL(string: "\(SummerCalWidgetShared.appURLScheme)://today"))
    }

    private var maxRows: Int {
        switch widgetFamily {
        case .systemSmall:
            return 2
        case .systemLarge:
            return 7
        default:
            return 4
        }
    }

    private func eventRow(_ event: WidgetEventSnapshot) -> some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.orange)
                .frame(width: 3, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                Text(timeLabel(for: event))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func timeLabel(for event: WidgetEventSnapshot) -> String {
        if event.isAllDay {
            return "All day"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return "\(formatter.string(from: event.startDate)) - \(formatter.string(from: event.endDate))"
    }
}
