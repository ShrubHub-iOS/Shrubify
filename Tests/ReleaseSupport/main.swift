import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
func check(_ value: @autoclosure () -> Bool, _ name: String) {
    guard value() else { fatalError("FAILED: " + name) }
}
// Regression fixtures for the stable release: real parser, buffer map and policies.
check(LyricsTextParser.timestampedLine("[:12.34] Invalid") == nil, "empty minute rejected safely")
check(LyricsTextParser.timestampedLine("[99999999999999999999999:12] Invalid") == nil, "oversized timestamp rejected")
check(LyricsTextParser.timestampedLine("[00:99.999] Invalid") == nil, "invalid seconds rejected")
let parsed = LyricsTextParser.timestampedLine("[03:12.345] Hello")
check(parsed?.milliseconds == 192345 && parsed?.content == "Hello", "millisecond LRC precision")
check(LyricsTextParser.lines("First\nLast") == ["First", "Last"], "last real line kept without trailing newline")
check(LyricsTextParser.lines("Only") == ["Only"], "single plain lyric kept")
check(LyricsTextParser.lines("First\r\nLast\r\n") == ["First", "Last"], "CRLF components retain lyric text")
check(!ServerSidedFeaturePolicy.shouldOverwriteResolvedConfiguration(requested: true), "legacy preference cannot replace account navigation configuration")
for route in ["https://spclient.wg.spotify.com/esperanto/metadata/get", "https://spclient.wg.spotify.com/esperanto/load"] {
    check(!URL(string: route)!.isAdRelated, "ordinary Esperanto request permitted")
}
check(URL(string: "https://spclient.wg.spotify.com/esperanto/ads/slot")!.isAdRelated, "known ad route still classified")
let sessionA = URLSession(configuration: .ephemeral)
let sessionB = URLSession(configuration: .ephemeral)
let taskA = sessionA.dataTask(with: URL(string: "https://example.com/a")!)
let taskB = sessionB.dataTask(with: URL(string: "https://example.com/b")!)
check(taskA.taskIdentifier == taskB.taskIdentifier, "fixture has colliding session-local IDs")
let buffers = URLSessionHelper.shared
buffers.setReplay(Data([1]), for: taskA)
buffers.setReplay(Data([2]), for: taskB)
check(buffers.obtainReplay(for: taskB) == Data([2]), "replay isolated across sessions")
check(buffers.obtainReplay(for: taskA) == Data([1]), "other session cannot consume replay")
buffers.setOrAppend(Data([1]), for: taskA); buffers.setOrAppend(Data([2]), for: taskA)
check(buffers.obtainData(for: taskA) == Data([1, 2]), "body assembled in order")
check(buffers.obtainData(for: taskA) == nil, "terminal read releases body")
buffers.setOrAppend(Data([3]), for: taskA); buffers.setReplay(Data([4]), for: taskA)
buffers.discardData(for: taskA)
check(buffers.obtainData(for: taskA) == nil && buffers.obtainReplay(for: taskA) == nil, "discard removes all request state")
sessionA.invalidateAndCancel(); sessionB.invalidateAndCancel()
check(ReplayPlaybackBoundary.didRepeat(previous: 235, current: 5, duration: 240, elapsed: 10, rate: 1), "natural Repeat One wrap counted")
check(!ReplayPlaybackBoundary.didRepeat(previous: 100, current: 5, duration: 240, elapsed: 10, rate: 1), "ordinary backward seek does not count as repeat")
check(!ReplayPlaybackBoundary.didRepeat(previous: 235, current: 5, duration: 240, elapsed: 90, rate: 1), "background gap not backfilled as a repeat")
print("V4 release reliability regression checks passed")

check(LyricsTextParser.milliseconds(Double.infinity) == nil, "nonfinite provider timing rejected")
check(LyricsTextParser.milliseconds(Double.greatestFiniteMagnitude) == nil, "overflowing provider timing rejected")
check(LyricsTextParser.milliseconds(-1) == nil, "negative provider timing rejected")
final class WaitingProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { }
    override func stopLoading() { }
}
for cancelFirst in [false, true] {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [WaitingProtocol.self]
    let session = URLSession(configuration: config)
    let finished = DispatchSemaphore(value: 0)
    let context = LyricsRequestContext()
    let task = session.dataTask(with: URL(string: "https://fixture.invalid/lyrics")!) { _, _, error in
        check((error as? URLError)?.code == .cancelled, "superseded provider request actually cancelled")
        finished.signal()
    }
    if cancelFirst { context.cancel() }
    context.run { LyricsRequestContext.resume(task) }
    if !cancelFirst { context.cancel() }
    check(finished.wait(timeout: .now() + 2) == .success, "cancelled worker does not wait for network timeout")
    session.invalidateAndCancel()
}
print("Request cancellation regression checks passed")
