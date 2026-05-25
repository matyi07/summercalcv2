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
    @State private var notificationEnabled: Bool = true
    @State private var reminderMinutesBefore: Int = 30
    @State private var selectedReminderOffsets: Set<Int> = [30]
    @State private var hasCustomReminderDate: Bool = false
    @State private var customReminderDate: Date = Date().addingTimeInterval(30 * 60)
    @State private var showPermissionAlert: Bool = false
    @State private var saveError: String?

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
                        .onChange(of: startDate) { _, newStart in
                            if endDate < newStart {
                                endDate = newStart.addingTimeInterval(3600)
                            }
                            if customReminderDate > newStart {
                                customReminderDate = defaultCustomReminderDate(for: newStart)
                            }
                        }

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

                if let saveError {
                    Section {
                        Label(saveError, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Toggle("Enable Reminder", isOn: $notificationEnabled)
                        .onChange(of: notificationEnabled) { _, enabled in
                            if enabled { checkNotificationPermission() }
                        }
                    if notificationEnabled {
                        ForEach(reminderOptions, id: \.self) { minutes in
                            Toggle(reminderLabel(minutes), isOn: Binding(
                                get: { selectedReminderOffsets.contains(minutes) },
                                set: { enabled in
                                    if enabled {
                                        selectedReminderOffsets.insert(minutes)
                                    } else {
                                        selectedReminderOffsets.remove(minutes)
                                    }
                                    if selectedReminderOffsets.isEmpty && !hasCustomReminderDate {
                                        selectedReminderOffsets.insert(30)
                                    }
                                }
                            ))
                        }

                        Toggle("Custom reminder date", isOn: $hasCustomReminderDate)
                            .onChange(of: hasCustomReminderDate) { _, enabled in
                                if enabled && customReminderDate > startDate {
                                    customReminderDate = defaultCustomReminderDate(for: startDate)
                                }
                                if !enabled && selectedReminderOffsets.isEmpty {
                                    selectedReminderOffsets.insert(30)
                                }
                            }

                        if hasCustomReminderDate {
                            DatePicker(
                                "Reminder",
                                selection: $customReminderDate,
                                in: customReminderRange,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            if customReminderDate > startDate {
                                Label("Custom reminders should be before the event start.", systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
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
                        if save() {
                            dismiss()
                        }
                    }
                    .disabled(title.isEmpty)
                }
            }
            .onAppear {
                if existingEvent == nil {
                    customReminderDate = defaultCustomReminderDate(for: startDate)
                    checkNotificationPermission()
                }
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
                    selectedReminderOffsets = Set(event.reminderOffsets())
                    if selectedReminderOffsets.isEmpty && event.customReminderDate == nil {
                        selectedReminderOffsets = [event.reminderMinutesBefore]
                    }
                    if let date = event.customReminderDate {
                        hasCustomReminderDate = true
                        customReminderDate = date
                    } else {
                        hasCustomReminderDate = false
                        customReminderDate = defaultCustomReminderDate(for: event.startDate)
                    }
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
                let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
                if !granted {
                    await MainActor.run {
                        notificationEnabled = false
                        showPermissionAlert = true
                    }
                }
            }
        }
    }

    private func save() -> Bool {
        saveError = nil
        let selectedOffsets = Array(selectedReminderOffsets).sorted()
        let sanitizedCustomReminder = hasCustomReminderDate ? min(customReminderDate, startDate) : nil

        if let event = existingEvent {
            event.title = title
            event.startDate = startDate
            event.endDate = endDate
            event.isAllDay = isAllDay
            event.location = location.isEmpty ? nil : location
            event.notes = notes.isEmpty ? nil : notes
            event.category = category
            event.isOutdoor = isOutdoor
            event.notificationEnabled = notificationEnabled
            event.setReminderOffsets(selectedOffsets)
            reminderMinutesBefore = event.reminderMinutesBefore
            event.customReminderDate = sanitizedCustomReminder
            event.updatedAt = Date()
            do {
                try modelContext.save()
            } catch {
                saveError = "Could not save event: \(error.localizedDescription)"
                return false
            }

            Task {
                await NotificationService.shared.cancelAll(forEventId: event.id)
                if notificationEnabled {
                    _ = await NotificationService.shared.scheduleAllEventReminders(event: event, notes: nil)
                }
            }
            WidgetDataService.refreshTodayEvents(modelContext: modelContext)
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
                reminderMinutesBefore: selectedOffsets.first ?? 30,
                reminderMinutesBeforeList: selectedOffsets.map(String.init).joined(separator: ","),
                customReminderDate: sanitizedCustomReminder
            )
            modelContext.insert(event)
            do {
                try modelContext.save()
            } catch {
                modelContext.delete(event)
                saveError = "Could not save event: \(error.localizedDescription)"
                return false
            }

            if notificationEnabled {
                Task {
                    _ = await NotificationService.shared.scheduleAllEventReminders(event: event, notes: nil)
                }
            }
            WidgetDataService.refreshTodayEvents(modelContext: modelContext)
        }
        return true
    }

    private func reminderLabel(_ minutes: Int) -> String {
        switch minutes {
        case 0: return "At time of event"
        case 60: return "1 hour before"
        case 1440: return "1 day before"
        default: return "\(minutes) minutes before"
        }
    }

    private func defaultCustomReminderDate(for start: Date) -> Date {
        let soon = Date().addingTimeInterval(60)
        if start <= soon {
            return max(start, Date())
        }
        return max(soon, start.addingTimeInterval(-30 * 60))
    }

    private var customReminderRange: ClosedRange<Date> {
        let lower = Date()
        let upper = max(startDate, lower)
        return lower...upper
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
