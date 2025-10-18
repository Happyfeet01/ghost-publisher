import Foundation

struct HTTPError: LocalizedError {
    let statusCode: Int
    let data: Data?

    var errorDescription: String? {
        if let data, let string = String(data: data, encoding: .utf8), !string.isEmpty {
            return "HTTP \(statusCode): \(string)"
        }
        return "HTTP \(statusCode)"
    }
}

final class HTTPClient {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func request(
        path: String,
        method: String = "GET",
        query: [URLQueryItem]? = nil,
        headers: [String: String] = [:],
        body: Data? = nil
    ) async throws -> Data {
        var url = baseURL
        url.append(path: path)

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = query

        guard let finalURL = components?.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: finalURL)
        request.httpMethod = method
        request.httpBody = body
        headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw HTTPError(statusCode: httpResponse.statusCode, data: data)
        }

        return data
    }
}
