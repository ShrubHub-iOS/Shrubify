import Foundation

/// Malformed provider text must never become a numeric trap or delete a lyric.
enum LyricsTextParser {
    static func milliseconds(_ seconds: Double) -> Int? {
        guard seconds.isFinite, seconds >= 0, seconds <= 86460 else { return nil }
        return Int((seconds * 1000).rounded())
    }
    static func lines(_ text: String) -> [String] {
        var result = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n")
        while result.last?.isEmpty == true { result.removeLast() }
        return result
    }

    static func timestampedLine(_ text: String) -> (content: String, milliseconds: Int)? {
        guard let regex = timestamp,
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let minuteRange = Range(match.range(at: 1), in: text),
              let secondRange = Range(match.range(at: 2), in: text),
              let contentRange = Range(match.range(at: 3), in: text),
              let minute = Int(text[minuteRange]), (0...1440).contains(minute),
              let seconds = Double(text[secondRange]), seconds.isFinite, seconds >= 0, seconds < 60 else { return nil }
        let total = (Double(minute) * 60 + seconds) * 1000
        return (String(text[contentRange]), Int(total.rounded()))
    }

    private static let timestamp = try? NSRegularExpression(pattern: #"^\[([0-9]+):([0-9]+(?:\.[0-9]+)?)\] ?(.*)$"#)
}
