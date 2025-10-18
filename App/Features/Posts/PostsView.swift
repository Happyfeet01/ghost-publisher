import SwiftUI

struct PostsView: View {
    @StateObject private var viewModel: PostsViewModel
    @State private var isPresentingDraftSheet = false
    @State private var draftTitle = ""

    init(appViewModel: AppViewModel) {
        _viewModel = StateObject(wrappedValue: PostsViewModel(appViewModel: appViewModel))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .idle, .loading, .loaded:
                    List(viewModel.posts) { post in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(post.title ?? "Untitled")
                                .font(.headline)
                            HStack {
                                if let status = post.status {
                                    Label(status.capitalized, systemImage: "tag.fill")
                                        .labelStyle(.titleOnly)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                if let updatedAt = post.updated_at {
                                    Text(updatedAt, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .overlay(overlayView)
                case .failed(let message):
                    ContentUnavailableView(
                        "Failed to load posts",
                        systemImage: "exclamationmark.triangle",
                        description: Text(message)
                    )
                }
            }
            .navigationTitle("Posts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPresentingDraftSheet = true
                    } label: {
                        Label("New Draft", systemImage: "square.and.pencil")
                    }
                }
            }
            .task {
                await viewModel.load()
            }
            .refreshable {
                await viewModel.load()
            }
            .sheet(isPresented: $isPresentingDraftSheet) {
                draftSheet
            }
        }
    }

    @ViewBuilder
    private var overlayView: some View {
        switch viewModel.state {
        case .loading:
            ProgressView("Loading posts…")
        case .idle, .loaded:
            if viewModel.posts.isEmpty {
                ContentUnavailableView("No posts found", systemImage: "doc.plaintext")
            } else {
                EmptyView()
            }
        case .failed:
            EmptyView()
        }
    }

    private var draftSheet: some View {
        NavigationStack {
            Form {
                Section(header: Text("Draft Title")) {
                    TextField("Title", text: $draftTitle)
                        .textInputAutocapitalization(.words)
                }
            }
            .navigationTitle("New Draft")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresentingDraftSheet = false
                        draftTitle = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await viewModel.createDraft(title: draftTitle.isEmpty ? "Untitled" : draftTitle)
                        }
                        isPresentingDraftSheet = false
                        draftTitle = ""
                    }
                    .disabled(draftTitle.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
