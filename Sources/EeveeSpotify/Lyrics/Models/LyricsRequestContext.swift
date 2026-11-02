import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Owns the active network task for one provider chain. Superseded requests and
/// the overall deadline cancel real URLSession tasks, freeing the worker promptly.
final class LyricsRequestContext {
    private static let threadKey = "com.shrubify.lyrics.context"
    private let lock = NSLock()
    private var cancelled = false
    private var task: URLSessionTask?

    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
    func cancel() {
        lock.lock(); cancelled = true; let current = task; task = nil; lock.unlock()
        current?.cancel()
    }
    func run<T>(_ body: () -> T) -> T {
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 20) { [weak self] in self?.cancel() }
        Thread.current.threadDictionary[Self.threadKey] = self
        defer { Thread.current.threadDictionary.removeObject(forKey: Self.threadKey) }
        return body()
    }
    static func resume(_ task: URLSessionTask) {
        guard let context = Thread.current.threadDictionary[threadKey] as? LyricsRequestContext else { task.resume(); return }
        context.lock.lock()
        let cancelled = context.cancelled
        context.task = task
        context.lock.unlock()
        if cancelled { task.cancel() }
        task.resume()
    }
}
