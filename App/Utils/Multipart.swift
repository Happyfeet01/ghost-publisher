import Foundation

final class MultipartFormData {
    let boundary: String
    private var parts: [Data] = []

    init(boundary: String = "Boundary-\(UUID().uuidString)") {
        self.boundary = boundary
    }

    func append(_ data: Data, name: String, filename: String? = nil, contentType: String? = nil) {
        var part = Data()
        part.append("--\(boundary)\r\n".data(using: .utf8)!)
        var disposition = "Content-Disposition: form-data; name=\"\(name)\""
        if let filename {
            disposition += "; filename=\"\(filename)\""
        }
        part.append("\(disposition)\r\n".data(using: .utf8)!)
        if let contentType {
            part.append("Content-Type: \(contentType)\r\n".data(using: .utf8)!)
        }
        part.append("\r\n".data(using: .utf8)!)
        part.append(data)
        part.append("\r\n".data(using: .utf8)!)
        parts.append(part)
    }

    func finalize() -> Data {
        var body = Data()
        for part in parts {
            body.append(part)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }
}
