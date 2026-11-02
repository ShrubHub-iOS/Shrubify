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
