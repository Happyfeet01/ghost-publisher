import PhotosUI
import SwiftUI

struct ImageUploadView: View {
    @StateObject private var viewModel: ImageUploadViewModel

    init(appViewModel: AppViewModel) {
        _viewModel = StateObject(wrappedValue: ImageUploadViewModel(appViewModel: appViewModel))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                PhotosPicker(selection: $viewModel.selectedItem, matching: .images, photoLibrary: .shared()) {
                    VStack {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 48))
                        Text("Select Photo")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6])))
                }
                .buttonStyle(.plain)

                Button("Upload") {
                    Task {
                        await viewModel.uploadSelectedPhoto()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.selectedItem == nil || viewModel.isUploading)

                Spacer()

                resultView
            }
            .padding()
            .navigationTitle("Upload")
        }
    }

    @ViewBuilder
    private var resultView: some View {
        switch viewModel.uploadState {
        case .idle:
            EmptyView()
        case .loading:
            ProgressView("Uploading…")
        case .success(let url):
            VStack(spacing: 8) {
                Label("Upload complete", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(url.absoluteString)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                ShareLink(item: url) {
                    Label("Share URL", systemImage: "square.and.arrow.up")
                }
            }
        case .failure(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
        }
    }
}
