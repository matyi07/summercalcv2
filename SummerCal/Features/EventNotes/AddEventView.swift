import SwiftUI
import SwiftData
import UserNotifications

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
    @State private var notificationEnabled: Bool = false
    @State private var reminderMinutesBefore: Int = 30
    @State private var showPermissionAlert: Bool = false

    private let categories = ["general", "meeting", "workout", "appointment", "travel", "social", "errand"]
    private let reminderOptions = [0, 5, 10, 15, 30, 60, 1440]

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

                Section {
                    Toggle("Enable Reminder", isOn: $notificationEnabled)
                        .onChange(of: notificationEnabled) { _, enabled in
                            if enabled { checkNotificationPermission() }
                        }
                    if notificationEnabled {
                        Picker("Remind", selection: $reminderMinutesBefore) {
                            Text("At time of event").tag(0)
                            Text("5 minutes before").tag(5)
                            Text("10 minutes before").tag(10)
                            Text("15 minutes before").tag(15)
                            Text("30 minutes before").tag(30)
                            Text("1 hour before").tag(60)
                            Text("1 day before").tag(1440)
                        }
                    }
                } header: {
                    Text("Reminder")
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
                notificationEnabled = event.notificationEnabled
                reminderMinutesBefore = event.reminderMinutesBefore
            }
        }
        .alert("Notifications Disabled", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {
                notificationEnabled = false
            }
        } message: {
            Text("Notifications are disabled for SummerCal. Enable them in Settings to receive event reminders.")
        }
        }
    }

    private func checkNotificationPermission() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            if settings.authorizationStatus == .denied {
                await MainActor.run { showPermissionAlert = true }
            } else if settings.authorizationStatus == .notDetermined {
                _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            }
        }
    }

    private func save() {
        if let event = existingEvent {
            let timeChanged = event.startDate != startDate || event.endDate != endDate
            let reminderChanged = event.reminderMinutesBefore != reminderMinutesBefore || event.notificationEnabled != notificationEnabled

            event.title = title
            event.startDate = startDate
            event.endDate = endDate
            event.isAllDay = isAllDay
            event.location = location.isEmpty ? nil : location
            event.notes = notes.isEmpty ? nil : notes
            event.category = category
            event.isOutdoor = isOutdoor
            event.notificationEnabled = notificationEnabled
            event.reminderMinutesBefore = reminderMinutesBefore
            event.updatedAt = Date()
            try? modelContext.save()

            if timeChanged || reminderChanged {
                Task {
                    await NotificationService.shared.cancelAll(forEventId: event.id)
                    if notificationEnabled {
                        _ = await NotificationService.shared.scheduleEventReminder(event: event, minutesBefore: reminderMinutesBefore, notes: nil)
                    }
                }
            }
        } else {
            let event = CalendarEvent(
                title: title,
                startDate: startDate,
                endDate: endDate,
                isAllDay: isAllDay,
                location: location.isEmpty ? nil : location,
                notes: notes.isEmpty ? nil : notes,
                category: category,
                isOutdoor: isOutdoor,
                notificationEnabled: notificationEnabled,
                reminderMinutesBefore: reminderMinutesBefore
            )
            modelContext.insert(event)
            try? modelContext.save()

            if notificationEnabled {
                Task {
                    _ = await NotificationService.shared.scheduleEventReminder(event: event, minutesBefore: reminderMinutesBefore, notes: nil)
                }
            }
        }
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
