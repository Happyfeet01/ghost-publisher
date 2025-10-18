# Ghost Admin Client for iOS 26

This repository now tracks the modern replacement for the legacy Ghost Publisher app. The new native SwiftUI client targets the Ghost v5 Admin API and is built with Swift 6.2 on the iOS 26 SDK.

## Project Brief

> _Codex Prompt_
>
> You are an experienced iOS engineer. Build a fully modern, native iOS app in Swift 6.2 (Xcode 26 SDK) that works with Ghost CMS v5. Replace the outdated Ghost Publisher project and rely exclusively on the Ghost v5 Admin API with Admin JWT authentication (HS256). No password login, no Content API. Only: Admin Key → JWT → `/ghost/api/admin/` → read, write, upload.

## Goals & Scope

### 1. Authentication & Security
- Admin API key–based JWT authentication (`id:secret`, where the secret is hex-encoded).
- JWT signed with HS256 using CryptoKit. Include `kid` in the header, `iat`, `exp` (+5 minutes), and `aud` of `/v5/admin/` in the payload.
- Required HTTP headers:
  - `Authorization: Ghost <jwt>`
  - `Accept-Version: v5.0`
- No session or password logins.
- Persist the Admin key securely in the Keychain (never in `UserDefaults`).

### 2. Admin API Endpoints
- Site info: `GET /ghost/api/admin/site/` → display site title.
- Posts: `GET /ghost/api/admin/posts/?limit=20&fields=id,title,status,updated_at`
- Draft creation: `POST /ghost/api/admin/posts/`
  ```json
  {"posts":[{"title":"…","status":"draft"}]}
  ```
- Image upload: `POST /ghost/api/admin/images/upload/` via `multipart/form-data` (file field carrying JPEG data).

### 3. SwiftUI Interface (MVVM)
- **SettingsView**: capture base URL and Admin key, offer “Test Connection” that reports the blog title.
- **PostsView**: list recent posts and include a “Create Draft” action.
- **ImageUploadView**: use `PhotosPicker` for selection, upload the image, and show/copy the resulting URL.
- Support dark mode, Dynamic Type, and layouts for 6–7" iPhone displays.

### 4. Networking & Serialization
- Use `URLSession` (async/await) for all HTTP/HTTPS requests and uploads.
- Parse JSON via `Codable`/`JSONDecoder`.
- Sign JWTs with `CryptoKit` HMAC-SHA256.
- Construct `multipart/form-data` requests manually (boundary, `Content-Disposition`, binary payload).
- Secure credentials with the Keychain.

## Platform Requirements (October 2025)
- Ghost version: v5 Admin API + Lexical editor (Mobiledoc removed).
- iOS 26 SDK (Xcode 17+) with a deployment target of iOS 18 or newer.
- Swift 6.2 with structured concurrency.
- Core frameworks: SwiftUI, CryptoKit, Foundation, PhotosUI, Security (Keychain).
- App Transport Security enforced (HTTPS), privacy descriptions for photo access, no `UIWebView` usage.

## Modernization Notes

### Remove Legacy Elements
- Email/password session login.
- Old API paths such as `/ghost/api/v3/…`.
- Mobiledoc payloads (use Lexical/HTML instead).
- Legacy Swift 5.x/iOS 13 code and Storyboards.
- `UIWebView` usage.
- Unsplash integration (review keys/endpoints before reintroducing).

### Adopt Modern Techniques
- Admin JWT authentication in place of sessions.
- CryptoKit-based HMAC signatures.
- `URLSession` with async/await.
- `Codable` models for responses.
- Keychain storage for credentials.
- Full support for dark mode, Dynamic Type, and updated privacy labels.

## Suggested File Layout
```
App/
 ├─ GhostAdminApp.swift
 ├─ Features/
 │   ├─ Settings/SettingsView.swift
 │   ├─ Posts/PostsView.swift
 │   └─ Upload/ImageUploadView.swift
 ├─ Services/
 │   ├─ SecureStore.swift          // Keychain wrapper
 │   ├─ JWT/GhostJWT.swift         // JWT builder using CryptoKit
 │   ├─ HTTP/HTTPClient.swift      // URLSession client
 │   └─ Ghost/GhostAPI.swift       // API interactions
 ├─ Models/GhostModels.swift
 └─ Utils/Multipart.swift          // Multipart helper
```

## Implementation Highlights

### GhostJWT.swift
```swift
import Foundation
import CryptoKit

enum GhostJWTErr: Error { case invalidKey, hexDecodeFailed }

struct GhostJWT {
    static func b64url(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func hexToData(_ hex: String) -> Data? {
        var h = hex
        if h.count % 2 != 0 { h = "0" + h }
        var out = Data()
        var i = h.startIndex
        while i < h.endIndex {
            let j = h.index(i, offsetBy: 2)
            guard j <= h.endIndex, let b = UInt8(h[i..<j], radix: 16) else { return nil }
            out.append(b)
            i = j
        }
        return out
    }

    static func make(adminKey: String, audience: String = "/v5/admin/") throws -> String {
        let parts = adminKey.split(separator: ":")
        guard parts.count == 2 else { throw GhostJWTErr.invalidKey }

        let kid = String(parts[0])
        guard let secret = hexToData(String(parts[1])) else { throw GhostJWTErr.hexDecodeFailed }

        let header = try JSONSerialization.data(withJSONObject: ["alg": "HS256", "typ": "JWT", "kid": kid])
        let now = Int(Date().timeIntervalSince1970)
        let payload = try JSONSerialization.data(withJSONObject: ["iat": now, "exp": now + 300, "aud": audience])

        let h = b64url(header)
        let p = b64url(payload)
        let signingInput = Data("\(h).\(p)".utf8)
        let mac = HMAC<SHA256>.authenticationCode(for: signingInput, using: SymmetricKey(data: secret))
        return "\(h).\(p).\(b64url(Data(mac)))"
    }
}
```

### HTTPClient.swift
```swift
import Foundation

struct HTTPError: Error { let status: Int; let body: Data? }

final class HTTPClient {
    let baseURL: URL

    init(baseURL: URL) { self.baseURL = baseURL }

    func request(
        path: String,
        method: String = "GET",
        query: [URLQueryItem]? = nil,
        headers: [String: String] = [:],
        body: Data? = nil
    ) async throws -> Data {
        var url = baseURL
        url.append(path: path)

        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        comps.queryItems = query

        var req = URLRequest(url: comps.url!)
        req.httpMethod = method
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        req.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(http.statusCode) else { throw HTTPError(status: http.statusCode, body: data) }
        return data
    }
}
```

### GhostAPI.swift
```swift
import Foundation

struct GhostSite: Decodable {
    let site: SiteInfo

    struct SiteInfo: Decodable { let title: String? }
}

struct GhostPost: Decodable {
    let id: String
    let title: String?
    let status: String?
    let updated_at: String?
}

struct GhostPostsResponse: Decodable { let posts: [GhostPost] }

final class GhostAPI {
    private let client: HTTPClient
    private let adminKeyProvider: () -> String

    init(baseURL: URL, adminKeyProvider: @escaping () -> String) {
        self.client = HTTPClient(baseURL: baseURL)
        self.adminKeyProvider = adminKeyProvider
    }

    private func authHeaders() throws -> [String: String] {
        [
            "Authorization": "Ghost \(try GhostJWT.make(adminKey: adminKeyProvider()))",
            "Accept-Version": "v5.0"
        ]
    }

    func site() async throws -> GhostSite {
        let data = try await client.request(path: "/ghost/api/admin/site/", headers: try authHeaders())
        return try JSONDecoder().decode(GhostSite.self, from: data)
    }

    func posts(limit: Int = 20) async throws -> [GhostPost] {
        let data = try await client.request(
            path: "/ghost/api/admin/posts/",
            query: [
                URLQueryItem(name: "limit", value: "\(limit)"),
                URLQueryItem(name: "fields", value: "id,title,status,updated_at")
            ],
            headers: try authHeaders()
        )
        return try JSONDecoder().decode(GhostPostsResponse.self, from: data).posts
    }

    func createDraft(title: String) async throws -> GhostPost {
        let payload = ["posts": [["title": title, "status": "draft"]]]
        let body = try JSONSerialization.data(withJSONObject: payload)
        var headers = try authHeaders()
        headers["Content-Type"] = "application/json"
        let data = try await client.request(path: "/ghost/api/admin/posts/", method: "POST", headers: headers, body: body)
        return try JSONDecoder().decode(GhostPostsResponse.self, from: data).posts.first!
    }
}
```

## Acceptance Criteria
- “Test Connection” displays the site title.
- Recent posts load correctly.
- Draft posts can be created successfully.
- Image uploads return a URL that is shown and can be copied.
- JWT tokens refresh automatically as they expire.
- Errors (401, 403, network issues) are handled gracefully.
- Builds with the iOS 26 SDK and runs on iOS 18+ devices via Xcode 17 or later.

