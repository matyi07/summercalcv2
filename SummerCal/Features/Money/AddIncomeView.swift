import SwiftUI
import SwiftData

struct AddIncomeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var existingEntry: IncomeEntry?

    @State private var date: Date = Date()
    @State private var amountText: String = ""
    @State private var source: String = ""
    @State private var note: String = ""
    @State private var category: IncomeCategory = .other
    @State private var entryCurrencyCode: String = ""
    @State private var isRecurring: Bool = false
    @State private var amountErrorTrigger: Bool = false
    @State private var isSaving: Bool = false
    @State private var saveError: String?

    var onSave: (() -> Void)?

    private var isEditing: Bool { existingEntry != nil }
    private let currencies = ["USD", "EUR", "GBP", "HUF", "JPY", "CAD", "AUD", "CHF", "CNY", "INR", "MXN", "BRL", "KRW"]

    private var sanitizedAmount: Double {
        let cleaned = amountText.replacingOccurrences(of: ",", with: ".")
        return Double(cleaned) ?? 0
    }

    private var amountIsValid: Bool {
        sanitizedAmount > 0
    }

    private var currencyCode: String {
        UserSettings.current(in: modelContext).currencyCode
    }

    private var selectedCurrencyCode: String {
        entryCurrencyCode.isEmpty ? currencyCode : entryCurrencyCode
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $date, displayedComponents: [.date])
                }

                Section {
                    Picker("Currency", selection: $entryCurrencyCode) {
                        ForEach(currencies, id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }

                    HStack {
                        Text(selectedCurrencyCode)
                            .foregroundStyle(Color(.systemGray))
                        TextField("Amount", text: $amountText)
                            .keyboardType(.decimalPad)
                            .onChange(of: amountText) { _, newValue in
                                let cleaned = newValue.replacingOccurrences(of: ",", with: ".")
                                if !newValue.isEmpty && (Double(cleaned) ?? 0) <= 0 {
                                    amountErrorTrigger.toggle()
                                }
                            }
                    }

                    Picker("Category", selection: $category) {
                        ForEach(IncomeCategory.allCases, id: \.self) { cat in
                            Label(categoryDisplayName(cat), systemImage: categoryIcon(cat))
                                .tag(cat)
                        }
                    }

                    TextField("Source (employer, client, etc.)", text: $source)
                        .autocorrectionDisabled()
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

                if !isEditing {
                    Section {
                        Toggle("Recurring Monthly", isOn: $isRecurring)
                    }
                }

                Section {
                    if amountIsValid {
                        HStack {
                            Text("Total")
                            Spacer()
                            Text(formattedPreview)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .sensoryFeedback(.error, trigger: amountErrorTrigger)
            .navigationTitle(isEditing ? "Edit Income" : "Add Income")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(!amountIsValid || source.isEmpty || isSaving)
                }
            }
            .onAppear {
                entryCurrencyCode = currencyCode
                if let entry = existingEntry {
                    date = entry.date
                    let formAmount = entry.originalAmount ?? entry.amount
                    amountText = String(format: "%.2f", formAmount).replacingOccurrences(of: ".", with: decimalSeparator())
                    entryCurrencyCode = entry.originalCurrencyCode ?? entry.currencyCode ?? currencyCode
                    source = entry.source
                    note = entry.descriptionText
                    category = entry.category
                }
            }
        }
    }

    private var formattedPreview: String {
        let amount = sanitizedAmount
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = selectedCurrencyCode
        let entered = formatter.string(from: NSNumber(value: amount)) ?? "\(String(format: "%.2f", amount)) \(selectedCurrencyCode)"
        guard selectedCurrencyCode != currencyCode else { return entered }
        return "\(entered) → saved in \(currencyCode)"
    }

    private func decimalSeparator() -> String {
        Locale.current.decimalSeparator ?? "."
    }

    private func categoryDisplayName(_ category: IncomeCategory) -> String {
        switch category {
        case .salary: return "Salary"
        case .freelance: return "Freelance"
        case .gig: return "Gig"
        case .other: return "Other"
        }
    }

    private func categoryIcon(_ category: IncomeCategory) -> String {
        switch category {
        case .salary: return "building.2"
        case .freelance: return "laptopcomputer"
        case .gig: return "figure.walk"
        case .other: return "ellipsis.circle"
        }
    }

    @MainActor
    private func save() async {
        let amount = sanitizedAmount
        guard amount > 0 else { return }

        isSaving = true
        saveError = nil

        let conversion: CurrencyConversionResult
        do {
            conversion = try await CurrencyConversionService().convert(
                amount: amount,
                from: selectedCurrencyCode,
                to: currencyCode
            )
        } catch {
            saveError = error.localizedDescription
            isSaving = false
            return
        }

        if let entry = existingEntry {
            entry.date = date
            entry.amount = conversion.convertedAmount
            entry.currencyCode = conversion.targetCurrency
            entry.originalAmount = conversion.originalAmount
            entry.originalCurrencyCode = conversion.originalCurrency ?? selectedCurrencyCode
            entry.exchangeRateToEntryCurrency = conversion.exchangeRate
            entry.exchangeRateDate = conversion.rateDate
            entry.source = source
            entry.descriptionText = note
            entry.category = category
        } else {
            let entry = IncomeEntry(
                date: date,
                amount: conversion.convertedAmount,
                currencyCode: conversion.targetCurrency,
                originalAmount: conversion.originalAmount,
                originalCurrencyCode: conversion.originalCurrency ?? selectedCurrencyCode,
                exchangeRateToEntryCurrency: conversion.exchangeRate,
                exchangeRateDate: conversion.rateDate,
                source: source,
                descriptionText: note,
                category: category
            )
            modelContext.insert(entry)

            if isRecurring, let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: date) {
                let futureEntry = IncomeEntry(
                    date: nextMonth,
                    amount: conversion.convertedAmount,
                    currencyCode: conversion.targetCurrency,
                    originalAmount: conversion.originalAmount,
                    originalCurrencyCode: conversion.originalCurrency ?? selectedCurrencyCode,
                    exchangeRateToEntryCurrency: conversion.exchangeRate,
                    exchangeRateDate: conversion.rateDate,
                    source: source,
                    descriptionText: note,
                    category: category
                )
                modelContext.insert(futureEntry)
            }
        }

        do {
            try modelContext.save()
        } catch {
            saveError = "Could not save income: \(error.localizedDescription)"
            isSaving = false
            return
        }
        isSaving = false
        NotificationCenter.default.post(
            name: .summerCalMoneyChanged,
            object: nil,
            userInfo: ["date": date]
        )
        onSave?()
        dismiss()
    }
}
