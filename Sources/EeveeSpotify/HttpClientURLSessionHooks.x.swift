import Foundation
import Orion

// Every task has one response, one body and one terminal callback. Custom lyrics
// are loaded after the underlying task completes, without blocking its delegate.
class HttpClientURLSessionHook: ClassHook<NSObject>, SpotifySessionDelegate {
    typealias Group = ResponseTransportGroup
    static let targetName = "Connectivity_HttpClientKit.HttpClientURLSession"

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
