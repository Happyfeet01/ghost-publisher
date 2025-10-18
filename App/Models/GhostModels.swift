import Foundation

struct GhostSite: Decodable {
    struct SiteInfo: Decodable {
        let title: String?
    }

    let site: SiteInfo
}

struct GhostPost: Identifiable, Decodable {
    let id: String
    let title: String?
    let status: String?
    let updated_at: Date?
}

struct GhostPostsResponse: Decodable {
    let posts: [GhostPost]
}

struct GhostUploadResponse: Decodable {
    struct Image: Decodable {
        let url: String
    }

    let images: [Image]
}
