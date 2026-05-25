import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = SettingsViewModel()
    @State private var showResetConfirmation: Bool = false
    @State private var showNotificationSettings: Bool = false

    private let currencies = ["USD", "EUR", "GBP", "HUF", "JPY", "CAD", "AUD", "CHF", "CNY", "INR", "MXN", "BRL", "KRW"]

    var body: some View {
        Form {
            aiSettingsSection

            notificationsSection

            locationSection

            preferencesSection

            currencySection

            aboutSection

            resetSection
        }
        .navigationTitle("Settings")
        .onAppear {
            viewModel.loadSettings(modelContext: modelContext)
        }
        .onDisappear {
            viewModel.saveSettings(modelContext: modelContext)
        }
        .sheet(isPresented: $showNotificationSettings) {
            SmartNotificationSettingsView()
        }
        .alert("Reset All Data", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                withAnimation {
                    viewModel.resetAllData(modelContext: modelContext)
                }
            }
        } message: {
            Text("This will permanently delete all your calendar events, settings, income entries, work sessions, weather data, places, activity suggestions, and notifications. This action cannot be undone.")
        }
    }

    private var aiSettingsSection: some View {
        Section {
            NavigationLink {
                AISettingsView()
            } label: {
                Label("AI Settings", systemImage: "brain.head.profile")
            }

            HStack {
                Text("Provider")
                Spacer()
                Text(providerDisplayName(viewModel.aiProviderKind))
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Model")
                Spacer()
                Text(viewModel.aiModelName)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        } header: {
            Text("AI Settings")
                .font(.footnote)
                .textCase(.uppercase)
                .foregroundColor(.secondary)
        }
    }

    private var notificationsSection: some View {
        Section {
            NavigationLink(destination: SmartNotificationSettingsView()) {
                Label("Notification Settings", systemImage: "bell.badge")
            }
        } header: {
            Text("Notifications")
                .font(.footnote)
                .textCase(.uppercase)
                .foregroundColor(.secondary)
        }
    }

    private var locationSection: some View {
        Section {
            Toggle("Enable Location", isOn: $viewModel.locationEnabled)
                .sensoryFeedback(.impact, trigger: viewModel.locationEnabled)
                .padding(.vertical, 4)

            Toggle("Approximate Location", isOn: $viewModel.approximateLocation)
                .disabled(!viewModel.locationEnabled)
                .opacity(viewModel.locationEnabled ? 1.0 : 0.4)
                .padding(.vertical, 4)
        } header: {
            Text("Location")
                .font(.footnote)
                .textCase(.uppercase)
                .foregroundColor(.secondary)
        } footer: {
            if !viewModel.locationEnabled {
                Text("Location is used for weather and nearby place suggestions.")
            }
        }
    }

    private var preferencesSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Activity Preferences")
                    .font(.subheadline)
                    .fontWeight(.medium)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(viewModel.availableActivities, id: \.id) { activity in
                        Button {
                            if viewModel.selectedActivities.contains(activity.id) {
                                viewModel.selectedActivities.remove(activity.id)
                            } else {
                                viewModel.selectedActivities.insert(activity.id)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: activity.icon)
                                    .font(.caption)
                                Text(activity.label)
                                    .font(.caption)
                                Spacer()
                                if viewModel.selectedActivities.contains(activity.id) {
                                    Image(systemName: "checkmark")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                viewModel.selectedActivities.contains(activity.id)
                                    ? Color.orange.opacity(0.12) : Color(.systemGray6)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        viewModel.selectedActivities.contains(activity.id)
                                            ? Color.orange : Color.clear, lineWidth: 1.5
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Energy Level")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(viewModel.energyLevel))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                }
                Slider(value: $viewModel.energyLevel, in: 1...5, step: 1)
                    .tint(.orange)
                    .sensoryFeedback(.selection, trigger: viewModel.energyLevel)
                HStack {
                    Text("Low")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("High")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Picker("Budget Preference", selection: $viewModel.budgetPreference) {
                ForEach(viewModel.budgetOptions, id: \.self) { option in
                    Text(option.capitalized).tag(option)
                }
            }
        } header: {
            Text("Preferences")
                .font(.footnote)
                .textCase(.uppercase)
                .foregroundColor(.secondary)
        }
    }

    private var currencySection: some View {
        Section {
            Picker("Currency", selection: $viewModel.currencyCode) {
                ForEach(currencies, id: \.self) { code in
                    Text(code).tag(code)
                }
            }

            HStack {
                Text("Monthly Goal")
                Spacer()
                if viewModel.monthlyIncomeGoal > 0 {
                    TextField("0", value: $viewModel.monthlyIncomeGoal, format: .currency(code: viewModel.currencyCode))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                } else {
                    Button("Set Goal") {
                        viewModel.monthlyIncomeGoal = 1000
                    }
                    .font(.subheadline)
                    .foregroundColor(.orange)
                }
            }

            Stepper(value: $viewModel.moneyEntryPreviewLimit, in: 1...50) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Money Entries Shown")
                    Text("\(viewModel.moneyEntryPreviewLimit) entries per section before More")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Currency & Goals")
                .font(.footnote)
                .textCase(.uppercase)
                .foregroundColor(.secondary)
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text("\(viewModel.appVersion) (\(viewModel.buildNumber))")
                    .foregroundStyle(.secondary)
            }

            NavigationLink {
                privacyStatementView
            } label: {
                Label("Privacy Statement", systemImage: "hand.raised")
            }

            Link(destination: URL(string: "https://summercal.app/support")!) {
                Label("Help & Support", systemImage: "questionmark.circle")
            }
        } header: {
            Text("About")
                .font(.footnote)
                .textCase(.uppercase)
                .foregroundColor(.secondary)
        }
    }

    private var privacyStatementView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("SummerCal Privacy Statement")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Last updated: June 2025")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("SummerCal is designed with your privacy in mind. Here's how your data is handled:")

                Group {
                    privacyPoint(icon: "calendar", title: "Calendar Data", description: "Your calendar data stays on your device. We access your events locally to provide planning suggestions and smart notifications.")
                    privacyPoint(icon: "location", title: "Location Data", description: "Location is used only locally to show weather and nearby places. Your precise location is never uploaded to our servers.")
                    privacyPoint(icon: "key", title: "API Keys", description: "AI provider API keys are stored securely in the iOS Keychain and are never shared with third parties.")
                    privacyPoint(icon: "network", title: "Network Requests", description: "Weather data is fetched from OpenWeatherMap. Place data comes from Google Places or Apple MapKit. AI requests go directly to your chosen provider.")
                    privacyPoint(icon: "icloud", title: "iCloud Sync", description: "If enabled, your data syncs via iCloud. We do not operate our own servers for data storage.")
                }
            }
            .padding()
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func privacyPoint(icon: String, title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.headline)
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var resetSection: some View {
        Section {
            Button(role: .destructive) {
                showResetConfirmation = true
            } label: {
                Label("Reset All Data", systemImage: "trash")
                    .foregroundColor(.red)
            }
        } footer: {
            Text("⚠️ This permanently deletes ALL your data. This action cannot be undone.")
                .foregroundColor(.red.opacity(0.8))
        }
    }

    private func providerDisplayName(_ kind: String) -> String {
        switch kind {
        case "openAI": return "OpenAI"
        case "anthropic": return "Anthropic"
        case "google": return "Google AI"
        case "deepSeek": return "DeepSeek"
        case "mistral": return "Mistral AI"
        case "custom": return "Custom"
        default: return kind.capitalized
        }
    }
}
