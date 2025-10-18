import Foundation

final class GhostAPI {
    private let client: HTTPClient
    private let adminKeyProvider: () throws -> String

    init(baseURL: URL, adminKeyProvider: @escaping () throws -> String) {
        self.client = HTTPClient(baseURL: baseURL)
        self.adminKeyProvider = adminKeyProvider
    }

    private func authHeaders() throws -> [String: String] {
        let jwt = try GhostJWT.make(adminKey: adminKeyProvider())
        return [
            "Authorization": "Ghost \(jwt)",
            "Accept-Version": "v5.0"
        ]
    }

    func fetchSite() async throws -> GhostSite {
        let data = try await client.request(path: "/ghost/api/admin/site/", headers: try authHeaders())
        let decoder = JSONDecoder()
        return try decoder.decode(GhostSite.self, from: data)
    }

    func fetchPosts(limit: Int = 20) async throws -> [GhostPost] {
        let data = try await client.request(
            path: "/ghost/api/admin/posts/",
            query: [
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "fields", value: "id,title,status,updated_at")
            ],
            headers: try authHeaders()
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(Self.iso8601Formatter)
        return try decoder.decode(GhostPostsResponse.self, from: data).posts
    }

    func createDraft(title: String) async throws -> GhostPost {
        let payload = ["posts": [["title": title, "status": "draft"]]]
        let body = try JSONSerialization.data(withJSONObject: payload)
        var headers = try authHeaders()
        headers["Content-Type"] = "application/json"

        let data = try await client.request(
            path: "/ghost/api/admin/posts/",
            method: "POST",
            headers: headers,
            body: body
        )

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(Self.iso8601Formatter)
        guard let post = try decoder.decode(GhostPostsResponse.self, from: data).posts.first else {
            throw URLError(.cannotParseResponse)
        }
        return post
    }

    func uploadImage(data: Data, filename: String, mimeType: String = "image/jpeg") async throws -> URL {
        var headers = try authHeaders()
        let multipart = MultipartFormData()
        multipart.append(data, name: "file", filename: filename, contentType: mimeType)
        let body = multipart.finalize()
        headers["Content-Type"] = "multipart/form-data; boundary=\(multipart.boundary)"

        let data = try await client.request(
            path: "/ghost/api/admin/images/upload/",
            method: "POST",
            headers: headers,
            body: body
        )

        let response = try JSONDecoder().decode(GhostUploadResponse.self, from: data)
        guard let urlString = response.images.first?.url, let url = URL(string: urlString) else {
            throw URLError(.badServerResponse)
        }
        return url
    }
}

private extension GhostAPI {
    static let iso8601Formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        return formatter
    }()
}
