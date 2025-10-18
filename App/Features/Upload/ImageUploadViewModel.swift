import Foundation
import PhotosUI
import SwiftUI

@MainActor
final class ImageUploadViewModel: ObservableObject {
    enum UploadState {
        case idle
        case loading
        case success(URL)
        case failure(String)
    }

    @Published var selectedItem: PhotosPickerItem?
    @Published var uploadState: UploadState = .idle

    private let appViewModel: AppViewModel

    init(appViewModel: AppViewModel) {
        self.appViewModel = appViewModel
    }

    var isUploading: Bool {
        if case .loading = uploadState { return true }
        return false
    }

    func uploadSelectedPhoto() async {
        guard let item = selectedItem else { return }
        uploadState = .loading
        do {
            let data = try await data(for: item)
            let api = try appViewModel.ghostAPI()
            let url = try await api.uploadImage(data: data, filename: filename(for: item))
            uploadState = .success(url)
        } catch {
            appViewModel.lastError = error.localizedDescription
            uploadState = .failure(error.localizedDescription)
        }
    }

    private func data(for item: PhotosPickerItem) async throws -> Data {
        if let data = try await item.loadTransferable(type: Data.self) {
            return data
        }
        struct ImageDataTransferable: Transferable {
            static var transferRepresentation: some TransferRepresentation {
                DataRepresentation(importedContentType: .image) { data in
                    data
                }
            }
        }
        if let transferable = try await item.loadTransferable(type: ImageDataTransferable.self) {
            return transferable
        }
        throw URLError(.cannotDecodeRawData)
    }

    private func filename(for item: PhotosPickerItem) -> String {
        if let suggested = item.suggestedName {
            return suggested
        }
        return "ghost-upload-\(UUID().uuidString).jpg"
    }
}
