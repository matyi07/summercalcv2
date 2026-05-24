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
    @State private var isRecurring: Bool = false
    @State private var amountErrorTrigger: Bool = false

    var onSave: (() -> Void)?

    private var isEditing: Bool { existingEntry != nil }

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

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $date, displayedComponents: [.date])
                }

                Section {
                    HStack {
                        Text(currencyCode)
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
                        save()
                    }
                    .disabled(!amountIsValid || source.isEmpty)
                }
            }
            .onAppear {
                if let entry = existingEntry {
                    date = entry.date
                    amountText = String(format: "%.2f", entry.amount).replacingOccurrences(of: ".", with: decimalSeparator())
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
        formatter.currencyCode = currencyCode
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(String(format: "%.2f", amount))"
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

    private func save() {
        let amount = sanitizedAmount
        guard amount > 0 else { return }

        if let entry = existingEntry {
            entry.date = date
            entry.amount = amount
            entry.source = source
            entry.descriptionText = note
            entry.category = category
        } else {
            let entry = IncomeEntry(
                date: date,
                amount: amount,
                source: source,
                descriptionText: note,
                category: category
            )
            modelContext.insert(entry)

            if isRecurring, let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: date) {
                let futureEntry = IncomeEntry(
                    date: nextMonth,
                    amount: amount,
                    source: source,
                    descriptionText: note,
                    category: category
                )
                modelContext.insert(futureEntry)
            }
        }

        try? modelContext.save()
        onSave?()
        dismiss()
    }
}
