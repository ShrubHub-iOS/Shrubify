import Foundation

// UIKit-free stand-ins let the actual cache and settings decoder run on macOS.
struct KaraokeLyricsDto { let marker: Int }
extension String { var localized: String { self } }
extension Notification.Name { static let eeveeKaraokeLyricsChanged = Notification.Name("V4LyricsChanged") }

func check(_ value: @autoclosure () -> Bool, _ name: String) {
    guard value() else { fatalError("FAILED: " + name) }
}

let old = try JSONDecoder().decode(KaraokeOptions.self, from: Data("{\"enabled\":false,\"customLyricsOnly\":true}".utf8))
check(!old.enabled && old.customLyricsOnly && old.timingOffsetMs == 0, "v3 settings survive migration")
var options = KaraokeOptions()
options.timingOffsetMs = 700
options.customLyricsOnly = true
let roundTrip = try JSONDecoder().decode(KaraokeOptions.self, from: JSONEncoder().encode(options))
check(roundTrip == options, "settings round trip")
let badOffset = try JSONDecoder().decode(KaraokeOptions.self, from: Data("{\"timingOffsetMs\":90000}".utf8))
check(badOffset.timingOffsetMs == 5000, "stored offsets bounded")
check(ShrubifyBetaSupport.lyricPosition(playbackMs: 1000, delayMs: 500) == 500, "positive offset delays lyric")
check(ShrubifyBetaSupport.seekPosition(lineMs: 1000, delayMs: 500) == 1500, "seek agrees with displayed timing")
check(ShrubifyBetaSupport.lyricPosition(playbackMs: 0, delayMs: 500) == 0, "negative displayed time clamped")
check(ShrubifyBetaSupport.seekPosition(lineMs: 100, delayMs: -500) == 0, "negative seek clamped")
check(ShrubifyBetaSupport.lyricPosition(playbackMs: Int.max, delayMs: -500) == Int.max, "display overflow bounded")
check(ShrubifyBetaSupport.seekPosition(lineMs: Int.max, delayMs: 500) == Int.max, "seek overflow bounded")
check(ShrubifyBetaSupport.matches(["Beyoncé", "Halo"], query: "  beyonce HALO "), "multiword case and accent search")
check(!ShrubifyBetaSupport.matches(["Halo"], query: "halo missing"), "all words required")
check(ShrubifyBetaSupport.matches([], query: "  "), "empty search matches")

let cache = KaraokeLyricsStore.shared
cache.clear()
for index in 0..<8 { cache.set(trackId: "\(index)", lyrics: KaraokeLyricsDto(marker: index)) }
check(cache.lyrics(forTrackId: "0")?.marker == 0, "cache retrieval")
cache.set(trackId: "8", lyrics: KaraokeLyricsDto(marker: 8))
check(cache.lyrics(forTrackId: "0") != nil && cache.lyrics(forTrackId: "1") == nil, "least recently read entry evicted")
RunLoop.main.run(until: Date().addingTimeInterval(0.05))
var notifications = 0
let observer = NotificationCenter.default.addObserver(forName: .eeveeKaraokeLyricsChanged, object: nil, queue: nil) { _ in notifications += 1 }
cache.notify(); cache.notify(); cache.notify()
RunLoop.main.run(until: Date().addingTimeInterval(0.05))
check(notifications == 1, "notification burst coalesced")
NotificationCenter.default.removeObserver(observer)
cache.clear()
check(cache.lyrics(forTrackId: "0") == nil, "cache clear")
print("V4 beta behavior checks passed")

check(LyricsFallbacks.chain(primary: .spicylyrics, fallbacks: [.lrclib, .spicylyrics, .lrclib, .genius]) == [.spicylyrics, .lrclib, .genius], "fallback order deduplicates and keeps primary first")
check(LyricsFallbacks.chain(primary: .notReplaced, fallbacks: [.spicylyrics]).isEmpty, "Spotify-only setting prevents provider calls")
check(LyricsFallbacks.unique([.notReplaced, .lrclib, .lrclib]) == [.lrclib], "invalid fallback removed")
check(LyricsSource.defaultSource == .spicylyrics, "default provider stays SpicyLyrics")
struct TestLyricsOptions { let geniusFallback = false }
extension UserDefaults {
    static var container: UserDefaults { UserDefaults.standard }
    static var lyricsOptions: TestLyricsOptions { TestLyricsOptions() }
}
