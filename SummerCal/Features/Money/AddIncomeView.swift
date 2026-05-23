import SwiftUI
import SwiftData

struct AddIncomeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var date: Date = Date()
    @State private var amountText: String = ""
    @State private var source: String = ""
    @State private var note: String = ""
    @State private var category: IncomeCategory = .other
    @State private var isRecurring: Bool = false

    var onSave: (() -> Void)?

    private var amountIsValid: Bool {
        guard let amount = Double(amountText), amount > 0 else { return false }
        return true
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
                            .foregroundStyle(.secondary)
                        TextField("Amount", text: $amountText)
                            .keyboardType(.decimalPad)
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

                Section {
                    Toggle("Recurring Monthly", isOn: $isRecurring)
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
            .navigationTitle("Add Income")
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
        }
    }

    private var formattedPreview: String {
        let amount = Double(amountText) ?? 0
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(String(format: "%.2f", amount))"
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
        guard let amount = Double(amountText), amount > 0 else { return }

        let entry = IncomeEntry(
            date: date,
            amount: amount,
            source: source,
            descriptionText: note,
            category: category
        )
        modelContext.insert(entry)
        try? modelContext.save()

        if isRecurring, let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: date) {
            let futureEntry = IncomeEntry(
                date: nextMonth,
                amount: amount,
                source: source,
                descriptionText: note,
                category: category
            )
            modelContext.insert(futureEntry)
            try? modelContext.save()
        }

        onSave?()
        dismiss()
    }
}
