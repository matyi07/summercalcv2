import SwiftUI
import SwiftData

struct SmartNotificationSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = SmartNotificationViewModel()
    @State private var quietHoursStart: Date = {
        var c = DateComponents(); c.hour = 22; c.minute = 0
        return Calendar.current.date(from: c) ?? Date()
    }()
    @State private var quietHoursEnd: Date = {
        var c = DateComponents(); c.hour = 8; c.minute = 0
        return Calendar.current.date(from: c) ?? Date()
    }()
    @State private var freeDayThreshold: Double = 4
    @State private var freeDayCheckTime: Date = {
        var c = DateComponents(); c.hour = 9; c.minute = 0
        return Calendar.current.date(from: c) ?? Date()
    }()
    @State private var maxPerDay: Double = 2
    @State private var weatherAlertThreshold: Double = 0.5
    @State private var dailyWeatherSummary = true
    @State private var showLogs = false

    var body: some View {
        Form {
            Section {
                ForEach(viewModel.rules, id: \.kind) { rule in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(rule.kind.displayName)
                                .font(.body)
                            Text(rule.kind.description)
                                .font(.caption)
                                .foregroundColor(Color(.systemGray))
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { rule.isEnabled },
                            set: { _ in
                                viewModel.toggleRule(rule, modelContext: modelContext)
                            }
                        ))
                    }
                    .frame(minHeight: 44)
                }
            } header: {
                Text("Notification Types")
                    .font(.footnote)
                    .textCase(.uppercase)
                    .foregroundColor(Color(.systemGray))
            }

            Section {
                DatePicker("Start", selection: $quietHoursStart, displayedComponents: .hourAndMinute)
                    .onChange(of: quietHoursStart) { _, newValue in
                        let hour = Calendar.current.component(.hour, from: newValue)
                        viewModel.updateQuietHours(start: hour, end: Calendar.current.component(.hour, from: quietHoursEnd), modelContext: modelContext)
                    }
                    .sensoryFeedback(.selection, trigger: quietHoursStart)

                DatePicker("End", selection: $quietHoursEnd, displayedComponents: .hourAndMinute)
                    .onChange(of: quietHoursEnd) { _, newValue in
                        let hour = Calendar.current.component(.hour, from: newValue)
                        viewModel.updateQuietHours(start: Calendar.current.component(.hour, from: quietHoursStart), end: hour, modelContext: modelContext)
                    }
                    .sensoryFeedback(.selection, trigger: quietHoursEnd)
            } header: {
                Text("Quiet Hours")
                    .font(.footnote)
                    .textCase(.uppercase)
                    .foregroundColor(Color(.systemGray))
            } footer: {
                Text("Notifications will not be sent during these hours.")
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(Int(freeDayThreshold)) hours")
                        .font(.subheadline)
                    Slider(value: $freeDayThreshold, in: 1...12, step: 1)
                }
                .onChange(of: freeDayThreshold) { _, newValue in
                    viewModel.updateFreeDayThreshold(Int(newValue), modelContext: modelContext)
                }

                DatePicker("Check at", selection: $freeDayCheckTime, displayedComponents: .hourAndMinute)
                    .onChange(of: freeDayCheckTime) { _, newValue in
                        let hour = Calendar.current.component(.hour, from: newValue)
                        let minute = Calendar.current.component(.minute, from: newValue)
                        viewModel.updateFreeDayCheck(hour: hour, minute: minute, modelContext: modelContext)
                    }
                    .sensoryFeedback(.selection, trigger: freeDayCheckTime)
            } header: {
                Text("Free Day")
                    .font(.footnote)
                    .textCase(.uppercase)
                    .foregroundColor(Color(.systemGray))
            } footer: {
                Text("How many free hours qualify as a free day, and when to check.")
            }

            Section {
                Stepper("Max per day: \(Int(maxPerDay))", value: $maxPerDay, in: 0...10, step: 1)
                    .onChange(of: maxPerDay) { _, newValue in
                        viewModel.updateMaxPerDay(Int(newValue), modelContext: modelContext)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Weather alert threshold: \(Int(weatherAlertThreshold * 100))%")
                        .font(.subheadline)
                    Slider(value: $weatherAlertThreshold, in: 0...1, step: 0.05)
                }
                .onChange(of: weatherAlertThreshold) { _, newValue in
                    viewModel.updateWeatherAlertThreshold(newValue, modelContext: modelContext)
                }

                Toggle("Daily Weather Summary", isOn: $dailyWeatherSummary)
                    .onChange(of: dailyWeatherSummary) { _, newValue in
                        viewModel.updateDailyWeatherSummary(newValue, modelContext: modelContext)
                    }
                    .frame(minHeight: 44)
            } header: {
                Text("Limits")
                    .font(.footnote)
                    .textCase(.uppercase)
                    .foregroundColor(Color(.systemGray))
            }

            Section {
                Button(role: .destructive) {
                    viewModel.resetToDefaults(modelContext: modelContext)
                    syncFromViewModel()
                } label: {
                    Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
            }

            Section {
                Button {
                    Task {
                        await viewModel.triggerSchedulingPipeline(modelContext: modelContext)
                    }
                } label: {
                    HStack {
                        if viewModel.isScheduling {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("Schedule Notifications Now")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(viewModel.isScheduling)

                if let error = viewModel.scheduleError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                NavigationLink {
                    notificationLogView
                } label: {
                    Label("View Notification Log", systemImage: "list.bullet.rectangle")
                }
            } header: {
                Text("Actions")
                    .font(.footnote)
                    .textCase(.uppercase)
                    .foregroundColor(Color(.systemGray))
            }
        }
        .navigationTitle("Smart Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .onAppear {
            viewModel.loadAll(modelContext: modelContext)
            syncFromViewModel()
        }
    }

    private func syncFromViewModel() {
        guard let settings = viewModel.userSettings else { return }
        freeDayThreshold = Double(settings.freeDayThresholdHours)
        maxPerDay = Double(settings.maxSmartNotificationsPerDay)
        weatherAlertThreshold = settings.rainThreshold
        dailyWeatherSummary = settings.dailyWeatherSummaryEnabled

        var startComp = DateComponents(); startComp.hour = settings.quietHoursStart; startComp.minute = 0
        quietHoursStart = Calendar.current.date(from: startComp) ?? quietHoursStart

        var endComp = DateComponents(); endComp.hour = settings.quietHoursEnd; endComp.minute = 0
        quietHoursEnd = Calendar.current.date(from: endComp) ?? quietHoursEnd

        var checkComp = DateComponents(); checkComp.hour = settings.freeDayCheckHour; checkComp.minute = settings.freeDayCheckMinute
        freeDayCheckTime = Calendar.current.date(from: checkComp) ?? freeDayCheckTime
    }

    private var notificationLogView: some View {
        List {
            if viewModel.notificationLogs.isEmpty {
                Text("No notifications logged yet")
                    .foregroundColor(Color(.systemGray))
            }
            ForEach(viewModel.notificationLogs) { log in
                VStack(alignment: .leading, spacing: 4) {
                    Text(log.title)
                        .font(.headline)
                    Text(log.body)
                        .font(.subheadline)
                        .foregroundColor(Color(.systemGray))
                    HStack {
                        Text(log.kind.displayName)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.blue.opacity(0.15)))
                        Text(log.scheduledFor, style: .relative)
                            .font(.caption)
                            .foregroundColor(Color(.systemGray))
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Notification Log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { showLogs = false }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Clear") {
                    viewModel.clearNotificationLogs(modelContext: modelContext)
                }
            }
        }
    }
}
