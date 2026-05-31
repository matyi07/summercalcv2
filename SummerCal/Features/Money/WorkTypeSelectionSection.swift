import SwiftUI
import SwiftData

struct WorkTypeSelectionSection: View {
    @Environment(\.modelContext) private var modelContext

    @Binding var selectedWorkTypeId: UUID?
    @Binding var workTypeName: String
    @Binding var rateText: String
    @Binding var pricingMode: String
    @Binding var currencyCode: String
    @Binding var selectedWorkVariantId: UUID?
    @Binding var locationName: String

    let defaultCurrency: String
    var workStartTime: Binding<Date>?
    var workEndTime: Binding<Date>?
    var showsWorkHours: Bool = false
    var onWorkTypeApplied: ((WorkType) -> Void)?

    @Query(sort: \WorkType.name) private var workTypes: [WorkType]
    @State private var workVariants: [WorkTimeVariant] = []
    @State private var variantNameText: String = ""

    private let currencies = ["USD", "EUR", "GBP", "HUF", "JPY", "CAD", "AUD", "CHF", "CNY", "INR", "MXN", "BRL", "KRW"]

    private var selectedCurrency: String {
        currencyCode.isEmpty ? defaultCurrency : currencyCode
    }

    private var rateAmount: Double {
        Double(rateText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var ratePlaceholderKey: LocalizedStringKey {
        pricingMode == "daily" ? "Daily Rate" : "Hourly Rate"
    }

    private var saveButtonTitleKey: LocalizedStringKey {
        selectedWorkTypeId == nil ? "Save Type" : "Update Type"
    }

    private var variantButtonTitleKey: LocalizedStringKey {
        selectedWorkVariantId == nil ? "Add Variant" : "Update Variant"
    }

    private var canSaveWorkType: Bool {
        !workTypeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && rateAmount > 0
    }

    private var canSaveVariant: Bool {
        guard let workStartTime,
              let workEndTime,
              workEndTime.wrappedValue > workStartTime.wrappedValue else {
            return false
        }
        return !variantNameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

            if showsWorkHours,
               let workStartTime,
               let workEndTime {
                TextField("Work Location", text: $locationName)

                if !workVariants.isEmpty {
                    Picker("Work Variant", selection: $selectedWorkVariantId) {
                        Text("Manual Hours").tag(nil as UUID?)
                        ForEach(workVariants) { variant in
                            Text("\(variant.name) (\(variant.timeRangeText()))").tag(Optional(variant.id))
                        }
                    }
                    .onChange(of: selectedWorkVariantId) { _, id in
                        applyVariant(id)
                    }
                }

                DatePicker(
                    "Work Starts",
                    selection: workStartTime,
                    displayedComponents: [.hourAndMinute]
                )
                .onChange(of: workStartTime.wrappedValue) { _, newStart in
                    if workEndTime.wrappedValue <= newStart {
                        workEndTime.wrappedValue = newStart.addingTimeInterval(3600)
                    }
                }

                DatePicker(
                    "Work Ends",
                    selection: workEndTime,
                    displayedComponents: [.hourAndMinute]
                )
                .onChange(of: workEndTime.wrappedValue) { _, newEnd in
                    if newEnd <= workStartTime.wrappedValue {
                        workEndTime.wrappedValue = workStartTime.wrappedValue.addingTimeInterval(3600)
                    }
                }

                HStack(spacing: 8) {
                    TextField("Variant Name", text: $variantNameText)
                    Button {
                        saveVariantFromCurrentHours()
                    } label: {
                        Text(variantButtonTitleKey)
                    }
                    .buttonStyle(.borderless)
                    .disabled(!canSaveVariant)
                }

                if !workVariants.isEmpty {
                    ForEach(workVariants) { variant in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(variant.name)
                                Text(variant.timeRangeText())
                                    .font(.caption)
                                    .foregroundStyle(Color(.systemGray))
                            }
                            Spacer()
                            Button {
                                selectedWorkVariantId = variant.id
                                variantNameText = variant.name
                                applyVariant(variant.id)
                            } label: {
                                Image(systemName: "checkmark.circle")
                            }
                            .buttonStyle(.borderless)

                            Button(role: .destructive) {
                                deleteVariant(variant)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
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
                TextField(ratePlaceholderKey, text: $rateText)
                    .keyboardType(.decimalPad)
            }

            HStack(spacing: 12) {
                Button {
                    saveWorkType()
                } label: {
                    Text(saveButtonTitleKey)
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
        guard let id else {
            if currencyCode.isEmpty {
                currencyCode = defaultCurrency
            }
            workVariants = []
            selectedWorkVariantId = nil
            return
        }

        guard let type = workTypes.first(where: { $0.id == id }) else {
            return
        }

        workTypeName = type.name
        rateText = String(format: "%.2f", type.rateAmount).replacingOccurrences(of: ".", with: decimalSeparator())
        pricingMode = type.pricingMode
        currencyCode = type.currencyCode ?? defaultCurrency
        locationName = type.locationName ?? ""
        workVariants = type.workVariants()

        if let defaultVariantId = type.defaultVariantId,
           workVariants.contains(where: { $0.id == defaultVariantId }) {
            selectedWorkVariantId = defaultVariantId
        } else if let selectedWorkVariantId,
                  !workVariants.contains(where: { $0.id == selectedWorkVariantId }) {
            self.selectedWorkVariantId = workVariants.first?.id
        } else if selectedWorkVariantId == nil {
            selectedWorkVariantId = workVariants.first?.id
        }

        if let selectedWorkVariantId,
           let selectedVariant = workVariants.first(where: { $0.id == selectedWorkVariantId }) {
            variantNameText = selectedVariant.name
        } else {
            variantNameText = ""
        }

        if includeSchedule, showsWorkHours {
            if let selectedWorkVariantId,
               workVariants.contains(where: { $0.id == selectedWorkVariantId }) {
                applyVariant(selectedWorkVariantId)
            } else {
                applyStoredWorkHours(from: type)
            }
        }
        onWorkTypeApplied?(type)
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
            existing.locationName = cleanedLocationName()
            existing.defaultVariantId = selectedWorkVariantId
            existing.setWorkVariants(workVariants)
            persistWorkHours(on: existing)
            existing.updatedAt = Date()
        } else {
            let type = WorkType(
                name: cleanedName,
                rateAmount: rateAmount,
                pricingMode: pricingMode,
                currencyCode: selectedCurrency,
                locationName: cleanedLocationName(),
                defaultVariantId: selectedWorkVariantId
            )
            type.setWorkVariants(workVariants)
            persistWorkHours(on: type)
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
        selectedWorkVariantId = nil
        workVariants = []
        variantNameText = ""
        try? modelContext.save()
    }

    private func saveVariantFromCurrentHours() {
        guard let workStartTime,
              let workEndTime,
              workEndTime.wrappedValue > workStartTime.wrappedValue,
              let newVariant = WorkTimeVariant(
                name: variantNameText,
                start: workStartTime.wrappedValue,
                end: workEndTime.wrappedValue
              ) else {
            return
        }

        if let selectedWorkVariantId,
           let index = workVariants.firstIndex(where: { $0.id == selectedWorkVariantId }) {
            workVariants[index] = WorkTimeVariant(
                id: selectedWorkVariantId,
                name: newVariant.name,
                startHour: newVariant.startHour,
                startMinute: newVariant.startMinute,
                endHour: newVariant.endHour,
                endMinute: newVariant.endMinute
            )
        } else {
            workVariants.append(newVariant)
            selectedWorkVariantId = newVariant.id
        }

        if selectedWorkTypeId == nil {
            saveWorkType()
        } else {
            persistVariantsOnSelectedType()
        }
    }

    private func deleteVariant(_ variant: WorkTimeVariant) {
        workVariants.removeAll { $0.id == variant.id }
        if selectedWorkVariantId == variant.id {
            selectedWorkVariantId = workVariants.first?.id
            variantNameText = workVariants.first?.name ?? ""
            applyVariant(selectedWorkVariantId)
        }
        persistVariantsOnSelectedType()
    }

    private func applyVariant(_ id: UUID?) {
        guard let id,
              let variant = workVariants.first(where: { $0.id == id }),
              let workStartTime,
              let start = variant.startDate(on: workStartTime.wrappedValue) else {
            return
        }

        workStartTime.wrappedValue = start
        variantNameText = variant.name

        guard let workEndTime else { return }
        let end = variant.endDate(on: start) ?? start.addingTimeInterval(3600)
        workEndTime.wrappedValue = normalizedEnd(start: start, end: end)
    }

    private func persistVariantsOnSelectedType() {
        guard let selectedWorkTypeId,
              let type = workTypes.first(where: { $0.id == selectedWorkTypeId }) else {
            return
        }

        type.defaultVariantId = selectedWorkVariantId
        type.setWorkVariants(workVariants)
        persistWorkHours(on: type)
        type.updatedAt = Date()
        try? modelContext.save()
    }

    private func cleanedLocationName() -> String? {
        let cleaned = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    private func decimalSeparator() -> String {
        Locale.current.decimalSeparator ?? "."
    }

    private func applyStoredWorkHours(from type: WorkType) {
        guard let workStartTime else { return }

        let calendar = Calendar.current
        let currentStart = workStartTime.wrappedValue
        if let startComponents = storedTimeComponents(
            hour: type.defaultStartHour,
            minute: type.defaultStartMinute,
            legacyDate: type.defaultStartDate
        ),
           let start = calendar.date(
            bySettingHour: startComponents.hour ?? 0,
            minute: startComponents.minute ?? 0,
            second: 0,
            of: currentStart
           ) {
            workStartTime.wrappedValue = start
        }

        guard let workEndTime else { return }

        let currentEndBase = workStartTime.wrappedValue
        if let endComponents = storedTimeComponents(
            hour: type.defaultEndHour,
            minute: type.defaultEndMinute,
            legacyDate: type.defaultEndDate
        ),
           let end = calendar.date(
            bySettingHour: endComponents.hour ?? 0,
            minute: endComponents.minute ?? 0,
            second: 0,
            of: currentEndBase
           ) {
            workEndTime.wrappedValue = normalizedEnd(start: workStartTime.wrappedValue, end: end)
        } else if workEndTime.wrappedValue <= workStartTime.wrappedValue {
            workEndTime.wrappedValue = workStartTime.wrappedValue.addingTimeInterval(3600)
        }
    }

    private func persistWorkHours(on type: WorkType) {
        if let start = workStartTime?.wrappedValue {
            let components = Calendar.current.dateComponents([.hour, .minute], from: start)
            type.defaultStartHour = components.hour
            type.defaultStartMinute = components.minute
        } else {
            type.defaultStartHour = nil
            type.defaultStartMinute = nil
        }

        if let end = workEndTime?.wrappedValue {
            let components = Calendar.current.dateComponents([.hour, .minute], from: end)
            type.defaultEndHour = components.hour
            type.defaultEndMinute = components.minute
        } else {
            type.defaultEndHour = nil
            type.defaultEndMinute = nil
        }

        type.defaultStartDate = nil
        type.defaultEndDate = nil
    }

    private func storedTimeComponents(hour: Int?, minute: Int?, legacyDate: Date?) -> DateComponents? {
        if let hour, let minute {
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            return components
        }

        guard let legacyDate else { return nil }
        return Calendar.current.dateComponents([.hour, .minute], from: legacyDate)
    }

    private func normalizedEnd(start: Date, end: Date) -> Date {
        if end <= start {
            return start.addingTimeInterval(3600)
        }
        return end
    }
}
