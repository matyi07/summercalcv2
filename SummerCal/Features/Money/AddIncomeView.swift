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
    @State private var amountErrorTrigger: Bool = false

    var onSave: (() -> Void)?

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
            .sensoryFeedback(.error, trigger: amountErrorTrigger)
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
        let amount = sanitizedAmount
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
        let amount = sanitizedAmount
        guard amount > 0 else { return }

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
