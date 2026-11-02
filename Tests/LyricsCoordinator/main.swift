import Foundation

func check(_ value: @autoclosure () -> Bool, _ name: String) { if !value() { fatalError(name) } }
func writeDebugLog(_ message: String) { }
extension String { var localized: String { self } }
extension Notification.Name { static let eeveeKaraokeLyricsChanged = Notification.Name("test.lyrics") }
struct LyricsOptions: Equatable { let romanization = false }
struct LyricsLoadingState { var isEmpty = false; var loadedSuccessfully = false; var wasRomanized = false; var fallbackError: LyricsError? }
enum LyricsError: Error { case noSuchSong }
var lyricsState = LyricsLoadingState()
var spotifyAccessToken: String? { nil }
func fetchTrackDetails(trackId: String, token: String) -> (title: String, artist: String)? { nil }
enum LyricsTrackMetadata { static func set(trackId: String, title: String, artist: String) {} }
struct KaraokeLyricsDto { let marker: Int
    static func lineSynced(from dto: LyricsDto, providerName: String) -> Self? { dto.karaoke }
}
enum Romanization { case original, romanized, canBeRomanized }
struct LyricsDto { var lines = ["line"]; var instrumental = false; var karaoke: KaraokeLyricsDto?; var romanization = Romanization.original }
protocol LyricsRepository { func getLyrics(_ query: LyricsSearchQuery, options: LyricsOptions) throws -> LyricsDto }
extension UserDefaults {
    static var lyricsSource: LyricsSource = .spicylyrics
    static var lyricsFallbackOrder: [LyricsSource] = [.lrclib]
    static var lyricsOptions = LyricsOptions()
    static var effectiveSpicyLyricsApiKey = "test"
    static var musixmatchToken = ""
}
final class ProviderFixture {
    static let shared = ProviderFixture()
    private let lock = NSLock()
    private var calls: [String: Int] = [:]
    let started = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    func count(_ key: String) -> Int { lock.lock(); defer { lock.unlock() }; return calls[key, default: 0] }
    func load(_ query: LyricsSearchQuery, source: String) throws -> LyricsDto {
        lock.lock(); calls[query.spotifyTrackId + source, default: 0] += 1; lock.unlock()
        if query.spotifyTrackId == "instrumental" { return LyricsDto(lines: [], instrumental: true) }
        if query.spotifyTrackId == "change" {
            if source == "spicy" { throw LyricsError.noSuchSong }
            if source == "lrclib" { started.signal(); _ = release.wait(timeout: .now() + 3) }
        }
        if query.spotifyTrackId == "dedup" { Thread.sleep(forTimeInterval: 0.08) }
        return LyricsDto(karaoke: KaraokeLyricsDto(marker: source == "petit" ? 3 : 1))
    }
}
class SpicyLyricsRepository: LyricsRepository {
    static let shared = SpicyLyricsRepository()
    func getLyrics(_ query: LyricsSearchQuery, options: LyricsOptions) throws -> LyricsDto { try ProviderFixture.shared.load(query, source: "spicy") }
}
class LrclibLyricsRepository: LyricsRepository {
    static let shared = LrclibLyricsRepository()
    func getLyrics(_ query: LyricsSearchQuery, options: LyricsOptions) throws -> LyricsDto { try ProviderFixture.shared.load(query, source: "lrclib") }
}
class PetitLyricsRepository: LyricsRepository {
    static let shared = PetitLyricsRepository()
    func getLyrics(_ query: LyricsSearchQuery, options: LyricsOptions) throws -> LyricsDto { try ProviderFixture.shared.load(query, source: "petit") }
}
class GeniusLyricsRepository: LyricsRepository {
    static let shared = GeniusLyricsRepository()
    func getLyrics(_ query: LyricsSearchQuery, options: LyricsOptions) throws -> LyricsDto { try ProviderFixture.shared.load(query, source: "genius") }
}
class MusixmatchLyricsRepository: LyricsRepository {
    static let shared = MusixmatchLyricsRepository()
    func getLyrics(_ query: LyricsSearchQuery, options: LyricsOptions) throws -> LyricsDto { try ProviderFixture.shared.load(query, source: "musixmatch") }
}
let coordinator = LyricsRequestCoordinator.shared
let fixture = ProviderFixture.shared
func query(_ id: String) -> LyricsSearchQuery { LyricsSearchQuery(title: "Title", primaryArtist: "Artist", spotifyTrackId: id) }
let complete = DispatchSemaphore(value: 0)
for _ in 0..<30 {
    coordinator.request(query("dedup"), force: false) { value in check(value != nil, "deduplicated completion missing"); complete.signal() }
}
for _ in 0..<30 { check(complete.wait(timeout: .now() + 3) == .success, "completion lost") }
check(fixture.count("dedupspicy") == 1, "same track performs duplicate network work")
coordinator.request(query("dedup"), force: false) { _ in complete.signal() }
check(complete.wait(timeout: .now() + 3) == .success && fixture.count("dedupspicy") == 1, "cache is not reused")

let cancelled = DispatchSemaphore(value: 0)
coordinator.request(query("change"), force: false) { value in check(value == nil, "old provider result leaked"); cancelled.signal() }
check(fixture.started.wait(timeout: .now() + 3) == .success, "old fallback did not start")
UserDefaults.lyricsFallbackOrder = [.petit]
coordinator.invalidate()
coordinator.request(query("change"), force: false) { value in check(value?.dto.karaoke?.marker == 3, "new fallback order ignored"); complete.signal() }
fixture.release.signal()
check(cancelled.wait(timeout: .now() + 3) == .success, "invalidated consumer not completed")
check(complete.wait(timeout: .now() + 3) == .success, "new request did not finish")
check(KaraokeLyricsStore.shared.lyrics(forTrackId: "change")?.marker == 3, "obsolete worker repopulated custom lyrics")
check(cancelled.wait(timeout: .now() + 0.05) == .timedOut, "consumer completed twice")
coordinator.request(query("instrumental"), force: false) { value in check(value?.dto.instrumental == true, "instrumental incorrectly rejected"); complete.signal() }
check(complete.wait(timeout: .now() + 3) == .success, "instrumental missing")
check(fixture.count("instrumentalpetit") == 0, "instrumental triggered unnecessary fallback")
print("Lyrics coordinator concurrency and fallback regression checks passed")
