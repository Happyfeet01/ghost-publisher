import SwiftUI

@main
struct GhostAdminApp: App {
    @StateObject private var appViewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            TabView {
                PostsView(appViewModel: appViewModel)
                    .tabItem {
                        Label("Posts", systemImage: "doc.text")
                    }

                ImageUploadView(appViewModel: appViewModel)
                    .tabItem {
                        Label("Upload", systemImage: "square.and.arrow.up")
                    }

                SettingsView(appViewModel: appViewModel)
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
            }
            .environmentObject(appViewModel)
        }
    }
}
