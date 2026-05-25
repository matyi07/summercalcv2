import SwiftUI
import SwiftData

struct AddSavingsGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var existingGoal: SavingsGoal?
    var onSave: (() -> Void)?

    @State private var name: String = ""
    @State private var targetText: String = ""
    @State private var currencyCode: String = ""
    @State private var iconName: String = "target"
    @State private var note: String = ""
    @State private var saveError: String?

    private let currencies = ["USD", "EUR", "GBP", "HUF", "JPY", "CAD", "AUD", "CHF", "CNY", "INR", "MXN", "BRL", "KRW"]
    private let icons = ["target", "house", "airplane", "car", "graduationcap", "laptopcomputer", "heart", "gift", "sparkles", "briefcase"]

    private var navigationTitleKey: LocalizedStringKey {
        existingGoal == nil ? "Savings Goal" : "Edit Goal"
    }

    private var targetAmount: Double {
        Double(targetText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var defaultCurrency: String {
        UserSettings.current(in: modelContext).currencyCode
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Goal") {
                    TextField("Name", text: $name)
                    Picker("Icon", selection: $iconName) {
                        ForEach(icons, id: \.self) { icon in
                            Label(iconLabel(icon), systemImage: icon).tag(icon)
                        }
                    }
                }

                Section("Target") {
                    Picker("Currency", selection: $currencyCode) {
                        ForEach(currencies, id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }
                    HStack {
                        Text(currencyCode.isEmpty ? defaultCurrency : currencyCode)
                            .foregroundStyle(Color(.systemGray))
                        TextField("Target Amount", text: $targetText)
                            .keyboardType(.decimalPad)
                    }
                }

                Section("Notes") {
                    TextField("What is this for?", text: $note, axis: .vertical)
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
            .navigationTitle(navigationTitleKey)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || targetAmount <= 0)
                }
            }
            .onAppear {
                currencyCode = defaultCurrency
                if let goal = existingGoal {
                    name = goal.name
                    targetText = String(format: "%.2f", goal.targetAmount).replacingOccurrences(of: ".", with: decimalSeparator())
                    currencyCode = goal.currencyCode ?? defaultCurrency
                    iconName = goal.iconName
                    note = goal.note
                }
            }
        }
    }

    private func save() {
        saveError = nil
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetCurrency = currencyCode.isEmpty ? defaultCurrency : currencyCode

        if let goal = existingGoal {
            goal.name = cleanedName
            goal.targetAmount = targetAmount
            goal.currencyCode = targetCurrency
            goal.iconName = iconName
            goal.note = note
            goal.updatedAt = Date()
        } else {
            modelContext.insert(SavingsGoal(
                name: cleanedName,
                targetAmount: targetAmount,
                currencyCode: targetCurrency,
                iconName: iconName,
                note: note
            ))
        }

        do {
            try modelContext.save()
        } catch {
            saveError = "Could not save goal: \(error.localizedDescription)"
            return
        }

        NotificationCenter.default.post(name: .summerCalMoneyChanged, object: nil)
        onSave?()
        dismiss()
    }

    private func decimalSeparator() -> String {
        Locale.current.decimalSeparator ?? "."
    }

    private func iconLabel(_ icon: String) -> String {
        switch icon {
        case "house": return "Home"
        case "airplane": return "Travel"
        case "car": return "Car"
        case "graduationcap": return "Education"
        case "laptopcomputer": return "Tech"
        case "heart": return "Health"
        case "gift": return "Gift"
        case "sparkles": return "Dream"
        case "briefcase": return "Work"
        default: return "Target"
        }
    }
}
