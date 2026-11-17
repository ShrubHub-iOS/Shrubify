import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Synchronous providers share one monotonic budget on their worker thread.
/// Never leave a URLSession request running after the caller stops waiting.
enum LyricsRequestBudget {
    private static let key = "com.shrubify.lyrics.deadline"

    static var deadline: TimeInterval? {
        (Thread.current.threadDictionary[key] as? NSNumber)?.doubleValue
    }

    static func withLimit<T>(seconds: TimeInterval, operation: () throws -> T) rethrows -> T {
        let previous = Thread.current.threadDictionary[key]
        let proposed = ProcessInfo.processInfo.systemUptime + max(0, seconds)
        Thread.current.threadDictionary[key] = NSNumber(value: min(deadline ?? proposed, proposed))
        defer {
            if let previous { Thread.current.threadDictionary[key] = previous }
            else { Thread.current.threadDictionary.removeObject(forKey: key) }
        }
        return try operation()
    }

    static func remaining(maximum: TimeInterval) -> TimeInterval {
        max(0, min(maximum, deadline.map { $0 - ProcessInfo.processInfo.systemUptime } ?? maximum))
    }

    static func check() throws {
        if remaining(maximum: 1) <= 0 { throw URLError(.timedOut) }
    }

    static func wait(_ semaphore: DispatchSemaphore, task: URLSessionTask, maximum: TimeInterval = 15) -> Bool {
        let duration = remaining(maximum: maximum)
        guard duration > 0, semaphore.wait(timeout: .now() + duration) == .success else {
            task.cancel()
            return false
        }
        return true
    }

    static func sleep(_ seconds: TimeInterval) throws {
        guard remaining(maximum: seconds) >= seconds else { throw URLError(.timedOut) }
        Thread.sleep(forTimeInterval: seconds)
        try check()
    }
}
