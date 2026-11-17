import Foundation
import CryptoKit

enum LyricsCacheSignature {
    /// Canonicalize before hashing so credentials influence cache identity but
    /// never become part of the diagnostic signature written to logs.
    static func make(settings: [String: Any]) -> String {
        func normalized(_ value: Any) -> Any {
            if let data = value as? Data { return data.base64EncodedString() }
            if let dictionary = value as? [String: Any] { return dictionary.mapValues(normalized) }
            if let array = value as? [Any] { return array.map(normalized) }
            return value
        }
        guard let data = try? JSONSerialization.data(withJSONObject: normalized(settings), options: [.sortedKeys]) else {
            return UUID().uuidString // Invalid settings must never reuse a cached response.
        }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
