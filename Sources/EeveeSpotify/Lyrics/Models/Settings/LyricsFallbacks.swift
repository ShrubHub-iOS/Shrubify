import Foundation

extension UserDefaults {
    static var lyricsFallbackOrder: [LyricsSource] {
        get {
            if let raw = container.array(forKey: "ShrubifyLyricsFallbackOrder4") as? [Int] {
                return LyricsFallbacks.unique(raw.compactMap(LyricsSource.init(rawValue:)))
            }
            return [.lrclib] + (lyricsOptions.geniusFallback ? [.genius] : [])
        }
        set { container.set(LyricsFallbacks.unique(newValue).map(\.rawValue), forKey: "ShrubifyLyricsFallbackOrder4") }
    }
}

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
