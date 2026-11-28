import Foundation

enum SpotifyArtistBiography {
    static func extract(from html: String) -> String? {
        let marker = #"data-testid\s*=\s*["']expandable-description["']"#
        guard let start = html.range(of: marker, options: .regularExpression) else { return nil }
        let section = String(html[start.upperBound...].prefix(16_384))
        // The public artist page renders the biography in the first span of
        // this component. Stay inside its initial div and span structure.
        let pattern = #"(?is)^[^>]*>\s*(?:<div\b[^>]*>\s*){0,5}<span\b[^>]*>(.*?)</span\s*>"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: section, range: NSRange(section.startIndex..., in: section)),
              let body = Range(match.range(at: 1), in: section) else { return nil }
        let value = section[body]
            .replacingOccurrences(of: #"(?i)<br\s*/?>"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"<[^>]*>"#, with: "", options: .regularExpression)
        let text = decodeEntities(value).trimmingCharacters(in: .whitespacesAndNewlines)
        return !text.isEmpty && text.count <= 5_000 ? text : nil
    }

    private static func decodeEntities(_ value: String) -> String {
        let replacements = ["amp": "&", "quot": "\"", "apos": "'", "lt": "<", "gt": ">", "nbsp": " "]
        let result = NSMutableString(string: value)
        let pattern = #"&(#x[0-9a-fA-F]+|#[0-9]+|amp|quot|apos|lt|gt|nbsp);"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return value }
        let matches = regex.matches(in: value, range: NSRange(value.startIndex..., in: value))
        for match in matches.reversed() {
            guard let range = Range(match.range(at: 1), in: value) else { continue }
            let entity = String(value[range])
            let replacement: String?
            if entity.hasPrefix("#") {
                let hex = entity.hasPrefix("#x")
                replacement = UInt32(entity.dropFirst(hex ? 2 : 1), radix: hex ? 16 : 10)
                    .flatMap(UnicodeScalar.init).map(String.init)
            } else {
                replacement = replacements[entity]
            }
            if let replacement { result.replaceCharacters(in: match.range, with: replacement) }
        }
        return result as String
    }
}
