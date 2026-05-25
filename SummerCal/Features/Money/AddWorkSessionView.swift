import SwiftUI
import SwiftData

struct AddWorkSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var existingSession: WorkSession?

    @State private var date: Date = Date()
    @State private var startTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var endTime: Date = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var hourlyRateText: String = ""
    @State private var pricingMode: String = "hourly"
    @State private var selectedWorkTypeId: UUID?
    @State private var workTypeName: String = ""
    @State private var workCurrencyCode: String = ""
    @State private var note: String = ""
    @State private var rateErrorTrigger: Bool = false
    @State private var saveError: String?

    var onSave: (() -> Void)?

    private var isEditing: Bool { existingSession != nil }

    private var hourlyRate: Double {
        let cleaned = hourlyRateText.replacingOccurrences(of: ",", with: ".")
        return Double(cleaned) ?? 0
    }

    private var rateAmount: Double { hourlyRate }

    private var durationHours: Double {
        max(endTime.timeIntervalSince(startTime) / 3600, 0)
    }

    private var estimatedEarnings: Double {
        pricingMode == "daily" ? rateAmount : durationHours * rateAmount
    }

    private var isValid: Bool {
        rateAmount > 0 && endTime > startTime
    }

    private var defaultCurrency: String {
        UserSettings.current(in: modelContext).currencyCode
    }

    private var selectedCurrency: String {
        workCurrencyCode.isEmpty ? defaultCurrency : workCurrencyCode
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $date, displayedComponents: [.date])
                }

                Section {
                    DatePicker("Start Time", selection: $startTime, displayedComponents: [.hourAndMinute])
                    DatePicker("End Time", selection: $endTime, in: startTime..., displayedComponents: [.hourAndMinute])
                }

                WorkTypeSelectionSection(
                    selectedWorkTypeId: $selectedWorkTypeId,
                    workTypeName: $workTypeName,
                    rateText: $hourlyRateText,
                    pricingMode: $pricingMode,
                    currencyCode: $workCurrencyCode,
                    defaultCurrency: defaultCurrency
                )
                .onChange(of: hourlyRateText) { _, newValue in
                    let cleaned = newValue.replacingOccurrences(of: ",", with: ".")
                    if !newValue.isEmpty && (Double(cleaned) ?? 0) <= 0 {
                        rateErrorTrigger.toggle()
                    }
                }

                Section {
                    TextField("Note", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }

                if let saveError {
                    Section {
                        Label(saveError, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                Section {
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text(formatDuration)
                            .foregroundStyle(Color(.systemGray))
                    }

                    if isValid {
                        HStack {
                            Text("Estimated Earnings")
                            Spacer()
                            Text(formatCurrency(estimatedEarnings))
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .sensoryFeedback(.error, trigger: rateErrorTrigger)
            .navigationTitle(isEditing ? "Edit Work Session" : "Add Work Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if let session = existingSession {
                    date = session.date
                    startTime = session.startTime
                    endTime = session.endTime
                    pricingMode = session.pricingMode ?? "hourly"
                    selectedWorkTypeId = session.workTypeId
                    workTypeName = session.workTypeName ?? ""
                    workCurrencyCode = session.currencyCode ?? defaultCurrency
                    hourlyRateText = String(format: "%.2f", session.hourlyRate).replacingOccurrences(of: ".", with: decimalSeparator())
                    note = session.descriptionText
                    if session.currencyCode == nil {
                        session.currencyCode = defaultCurrency
                        try? modelContext.save()
                    }
                } else {
                    workCurrencyCode = defaultCurrency
                }
            }
        }
    }

    private var formatDuration: String {
        let hours = Int(durationHours)
        let minutes = Int((durationHours - Double(hours)) * 60)
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = selectedCurrency
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(String(format: "%.2f", amount))"
    }

    private func decimalSeparator() -> String {
        Locale.current.decimalSeparator ?? "."
    }

    private func save() {
        let sessionStart = combinedDateTime(date: date, time: startTime)
        let sessionEnd = combinedDateTime(date: date, time: endTime)
        let duration = sessionEnd.timeIntervalSince(sessionStart) / 3600
        let earned = pricingMode == "daily" ? rateAmount : duration * rateAmount
        let cleanedWorkTypeName = workTypeName.trimmingCharacters(in: .whitespacesAndNewlines)

        if let session = existingSession {
            session.date = Calendar.current.startOfDay(for: sessionStart)
            session.startTime = sessionStart
            session.endTime = sessionEnd
            session.hourlyRate = rateAmount
            session.totalEarned = earned
            session.currencyCode = selectedCurrency
            session.pricingMode = pricingMode
            session.workTypeId = selectedWorkTypeId
            session.workTypeName = cleanedWorkTypeName.isEmpty ? nil : cleanedWorkTypeName
            session.descriptionText = note
            syncLinkedEvent(from: session)
        } else {
            let session = WorkSession(
                date: Calendar.current.startOfDay(for: sessionStart),
                startTime: sessionStart,
                endTime: sessionEnd,
                hourlyRate: rateAmount,
                totalEarned: earned,
                currencyCode: selectedCurrency,
                pricingMode: pricingMode,
                workTypeId: selectedWorkTypeId,
                workTypeName: cleanedWorkTypeName.isEmpty ? nil : cleanedWorkTypeName,
                descriptionText: note
            )
            modelContext.insert(session)
        }

        do {
            try modelContext.save()
        } catch {
            saveError = "Could not save work session: \(error.localizedDescription)"
            return
        }
        NotificationCenter.default.post(
            name: .summerCalMoneyChanged,
            object: nil,
            userInfo: ["date": sessionStart]
        )
        WidgetDataService.refreshTodayEvents(modelContext: modelContext)
        onSave?()
        dismiss()
    }

    private func syncLinkedEvent(from session: WorkSession) {
        guard let eventId = session.calendarEventId else { return }
        let events = (try? modelContext.fetch(FetchDescriptor<CalendarEvent>())) ?? []
        guard let event = events.first(where: { $0.id == eventId }) else { return }

        event.startDate = session.startTime
        event.endDate = session.endTime
        event.category = "work"
        event.workTypeId = session.workTypeId
        event.workTypeName = session.workTypeName
        event.workRateAmount = session.hourlyRate
        event.workPricingMode = session.pricingMode
        event.workCurrencyCode = session.currencyCode
        event.notes = session.descriptionText.isEmpty ? event.notes : session.descriptionText
        event.updatedAt = Date()
    }

    private func combinedDateTime(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)
        var merged = DateComponents()
        merged.year = dateComponents.year
        merged.month = dateComponents.month
        merged.day = dateComponents.day
        merged.hour = timeComponents.hour
        merged.minute = timeComponents.minute
        merged.second = timeComponents.second
        return calendar.date(from: merged) ?? date
    }
}
