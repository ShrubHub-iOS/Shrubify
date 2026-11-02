import Foundation

/// Replay is sampled/estimated. Count a wrap only when the prior position was
/// close enough to the end to finish naturally during this sampling interval.
enum ReplayPlaybackBoundary {
    static func didRepeat(previous: Double?, current: Double, duration: Double, elapsed: Double, rate: Double) -> Bool {
        guard let previous, previous.isFinite, current.isFinite, duration.isFinite,
              elapsed.isFinite, rate.isFinite, duration > 0, elapsed > 0, elapsed <= 12,
              rate > 0, previous > current + 5 else { return false }
        let advance = elapsed * rate
        let expected = previous + advance - duration
        return previous <= duration + 1 && expected >= -1
            && current <= advance + 1 && abs(current - max(0, expected)) <= 2
    }
}
