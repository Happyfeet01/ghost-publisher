import Foundation

@MainActor
final class PostsViewModel: ObservableObject {
    enum State {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    @Published var posts: [GhostPost] = []
    @Published var state: State = .idle

    private let appViewModel: AppViewModel

    init(appViewModel: AppViewModel) {
        self.appViewModel = appViewModel
    }

    func load() async {
        state = .loading
        do {
            let api = try appViewModel.ghostAPI()
            posts = try await api.fetchPosts()
            state = .loaded
        } catch {
            appViewModel.lastError = error.localizedDescription
            state = .failed(error.localizedDescription)
        }
    }

    func createDraft(title: String) async {
        state = .loading
        do {
            let api = try appViewModel.ghostAPI()
            let post = try await api.createDraft(title: title)
            posts.insert(post, at: 0)
            state = .loaded
        } catch {
            appViewModel.lastError = error.localizedDescription
            state = .failed(error.localizedDescription)
        }
    }
}
