import SwiftUI
import SwiftData

struct EventDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appRouter: AppRouter

    let eventId: UUID

    @State private var event: CalendarEvent?
    @State private var viewModel = EventNoteViewModel()
    @State private var selectedTab: EventDetailTab = .notes
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showNoteSheet = false

    @Query private var reminders: [EventReminder]
    @Query private var weatherSnapshots: [WeatherSnapshot]

    enum EventDetailTab: String, CaseIterable {
        case notes = "Notes"
        case prep = "Prep"
        case checklist = "Checklist"
        case links = "Links"
        case weather = "Weather"
    }

    init(eventId: UUID) {
        self.eventId = eventId
        let id = eventId
        _reminders = Query(filter: #Predicate<EventReminder> { $0.eventId == id }, sort: \.reminderDate)
        _weatherSnapshots = Query(sort: \.forecastDate)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let event = event {
                    eventHeader(event)

                    Divider()
                        .padding(.horizontal)

                    Picker("Tab", selection: $selectedTab) {
                        ForEach(EventDetailTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    tabContent
                } else {
                    ProgressView()
                        .padding(.top, 100)
                }
            }
        }
        .navigationTitle(event?.title ?? "Event")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showEditSheet = true
                    } label: {
                        Label("Edit Event", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Event", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(item: Binding<CalendarEvent?>(
            get: { showEditSheet ? event : nil },
            set: { showEditSheet = $0 != nil }
        )) { ev in
            NavigationStack {
                AddEventView(existingEvent: ev)
            }
        }
        .sheet(isPresented: $showNoteSheet) {
            EventNoteView(eventId: eventId, eventNoteViewModel: viewModel)
        }
        .alert("Delete Event", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteEvent()
            }
        } message: {
            Text("Are you sure you want to delete \"\(event?.title ?? "")\"? This cannot be undone.")
        }
        .onAppear {
            fetchEvent()
            viewModel.fetchNotes(for: eventId, modelContext: modelContext)
        }
    }

    func reminderLabel(_ minutes: Int) -> String {
        switch minutes {
        case 0: return "at event time"
        case 5: return "5 min before"
        case 10: return "10 min before"
        case 15: return "15 min before"
        case 30: return "30 min before"
        case 60: return "1 hour before"
        case 1440: return "1 day before"
        default: return "\(minutes) min before"
        }
    }

    private func fetchEvent() {
        let descriptor = FetchDescriptor<CalendarEvent>(
            predicate: #Predicate { $0.id == eventId }
        )
        event = (try? modelContext.fetch(descriptor))?.first
    }

    private func eventHeader(_ event: CalendarEvent) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(event.title)
                .font(.title2.weight(.bold))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                if event.isAllDay {
                    Text(event.startDate, style: .date)
                        .font(.subheadline)
                        .foregroundColor(Color(.systemGray))
                } else {
                    HStack(spacing: 4) {
                        Text(event.startDate, style: .date)
                        Text(event.startDate, style: .time)
                        Text("–")
                        Text(event.endDate, style: .time)
                    }
                    .font(.subheadline)
                    .foregroundColor(Color(.systemGray))
                }

                if let category = event.category {
                    Label(category.capitalized, systemImage: "tag")
                        .font(.subheadline)
                        .foregroundColor(Color(.systemGray))
                }
            }

            if let location = event.location, !location.isEmpty {
                Label(location, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundColor(Color(.systemGray))
            }

            if event.isOutdoor {
                Label("Outdoor", systemImage: "leaf")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }

            if event.notificationEnabled {
                HStack(spacing: 4) {
                    Image(systemName: "bell.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("Reminder \(reminderLabel(event.reminderMinutesBefore))")
                        .font(.subheadline)
                        .foregroundColor(Color(.systemGray))
                }
            }

            if let notes = event.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes")
                        .font(.caption)
                        .foregroundColor(Color(.systemGray))
                    Text(notes)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
            }

            remindersSection
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Reminders")
                .font(.caption.weight(.semibold))
                .foregroundColor(Color(.systemGray))
                .textCase(.uppercase)

            if reminders.isEmpty {
                Text("No reminders set")
                    .font(.subheadline)
                    .foregroundColor(Color(.systemGray))
            } else {
                ForEach(reminders) { reminder in
                    HStack {
                        Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(reminder.isCompleted ? .green : Color(.systemGray))
                        Text(reminder.reminderDate, style: .date)
                        Text(reminder.reminderDate, style: .time)
                            .foregroundColor(Color(.systemGray))
                    }
                    .font(.subheadline)
                }
            }

            Button {
                scheduleReminder()
            } label: {
                Label("Add Reminder", systemImage: "bell.badge")
                    .font(.subheadline)
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .notes:
            notesTab
        case .prep:
            prepTab
        case .checklist:
            checklistTab
        case .links:
            linksTab
        case .weather:
            weatherTab
        }
    }

    private var notesTab: some View {
        VStack(spacing: 12) {
            Button {
                showNoteSheet = true
            } label: {
                Label("Add Note", systemImage: "plus")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange))
            }
            .padding(.horizontal)

            let general = viewModel.generalNotes
            if general.isEmpty {
                emptyTabState("No notes yet")
            } else {
                ForEach(general) { note in
                    noteCard(note)
                }
            }
        }
    }

    private var prepTab: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    await viewModel.generatePrepNote(for: eventId, modelContext: modelContext)
                    viewModel.fetchNotes(for: eventId, modelContext: modelContext)
                }
            } label: {
                HStack {
                    if viewModel.isGeneratingPrep {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(viewModel.isGeneratingPrep ? "Generating..." : "AI Generate Prep")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.purple))
            }
            .disabled(viewModel.isGeneratingPrep)
            .padding(.horizontal)

            let prep = viewModel.prepNotes
            if prep.isEmpty {
                emptyTabState("No prep notes")
            } else {
                ForEach(prep) { note in
                    noteCard(note)
                }
            }
        }
    }

    private var checklistTab: some View {
        VStack(spacing: 12) {
            let checklist = viewModel.checklistNotes
            if checklist.isEmpty {
                emptyTabState("No checklists")
            } else {
                ForEach(checklist) { note in
                    checklistSection(note)
                }
            }

            Button {
                showNoteSheet = true
            } label: {
                Label("Add Checklist", systemImage: "plus")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange))
            }
            .padding(.horizontal)
        }
    }

    private func checklistSection(_ note: EventNote) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !note.body.isEmpty {
                Text(note.body)
                    .font(.subheadline)
                    .foregroundColor(Color(.systemGray))
            }

            ForEach(note.checklistItems.indices, id: \.self) { index in
                let item = note.checklistItems[index]
                let isChecked = item.hasPrefix("[x] ")
                let display = isChecked ? String(item.dropFirst(4)) : String(item.dropFirst(4))

                Button {
                    viewModel.toggleChecklistItem(in: note, at: index, modelContext: modelContext)
                    viewModel.fetchNotes(for: eventId, modelContext: modelContext)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                            .foregroundColor(isChecked ? .green : Color(.systemGray))
                        Text(display)
                            .strikethrough(isChecked)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground)).shadow(color: .black.opacity(0.05), radius: 3))
        .padding(.horizontal)
    }

    private var linksTab: some View {
        VStack(spacing: 12) {
            let linkNotes = viewModel.linkNotes
            if linkNotes.isEmpty {
                emptyTabState("No links")
            } else {
                ForEach(linkNotes) { note in
                    linksSection(note)
                }
            }
        }
    }

    private func linksSection(_ note: EventNote) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !note.body.isEmpty {
                Text(note.body)
                    .font(.subheadline)
                    .foregroundColor(Color(.systemGray))
            }

            ForEach(note.links.indices, id: \.self) { index in
                let url = note.links[index]
                HStack {
                    Image(systemName: "link")
                        .foregroundColor(.blue)
                    Text(url)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.blue.opacity(0.05)))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground)).shadow(color: .black.opacity(0.05), radius: 3))
        .padding(.horizontal)
    }

    private var weatherTab: some View {
        VStack(spacing: 12) {
            if let ev = event {
                // Filter to snapshots within the event's time window
                let eventWeather = weatherSnapshots.filter { snapshot in
                    snapshot.forecastDate >= ev.startDate && snapshot.forecastDate <= ev.endDate
                }

                if eventWeather.isEmpty {
                    // Fall back to same-day weather
                    let dayWeather = weatherSnapshots.filter { snapshot in
                        Calendar.current.isDate(snapshot.forecastDate, inSameDayAs: ev.startDate)
                    }
                    if dayWeather.isEmpty {
                        emptyTabState("No weather data for event time")
                    } else {
                        Text("No hourly data for event window — showing today's forecast")
                            .font(.caption)
                            .foregroundColor(Color(.systemGray))
                            .padding(.horizontal)
                        ForEach(dayWeather.prefix(6)) { snapshot in
                            weatherCard(snapshot)
                        }
                    }
                } else {
                    ForEach(eventWeather.prefix(8)) { snapshot in
                        weatherCard(snapshot)
                    }
                }
            } else {
                emptyTabState("Loading event...")
            }
        }
    }

    private func weatherCard(_ snapshot: WeatherSnapshot) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: weatherIcon(for: snapshot.condition))
                    .font(.title)
                    .foregroundColor(.blue)
                VStack(alignment: .leading) {
                    Text("\(Int(snapshot.temperatureCelsius))°C")
                        .font(.headline)
                    Text(snapshot.condition)
                        .font(.subheadline)
                        .foregroundColor(Color(.systemGray))
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("\(Int(snapshot.precipitationChance * 100))% rain")
                        .font(.caption)
                        .foregroundColor(Color(.systemGray))
                    if let wind = snapshot.windSpeedKph {
                        Text("\(Int(wind)) km/h wind")
                            .font(.caption)
                            .foregroundColor(Color(.systemGray))
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground)).shadow(color: .black.opacity(0.05), radius: 3))
        .padding(.horizontal)
    }

    private func noteCard(_ note: EventNote) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(note.body)
                .font(.body)
                .foregroundColor(Color(.label))

            Text(note.createdAt, style: .date)
                .font(.caption)
                .foregroundColor(Color(.systemGray))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground)).shadow(color: .black.opacity(0.05), radius: 3))
        .padding(.horizontal)
        .contextMenu {
            Button(role: .destructive) {
                viewModel.deleteNote(note, modelContext: modelContext)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func emptyTabState(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.title2)
                .foregroundColor(Color(.systemGray))
            Text(message)
                .font(.subheadline)
                .foregroundColor(Color(.systemGray))
        }
        .padding(.vertical, 40)
    }

    private func scheduleReminder() {
        guard let event = event else { return }
        let reminderDate = event.startDate.addingTimeInterval(-30 * 60)
        let reminder = EventReminder(
            eventId: eventId,
            reminderDate: max(reminderDate, Date())
        )
        modelContext.insert(reminder)
        try? modelContext.save()
    }

    private func deleteEvent() {
        guard let event = event else { return }
        for reminder in reminders {
            modelContext.delete(reminder)
        }
        viewModel.notes.forEach { modelContext.delete($0) }
        modelContext.delete(event)
        try? modelContext.save()

        Task {
            await NotificationService.shared.cancelAll(forEventId: event.id)
        }
        dismiss()
    }

    private func weatherIcon(for condition: String) -> String {
        let lower = condition.lowercased()
        if lower.contains("rain") { return "cloud.rain" }
        if lower.contains("snow") { return "cloud.snow" }
        if lower.contains("cloud") { return "cloud" }
        if lower.contains("clear") || lower.contains("sun") { return "sun.max" }
        if lower.contains("fog") { return "cloud.fog" }
        if lower.contains("wind") { return "wind" }
        return "cloud.sun"
    }
}
