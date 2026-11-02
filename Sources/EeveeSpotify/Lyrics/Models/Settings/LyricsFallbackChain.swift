import Foundation

enum LyricsFallbacks {
    static func unique(_ sources: [LyricsSource]) -> [LyricsSource] {
        var seen = Set<Int>()
        return sources.filter { $0 != .notReplaced && seen.insert($0.rawValue).inserted }
    }
    static func chain(primary: LyricsSource, fallbacks: [LyricsSource]) -> [LyricsSource] {
        guard primary != .notReplaced else { return [] }
        return unique([primary] + fallbacks)
    }
}
