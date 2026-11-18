import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// Only providers, protobufs and patch policy are stand-ins. The callback
// ordering, buffering and delegate decisions are the production implementation.
func captureAccessToken(from _: URLRequest?) {}
enum CasitaResponseProbe {
    static func shouldProbe(_: URL) -> Bool { false }
    static func append(_: Data, for _: URLSessionTask) {}
    static func flush(_: URLSessionTask, url _: URL) {}
}
enum LyricsURLCachePurge { static func remember(session _: URLSession, url _: URL) {} }
extension UserDefaults { static let shouldHandleLyricsTraffic = true }
struct Lyrics {
    let bytes: Data
    init(serializedBytes: Data) throws { bytes = serializedBytes }
    func serializedData() throws -> Data { bytes }
}
private var providerCompletion: ((Data?) -> Void)?
func loadLyricsDataAsync(_: String, originalLyrics _: Lyrics?, completion: @escaping (Data?) -> Void) { providerCompletion = completion }
func emptyLyricsData() -> Data? { nil }
enum SpotifyResponsePatcher {
    struct Result { let data: Data }
    static let cachedCustomizeData: Data? = Data([9])
    static func shouldBlock(_: URL) -> Bool { false }
    static func blockedResponseData(for _: URL) -> Data { Data() }
    static func shouldModify(_ url: URL) -> Bool { url.isLyrics || url.isCustomize }
    static func patch(url _: URL, buffer _: Data) throws -> Result? { throw URLError(.cannotParseResponse) }
}

let session = URLSession(configuration: .ephemeral)
func task(_ path: String) -> URLSessionDataTask { session.dataTask(with: URL(string: "https://example.invalid" + path)!) }
func status(_ code: Int, for task: URLSessionDataTask) -> Int {
    let response = HTTPURLResponse(url: task.originalRequest!.url!, statusCode: code, httpVersion: nil, headerFields: nil)!
    return SpotifySessionTransport.response(response, for: task).statusCode
}
var events: [String] = []
func complete(_ task: URLSessionDataTask, error: Error? = nil) {
    events.removeAll()
    SpotifySessionTransport.complete(session, task: task, error: error, deliver: { events.append("body:\(Array($0))") },
                                    finish: { events.append($0 == nil ? "finish" : "error") })
}
let plain = task("/music")
precondition(status(200, for: plain) == 200 && SpotifySessionTransport.forwards(Data([1]), for: plain))
complete(plain); precondition(events == ["finish"])
let replay = task("/v1/customize")
precondition(status(304, for: replay) == 200)
complete(replay); precondition(events == ["body:[9]", "finish"])
let patch = task("/v1/customize")
precondition(!SpotifySessionTransport.forwards(Data([1]), for: patch))
precondition(!SpotifySessionTransport.forwards(Data([2]), for: patch))
complete(patch); precondition(events == ["body:[1, 2]", "finish"], "Keep all original chunks after a patch failure")
let cancelled = task("/color-lyrics/v2/track/test")
precondition(status(404, for: cancelled) == 200)
complete(cancelled, error: URLError(.cancelled))
precondition(events == ["error"] && providerCompletion == nil && URLSessionHelper.shared.obtainData(for: cancelled) == nil)
let lyrics = task("/color-lyrics/v2/track/test")
precondition(status(404, for: lyrics) == 200)
complete(lyrics)
precondition(events.isEmpty && providerCompletion != nil, "Do not block the delegate or synthesize an early completion")
providerCompletion?(Data([7])); providerCompletion = nil
let deadline = Date().addingTimeInterval(2)
while events.isEmpty && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
precondition(events == ["body:[7]", "finish"], "Even a zero-byte native response gets one custom body, then one completion")
session.invalidateAndCancel()
print("Shared delegate transport: passthrough, replay, patch fallback, cancellation and asynchronous lyrics passed")
