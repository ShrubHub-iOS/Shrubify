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
    typealias Group = ResponseTransportGroup
    static let targetName = "SPTDataLoaderService"

    func URLSession(_ session: URLSession, task: URLSessionDataTask, didCompleteWithError error: Error?) {
        SpotifySessionTransport.complete(session, task: task, error: error, deliver: { [self] data in
            orig.URLSession(session, dataTask: task, didReceiveData: data)
        }, finish: { [self] error in
            orig.URLSession(session, task: task, didCompleteWithError: error)
        })
    }

    func URLSession(_ session: URLSession, dataTask task: URLSessionDataTask,
                    didReceiveResponse response: HTTPURLResponse,
                    completionHandler handler: @escaping (URLSession.ResponseDisposition) -> Void) {
        orig.URLSession(session, dataTask: task, didReceiveResponse: SpotifySessionTransport.response(response, for: task), completionHandler: handler)
    }

    func URLSession(_ session: URLSession, dataTask task: URLSessionDataTask, didReceiveData data: Data) {
        if SpotifySessionTransport.forwards(data, for: task) {
            orig.URLSession(session, dataTask: task, didReceiveData: data)
        }
    }
}
