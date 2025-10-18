import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel

    init(appViewModel: AppViewModel) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(appViewModel: appViewModel))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Ghost Admin API")) {
                    TextField("Base URL", text: $viewModel.baseURL)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    SecureField("Admin API Key", text: $viewModel.adminKey)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }

                Section(footer: statusView) {
                    Button(action: testConnection) {
                        if viewModel.connectionState == .connecting {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Test Connection")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch viewModel.connectionState {
        case .idle:
            EmptyView()
        case .connecting:
            Text("Connecting…")
                .foregroundStyle(.secondary)
        case .success(let title):
            Label("Connected to \(title)", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failure(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }

    private func testConnection() {
        Task {
            await viewModel.testConnection()
        }
    }
}
