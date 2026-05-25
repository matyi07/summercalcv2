import SwiftUI
import SwiftData

struct AddSavingsEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var existingEntry: SavingsEntry?
    var goals: [SavingsGoal]
    var onSave: (() -> Void)?

    @State private var date: Date = Date()
    @State private var amountText: String = ""
    @State private var currencyCode: String = ""
    @State private var direction: String = "deposit"
    @State private var selectedGoalId: UUID?
    @State private var note: String = ""
    @State private var isSaving: Bool = false
    @State private var saveError: String?

    private let currencies = ["USD", "EUR", "GBP", "HUF", "JPY", "CAD", "AUD", "CHF", "CNY", "INR", "MXN", "BRL", "KRW"]

    private var amount: Double {
        Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var defaultCurrency: String {
        UserSettings.current(in: modelContext).currencyCode
    }

    private var selectedCurrency: String {
        currencyCode.isEmpty ? defaultCurrency : currencyCode
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $date, displayedComponents: [.date])
                }

                Section {
                    Picker("Type", selection: $direction) {
                        Label("Deposit", systemImage: "plus.circle").tag("deposit")
                        Label("Withdrawal", systemImage: "minus.circle").tag("withdrawal")
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
                        TextField("Amount", text: $amountText)
                            .keyboardType(.decimalPad)
                    }
                }

                Section("Goal") {
                    Picker("Apply To", selection: $selectedGoalId) {
                        Text("Unassigned Savings").tag(nil as UUID?)
                        ForEach(goals) { goal in
                            Label(goal.name, systemImage: goal.iconName).tag(Optional(goal.id))
                        }
                    }
                }

                Section("Note") {
                    TextField("Source, purpose, or account", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }

                if let saveError {
                    Section {
                        Label(saveError, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(existingEntry == nil ? "Savings Entry" : "Edit Savings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(amount <= 0 || isSaving)
                }
            }
            .onAppear {
                currencyCode = defaultCurrency
                if let entry = existingEntry {
                    date = entry.date
                    let formAmount = abs(entry.originalAmount ?? entry.amount)
                    amountText = String(format: "%.2f", formAmount).replacingOccurrences(of: ".", with: decimalSeparator())
                    currencyCode = entry.originalCurrencyCode ?? entry.currencyCode ?? defaultCurrency
                    direction = entry.amount < 0 ? "withdrawal" : "deposit"
                    selectedGoalId = entry.goalId
                    note = entry.note
                }
            }
        }
    }

    @MainActor
    private func save() async {
        isSaving = true
        saveError = nil

        let signedOriginalAmount = direction == "withdrawal" ? -amount : amount
        let conversion: CurrencyConversionResult
        do {
            conversion = try await CurrencyConversionService().convert(
                amount: abs(signedOriginalAmount),
                from: selectedCurrency,
                to: defaultCurrency
            )
        } catch {
            saveError = error.localizedDescription
            isSaving = false
            return
        }

        let signedConverted = direction == "withdrawal" ? -conversion.convertedAmount : conversion.convertedAmount
        let signedOriginal = direction == "withdrawal" ? -conversion.originalAmount : conversion.originalAmount

        if let entry = existingEntry {
            entry.date = date
            entry.amount = signedConverted
            entry.currencyCode = conversion.targetCurrency
            entry.originalAmount = signedOriginal
            entry.originalCurrencyCode = conversion.originalCurrency ?? selectedCurrency
            entry.exchangeRateToEntryCurrency = conversion.exchangeRate
            entry.exchangeRateDate = conversion.rateDate
            entry.goalId = selectedGoalId
            entry.note = note
        } else {
            modelContext.insert(SavingsEntry(
                date: date,
                amount: signedConverted,
                currencyCode: conversion.targetCurrency,
                originalAmount: signedOriginal,
                originalCurrencyCode: conversion.originalCurrency ?? selectedCurrency,
                exchangeRateToEntryCurrency: conversion.exchangeRate,
                exchangeRateDate: conversion.rateDate,
                goalId: selectedGoalId,
                note: note
            ))
        }

        do {
            try modelContext.save()
        } catch {
            saveError = "Could not save savings entry: \(error.localizedDescription)"
            isSaving = false
            return
        }

        isSaving = false
        NotificationCenter.default.post(name: .summerCalMoneyChanged, object: nil)
        onSave?()
        dismiss()
    }

    private func decimalSeparator() -> String {
        Locale.current.decimalSeparator ?? "."
    }
}
