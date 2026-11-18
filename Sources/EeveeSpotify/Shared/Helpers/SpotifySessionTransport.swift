import Foundation

/// The two Spotify transports expose the same contract. Only their Orion
/// trampolines differ; buffering, recovery, queue and callback order do not.
enum SpotifySessionTransport {
    static func complete(_ session: URLSession, task: URLSessionDataTask, error: Error?,
                         deliver: @escaping (Data) -> Void, finish: @escaping (Error?) -> Void) {
        captureAccessToken(from: task.currentRequest)
        let buffer = URLSessionHelper.shared.obtainData(for: task)
        let replay = URLSessionHelper.shared.obtainReplay(for: task)
        guard let url = task.currentRequest?.url else {
            finish(error)
            return
        }
        if CasitaResponseProbe.shouldProbe(url) { CasitaResponseProbe.flush(task, url: url) }
        guard error == nil else {
            finish(error)
            return
        }
        if let replay {
            deliver(replay)
            finish(nil)
            return
        }
        if SpotifyResponsePatcher.shouldBlock(url) {
            deliver(SpotifyResponsePatcher.blockedResponseData(for: url))
            finish(nil)
            return
        }
        guard let buffer else {
            finish(nil)
            return
        }
        if url.isLyrics {
            LyricsURLCachePurge.remember(session: session, url: url)
            let original = try? Lyrics(serializedBytes: buffer)
            loadLyricsDataAsync(url.path, originalLyrics: original) { data in
                // The modern lyrics consumer is main-actor isolated.
                DispatchQueue.main.async {
                    deliver(data ?? original.flatMap { try? $0.serializedData() } ?? emptyLyricsData() ?? Data())
                    finish(nil)
                }
            }
            return
        }
        // Never turn an unsuccessful patch into a missing body/completion.
        let patched = try? SpotifyResponsePatcher.patch(url: url, buffer: buffer)
        deliver(patched?.data ?? buffer)
        finish(nil)
    }

    static func response(_ response: HTTPURLResponse, for task: URLSessionDataTask) -> HTTPURLResponse {
        captureAccessToken(from: task.currentRequest)
        guard let url = task.currentRequest?.url else {
            return response
        }
        if url.isCustomize, response.statusCode == 304,
           let cached = SpotifyResponsePatcher.cachedCustomizeData,
           let ok = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "2.0", headerFields: [:]) {
            URLSessionHelper.shared.setReplay(cached, for: task)
            return ok
        }
        if url.isLyrics, UserDefaults.shouldHandleLyricsTraffic {
            // A missing native lyric may still have a valid custom/fallback result.
            // Buffer a zero-byte native response too. Do not synthesize completion here.
            URLSessionHelper.shared.setOrAppend(Data(), for: task)
            if response.statusCode != 200,
               let ok = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "2.0", headerFields: [:]) {
                return ok
            }
        }
        return response
    }

    /// True means forward this chunk unchanged; otherwise it is buffered or consumed.
    static func forwards(_ data: Data, for task: URLSessionDataTask) -> Bool {
        guard let url = task.currentRequest?.url else { return true }
        if SpotifyResponsePatcher.shouldBlock(url) { return false }
        if CasitaResponseProbe.shouldProbe(url) { CasitaResponseProbe.append(data, for: task) }
        if SpotifyResponsePatcher.shouldModify(url) {
            URLSessionHelper.shared.setOrAppend(data, for: task)
            return false
        }
        return true
    }
}
