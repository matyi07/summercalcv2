import SwiftUI
import SwiftData

struct AddWorkSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var existingSession: WorkSession?

    @State private var date: Date = Date()
    @State private var startTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var endTime: Date = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var hourlyRateText: String = ""
    @State private var pricingMode: String = "hourly"
    @State private var note: String = ""
    @State private var rateErrorTrigger: Bool = false
    @State private var saveError: String?

    var onSave: (() -> Void)?

    private var isEditing: Bool { existingSession != nil }

    private var hourlyRate: Double {
        let cleaned = hourlyRateText.replacingOccurrences(of: ",", with: ".")
        return Double(cleaned) ?? 0
    }

    private var rateAmount: Double { hourlyRate }

    private var durationHours: Double {
        max(endTime.timeIntervalSince(startTime) / 3600, 0)
    }

    private var estimatedEarnings: Double {
        pricingMode == "daily" ? rateAmount : durationHours * rateAmount
    }

    private var isValid: Bool {
        rateAmount > 0 && endTime > startTime
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
                    DatePicker("Start Time", selection: $startTime, displayedComponents: [.hourAndMinute])
                    DatePicker("End Time", selection: $endTime, in: startTime..., displayedComponents: [.hourAndMinute])
                }

                Section {
                    Picker("Pricing", selection: $pricingMode) {
                        Label("Hourly", systemImage: "clock").tag("hourly")
                        Label("Daily", systemImage: "calendar").tag("daily")
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Text(currencyCode)
                            .foregroundStyle(Color(.systemGray))
                        TextField(pricingMode == "daily" ? "Daily Rate" : "Hourly Rate", text: $hourlyRateText)
                            .keyboardType(.decimalPad)
                            .onChange(of: hourlyRateText) { _, newValue in
                                let cleaned = newValue.replacingOccurrences(of: ",", with: ".")
                                if !newValue.isEmpty && (Double(cleaned) ?? 0) <= 0 {
                                    rateErrorTrigger.toggle()
                                }
                            }
                    }
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

                Section {
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text(formatDuration)
                            .foregroundStyle(Color(.systemGray))
                    }

                    if isValid {
                        HStack {
                            Text("Estimated Earnings")
                            Spacer()
                            Text(formatCurrency(estimatedEarnings))
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .sensoryFeedback(.error, trigger: rateErrorTrigger)
            .navigationTitle(isEditing ? "Edit Work Session" : "Add Work Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if let session = existingSession {
                    date = session.date
                    startTime = session.startTime
                    endTime = session.endTime
                    pricingMode = session.pricingMode ?? "hourly"
                    hourlyRateText = String(format: "%.2f", session.hourlyRate).replacingOccurrences(of: ".", with: decimalSeparator())
                    note = session.descriptionText
                    if session.currencyCode == nil {
                        session.currencyCode = currencyCode
                        try? modelContext.save()
                    }
                }
            }
        }
    }

    private var formatDuration: String {
        let hours = Int(durationHours)
        let minutes = Int((durationHours - Double(hours)) * 60)
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(String(format: "%.2f", amount))"
    }

    private func decimalSeparator() -> String {
        Locale.current.decimalSeparator ?? "."
    }

    private func save() {
        let duration = endTime.timeIntervalSince(startTime) / 3600
        let earned = pricingMode == "daily" ? rateAmount : duration * rateAmount

        if let session = existingSession {
            session.date = date
            session.startTime = startTime
            session.endTime = endTime
            session.hourlyRate = rateAmount
            session.totalEarned = earned
            session.currencyCode = session.currencyCode ?? currencyCode
            session.pricingMode = pricingMode
            session.descriptionText = note
        } else {
            let session = WorkSession(
                date: date,
                startTime: startTime,
                endTime: endTime,
                hourlyRate: rateAmount,
                totalEarned: earned,
                currencyCode: currencyCode,
                pricingMode: pricingMode,
                descriptionText: note
            )
            modelContext.insert(session)
        }

        do {
            try modelContext.save()
        } catch {
            saveError = "Could not save work session: \(error.localizedDescription)"
            return
        }
        NotificationCenter.default.post(
            name: .summerCalMoneyChanged,
            object: nil,
            userInfo: ["date": date]
        )
        onSave?()
        dismiss()
    }
}
