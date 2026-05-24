import SwiftUI
import SwiftData

struct AddWorkSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var date: Date = Date()
    @State private var startTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var endTime: Date = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var hourlyRateText: String = ""
    @State private var note: String = ""
    @State private var rateErrorTrigger: Bool = false

    var onSave: (() -> Void)?

    private var hourlyRate: Double {
        let cleaned = hourlyRateText.replacingOccurrences(of: ",", with: ".")
        return Double(cleaned) ?? 0
    }

    private var durationHours: Double {
        max(endTime.timeIntervalSince(startTime) / 3600, 0)
    }

    private var estimatedEarnings: Double {
        durationHours * hourlyRate
    }

    private var isValid: Bool {
        hourlyRate > 0 && endTime > startTime
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
                    HStack {
                        Text(currencyCode)
                            .foregroundStyle(Color(.systemGray))
                        TextField("Hourly Rate", text: $hourlyRateText)
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
            .navigationTitle("Add Work Session")
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

    private func save() {
        let duration = endTime.timeIntervalSince(startTime) / 3600
        let earned = duration * hourlyRate

        let session = WorkSession(
            date: date,
            startTime: startTime,
            endTime: endTime,
            hourlyRate: hourlyRate,
            totalEarned: earned,
            descriptionText: note
        )
        modelContext.insert(session)
        try? modelContext.save()

        onSave?()
        dismiss()
    }
}
