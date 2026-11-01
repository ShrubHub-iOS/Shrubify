import Foundation

/// Pure helpers shared by the beta UI and the native regression harness.
enum ShrubifyBetaSupport {
    static func timingOffset(_ value: Int) -> Int { min(5000, max(-5000, value)) }

    // Positive delay means a lyric should appear later in the song.
    static func lyricPosition(playbackMs: Int, delayMs: Int) -> Int {
        let delay = timingOffset(delayMs)
        let position = max(0, playbackMs)
        if delay >= 0 { return max(0, position - delay) }
        return position > Int.max + delay ? Int.max : position - delay
    }

    static func seekPosition(lineMs: Int, delayMs: Int) -> Int {
        let delay = timingOffset(delayMs)
        let line = max(0, lineMs)
        if delay <= 0 { return max(0, line + delay) }
        return line > Int.max - delay ? Int.max : line + delay
    }

    static func matches(_ values: [String], query: String) -> Bool {
        let words = query.split(whereSeparator: { $0.isWhitespace })
        let text = values.joined(separator: " ")
        return words.allSatisfy { text.range(of: String($0), options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }
}
