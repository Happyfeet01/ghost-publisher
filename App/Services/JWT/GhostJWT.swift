import Foundation
import CryptoKit

enum GhostJWTErr: Error, LocalizedError {
    case invalidKey
    case hexDecodeFailed

    var errorDescription: String? {
        switch self {
        case .invalidKey:
            return "The admin key must be in the format <id>:<secret>."
        case .hexDecodeFailed:
            return "The admin key secret is not valid hex data."
        }
    }
}

struct GhostJWT {
    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func hexToData(_ hex: String) -> Data? {
        var value = hex
        if value.count % 2 != 0 {
            value = "0" + value
        }

        var output = Data(capacity: value.count / 2)
        var index = value.startIndex
        while index < value.endIndex {
            let nextIndex = value.index(index, offsetBy: 2)
            guard nextIndex <= value.endIndex, let byte = UInt8(value[index..<nextIndex], radix: 16) else {
                return nil
            }
            output.append(byte)
            index = nextIndex
        }

        return output
    }

    static func make(adminKey: String, audience: String = "/v5/admin/") throws -> String {
        let components = adminKey.split(separator: ":")
        guard components.count == 2 else {
            throw GhostJWTErr.invalidKey
        }

        let keyID = String(components[0])
        guard let secretData = hexToData(String(components[1])) else {
            throw GhostJWTErr.hexDecodeFailed
        }

        let now = Int(Date().timeIntervalSince1970)
        let header = try JSONSerialization.data(withJSONObject: ["alg": "HS256", "typ": "JWT", "kid": keyID])
        let payload = try JSONSerialization.data(withJSONObject: [
            "iat": now,
            "exp": now + 300,
            "aud": audience
        ])

        let encodedHeader = base64URL(header)
        let encodedPayload = base64URL(payload)
        let signingInput = Data("\(encodedHeader).\(encodedPayload)".utf8)
        let mac = HMAC<SHA256>.authenticationCode(for: signingInput, using: SymmetricKey(data: secretData))
        let signature = base64URL(Data(mac))

        return "\(encodedHeader).\(encodedPayload).\(signature)"
    }
}
