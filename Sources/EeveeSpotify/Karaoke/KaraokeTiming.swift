import Foundation

enum KaraokeTiming {
    static func adjustedOffset(_ current: Int, step: Int) -> Int {
        min(5000, max(-5000, min(5000, max(-5000, current)) + min(100, max(-100, step))))
    }
    static func progress(position: Int, start: Int, end: Int) -> Double {
        guard end > start else { return position >= start ? 1 : 0 }
        return min(1, max(0, (Double(position) - Double(start)) / (Double(end) - Double(start))))
    }
}
