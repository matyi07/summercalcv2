import SwiftUI
import SwiftData
import UserNotifications

struct AddEventView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var existingEvent: CalendarEvent?
    var initialDate: Date?

    init(existingEvent: CalendarEvent? = nil, initialDate: Date? = nil) {
        self.existingEvent = existingEvent
        self.initialDate = initialDate
    }

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
    @State private var selectedWorkTypeId: UUID?
    @State private var workTypeName: String = ""
    @State private var workRateText: String = ""
    @State private var workPricingMode: String = "hourly"
    @State private var workCurrencyCode: String = ""
    @State private var showPermissionAlert: Bool = false
    @State private var saveError: String?

    private let categories = ["general", "work", "meeting", "workout", "appointment", "travel", "social", "errand"]
    private let reminderOptions = [0, 5, 10, 15, 30, 60, 1440]

    private var defaultCurrency: String {
        UserSettings.current(in: modelContext).currencyCode
    }

    private var isWorkEvent: Bool {
        category == "work"
    }

    private var workRateAmount: Double {
        Double(workRateText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var canSave: Bool {
        let hasTitle = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard hasTitle else { return false }
        if isWorkEvent {
            return !workTypeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && workRateAmount > 0
        }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Event Title", text: $title)
                }

                Section("Time") {
                    if isWorkEvent {
                        Label("Set the full work start and end in the Work Type section.", systemImage: "briefcase")
                            .font(.caption)
                            .foregroundStyle(Color(.systemGray))
                    } else {
                        Toggle("All Day", isOn: $isAllDay)

                        startDatePicker

                        DatePicker("Ends", selection: $endDate, in: startDate..., displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                            .onChange(of: startDate) { _, newStart in
                                if endDate < newStart {
                                    endDate = newStart.addingTimeInterval(3600)
                                }
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
                    .onChange(of: category) { _, newCategory in
                        if newCategory == "work" {
                            isAllDay = false
                            if workCurrencyCode.isEmpty {
                                workCurrencyCode = defaultCurrency
                            }
                            if endDate < startDate {
                                endDate = startDate.addingTimeInterval(3600)
                            }
                        }
                    }

                    TextField("Location", text: $location)

                    Toggle("Outdoor Event", isOn: $isOutdoor)
                }

                if isWorkEvent {
                    WorkTypeSelectionSection(
                        selectedWorkTypeId: $selectedWorkTypeId,
                        workTypeName: $workTypeName,
                        rateText: $workRateText,
                        pricingMode: $workPricingMode,
                        currencyCode: $workCurrencyCode,
                        defaultCurrency: defaultCurrency,
                        scheduleStartDate: $startDate,
                        scheduleEndDate: $endDate,
                        showsScheduleFields: true
                    )
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
                    .disabled(!canSave)
                }
            }
            .onAppear {
                if existingEvent == nil {
                    let seedStart = defaultStartDate()
                    startDate = seedStart
                    endDate = seedStart.addingTimeInterval(3600)
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
                    selectedWorkTypeId = event.workTypeId
                    workTypeName = event.workTypeName ?? ""
                    if let rate = event.workRateAmount {
                        workRateText = String(format: "%.2f", rate).replacingOccurrences(of: ".", with: decimalSeparator())
                    }
                    workPricingMode = event.workPricingMode ?? "hourly"
                    workCurrencyCode = event.workCurrencyCode ?? defaultCurrency
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

    @ViewBuilder
    private var startDatePicker: some View {
        if existingEvent == nil {
            DatePicker(
                "Starts",
                selection: $startDate,
                in: Calendar.current.startOfDay(for: Date())...,
                displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
            )
            .onChange(of: startDate) { _, newStart in
                normalizeDatesAfterStartChange(newStart)
            }
        } else {
            DatePicker(
                "Starts",
                selection: $startDate,
                displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
            )
            .onChange(of: startDate) { _, newStart in
                normalizeDatesAfterStartChange(newStart)
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
        if existingEvent == nil && startDate < Calendar.current.startOfDay(for: Date()) {
            saveError = "New events cannot be added to past days."
            return false
        }

        let selectedOffsets = Array(selectedReminderOffsets).sorted()
        let sanitizedCustomReminder = hasCustomReminderDate ? min(customReminderDate, startDate) : nil
        let cleanedWorkTypeName = workTypeName.trimmingCharacters(in: .whitespacesAndNewlines)
        let shouldCreateWorkSession = isWorkEvent && !cleanedWorkTypeName.isEmpty && workRateAmount > 0
        if shouldCreateWorkSession {
            upsertWorkType(named: cleanedWorkTypeName)
        }

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
            applyWorkFields(to: event, shouldCreateWorkSession: shouldCreateWorkSession, cleanedWorkTypeName: cleanedWorkTypeName)
            event.updatedAt = Date()
            do {
                syncWorkSession(for: event, shouldCreate: shouldCreateWorkSession)
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
            applyWorkFields(to: event, shouldCreateWorkSession: shouldCreateWorkSession, cleanedWorkTypeName: cleanedWorkTypeName)
            modelContext.insert(event)
            do {
                syncWorkSession(for: event, shouldCreate: shouldCreateWorkSession)
                try modelContext.save()
            } catch {
                modelContext.delete(event)
                let sessions = (try? modelContext.fetch(FetchDescriptor<WorkSession>())) ?? []
                for session in sessions where session.calendarEventId == event.id {
                    modelContext.delete(session)
                }
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

    private func normalizeDatesAfterStartChange(_ newStart: Date) {
        if existingEvent == nil {
            let earliest = Calendar.current.startOfDay(for: Date())
            if newStart < earliest {
                startDate = earliest
                return
            }
        }
        if endDate < newStart {
            endDate = newStart.addingTimeInterval(3600)
        }
        if customReminderDate > newStart {
            customReminderDate = defaultCustomReminderDate(for: newStart)
        }
    }

    private func applyWorkFields(to event: CalendarEvent, shouldCreateWorkSession: Bool, cleanedWorkTypeName: String) {
        guard shouldCreateWorkSession else {
            event.workTypeId = nil
            event.workTypeName = nil
            event.workRateAmount = nil
            event.workPricingMode = nil
            event.workCurrencyCode = nil
            return
        }

        event.workTypeId = selectedWorkTypeId
        event.workTypeName = cleanedWorkTypeName
        event.workRateAmount = workRateAmount
        event.workPricingMode = workPricingMode
        event.workCurrencyCode = workCurrencyCode.isEmpty ? defaultCurrency : workCurrencyCode
    }

    private func upsertWorkType(named cleanedName: String) {
        let types = (try? modelContext.fetch(FetchDescriptor<WorkType>())) ?? []
        let targetCurrency = workCurrencyCode.isEmpty ? defaultCurrency : workCurrencyCode
        let selectedType = selectedWorkTypeId.flatMap { id in types.first(where: { $0.id == id }) }
        let matchingType = types.first { $0.name.caseInsensitiveCompare(cleanedName) == .orderedSame }
        let type = selectedType ?? matchingType

        if let type {
            type.name = cleanedName
            type.rateAmount = workRateAmount
            type.pricingMode = workPricingMode
            type.currencyCode = targetCurrency
            type.defaultStartDate = startDate
            type.defaultEndDate = endDate
            type.updatedAt = Date()
            selectedWorkTypeId = type.id
        } else {
            let type = WorkType(
                name: cleanedName,
                rateAmount: workRateAmount,
                pricingMode: workPricingMode,
                currencyCode: targetCurrency,
                defaultStartDate: startDate,
                defaultEndDate: endDate
            )
            modelContext.insert(type)
            selectedWorkTypeId = type.id
        }
    }

    private func syncWorkSession(for event: CalendarEvent, shouldCreate: Bool) {
        let sessions = (try? modelContext.fetch(FetchDescriptor<WorkSession>())) ?? []
        let existingSession = sessions.first { $0.calendarEventId == event.id }

        guard shouldCreate,
              let rate = event.workRateAmount,
              let pricingMode = event.workPricingMode else {
            if let existingSession {
                modelContext.delete(existingSession)
            }
            return
        }

        let earned = pricingMode == "daily" ? rate : max(event.endDate.timeIntervalSince(event.startDate) / 3600, 0) * rate
        let note = notes.isEmpty ? title : notes

        if let existingSession {
            existingSession.date = Calendar.current.startOfDay(for: event.startDate)
            existingSession.startTime = event.startDate
            existingSession.endTime = event.endDate
            existingSession.hourlyRate = rate
            existingSession.totalEarned = earned
            existingSession.currencyCode = event.workCurrencyCode ?? defaultCurrency
            existingSession.pricingMode = pricingMode
            existingSession.workTypeId = event.workTypeId
            existingSession.workTypeName = event.workTypeName
            existingSession.descriptionText = note
        } else {
            modelContext.insert(WorkSession(
                date: Calendar.current.startOfDay(for: event.startDate),
                startTime: event.startDate,
                endTime: event.endDate,
                hourlyRate: rate,
                totalEarned: earned,
                currencyCode: event.workCurrencyCode ?? defaultCurrency,
                pricingMode: pricingMode,
                calendarEventId: event.id,
                workTypeId: event.workTypeId,
                workTypeName: event.workTypeName,
                descriptionText: note
            ))
        }
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

    private func iconForCategory(_ category: String) -> String {
        switch category {
        case "work": return "briefcase"
        case "meeting": return "person.2"
        case "workout": return "figure.run"
        case "appointment": return "stethoscope"
        case "travel": return "airplane"
        case "social": return "bubble.left"
        case "errand": return "cart"
        default: return "calendar"
        }
    }

    private func defaultStartDate() -> Date {
        guard let initialDate else { return startDate }
        let calendar = Calendar.current
        let day = calendar.dateComponents([.year, .month, .day], from: initialDate)
        let nowTime = calendar.dateComponents([.hour, .minute], from: Date())
        var components = DateComponents()
        components.year = day.year
        components.month = day.month
        components.day = day.day
        components.hour = nowTime.hour
        components.minute = nowTime.minute
        return calendar.date(from: components) ?? initialDate
    }

    private func decimalSeparator() -> String {
        Locale.current.decimalSeparator ?? "."
    }
}
