import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

func check(_ value: @autoclosure () -> Bool, _ message: String) {
    guard value() else { fatalError(message) }
}
check(LyricsActivationPolicy.shouldCapturePlayer(replacingLyrics: false, stabilityMode: false), "Native lyrics must not disable sleep timer/player capture")
check(!LyricsActivationPolicy.shouldCapturePlayer(replacingLyrics: false, stabilityMode: true), "Stability Mode must skip optional capture when custom lyrics are off")
check(LyricsActivationPolicy.shouldReplaceLyrics(replacementSelected: true, officialExperiment: false, disabled: false), "Custom lyrics must work independently of premium patching")
check(LyricsActivationPolicy.shouldReplaceLyrics(replacementSelected: false, officialExperiment: true, disabled: false), "Official experiment overrides native-source selection")
check(LyricsActivationPolicy.shouldHandleLyricsTraffic(replacementSelected: false, officialExperiment: false, disabled: true), "Disabling all lyrics must still intercept and suppress the native response")
check(!LyricsActivationPolicy.shouldReplaceLyrics(replacementSelected: false, officialExperiment: false, disabled: false), "Native-only mode must not call providers")
check(!LyricsActivationPolicy.shouldReplaceLyrics(replacementSelected: true, officialExperiment: true, disabled: true), "Explicit disable must win")
check(!LyricsResultPolicy.matchesRequestedTrack(requested: "A", current: "B"), "A delayed lookup must not overwrite the next track")
check(!LyricsResultPolicy.matchesRequestedTrack(requested: "A", current: nil), "Lost player identity must not publish stale lyrics")
check(LyricsResultPolicy.matchesRequestedTrack(requested: "A", current: "A"), "Current track result is accepted")
let first = LyricsCacheSignature.make(settings: ["source": 7, "credential": "fixture-key", "options": Data([1,2])])
let reordered = LyricsCacheSignature.make(settings: ["options": Data([1,2]), "credential": "fixture-key", "source": 7])
check(first == reordered, "Dictionary order must not defeat memo reuse")
check(!first.contains("fixture-key") && first.count == 64, "Signatures must not expose credentials")
check(first != LyricsCacheSignature.make(settings: ["source": 7, "credential": "changed", "options": Data([1,2])]), "Changing a credential must invalidate the memo")
check(first != LyricsCacheSignature.make(settings: ["source": 7, "credential": "fixture-key", "options": Data([3])]), "Changing provider options must invalidate the memo")

LyricsRequestBudget.withLimit(seconds: 1) {
    let outer = LyricsRequestBudget.deadline!
    LyricsRequestBudget.withLimit(seconds: 30) {
        check(LyricsRequestBudget.deadline == outer, "Nested request must not extend the deadline")
    }
    check(LyricsRequestBudget.deadline == outer, "Nested context must restore its parent")
}
check(LyricsRequestBudget.deadline == nil, "A completed request must not leak its budget to the next lookup")
LyricsRequestBudget.withLimit(seconds: 0) {
    do { try LyricsRequestBudget.check(); fatalError("Expired budget was accepted") }
    catch { check((error as? URLError)?.code == .timedOut, "Expiry must report timeout") }
}
final class StalledProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {}
    override func stopLoading() {}
}
let config = URLSessionConfiguration.ephemeral
config.protocolClasses = [StalledProtocol.self]
let session = URLSession(configuration: config)
let callback = DispatchSemaphore(value: 0)
let networkFinished = DispatchSemaphore(value: 0)
let task = session.dataTask(with: URL(string: "https://fixture.invalid/lyrics")!) { _, _, error in
    check((error as? URLError)?.code == .cancelled, "Timed-out request must actually cancel the task")
    networkFinished.signal()
}
task.resume()
let start = ProcessInfo.processInfo.systemUptime
let completed = LyricsRequestBudget.withLimit(seconds: 0.05) {
    LyricsRequestBudget.wait(callback, task: task, maximum: 15)
}
check(!completed, "A stalled provider must return timeout")
check(ProcessInfo.processInfo.systemUptime - start < 2, "The shared budget must bound waiting")
check(networkFinished.wait(timeout: .now() + 2) == .success, "Cancellation must reach URLSession")
session.invalidateAndCancel()
print("PR integration, stale-track, memo-identity and request-cancellation checks passed")
