import Foundation

/// An injected monotonic clock makes suspension, replacement and expiry testable.
struct SleepTimerCountdown {
    static let presetMinutes = [1, 5, 10, 15, 30, 45, 60, 90]
    private(set) var deadline: TimeInterval?

    mutating func start(minutes: Int, now: TimeInterval) {
        guard Self.presetMinutes.contains(minutes), now.isFinite else { return }
        deadline = now + Double(minutes * 60)
    }

    mutating func cancel() { deadline = nil }

    func remaining(at now: TimeInterval) -> TimeInterval? {
        guard let deadline else { return nil }
        return max(0, deadline - now)
    }

    /// Consume once; a delayed callback must never pause a later listening session.
    mutating func consumeExpiry(at now: TimeInterval) -> Bool {
        guard let deadline, now >= deadline else { return false }
        self.deadline = nil
        return true
    }
}
