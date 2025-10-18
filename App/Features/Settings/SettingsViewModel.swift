import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    enum ConnectionState: Equatable {
        case idle
        case connecting
        case success(title: String)
        case failure(message: String)
    }

    @Published var baseURL: String
    @Published var adminKey: String
    @Published var connectionState: ConnectionState = .idle

    private let appViewModel: AppViewModel

    init(appViewModel: AppViewModel) {
        self.appViewModel = appViewModel
        self.baseURL = appViewModel.baseURLString
        self.adminKey = appViewModel.loadAdminKey()
    }

    func saveCredentials() {
        appViewModel.baseURLString = baseURL
        appViewModel.saveAdminKey(adminKey)
    }

    func testConnection() async {
        saveCredentials()
        connectionState = .connecting
        do {
            let api = try appViewModel.ghostAPI()
            let site = try await api.fetchSite()
            let title = site.site.title ?? "Ghost"
            appViewModel.updateSiteTitle(title)
            connectionState = .success(title: title)
        } catch {
            appViewModel.lastError = error.localizedDescription
            connectionState = .failure(message: error.localizedDescription)
        }
    }
}
