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
    @State private var selectedWorkVariantId: UUID?
    @State private var workTypeName: String = ""
    @State private var workLocation: String = ""
    @State private var workCurrencyCode: String = ""
    @State private var spendableAmountText: String = ""
    @State private var selectedSavingsGoalId: UUID?
    @State private var note: String = ""
    @State private var rateErrorTrigger: Bool = false
    @State private var saveError: String?

    @Query(sort: \SavingsGoal.createdAt, order: .reverse) private var savingsGoals: [SavingsGoal]

    var onSave: (() -> Void)?

    private var isEditing: Bool { existingSession != nil }

    private var navigationTitleKey: LocalizedStringKey {
        isEditing ? "Edit Work Session" : "Add Work Session"
    }

    private var hourlyRate: Double {
        let cleaned = hourlyRateText.replacingOccurrences(of: ",", with: ".")
        return Double(cleaned) ?? 0
    }

    private var rateAmount: Double { hourlyRate }

    private var durationHours: Double {
        max(sessionEndDateTime.timeIntervalSince(sessionStartBinding.wrappedValue) / 3600, 0)
    }

    private var estimatedEarnings: Double {
        pricingMode == "daily" ? rateAmount : durationHours * rateAmount
    }

    private var requestedSpendableAmount: Double {
        let cleaned = spendableAmountText.replacingOccurrences(of: ",", with: ".")
        guard !cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let amount = Double(cleaned) else {
            return estimatedEarnings
        }
        return min(max(amount, 0), estimatedEarnings)
    }

    private var estimatedSavingsAmount: Double {
        max(estimatedEarnings - requestedSpendableAmount, 0)
    }

    private var activeSavingsGoals: [SavingsGoal] {
        savingsGoals.filter { !$0.archived }
    }

    private var isValid: Bool {
        rateAmount > 0 &&
        !workTypeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        sessionEndDateTime > sessionStartBinding.wrappedValue
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
                Section("Date") {
                    DatePicker("Date", selection: $date, displayedComponents: [.date])
                }

                WorkTypeSelectionSection(
                    selectedWorkTypeId: $selectedWorkTypeId,
                    workTypeName: $workTypeName,
                    rateText: $hourlyRateText,
                    pricingMode: $pricingMode,
                    currencyCode: $workCurrencyCode,
                    selectedWorkVariantId: $selectedWorkVariantId,
                    locationName: $workLocation,
                    defaultCurrency: defaultCurrency,
                    workStartTime: sessionStartBinding,
                    workEndTime: sessionEndBinding,
                    showsWorkHours: true
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

                Section {
                    Picker("Savings Account", selection: $selectedSavingsGoalId) {
                        Text("Unassigned Savings").tag(nil as UUID?)
                        ForEach(activeSavingsGoals) { goal in
                            Label(goal.name, systemImage: goal.iconName).tag(Optional(goal.id))
                        }
                    }

                    HStack {
                        Text(selectedCurrency)
                            .foregroundStyle(Color(.systemGray))
                        TextField("Spendable Amount", text: $spendableAmountText)
                            .keyboardType(.decimalPad)
                    }

                    if isValid {
                        HStack {
                            Text("Saved From Work")
                            Spacer()
                            Text(formatCurrency(estimatedSavingsAmount))
                                .fontWeight(.semibold)
                                .foregroundColor(.purple)
                        }
                    }
                } header: {
                    Text("Work Funds")
                } footer: {
                    Text("Leave spendable blank to keep all earnings spendable. Any remaining earnings are counted toward the selected savings account.")
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
            .navigationTitle(navigationTitleKey)
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
                    selectedSavingsGoalId = session.savingsGoalId
                    workTypeName = session.workTypeName ?? ""
                    workCurrencyCode = session.currencyCode ?? defaultCurrency
                    hourlyRateText = String(format: "%.2f", session.hourlyRate).replacingOccurrences(of: ".", with: decimalSeparator())
                    spendableAmountText = String(format: "%.2f", session.spendableWorkAmount).replacingOccurrences(of: ".", with: decimalSeparator())
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

    private var sessionStartBinding: Binding<Date> {
        Binding(
            get: {
                combinedDateTime(date: date, time: startTime)
            },
            set: { newValue in
                date = Calendar.current.startOfDay(for: newValue)
                startTime = newValue
                if sessionEndDateTime < newValue {
                    endTime = newValue.addingTimeInterval(3600)
                }
            }
        )
    }

    private var sessionEndBinding: Binding<Date> {
        Binding(
            get: {
                sessionEndDateTime
            },
            set: { newValue in
                endTime = max(newValue, sessionStartBinding.wrappedValue.addingTimeInterval(60))
            }
        )
    }

    private var sessionEndDateTime: Date {
        let calendar = Calendar.current
        if !calendar.isDate(startTime, inSameDayAs: endTime) {
            return endTime
        }
        return combinedDateTime(date: date, time: endTime)
    }

    private func save() {
        let sessionStart = sessionStartBinding.wrappedValue
        let sessionEnd = sessionEndBinding.wrappedValue
        let duration = sessionEnd.timeIntervalSince(sessionStart) / 3600
        let earned = pricingMode == "daily" ? rateAmount : duration * rateAmount
        let spendable = min(max(requestedSpendableAmount, 0), earned)
        let cleanedWorkTypeName = workTypeName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanedWorkTypeName.isEmpty, rateAmount > 0 {
            upsertWorkType(named: cleanedWorkTypeName)
        }

        if let session = existingSession {
            session.date = Calendar.current.startOfDay(for: sessionStart)
            session.startTime = sessionStart
            session.endTime = sessionEnd
            session.hourlyRate = rateAmount
            session.totalEarned = earned
            session.currencyCode = selectedCurrency
            session.pricingMode = pricingMode
            session.spendableAmount = spendable
            session.savingsGoalId = selectedSavingsGoalId
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
                spendableAmount: spendable,
                savingsGoalId: selectedSavingsGoalId,
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

    private func upsertWorkType(named cleanedName: String) {
        let types = (try? modelContext.fetch(FetchDescriptor<WorkType>())) ?? []
        let selectedType = selectedWorkTypeId.flatMap { id in types.first(where: { $0.id == id }) }
        let matchingType = types.first { $0.name.caseInsensitiveCompare(cleanedName) == .orderedSame }
        let type = selectedType ?? matchingType

        if let type {
            type.name = cleanedName
            type.rateAmount = rateAmount
            type.pricingMode = pricingMode
            type.currencyCode = selectedCurrency
            type.locationName = cleanedWorkLocation()
            type.defaultVariantId = selectedWorkVariantId
            persistWorkHours(on: type)
            type.updatedAt = Date()
            selectedWorkTypeId = type.id
        } else {
            let type = WorkType(
                name: cleanedName,
                rateAmount: rateAmount,
                pricingMode: pricingMode,
                currencyCode: selectedCurrency,
                locationName: cleanedWorkLocation(),
                defaultVariantId: selectedWorkVariantId
            )
            persistWorkHours(on: type)
            modelContext.insert(type)
            selectedWorkTypeId = type.id
        }
    }

    private func persistWorkHours(on type: WorkType) {
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute], from: sessionStartBinding.wrappedValue)
        let endComponents = calendar.dateComponents([.hour, .minute], from: sessionEndBinding.wrappedValue)
        type.defaultStartHour = startComponents.hour
        type.defaultStartMinute = startComponents.minute
        type.defaultEndHour = endComponents.hour
        type.defaultEndMinute = endComponents.minute
        type.defaultStartDate = nil
        type.defaultEndDate = nil
    }

    private func cleanedWorkLocation() -> String? {
        let cleaned = workLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
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
