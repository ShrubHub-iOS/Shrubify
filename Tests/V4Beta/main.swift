import Foundation
import Security
#if canImport(Darwin)
import Darwin
#endif

if CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "--persist-launch-probe" {
    let preferences = UserDefaults(suiteName: CommandLine.arguments[2])!
    _ = LaunchRecoveryPolicy.begin(in: preferences)
    _exit(73) // Deliberately bypass normal process-exit preference cleanup.
}


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
check([LyricsSource.autoSelect, .petit].contains(LyricsSource.defaultSource), "Evolved default is region-aware auto select")
struct TestLyricsOptions { let geniusFallback = false }
extension UserDefaults {
    static var container: UserDefaults { UserDefaults.standard }
    static var lyricsOptions: TestLyricsOptions { TestLyricsOptions() }
}

// Facts read from actual Objective-C player fixtures through the shipping bridge.
let player = ShrubTestPlayer()
let clock = KaraokePlaybackTracker.shared
let pausedFacts = ShrubReadLivePlayback(player)!
check((pausedFacts["position"] as? NSNumber)?.doubleValue == 10, "paused clock uses positionAsOfTimestamp")
clock.processStateChange(state: pausedFacts as NSDictionary)
check(clock.currentPositionMs() == 10000, "native facts update the lyric clock")
check(ShrubSeekPlaybackSeconds(player, 70), "real bridge invokes a seconds-based seek")
clock.didSeek(milliseconds: 70000)
check(clock.currentPositionMs() == 70000, "seek immediately updates lyric clock")
clock.processStateChange(state: pausedFacts as NSDictionary)
check(clock.currentPositionMs() == 70000, "stale sample cannot undo seek")
clock.processStateChange(state: ShrubReadLivePlayback(player)! as NSDictionary)
check(clock.currentPositionMs() == 70000, "live seek acknowledgement reconciles")
clock.processStateChange(state: ["position": Double.nan] as NSDictionary)
check(clock.currentPositionMs() == 70000, "invalid playback position does not crash")
check(ShrubSetPlaybackPaused(player, false), "resume command accepted")
clock.processStateChange(state: ShrubReadLivePlayback(player)! as NSDictionary)
check(clock.isPlaying(), "isPaused drives play state")
RunLoop.main.run(until: Date().addingTimeInterval(0.02))
check(clock.currentPositionMs() > 70000, "clock advances while playing")
check(ShrubSetPlaybackPaused(player, true), "pause command accepted")
clock.processStateChange(state: ShrubReadLivePlayback(player)! as NSDictionary)
check(!clock.isPlaying(), "pause reflected in shared clock")
check(clock.snapshot().durationMs == 240000, "duration read for progress control")
let throwing = ShrubTestThrowingPlayer()
check(ShrubReadLivePlayback(throwing) == nil, "state exception stays outside Swift")
check(!ShrubSeekPlaybackSeconds(throwing, 5), "seek exception handled")
check(!ShrubRegisterPlaybackObserver(throwing, NSObject()), "observer exception handled")
check(!ShrubSeekPlaybackSeconds(NSObject(), 5), "unsupported seek rejected")
check(!ShrubSeekPlaybackSeconds(player, Double.infinity), "invalid seek rejected")
print("Native playback bridge and shared clock checks passed")

clock.didSeek(milliseconds: 90000)
clock.processStateChange(state: ["position": 70, "paused": true] as NSDictionary)
check(!clock.isPlaying(), "pause update survives pending seek")
RunLoop.main.run(until: Date().addingTimeInterval(0.7))
clock.processStateChange(state: ["position": 75, "paused": true] as NSDictionary)
check(clock.currentPositionMs() == 75000, "rejected/clamped seek reconciles promptly")
print("Seek rejection and pause reconciliation checks passed")

// Existing archives keep the original type scale; malformed sizes are bounded.
assert(old.fontSize == 30 && old.lineSpacing == 16)
let typography = try JSONDecoder().decode(KaraokeOptions.self,
    from: Data("{\"fontSize\":9000,\"lineSpacing\":-100}".utf8))
assert(typography.resolvedFontSize == 40 && typography.resolvedLineSpacing == 8)
var customTypography = KaraokeOptions()
customTypography.fontSize = 36
customTypography.lineSpacing = 24
let restoredTypography = try JSONDecoder().decode(KaraokeOptions.self,
    from: JSONEncoder().encode(customTypography))
assert(restoredTypography == customTypography)
customTypography.fontSize = .nan
assert(customTypography.resolvedFontSize == 30)

let noArgumentPlayer = ShrubTestNoArgumentPlayer()
check(ShrubSetPlaybackPaused(noArgumentPlayer, true), "Zero-argument pause variants are ABI checked")
check(ShrubSetPlaybackPaused(noArgumentPlayer, false), "Zero-argument resume variants are ABI checked")
check(!ShrubSeekPlaybackSeconds(ShrubTestIntegerSeekPlayer(), 20), "Never pass a double to an integer seek selector")
let podcastFacts = ShrubReadLivePlayback(ShrubTestLongPodcast())!
check((podcastFacts["duration"] as? NSNumber)?.doubleValue == 10800, "Long podcast duration remains seconds")
check((podcastFacts["position"] as? NSNumber)?.doubleValue == 7200, "Long podcast playhead remains seconds")
print("Pause ABI and long podcast regression checks passed")

let modernInfo = SafeTrackMetadata(track: ShrubTestModernTrack() as AnyObject)
check(modernInfo?.title == "Modern track" && modernInfo?.artist == "Modern artist", "Modern metadata never invokes the legacy artistTitle getter")
check(modernInfo?.metadata["album_uri"] == "spotify:album:fixture", "Known string metadata is retained")
check(modernInfo?.metadata["bad_field"] == nil, "Unexpected metadata value types are discarded")
check(SafeTrackMetadata(track: ShrubTestLegacyTrack() as AnyObject)?.artist == "Legacy artist", "Legacy-only getter is safely supported")
check(SafeTrackMetadata(track: ShrubTestThrowingTrack() as AnyObject) == nil, "Objective-C exceptions cannot escape display metadata reads")
check(SafeTrackMetadata(track: ShrubTestScalarTrack() as AnyObject) == nil, "Wrong metadata return ABI is rejected")
check(SafeTrackMetadata(track: NSObject()) == nil, "Missing metadata methods fall back to native UI")
check(modernInfo?.identifier == "modern" && modernInfo?.durationMs == 28000, "A short explicit millisecond duration is not seconds")
check(modernInfo?.metadata["artist_name:1"] == "Guest" && modernInfo?.metadata["title"] == "Localized title", "Keep collaborator and localized search data")
let legacyTrack = ShrubReadCurrentTrack(nil, ShrubTestLegacyController())
let legacyInfo = SafeTrackMetadata(track: legacyTrack as AnyObject?)
check(legacyInfo?.title == "Legacy track" && legacyInfo?.extractedColor == "abcdef" && legacyInfo?.identifier == nil, "Guarded legacy object ivars; a malformed URI does not lose other metadata")
check(ShrubReadCurrentTrack(nil, NSObject()) == nil, "No fallback when the legacy controller layout changes")
check(ShrubTrackIdentifier(ShrubReadCurrentTrack(ShrubTestDirectPlayer(), nil)) == "direct-clock", "Identity does not depend on display metadata")
for key in ["duration_ms", "durationMs", "durationInMilliseconds"] {
    check(SafeTrackMetadata.durationMilliseconds(in: [key: "1234.5", "duration": "400"]) == 1235, "Explicit duration units take priority")
}
check(SafeTrackMetadata.durationMilliseconds(in: ["duration": "2.25"]) == 2250, "Preserve fractional seconds")
for invalid in ["-1", "nan", "inf", "1e200", "bad"] {
    check(SafeTrackMetadata.durationMilliseconds(in: ["duration_ms": invalid]) == nil, "Reject unrepresentable duration")
}
let blurLevels = (0...40).map { KaraokeOptions(blurIntensity: Double($0) / 10).resolvedBlurRadius }
check(blurLevels.first == 0 && blurLevels.last == 40 && Set(blurLevels).count == 41, "Every blur slider stop has an effect")

// Exercise the production delete planner without touching the runner's Keychain.
let ref = Data([1, 2, 3])
let labelKey = kSecAttrLabel as String, refKey = kSecValuePersistentRef as String
for cls in [kSecClassKey, kSecClassInternetPassword, kSecClassGenericPassword, kSecClassCertificate, kSecClassIdentity] {
    let attrs: [String: Any] = [labelKey: "Spotify fixture", kSecClass as String: cls]
    check(FullResetHelper.deletionQuery(for: attrs) == nil, "Never fall back to a class-only delete")
    let exact = FullResetHelper.deletionQuery(for: attrs.merging([refKey: ref]) { _, new in new })
    check(exact?.count == 1 && exact?[kSecValuePersistentRef] as? Data == ref, "Delete only this exact item")
}
check(FullResetHelper.deletionQuery(for: [labelKey: "Other app", refKey: ref]) == nil, "Do not delete unrelated references")
check(FullResetHelper.deletionQuery(for: [labelKey: "Spotify", refKey: Data()]) == nil, "Reject empty references")

let recoverySuite = "Shrubify.RecoveryTests." + UUID().uuidString
let recoveryDefaults = UserDefaults(suiteName: recoverySuite)!
check(!LaunchRecoveryPolicy.begin(in: recoveryDefaults), "First launch leaves interface preference intact")
check(LaunchRecoveryPolicy.begin(in: recoveryDefaults), "Incomplete launch requests recovery on retry")
check(recoveryDefaults.bool(forKey: "ShrubifyStabilityMode"), "Recovery keeps optional UI hooks out of the next startup")
LaunchRecoveryPolicy.complete(in: recoveryDefaults)
recoveryDefaults.set(false, forKey: "ShrubifyStabilityMode")
check(!LaunchRecoveryPolicy.begin(in: recoveryDefaults), "Healthy launch must not repeatedly force recovery")
LaunchRecoveryPolicy.complete(in: recoveryDefaults)
recoveryDefaults.removePersistentDomain(forName: recoverySuite)
print("Modern/legacy metadata ABI, exception containment and startup recovery checks passed")

let abruptSuite = "Shrubify.AbruptRecovery." + UUID().uuidString
let child = Process()
child.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
child.arguments = ["--persist-launch-probe", abruptSuite]
try child.run()
child.waitUntilExit()
check(child.terminationStatus == 73, "Recovery fixture exits without normal shutdown")
let abruptDefaults = UserDefaults(suiteName: abruptSuite)!
check(abruptDefaults.bool(forKey: LaunchRecoveryPolicy.pendingKey), "Startup probe survives abrupt process exit")
check(LaunchRecoveryPolicy.begin(in: abruptDefaults), "Next process can recover an interrupted startup")
LaunchRecoveryPolicy.complete(in: abruptDefaults)
abruptDefaults.removePersistentDomain(forName: abruptSuite)
print("Cross-process startup probe persistence passed")

let directFacts = ShrubReadLivePlayback(ShrubTestDirectPlayer())!
check((directFacts["position"] as? NSNumber)?.doubleValue == 24, "direct StatefulPlayer clock without a state object")
check((directFacts["duration"] as? NSNumber)?.doubleValue == 220, "direct clock duration")
check(directFacts["uri"] as? String == "spotify:track:direct-clock", "currentTrack URI fallback keeps clock identity")
check(ShrubReadLivePlayback(ShrubTestScalarPositionPlayer()) == nil, "reject scalar clock ABI mismatch")
let restoredClock = KaraokePlaybackTracker.shared
restoredClock.processStateChange(state: ["position": 10, "duration": 220, "paused": true, "uri": "spotify:track:before-restored"] as NSDictionary)
check(restoredClock.snapshot().hasPosition && restoredClock.snapshot().isPlaybackStateKnown, "valid clock and pause facts are known")
restoredClock.processStateChange(state: ["position": 1, "uri": "spotify:track:after-restored"] as NSDictionary)
check(restoredClock.snapshot().durationMs == 0 && !restoredClock.snapshot().isPlaybackStateKnown, "new tracks cannot inherit old duration or pause state")
print("Restored custom lyrics direct-clock ABI and track transition regressions passed")
