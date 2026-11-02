import Foundation
import Orion


// Written from concurrent URLSession delegate queues; unguarded access crashed on release.
private let accessTokenLock = NSLock()
private var storedAccessToken: String?

var spotifyAccessToken: String? {
    accessTokenLock.lock(); defer { accessTokenLock.unlock() }; return storedAccessToken
}

func captureAccessToken(from request: URLRequest?) {
    guard let auth = request?.value(forHTTPHeaderField: "Authorization"), auth.hasPrefix("Bearer ") else { return }
    let token = String(auth.dropFirst(7))
    accessTokenLock.lock()
    let first = storedAccessToken == nil
    if storedAccessToken != token { storedAccessToken = token }
    accessTokenLock.unlock()
    if first {
        eeveeLog("[Shrubify][TokenCapture] First token, len %d from %@%@", token.count, request?.url?.host ?? "?", request?.url?.path ?? "")
    }
}

// Every task has one response, one body and one terminal callback. Custom lyrics
// are loaded after the underlying task completes, without blocking its delegate.
class SPTDataLoaderServiceHook: ClassHook<NSObject>, SpotifySessionDelegate {
    typealias Group = PremiumBootstrapGroup
    static let targetName = "SPTDataLoaderService"

    func URLSession(_ session: URLSession, task: URLSessionDataTask, didCompleteWithError error: Error?) {
        captureAccessToken(from: task.currentRequest)
        let buffer = URLSessionHelper.shared.obtainData(for: task)
        let replay = URLSessionHelper.shared.obtainReplay(for: task)
        guard let url = task.currentRequest?.url else {
            orig.URLSession(session, task: task, didCompleteWithError: error)
            return
        }
        if CasitaResponseProbe.shouldProbe(url) { CasitaResponseProbe.flush(task, url: url) }
        guard error == nil else {
            orig.URLSession(session, task: task, didCompleteWithError: error)
            return
        }
        if let replay {
            orig.URLSession(session, dataTask: task, didReceiveData: replay)
            orig.URLSession(session, task: task, didCompleteWithError: nil)
            return
        }
        if SpotifyResponsePatcher.shouldBlock(url) {
            orig.URLSession(session, dataTask: task, didReceiveData: SpotifyResponsePatcher.blockedResponseData(for: url))
            orig.URLSession(session, task: task, didCompleteWithError: nil)
            return
        }
        guard let buffer else {
            orig.URLSession(session, task: task, didCompleteWithError: nil)
            return
        }
        if url.isLyrics {
            let original = try? Lyrics(serializedBytes: buffer)
            loadLyricsDataAsync(url.path, originalLyrics: original) { [self] data in
                // The modern lyrics consumer is main-actor isolated.
                DispatchQueue.main.async { [self] in
                    orig.URLSession(session, dataTask: task, didReceiveData: data ?? original.flatMap { try? $0.serializedData() } ?? emptyLyricsData() ?? Data())
                    orig.URLSession(session, task: task, didCompleteWithError: nil)
                }
            }
            return
        }
        // Never turn an unsuccessful patch into a missing body/completion.
        let patched = try? SpotifyResponsePatcher.patch(url: url, buffer: buffer)
        orig.URLSession(session, dataTask: task, didReceiveData: patched?.data ?? buffer)
        orig.URLSession(session, task: task, didCompleteWithError: nil)
    }

    func URLSession(_ session: URLSession, dataTask task: URLSessionDataTask,
                    didReceiveResponse response: HTTPURLResponse,
                    completionHandler handler: @escaping (URLSession.ResponseDisposition) -> Void) {
        captureAccessToken(from: task.currentRequest)
        guard let url = task.currentRequest?.url else {
            orig.URLSession(session, dataTask: task, didReceiveResponse: response, completionHandler: handler)
            return
        }
        if url.isCustomize, response.statusCode == 304,
           let cached = SpotifyResponsePatcher.cachedCustomizeData,
           let ok = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "2.0", headerFields: [:]) {
            URLSessionHelper.shared.setReplay(cached, for: task)
            orig.URLSession(session, dataTask: task, didReceiveResponse: ok, completionHandler: handler)
            return
        }
        if url.isLyrics, BaseLyricsGroup.isActive, UserDefaults.lyricsSource.isReplacingLyrics {
            // A missing native lyric may still have a valid custom/fallback result.
            // Buffer a zero-byte native response too. Do not synthesize completion here.
            URLSessionHelper.shared.setOrAppend(Data(), for: task)
            if response.statusCode != 200,
               let ok = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "2.0", headerFields: [:]) {
                orig.URLSession(session, dataTask: task, didReceiveResponse: ok, completionHandler: handler)
                return
            }
        }
        orig.URLSession(session, dataTask: task, didReceiveResponse: response, completionHandler: handler)
    }

    func URLSession(_ session: URLSession, dataTask task: URLSessionDataTask, didReceiveData data: Data) {
        guard let url = task.currentRequest?.url else {
            orig.URLSession(session, dataTask: task, didReceiveData: data)
            return
        }
        if SpotifyResponsePatcher.shouldBlock(url) { return }
        if CasitaResponseProbe.shouldProbe(url) { CasitaResponseProbe.append(data, for: task) }
        if SpotifyResponsePatcher.shouldModify(url) {
            URLSessionHelper.shared.setOrAppend(data, for: task)
            return
        }
        orig.URLSession(session, dataTask: task, didReceiveData: data)
    }
}
