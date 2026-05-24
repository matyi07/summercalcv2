import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct AddExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var existingEntry: ExpenseEntry?

    @State private var date: Date = Date()
    @State private var amountText: String = ""
    @State private var category: ExpenseCategory = .other
    @State private var paymentMethod: String = "card"
    @State private var note: String = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var receiptData: Data?
    @State private var amountErrorTrigger: Bool = false
    @State private var isScanning: Bool = false
    @State private var scanError: String?
    @State private var scanCompleted: Bool = false

    var onSave: (() -> Void)?

    private var isEditing: Bool { existingEntry != nil }
    private let paymentMethods = ["card", "cash", "transfer", "direct debit"]

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
                        ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                            Label(cat.label, systemImage: cat.icon)
                                .tag(cat)
                        }
                    }

                    Picker("Payment Method", selection: $paymentMethod) {
                        ForEach(paymentMethods, id: \.self) { method in
                            Label(method.capitalized, systemImage: paymentIcon(method))
                                .tag(method)
                        }
                    }
                }

                Section {
                    TextField("Note", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        HStack {
                            if let receiptData, let uiImage = UIImage(data: receiptData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                Label("Add Receipt Photo", systemImage: "doc.text.viewfinder")
                                    .foregroundColor(.blue)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .onChange(of: selectedPhoto) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                receiptData = data
                                scanCompleted = false
                                scanError = nil
                            }
                        }
                    }

                    if let receiptData, !scanCompleted {
                        if isScanning {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Scanning receipt...")
                                    .font(.caption)
                                    .foregroundStyle(Color(.systemGray))
                            }
                        } else {
                            Button {
                                Task { await scanReceipt(imageData: receiptData) }
                            } label: {
                                Label("Scan Receipt with AI", systemImage: "text.viewfinder")
                                    .font(.subheadline)
                            }
                        }
                    }

                    if let scanError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                            Text(scanError)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }

                    if scanCompleted {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Receipt scanned — review below")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                } header: {
                    Text("Receipt")
                }

                Section {
                    if amountIsValid {
                        HStack {
                            Text("Total")
                            Spacer()
                            Text(formattedPreview)
                                .fontWeight(.semibold)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .sensoryFeedback(.error, trigger: amountErrorTrigger)
            .navigationTitle(isEditing ? "Edit Expense" : "Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!amountIsValid)
                }
            }
            .onAppear {
                if let entry = existingEntry {
                    date = entry.date
                    amountText = String(format: "%.2f", entry.amount).replacingOccurrences(of: ".", with: decimalSeparator())
                    category = entry.category
                    paymentMethod = entry.paymentMethod
                    note = entry.note
                    receiptData = entry.receiptImageData
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

    private func paymentIcon(_ method: String) -> String {
        switch method {
        case "card": return "creditcard"
        case "cash": return "banknote"
        case "transfer": return "arrow.left.arrow.right"
        case "direct debit": return "arrow.down.forward"
        default: return "creditcard"
        }
    }

    private func save() {
        let amount = sanitizedAmount
        guard amount > 0 else { return }

        if let entry = existingEntry {
            entry.date = date
            entry.amount = amount
            entry.category = category
            entry.paymentMethod = paymentMethod
            entry.note = note
            entry.receiptImageData = receiptData
        } else {
            let entry = ExpenseEntry(
                date: date,
                amount: amount,
                category: category,
                paymentMethod: paymentMethod,
                note: note,
                receiptImageData: receiptData
            )
            modelContext.insert(entry)
        }

        try? modelContext.save()
        onSave?()
        dismiss()
    }

    private func scanReceipt(imageData: Data) async {
        isScanning = true
        scanError = nil

        let settings = UserSettings.current(in: modelContext)
        let provider = settings.aiProviderKind

        let keychain = KeychainStore.shared
        guard let apiKey = try? keychain.readAPIKey(provider: provider) else {
            isScanning = false
            scanError = "No API key configured. Set one in Settings > AI Settings."
            return
        }

        let model: String
        switch provider {
        case "openAI": model = "gpt-4o"
        case "claude": model = "claude-3-5-sonnet-latest"
        case "deepSeek": model = "deepseek-chat"
        case "openAICompatible": model = settings.aiModelName.isEmpty ? "gpt-4o" : settings.aiModelName
        default: model = "gpt-4o"
        }

        let baseURL: String? = {
            switch provider {
            case "openAI": return nil
            case "deepSeek": return "https://api.deepseek.com"
            default: return settings.aiBaseURL
            }
        }()

        let scanner = ReceiptScannerService()
        do {
            let result = try await scanner.scanReceipt(imageData: imageData, provider: provider, apiKey: apiKey, model: model, baseURL: baseURL)

            await MainActor.run {
                if let total = result.total, total > 0 {
                    amountText = String(format: "%.2f", total).replacingOccurrences(of: ".", with: decimalSeparator())
                }
                if let dateStr = result.date {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    if let parsedDate = formatter.date(from: dateStr) {
                        date = parsedDate
                    }
                }
                if let merchant = result.merchantName, !merchant.isEmpty {
                    note = merchant + (note.isEmpty ? "" : "\n\(note)")
                }
                if let cat = result.category {
                    category = ExpenseCategory.allCases.first { $0.label.lowercased() == cat.lowercased() } ?? .other
                }
                if let cur = result.currency {
                    // Currency detection is informational; we store the amount, not the currency field
                    note = note.isEmpty ? "Currency: \(cur)" : "\(note)\nCurrency: \(cur)"
                }
                isScanning = false
                scanCompleted = true
            }
        } catch {
            await MainActor.run {
                scanError = error.localizedDescription
                isScanning = false
            }
        }
    }
}
