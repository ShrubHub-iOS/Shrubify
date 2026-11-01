import Foundation

/// Bounded, locked in-memory handoff between lyrics fetching and the custom view.
/// Reads refresh recency; repeated notifications are coalesced on the main queue.
final class KaraokeLyricsStore {
    static let shared = KaraokeLyricsStore()

    private let lock = NSLock()
    private var cache: [String: KaraokeLyricsDto] = [:]
    private var order: [String] = []
    private let capacity = 8
    private var notificationPending = false

    private init() {}

    func set(trackId: String, lyrics: KaraokeLyricsDto) {
        guard !trackId.isEmpty else { return }
        lock.lock()
        cache[trackId] = lyrics
        order.removeAll { $0 == trackId }
        order.append(trackId)
        if order.count > capacity { cache[order.removeFirst()] = nil }
        lock.unlock()
        notify()
    }

    /// Drops a track's entry. Called before every fresh fetch so a result from an
    /// earlier source (or an earlier attempt) can never keep the button alive
    /// for a track whose current fetch found nothing.
    func remove(trackId: String) {
        guard !trackId.isEmpty else { return }
        lock.lock()
        let hadEntry = cache.removeValue(forKey: trackId) != nil
        order.removeAll { $0 == trackId }
        lock.unlock()
        if hadEntry { notify() }
    }

    func lyrics(forTrackId trackId: String) -> KaraokeLyricsDto? {
        lock.lock()
        defer { lock.unlock() }
        guard let lyrics = cache[trackId] else { return nil }
        order.removeAll { $0 == trackId }
        order.append(trackId)
        return lyrics
    }

    func clear() {
        lock.lock()
        cache = [:]
        order = []
        lock.unlock()
        notify()
    }

    func notify() {
        lock.lock()
        guard !notificationPending else { lock.unlock(); return }
        notificationPending = true
        lock.unlock()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.lock.lock()
            self.notificationPending = false
            self.lock.unlock()
            NotificationCenter.default.post(name: .eeveeKaraokeLyricsChanged, object: nil)
        }
    }
}
