import SwiftUI
import SwiftData

struct AddEventView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var existingEvent: CalendarEvent?

    @State private var title: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date().addingTimeInterval(3600)
    @State private var isAllDay: Bool = false
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var category: String = "general"
    @State private var isOutdoor: Bool = false

    private let categories = ["general", "meeting", "workout", "appointment", "travel", "social", "errand"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Event Title", text: $title)
                }

                Section("Time") {
                    Toggle("All Day", isOn: $isAllDay)

                    DatePicker("Starts", selection: $startDate, displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])

                    DatePicker("Ends", selection: $endDate, in: startDate..., displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                        .onChange(of: startDate) { _, newStart in
                            if endDate < newStart {
                                endDate = newStart.addingTimeInterval(3600)
                            }
                        }
                }

                Section("Details") {
                    Picker("Type", selection: $category) {
                        ForEach(categories, id: \.self) { cat in
                            Label(cat.capitalized, systemImage: iconForCategory(cat))
                                .tag(cat)
                        }
                    }

                    TextField("Location", text: $location)

                    Toggle("Outdoor Event", isOn: $isOutdoor)
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle(existingEvent == nil ? "New Event" : "Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .onAppear {
                if let event = existingEvent {
                    title = event.title
                    startDate = event.startDate
                    endDate = event.endDate
                    isAllDay = event.isAllDay
                    location = event.location ?? ""
                    notes = event.notes ?? ""
                    category = event.category ?? "general"
                    isOutdoor = event.isOutdoor
                }
            }
        }
    }

    private func save() {
        if let event = existingEvent {
            event.title = title
            event.startDate = startDate
            event.endDate = endDate
            event.isAllDay = isAllDay
            event.location = location.isEmpty ? nil : location
            event.notes = notes.isEmpty ? nil : notes
            event.category = category
            event.isOutdoor = isOutdoor
            event.updatedAt = Date()
        } else {
            let event = CalendarEvent(
                title: title,
                startDate: startDate,
                endDate: endDate,
                isAllDay: isAllDay,
                location: location.isEmpty ? nil : location,
                notes: notes.isEmpty ? nil : notes,
                category: category,
                isOutdoor: isOutdoor
            )
            modelContext.insert(event)
        }
        try? modelContext.save()
    }

    private func iconForCategory(_ category: String) -> String {
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
}
