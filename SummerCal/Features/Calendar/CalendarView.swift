import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appRouter: AppRouter

    @State private var viewModel = CalendarViewModel()
    @State private var showAddEvent = false

    @Query(sort: \CalendarEvent.startDate) private var events: [CalendarEvent]
    @Query(sort: \WorkSession.date) private var workSessions: [WorkSession]

    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        VStack(spacing: 0) {
            monthHeader

            weekdayHeadersRow

            colorLegend

            monthGrid

            Divider()
                .padding(.horizontal)

            agendaList
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddEvent = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddEvent) {
            NavigationStack {
                AddEventView()
            }
        }
        .onAppear {
            viewModel.refreshEvents(with: events)
            viewModel.refreshWorkSessions(with: workSessions)
        }
        .onChange(of: events) { _, newEvents in
            viewModel.refreshEvents(with: newEvents)
        }
        .onChange(of: workSessions) { _, newSessions in
            viewModel.refreshWorkSessions(with: newSessions)
        }
        .onChange(of: appRouter.selectedTab) { _, tab in
            if tab == .calendar {
                viewModel.refreshEvents(with: events)
                viewModel.refreshWorkSessions(with: workSessions)
            }
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                withAnimation { viewModel.goToPreviousMonth() }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .foregroundColor(.orange)
            }
            .frame(minWidth: 44, minHeight: 44)
            .padding(.leading)

            Spacer()

            Text(viewModel.monthTitle)
                .font(.title3.weight(.semibold))

            Spacer()

            Button {
                withAnimation { viewModel.goToNextMonth() }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundColor(.orange)
            }
            .frame(minWidth: 44, minHeight: 44)
            .padding(.trailing)
        }
        .padding(.vertical, 8)
    }

    private var weekdayHeadersRow: some View {
        HStack(spacing: 0) {
            ForEach(viewModel.weekdayHeaders, id: \.self) { day in
                Text(day)
                    .font(.caption.weight(.medium))
                    .foregroundColor(Color(.systemGray))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }

    private var colorLegend: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                Circle().fill(.green).frame(width: 8, height: 8)
                Text("Free").font(.caption2).foregroundStyle(Color(.systemGray))
            }
            HStack(spacing: 4) {
                Circle().fill(.yellow).frame(width: 8, height: 8)
                Text("Partial").font(.caption2).foregroundStyle(Color(.systemGray))
            }
            HStack(spacing: 4) {
                Circle().fill(.red).frame(width: 8, height: 8)
                Text("Busy").font(.caption2).foregroundStyle(Color(.systemGray))
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
    }

    private var monthGrid: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(viewModel.daysInMonth, id: \.self) { date in
                dayCell(date)
            }
        }
        .padding(.horizontal, 8)
    }

    private func dayCell(_ date: Date) -> some View {
        let dayNumber = Calendar.current.component(.day, from: date)
        let isSelected = Calendar.current.isDate(date, inSameDayAs: viewModel.selectedDay)
        let isToday = viewModel.isToday(date)
        let inCurrentMonth = viewModel.isCurrentMonth(date)

        return Button {
            withAnimation { viewModel.selectDay(date) }
        } label: {
            VStack(spacing: 4) {
                Text("\(dayNumber)")
                    .font(.callout.weight(isToday ? .bold : .regular))
                    .foregroundColor(inCurrentMonth ? (isToday ? .white : .primary) : Color(.systemGray3))
                    .frame(width: 32, height: 32)
                    .background(
                        Group {
                            if isToday {
                                Circle().fill(Color.orange)
                            } else if isSelected {
                                Circle().fill(Color.orange.opacity(0.2))
                            }
                        }
                    )

                Circle()
                    .fill(viewModel.dayIndicatorColor(date))
                    .frame(width: 8, height: 8)
            }
        }
        .buttonStyle(.plain)
    }

    private var agendaList: some View {
        List {
            if viewModel.eventsOnSelectedDay.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.title2)
                            .foregroundColor(Color(.systemGray))
                        Text("No events")
                            .font(.subheadline)
                            .foregroundColor(Color(.systemGray))
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.eventsOnSelectedDay) { event in
                    Button {
                        appRouter.navigateToEvent(event.id)
                    } label: {
                        eventRow(event)
                    }
                }
                .onDelete(perform: deleteEvents)
            }
        }
        .listStyle(.plain)
    }

    private func eventRow(_ event: CalendarEvent) -> some View {
        HStack(spacing: 12) {
            Image(systemName: iconForCategory(event.category))
                .foregroundColor(categoryColor(event.category))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.body.weight(.medium))
                    .foregroundColor(.primary)

                if event.isAllDay {
                    Text("All Day")
                        .font(.caption)
                        .foregroundColor(Color(.systemGray))
                } else {
                    Text("\(event.startDate, style: .time) – \(event.endDate, style: .time)")
                        .font(.caption)
                        .foregroundColor(Color(.systemGray))
                }
            }
        }
        .frame(minHeight: 44)
        .padding(.vertical, 4)
    }

    private func deleteEvents(at offsets: IndexSet) {
        for index in offsets {
            let event = viewModel.eventsOnSelectedDay[index]
            Task { await NotificationService.shared.cancelAll(forEventId: event.id) }
            modelContext.delete(event)
        }
        try? modelContext.save()
    }

    private func iconForCategory(_ category: String?) -> String {
        switch category {
        case "meeting": return "person.2"
        case "workout": return "figure.run"
        case "appointment": return "stethoscope"
        case "travel": return "airplane"
        case "social": return "bubble.left"
        case "errand": return "cart"
        default: return "calendar"
        }
    }

    private func categoryColor(_ category: String?) -> Color {
        switch category {
        case "meeting": return .blue
        case "workout": return .green
        case "appointment": return .red
        case "travel": return .purple
        case "social": return .pink
        case "errand": return .teal
        default: return .orange
        }
    }
}
