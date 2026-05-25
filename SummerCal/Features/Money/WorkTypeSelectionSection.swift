import SwiftUI
import SwiftData

struct WorkTypeSelectionSection: View {
    @Environment(\.modelContext) private var modelContext

    @Binding var selectedWorkTypeId: UUID?
    @Binding var workTypeName: String
    @Binding var rateText: String
    @Binding var pricingMode: String
    @Binding var currencyCode: String

    let defaultCurrency: String
    var scheduleStartDate: Binding<Date>?
    var scheduleEndDate: Binding<Date>?
    var showsScheduleFields: Bool = false

    @Query(sort: \WorkType.name) private var workTypes: [WorkType]

    private let currencies = ["USD", "EUR", "GBP", "HUF", "JPY", "CAD", "AUD", "CHF", "CNY", "INR", "MXN", "BRL", "KRW"]

    private var selectedCurrency: String {
        currencyCode.isEmpty ? defaultCurrency : currencyCode
    }

    private var rateAmount: Double {
        Double(rateText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var canSaveWorkType: Bool {
        !workTypeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && rateAmount > 0
    }

    var body: some View {
        Section {
            Picker("Saved Type", selection: $selectedWorkTypeId) {
                Text("Custom").tag(nil as UUID?)
                ForEach(workTypes) { type in
                    Text(type.name).tag(Optional(type.id))
                }
            }
            .onChange(of: selectedWorkTypeId) { _, id in
                applyWorkType(id, includeSchedule: true)
            }

            TextField("Work Type Name", text: $workTypeName)

            if showsScheduleFields,
               let scheduleStartDate,
               let scheduleEndDate {
                DatePicker(
                    "Work Starts",
                    selection: scheduleStartDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .onChange(of: scheduleStartDate.wrappedValue) { _, newStart in
                    if scheduleEndDate.wrappedValue < newStart {
                        scheduleEndDate.wrappedValue = newStart.addingTimeInterval(3600)
                    }
                }

                DatePicker(
                    "Work Ends",
                    selection: scheduleEndDate,
                    in: scheduleStartDate.wrappedValue...,
                    displayedComponents: [.date, .hourAndMinute]
                )
            }

            Picker("Pricing", selection: $pricingMode) {
                Label("Hourly", systemImage: "clock").tag("hourly")
                Label("Daily", systemImage: "calendar").tag("daily")
            }
            .pickerStyle(.segmented)

            Picker("Currency", selection: $currencyCode) {
                ForEach(currencies, id: \.self) { code in
                    Text(code).tag(code)
                }
            }

            HStack {
                Text(selectedCurrency)
                    .foregroundStyle(Color(.systemGray))
                TextField(pricingMode == "daily" ? "Daily Rate" : "Hourly Rate", text: $rateText)
                    .keyboardType(.decimalPad)
            }

            HStack(spacing: 12) {
                Button(selectedWorkTypeId == nil ? "Save Type" : "Update Type") {
                    saveWorkType()
                }
                .buttonStyle(.borderless)
                .disabled(!canSaveWorkType)

                if selectedWorkTypeId != nil {
                    Button("Use as Custom") {
                        selectedWorkTypeId = nil
                    }
                    .buttonStyle(.borderless)

                    Button("Delete Type", role: .destructive) {
                        deleteSelectedWorkType()
                    }
                    .buttonStyle(.borderless)
                }
            }
            .font(.caption.weight(.medium))
        } header: {
            Text("Work Type")
        } footer: {
            Text("Saved work types can be reused in Calendar work events and Money work sessions.")
        }
        .onAppear {
            if currencyCode.isEmpty {
                currencyCode = defaultCurrency
            }
            applyWorkType(selectedWorkTypeId, includeSchedule: false)
        }
    }

    private func applyWorkType(_ id: UUID?, includeSchedule: Bool) {
        guard let id,
              let type = workTypes.first(where: { $0.id == id }) else {
            if currencyCode.isEmpty {
                currencyCode = defaultCurrency
            }
            return
        }

        workTypeName = type.name
        rateText = String(format: "%.2f", type.rateAmount).replacingOccurrences(of: ".", with: decimalSeparator())
        pricingMode = type.pricingMode
        currencyCode = type.currencyCode ?? defaultCurrency
        if includeSchedule,
           showsScheduleFields,
           let start = type.defaultStartDate,
           let end = type.defaultEndDate {
            scheduleStartDate?.wrappedValue = start
            scheduleEndDate?.wrappedValue = max(end, start.addingTimeInterval(3600))
        }
    }

    private func saveWorkType() {
        let cleanedName = workTypeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty, rateAmount > 0 else { return }

        if let id = selectedWorkTypeId,
           let existing = workTypes.first(where: { $0.id == id }) {
            existing.name = cleanedName
            existing.rateAmount = rateAmount
            existing.pricingMode = pricingMode
            existing.currencyCode = selectedCurrency
            existing.defaultStartDate = scheduleStartDate?.wrappedValue
            existing.defaultEndDate = scheduleEndDate?.wrappedValue
            existing.updatedAt = Date()
        } else {
            let type = WorkType(
                name: cleanedName,
                rateAmount: rateAmount,
                pricingMode: pricingMode,
                currencyCode: selectedCurrency,
                defaultStartDate: scheduleStartDate?.wrappedValue,
                defaultEndDate: scheduleEndDate?.wrappedValue
            )
            modelContext.insert(type)
            selectedWorkTypeId = type.id
        }

        try? modelContext.save()
    }

    private func deleteSelectedWorkType() {
        guard let id = selectedWorkTypeId,
              let type = workTypes.first(where: { $0.id == id }) else { return }
        modelContext.delete(type)
        selectedWorkTypeId = nil
        try? modelContext.save()
    }

    private func decimalSeparator() -> String {
        Locale.current.decimalSeparator ?? "."
    }
}
