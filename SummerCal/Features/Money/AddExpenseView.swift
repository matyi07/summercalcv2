import SwiftUI
import SwiftData
import PhotosUI
import UIKit
import AVFoundation

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

                PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 5, matching: .images) {
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
                    Label("Scan \(receiptImages.count) Receipt\(receiptImages.count > 1 ? "s" : "") with AI", systemImage: "text.viewfinder")
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
        var merged: [String: Any?] = [:]

        for (idx, imageData) in receiptImages.enumerated() {
            do {
                let result = try await scanner.scanReceipt(
                    imageData: imageData, provider: provider, apiKey: apiKey,
                    model: model, baseURL: baseURL
                )
                if let t = result.total, t > 0 {
                    let prev = (merged["total"] as? Double) ?? 0
                    let cnt = (merged["count"] as? Int) ?? 0
                    merged["total"] = prev + t
                    merged["count"] = cnt + 1
                }
                if merged["merchantName"] == nil { merged["merchantName"] = result.merchantName }
                if merged["date"] == nil { merged["date"] = result.date }
                if merged["category"] == nil { merged["category"] = result.category }
                if merged["currency"] == nil { merged["currency"] = result.currency }
                scannedCount = idx + 1
            } catch {
                isScanning = false
                scanError = "Photo \(idx + 1): \(error.localizedDescription)"
                scannedCount = idx
                return
            }
        }

        let mergedTotal: Double? = {
            guard let sum = merged["total"] as? Double, sum > 0 else { return nil }
            return sum
        }()

        await MainActor.run {
            if let total = mergedTotal, total > 0 {
                amountText = String(format: "%.2f", total).replacingOccurrences(of: ".", with: decimalSeparator())
            }
            if let dateStr = merged["date"] as? String {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                if let parsedDate = formatter.date(from: dateStr) { date = parsedDate }
            }
            if let merchant = merged["merchantName"] as? String, !merchant.isEmpty {
                note = merchant + (note.isEmpty ? "" : "\n\(note)")
            }
            if let cat = merged["category"] as? String {
                category = ExpenseCategory.allCases.first { $0.label.lowercased() == cat.lowercased() } ?? .other
            }
            if let cur = merged["currency"] as? String {
                note = note.isEmpty ? "Currency: \(cur)" : "\(note)\nCurrency: \(cur)"
            }
            isScanning = false
            scanError = nil
        }
    }
}
