import Foundation
import Combine

@MainActor
final class AppViewModel: ObservableObject {
    @Published var siteTitle: String?
    @Published var lastError: String?

    private let secureStore: SecureStoring
    private let baseURLDefaultsKey = "ghost.admin.baseURL"
    private let keychainService = "com.ghost.publisher.adminkey"
    private let keychainAccount = "adminKey"

    init(secureStore: SecureStoring = SecureStore()) {
        self.secureStore = secureStore
    }

    var baseURLString: String {
        get {
            UserDefaults.standard.string(forKey: baseURLDefaultsKey) ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: baseURLDefaultsKey)
        }
    }

    func saveAdminKey(_ key: String) {
        do {
            try secureStore.save(Data(key.utf8), service: keychainService, account: keychainAccount)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func loadAdminKey() -> String {
        do {
            if let data = try secureStore.load(service: keychainService, account: keychainAccount),
               let key = String(data: data, encoding: .utf8) {
                return key
            }
        } catch {
            lastError = error.localizedDescription
        }
        return ""
    }

    func clearAdminKey() {
        do {
            try secureStore.delete(service: keychainService, account: keychainAccount)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func updateSiteTitle(_ title: String?) {
        siteTitle = title
    }

    func ghostAPI() throws -> GhostAPI {
        guard let baseURL = URL(string: baseURLString), !baseURLString.isEmpty else {
            throw URLError(.badURL)
        }
        let adminKey = loadAdminKey()
        guard !adminKey.isEmpty else {
            throw GhostJWTErr.invalidKey
        }
        return GhostAPI(baseURL: baseURL) { adminKey }
    }
}
