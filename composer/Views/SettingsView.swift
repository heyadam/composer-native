//
//  SettingsView.swift
//  composer
//
//  Settings for API key configuration
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var openAIKey: String = ""
    @State private var anthropicKey: String = ""
    @State private var googleKey: String = ""

    @State private var hasOpenAIKey = false
    @State private var hasAnthropicKey = false
    @State private var hasGoogleKey = false

    @State private var isSaving = false
    @State private var saveError: String?

    private var hasChanges: Bool {
        !openAIKey.isEmpty || !anthropicKey.isEmpty || !googleKey.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    APIKeyField(
                        label: "OpenAI",
                        placeholder: "sk-...",
                        key: $openAIKey,
                        hasKey: hasOpenAIKey
                    )

                    APIKeyField(
                        label: "Anthropic",
                        placeholder: "sk-ant-...",
                        key: $anthropicKey,
                        hasKey: hasAnthropicKey
                    )

                    APIKeyField(
                        label: "Google",
                        placeholder: "AIza...",
                        key: $googleKey,
                        hasKey: hasGoogleKey
                    )
                } header: {
                    Text("API Keys")
                } footer: {
                    Text("Keys are stored securely in your device's Keychain.")
                }

                if let error = saveError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveKeys()
                    }
                    .disabled(isSaving || !hasChanges)
                }
            }
            .task {
                await loadKeyStatus()
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 300)
        #endif
    }

    private func loadKeyStatus() async {
        hasOpenAIKey = await APIKeyStorage.shared.hasKey(for: "openai")
        hasAnthropicKey = await APIKeyStorage.shared.hasKey(for: "anthropic")
        hasGoogleKey = await APIKeyStorage.shared.hasKey(for: "google")
    }

    private func saveKeys() {
        isSaving = true
        saveError = nil

        Task {
            do {
                if !openAIKey.isEmpty {
                    try await APIKeyStorage.shared.setKey(openAIKey, for: "openai")
                    hasOpenAIKey = true
                    openAIKey = ""
                }

                if !anthropicKey.isEmpty {
                    try await APIKeyStorage.shared.setKey(anthropicKey, for: "anthropic")
                    hasAnthropicKey = true
                    anthropicKey = ""
                }

                if !googleKey.isEmpty {
                    try await APIKeyStorage.shared.setKey(googleKey, for: "google")
                    hasGoogleKey = true
                    googleKey = ""
                }

                dismiss()
            } catch {
                saveError = error.localizedDescription
            }

            isSaving = false
        }
    }
}

// MARK: - API Key Field

struct APIKeyField: View {
    let label: String
    let placeholder: String
    @Binding var key: String
    let hasKey: Bool

    var body: some View {
        HStack {
            Text(label)
                .frame(width: 80, alignment: .leading)

            SecureField(placeholder, text: $key)
                .textContentType(.password)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif

            if hasKey {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }
}

#Preview {
    SettingsView()
}
