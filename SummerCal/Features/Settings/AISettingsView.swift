import SwiftUI

struct AISettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = SettingsViewModel()
    @State private var showSaveConfirmation = false

    private let providers = [
        ("openAI", "OpenAI", "brain.head.profile"),
        ("anthropic", "Anthropic", "sparkles"),
        ("google", "Google AI", "g.circle"),
        ("mistral", "Mistral AI", "leaf.circle"),
        ("deepSeek", "DeepSeek", "brain"),
        ("custom", "Custom", "server.rack")
    ]

    private let models: [String: [String]] = [
        "openAI": ["gpt-4o", "gpt-4o-mini", "gpt-4-turbo", "gpt-4", "gpt-3.5-turbo", "o1", "o1-mini", "o3-mini"],
        "anthropic": ["claude-3.5-sonnet-latest", "claude-3.5-haiku-latest", "claude-3-opus-latest", "claude-3-sonnet-20240229", "claude-3-haiku-20240307"],
        "google": ["gemini-2.0-flash", "gemini-2.0-pro", "gemini-1.5-pro", "gemini-1.5-flash", "gemini-1.0-pro"],
        "deepSeek": ["deepseek-v4-flash", "deepseek-v4-pro"],
        "mistral": ["mistral-large-latest", "mistral-medium-latest", "mistral-small-latest", "open-mistral-nemo", "open-mixtral-8x22b"],
        "custom": []
    ]

    private var maxTokensFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: viewModel.maxTokens)) ?? "\(viewModel.maxTokens)"
    }

    var body: some View {
        Form {
            if viewModel.apiKey.isEmpty && viewModel.settings?.aiProviderKind == "openAI" {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Get Started with AI", systemImage: "sparkles")
                            .font(.headline)
                        Text("Connect an AI provider like OpenAI or DeepSeek to enable smart day planning, event preparation, and personalized suggestions.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                Picker("Provider", selection: $viewModel.aiProviderKind) {
                    ForEach(providers, id: \.0) { provider in
                        Label(provider.1, systemImage: provider.2).tag(provider.0)
                    }
                }
            } header: {
                Text("AI Provider")
            } footer: {
                Text("Select the AI provider you want to use for planning and suggestions.")
                    .foregroundColor(Color(.systemGray))
            }

            if viewModel.aiProviderKind == "custom" {
                Section {
                    TextField("Base URL", text: $viewModel.aiBaseURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                } header: {
                    Text("Custom Endpoint")
                } footer: {
                    Text("Enter the API base URL for your custom provider.")
                        .foregroundColor(Color(.systemGray))
                }
            }

            Section {
                if viewModel.aiProviderKind == "custom" {
                    TextField("Model Name", text: $viewModel.aiModelName)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                } else {
                    Picker("Model", selection: $viewModel.aiModelName) {
                        ForEach(models[viewModel.aiProviderKind] ?? [], id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                }
            } header: {
                Text("Model")
            }

            Section {
                SecureField("API Key", text: $viewModel.apiKey)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            } header: {
                Text("API Key")
            } footer: {
                Text("Your API key is stored securely in the Keychain and never shared.")
                    .foregroundColor(Color(.systemGray))
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Max Tokens")
                        Spacer()
                        Text(maxTokensFormatted)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }
                    Picker("", selection: $viewModel.maxTokens) {
                        Text("256").tag(256)
                        Text("512").tag(512)
                        Text("1,024").tag(1024)
                        Text("2,048").tag(2048)
                        Text("4,096").tag(4096)
                        Text("8,192").tag(8192)
                    }
                    .pickerStyle(.segmented)
                }
            } header: {
                Text("Response Length")
            } footer: {
                Text("Higher values allow longer AI responses but consume more credits. 1,024 is recommended for most planning tasks.")
                    .foregroundColor(Color(.systemGray))
            }

            Section {
                Button {
                    Task { await viewModel.testConnection() }
                } label: {
                    HStack {
                        Text("Test Connection")
                        Spacer()
                        if viewModel.isTestingConnection {
                            ProgressView()
                        } else if let result = viewModel.testConnectionResult {
                            if result == "Connection successful" {
                                Label(result, systemImage: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Label(result, systemImage: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                .disabled(viewModel.apiKey.isEmpty || viewModel.isTestingConnection)
            } footer: {
                if viewModel.apiKey.isEmpty {
                    Text("Enter your API key above to test the connection.")
                        .foregroundColor(Color(.systemGray))
                }
            }

            Section {
                Button {
                    viewModel.saveSettings(modelContext: modelContext)
                    showSaveConfirmation = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showSaveConfirmation = false
                    }
                } label: {
                    HStack {
                        Spacer()
                        if showSaveConfirmation {
                            Label("Saved", systemImage: "checkmark")
                                .fontWeight(.semibold)
                        } else {
                            Label("Save Settings", systemImage: "square.and.arrow.down")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(viewModel.apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
            } footer: {
                if viewModel.apiKey.isEmpty {
                    Text("Enter your API key to save.")
                        .foregroundColor(Color(.systemGray))
                }
            }
        }
        .navigationTitle("AI Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadSettings(modelContext: modelContext)
        }
        .onDisappear {
            viewModel.saveSettings(modelContext: modelContext)
        }
    }
}
