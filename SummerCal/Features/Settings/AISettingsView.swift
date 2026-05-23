import SwiftUI

struct AISettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = SettingsViewModel()

    private let providers = [
        ("openAI", "OpenAI", "brain.head.profile"),
        ("anthropic", "Anthropic", "sparkles"),
        ("google", "Google AI", "g.circle"),
        ("mistral", "Mistral AI", "leaf.circle"),
        ("custom", "Custom", "server.rack")
    ]

    private let models: [String: [String]] = [
        "openAI": ["gpt-4o", "gpt-4o-mini", "gpt-4-turbo", "gpt-3.5-turbo"],
        "anthropic": ["claude-3-opus", "claude-3-sonnet", "claude-3-haiku", "claude-3.5-sonnet"],
        "google": ["gemini-1.5-pro", "gemini-1.5-flash", "gemini-1.0-pro"],
        "mistral": ["mistral-large", "mistral-medium", "mistral-small"],
        "custom": []
    ]

    var body: some View {
        Form {
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
            }

            Section {
                Stepper("Max Tokens: \(viewModel.maxTokens)", value: $viewModel.maxTokens, in: 256...4096, step: 256)
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
            }
        }
        .navigationTitle("AI Settings")
        .onAppear {
            viewModel.loadSettings(modelContext: modelContext)
        }
        .onDisappear {
            viewModel.saveSettings(modelContext: modelContext)
        }
    }
}
