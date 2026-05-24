import SwiftUI
import SwiftData
import PhotosUI
import UIKit
import AVFoundation

private struct ReceiptExpenseDraft {
    let date: Date
    let amount: Double
    let category: ExpenseCategory
    let paymentMethod: String
    let note: String
    let receiptImageData: Data
}

struct AddExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var existingEntry: ExpenseEntry?

    @State private var date: Date = Date()
    @State private var amountText: String = ""
    @State private var category: ExpenseCategory = .other
    @State private var paymentMethod: String = "card"
    @State private var note: String = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var receiptImages: [Data] = []
    @State private var amountErrorTrigger: Bool = false
    @State private var isScanning: Bool = false
    @State private var scanError: String?
    @State private var scannedCount: Int = 0
    @State private var showCamera: Bool = false
    @State private var capturedUIImage: UIImage?

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

                receiptSection

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
                    Button("Save") { save() }
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
                    if let img = entry.receiptImageData {
                        receiptImages = [img]
                        scannedCount = 1
                    }
                }
            }
            .onChange(of: selectedPhotos) { _, _ in
                Task {
                    await loadSelectedPhotos()
                }
            }
            .onChange(of: capturedUIImage) { _, image in
                guard let image else { return }
                do {
                    receiptImages.append(try ReceiptImageNormalizer.jpegData(from: image))
                    scannedCount = 0
                    scanError = nil
                } catch {
                    scanError = error.localizedDescription
                }
                capturedUIImage = nil
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraCaptureView(
                    capturedImage: $capturedUIImage,
                    errorMessage: $scanError
                )
                .ignoresSafeArea()
            }
        }
    }

    private var receiptSection: some View {
        Section {
            if !receiptImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(receiptImages.enumerated()), id: \.offset) { idx, data in
                            if let uiImage = UIImage(data: data) {
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))

                                    Button {
                                        guard receiptImages.indices.contains(idx) else { return }
                                        receiptImages.remove(at: idx)
                                        if selectedPhotos.indices.contains(idx) {
                                            selectedPhotos.remove(at: idx)
                                        }
                                        scannedCount = min(scannedCount, receiptImages.count)
                                        scanError = nil
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .padding(4)
                                            .background(Circle().fill(Color.black.opacity(0.6)))
                                            .padding(2)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            HStack(spacing: 16) {
                Button {
                    requestCameraAndShow()
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "camera.fill").font(.title2)
                        Text("Take Photo").font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                PhotosPicker(selection: $selectedPhotos, maxSelectionCount: isEditing ? 1 : 5, matching: .images) {
                    VStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle").font(.title2)
                        Text("Choose Photo\(receiptImages.isEmpty ? "" : "s")").font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }

            if !receiptImages.isEmpty, scannedCount < receiptImages.count, !isScanning {
                Button {
                    Task { await scanAllReceipts() }
                } label: {
                    Label(scanButtonTitle, systemImage: "text.viewfinder")
                }
            }

            if isScanning {
                HStack {
                    ProgressView().scaleEffect(0.8)
                    Text("Scanning \(min(scannedCount + 1, receiptImages.count))/\(receiptImages.count)...")
                        .font(.caption).foregroundStyle(Color(.systemGray))
                }
            }

            if let scanError {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red).font(.caption)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(scanError).font(.caption).foregroundColor(.red)
                        Button("Retry") {
                            Task { await scanAllReceipts() }
                        }
                        .font(.caption).foregroundColor(.blue)
                    }
                }
            }

            if scannedCount > 0, scannedCount >= receiptImages.count, scanError == nil, !receiptImages.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    Text("Scanned \(scannedCount) receipt\(scannedCount > 1 ? "s" : "") — review below")
                        .font(.caption).foregroundColor(.green)
                }
            }
        } header: {
            Text("Receipt")
        }
    }

    private var scanButtonTitle: String {
        if !isEditing && receiptImages.count > 1 {
            return "Scan & Add \(receiptImages.count) Expenses"
        }
        return "Scan \(receiptImages.count) Receipt\(receiptImages.count > 1 ? "s" : "") with AI"
    }

    @MainActor
    private func loadSelectedPhotos() async {
        let items = selectedPhotos
        guard !items.isEmpty else { return }

        var loaded: [Data] = []
        var firstError: String?

        for (idx, item) in items.enumerated() {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw NSError(
                        domain: "ReceiptPhotoPicker",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Photo \(idx + 1) could not be loaded."]
                    )
                }
                loaded.append(try ReceiptImageNormalizer.jpegData(from: data))
            } catch {
                if firstError == nil {
                    firstError = "Photo \(idx + 1): \(error.localizedDescription)"
                }
            }
        }

        receiptImages = loaded
        selectedPhotos = []
        scannedCount = 0
        scanError = firstError
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

    private func providerLabel(_ key: String) -> String {
        switch key {
        case "openAI": return "OpenAI"
        case "deepSeek": return "DeepSeek"
        case "anthropic": return "Anthropic"
        case "custom": return "Custom"
        case "google": return "Google AI"
        case "mistral": return "Mistral"
        default: return key
        }
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

    private func requestCameraAndShow() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            scanError = "Camera not available on this device."
            return
        }
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { showCamera = true }
                    else { scanError = "Camera access denied." }
                }
            }
        case .denied, .restricted:
            scanError = "Camera access denied. Enable in Settings."
        @unknown default:
            scanError = "Camera unavailable."
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
            entry.receiptImageData = receiptImages.first
        } else {
            let entry = ExpenseEntry(
                date: date,
                amount: amount,
                category: category,
                paymentMethod: paymentMethod,
                note: note,
                receiptImageData: receiptImages.first
            )
            modelContext.insert(entry)
        }

        try? modelContext.save()
        onSave?()
        dismiss()
    }

    private func scanAllReceipts() async {
        guard !receiptImages.isEmpty else { return }
        isScanning = true
        scanError = nil

        let settings = UserSettings.current(in: modelContext)
        let provider = settings.aiProviderKind

        let keychain = KeychainStore.shared
        guard let apiKey = try? keychain.readAPIKey(provider: provider) else {
            isScanning = false
            scanError = "No API key for \(providerLabel(provider)). Configure in Settings > AI Settings."
            return
        }

        let model = settings.aiModelName.isEmpty
            ? (AIProviderKind.fromSettings(provider)?.defaultModel ?? "gpt-4o")
            : settings.aiModelName

        let baseURL: String? = {
            switch provider {
            case "openAI": return nil
            case "deepSeek": return "https://api.deepseek.com"
            case "custom": return settings.aiBaseURL
            case "google": return "https://generativelanguage.googleapis.com/v1beta/openai"
            case "mistral": return "https://api.mistral.ai"
            default: return settings.aiBaseURL
            }
        }()

        let scanner = ReceiptScannerService()
        let converter = CurrencyConversionService()
        let targetCurrency = settings.currencyCode

        var drafts: [ReceiptExpenseDraft] = []
        for (idx, imageData) in receiptImages.enumerated() {
            do {
                let result = try await scanner.scanReceipt(
                    imageData: imageData, provider: provider, apiKey: apiKey,
                    model: model, baseURL: baseURL
                )

                let draft = try await expenseDraft(
                    from: result,
                    imageData: imageData,
                    targetCurrency: targetCurrency,
                    converter: converter,
                    existingNote: note
                )
                drafts.append(draft)
                scannedCount = idx + 1
            } catch {
                isScanning = false
                scanError = "Photo \(idx + 1): \(error.localizedDescription)"
                scannedCount = idx
                return
            }
        }

        await MainActor.run {
            if !isEditing && drafts.count > 1 {
                for draft in drafts {
                    let entry = ExpenseEntry(
                        date: draft.date,
                        amount: draft.amount,
                        category: draft.category,
                        paymentMethod: draft.paymentMethod,
                        note: draft.note,
                        receiptImageData: draft.receiptImageData
                    )
                    modelContext.insert(entry)
                }
                try? modelContext.save()
                isScanning = false
                scanError = nil
                onSave?()
                dismiss()
                return
            }

            guard let draft = drafts.first else {
                isScanning = false
                scanError = "No receipt data was found."
                return
            }

            amountText = String(format: "%.2f", draft.amount).replacingOccurrences(of: ".", with: decimalSeparator())
            date = draft.date
            category = draft.category
            paymentMethod = draft.paymentMethod
            note = draft.note
            isScanning = false
            scanError = nil
        }
    }

    private func expenseDraft(
        from extraction: ReceiptExtraction,
        imageData: Data,
        targetCurrency: String,
        converter: CurrencyConversionService,
        existingNote: String
    ) async throws -> ReceiptExpenseDraft {
        guard let total = extraction.total, total > 0 else {
            throw NSError(
                domain: "ReceiptScanner",
                code: 422,
                userInfo: [NSLocalizedDescriptionKey: "No total amount found on this receipt."]
            )
        }

        let conversion = try await converter.convert(
            amount: total,
            from: extraction.currency,
            to: targetCurrency
        )

        return ReceiptExpenseDraft(
            date: receiptDate(from: extraction.date),
            amount: conversion.convertedAmount,
            category: normalizedExpenseCategory(extraction.category ?? ""),
            paymentMethod: normalizedPaymentMethod(extraction.paymentMethod),
            note: receiptNote(existingNote: existingNote, extraction: extraction, conversion: conversion),
            receiptImageData: imageData
        )
    }

    private func receiptDate(from dateString: String?) -> Date {
        guard let dateString else { return Date() }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString) ?? Date()
    }

    private func normalizedExpenseCategory(_ value: String) -> ExpenseCategory {
        let normalized = value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
        if let category = ExpenseCategory.allCases.first(where: {
            $0.rawValue.lowercased() == normalized || $0.label.lowercased() == normalized
        }) {
            return category
        }

        switch normalized {
        case let value where ["restaurant", "dining", "grocery", "groceries", "cafe", "coffee", "food", "elelmiszer"].contains(where: { value.contains($0) }):
            return .food
        case let value where ["fuel", "gas station", "parking", "taxi", "transport", "bus", "train", "benzinkut"].contains(where: { value.contains($0) }):
            return .transport
        case let value where ["pharmacy", "medical", "clinic", "health", "patika", "gyogyszertar"].contains(where: { value.contains($0) }):
            return .health
        case let value where ["movie", "cinema", "ticket", "concert", "entertainment"].contains(where: { value.contains($0) }):
            return .entertainment
        case let value where ["subscription", "netflix", "spotify", "elofizetes"].contains(where: { value.contains($0) }):
            return .subscription
        case let value where ["hotel", "flight", "airline", "travel"].contains(where: { value.contains($0) }):
            return .travel
        case let value where ["book", "school", "education", "konyv", "iskola"].contains(where: { value.contains($0) }):
            return .education
        case let value where ["utility", "bill", "water", "electric", "gas bill", "kozmu"].contains(where: { value.contains($0) }):
            return .utilities
        case let value where ["store", "shop", "retail", "clothing", "bolt", "aruhaz"].contains(where: { value.contains($0) }):
            return .shopping
        default:
            return .other
        }
    }

    private func normalizedPaymentMethod(_ value: String?) -> String {
        guard let value else { return paymentMethod }
        let normalized = value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
        if paymentMethods.contains(normalized) { return normalized }
        if ["keszpenz", "cash", "kp"].contains(where: { normalized.contains($0) }) {
            return "cash"
        }
        if ["bankkartya", "bank card", "card", "kartya", "visa", "mastercard", "maestro", "pos"].contains(where: { normalized.contains($0) }) {
            return "card"
        }
        if ["atutalas", "transfer", "bank transfer"].contains(where: { normalized.contains($0) }) {
            return "transfer"
        }
        if ["direct debit", "csoportos beszedes"].contains(where: { normalized.contains($0) }) {
            return "direct debit"
        }
        return paymentMethod
    }

    private func receiptNote(
        existingNote: String,
        extraction: ReceiptExtraction,
        conversion: CurrencyConversionResult
    ) -> String {
        var lines: [String] = []

        if let merchant = extraction.merchantName, !merchant.isEmpty {
            lines.append("Store: \(merchant)")
        }
        if let method = extraction.paymentMethod, !method.isEmpty {
            lines.append("Payment: \(method.capitalized)")
        }
        if let currency = conversion.originalCurrency {
            lines.append("Currency: \(currency)")
        } else if let currency = extraction.currency, !currency.isEmpty {
            lines.append("Currency: \(currency)")
        }
        if conversion.converted, let originalCurrency = conversion.originalCurrency {
            lines.append("Original: \(formattedAmount(conversion.originalAmount, currency: originalCurrency))")
            lines.append("Converted: \(formattedAmount(conversion.convertedAmount, currency: conversion.targetCurrency))")
            if let rate = conversion.exchangeRate {
                var rateLine = "Rate: 1 \(originalCurrency) = \(String(format: "%.6f", rate)) \(conversion.targetCurrency)"
                if let rateDate = conversion.rateDate {
                    rateLine += " (\(rateDate))"
                }
                lines.append(rateLine)
            }
        }
        if let tax = extraction.tax, tax > 0 {
            let taxCurrency = conversion.originalCurrency ?? extraction.currency ?? conversion.targetCurrency
            lines.append("Tax: \(formattedAmount(tax, currency: taxCurrency))")
        }
        if let items = extraction.lineItems, !items.isEmpty {
            lines.append("Items: \(items.prefix(8).joined(separator: ", "))")
        }
        let autoPrefixes = ["Store:", "Payment:", "Currency:", "Original:", "Converted:", "Rate:", "Tax:", "Items:"]
        let customLines = existingNote
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { line in
                !line.isEmpty && !autoPrefixes.contains { line.hasPrefix($0) }
            }
        lines.append(contentsOf: customLines)

        return lines.joined(separator: "\n")
    }

    private func formattedAmount(_ amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "\(String(format: "%.2f", amount)) \(currency)"
    }
}
