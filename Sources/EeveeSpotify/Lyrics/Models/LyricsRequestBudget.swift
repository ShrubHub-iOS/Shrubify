import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Synchronous providers share one monotonic budget on their worker thread.
/// Never leave a URLSession request running after the caller stops waiting.
final class LyricsCancellationToken: NSObject {
    private let lock = NSLock()
    private var cancelled = false
    private let parent: LyricsCancellationToken?
    init(parent: LyricsCancellationToken? = nil) { self.parent = parent; super.init() }
    func cancel() { lock.lock(); cancelled = true; lock.unlock() }
    var isCancelled: Bool {
        lock.lock(); let own = cancelled; lock.unlock()
        return own || parent?.isCancelled == true
    }
}

enum LyricsRequestBudget {
    private static let key = "com.shrubify.lyrics.deadline"

    static var deadline: TimeInterval? {
        (Thread.current.threadDictionary[key] as? NSNumber)?.doubleValue
    }

    static var cancellation: LyricsCancellationToken? {
        Thread.current.threadDictionary[key + ".cancellation"] as? LyricsCancellationToken
    }

    static func withLimit<T>(seconds: TimeInterval, cancellation token: LyricsCancellationToken? = nil,
                             operation: () throws -> T) rethrows -> T {
        let oldToken = cancellation
        if let token { Thread.current.threadDictionary[key + ".cancellation"] = token }
        let previous = Thread.current.threadDictionary[key]
        let proposed = ProcessInfo.processInfo.systemUptime + max(0, seconds)
        Thread.current.threadDictionary[key] = NSNumber(value: min(deadline ?? proposed, proposed))
        defer {
            if let oldToken { Thread.current.threadDictionary[key + ".cancellation"] = oldToken }
            else { Thread.current.threadDictionary.removeObject(forKey: key + ".cancellation") }
            if let previous { Thread.current.threadDictionary[key] = previous }
            else { Thread.current.threadDictionary.removeObject(forKey: key) }
        }
        return try operation()
    }

    static func remaining(maximum: TimeInterval) -> TimeInterval {
        cancellation?.isCancelled == true ? 0 : max(0, min(maximum, deadline.map { $0 - ProcessInfo.processInfo.systemUptime } ?? maximum))
    }

    static func check() throws {
        if remaining(maximum: 1) <= 0 { throw URLError(.timedOut) }
    }

    static func wait(_ semaphore: DispatchSemaphore, task: URLSessionTask, maximum: TimeInterval = 15) -> Bool {
        guard waitSignal(semaphore, maximum: maximum) else { task.cancel(); return false }
        return true
    }

    static func waitSignal(_ semaphore: DispatchSemaphore, maximum: TimeInterval) -> Bool {
        let until = ProcessInfo.processInfo.systemUptime + remaining(maximum: maximum)
        while remaining(maximum: until - ProcessInfo.processInfo.systemUptime) > 0 {
            let slice = min(0.1, remaining(maximum: until - ProcessInfo.processInfo.systemUptime))
            if semaphore.wait(timeout: .now() + slice) == .success { return cancellation?.isCancelled != true }
        }
        return false
    }

    static func sleep(_ seconds: TimeInterval) throws {
        guard remaining(maximum: seconds) >= seconds else { throw URLError(.timedOut) }
        let until = ProcessInfo.processInfo.systemUptime + seconds
        while ProcessInfo.processInfo.systemUptime < until {
            try check()
            Thread.sleep(forTimeInterval: min(0.05, max(0, until - ProcessInfo.processInfo.systemUptime)))
        }
        try check()
    }
}
