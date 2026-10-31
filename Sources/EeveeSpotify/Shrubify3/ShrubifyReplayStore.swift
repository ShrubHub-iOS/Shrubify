import Foundation
import Combine
import MediaPlayer
import UIKit

/// Local-only, opt-in listening history. No Spotify API, account token, or network traffic.
/// Samples MediaPlayer once every ten seconds while this app is active. It is NOT a
/// lifetime Spotify history, and elapsed time is an estimate, not a billing metric.
struct ShrubifyTrackRecord: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var artist: String
    var seconds: Double
    var plays: Int
    var lastPlayed: Date
    var spotifyURI: String?
}

struct ShrubifySession: Codable, Identifiable {
    let id: UUID
    let savedAt: Date
    let title: String
    let tracks: [ShrubifyTrackRecord]
}

private struct ShrubifyReplayArchive: Codable {
    var tracks: [ShrubifyTrackRecord] = []
    var dailySeconds: [String: Double] = [:]
    var sessions: [ShrubifySession] = []
}

struct ShrubifyArtistTotal: Identifiable {
    let name: String
    let seconds: Double
    var id: String { name }
}

struct ShrubifyDailyTotal: Identifiable {
    let day: String
    let seconds: Double
    var id: String { day }
}

final class ShrubifyReplayStore: ObservableObject {
    static let shared = ShrubifyReplayStore()
    private static let storageKey = "ShrubifyReplayArchive3"
    private static let enabledKey = "ShrubifyReplayEnabled3"
    private static let maxTracks = 350

    @Published private(set) var tracks: [ShrubifyTrackRecord] = []
    @Published private(set) var sessions: [ShrubifySession] = []
    @Published private(set) var todaySeconds: Double = 0
    @Published private(set) var totalSeconds: Double = 0
    @Published private(set) var enabled: Bool = false

    private var archive = ShrubifyReplayArchive()
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var previousStamp: TimeInterval?
    private var previousKey: String?
    private var countedCurrentPlay = false
    private var currentPlaySeconds: Double = 0
    private var lastSave: TimeInterval = 0
    private var isActive = true

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode(ShrubifyReplayArchive.self, from: data) {
            archive = saved
        }
        enabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        publish()
    }

    func start() {
        if !Thread.isMainThread { DispatchQueue.main.async { self.start() }; return }
        // No timer or notification observers until tracking is explicitly enabled.
        guard enabled, timer == nil else { return }
        isActive = UIApplication.shared.applicationState == .active
        observers.append(NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.isActive = false
            self?.previousStamp = nil
            self?.persist()
        })
        observers.append(NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.isActive = true
            self?.previousStamp = nil
        })
        observers.append(NotificationCenter.default.addObserver(forName: UIApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in self?.persist() })
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in self?.sample() }
        timer?.tolerance = 2
        sample()
    }

    func setEnabled(_ value: Bool) {
        assert(Thread.isMainThread)
        enabled = value
        if value {
            start()
        } else {
            timer?.invalidate()
            timer = nil
            for observer in observers { NotificationCenter.default.removeObserver(observer) }
            observers.removeAll()
        }
        UserDefaults.standard.set(value, forKey: Self.enabledKey)
        previousStamp = nil
        previousKey = nil
        currentPlaySeconds = 0
        countedCurrentPlay = false
        persist()
    }

    func sample() {
        guard Thread.isMainThread, isActive, enabled else { previousStamp = nil; return }
        let now = ProcessInfo.processInfo.systemUptime
        let priorStamp = previousStamp
        previousStamp = nil
        guard let info = MPNowPlayingInfoCenter.default().nowPlayingInfo,
              let title = info[MPMediaItemPropertyTitle] as? String, !title.isEmpty,
              let artist = info[MPMediaItemPropertyArtist] as? String, !artist.isEmpty else {
            previousKey = nil
            return
        }
        let rate = (info[MPNowPlayingInfoPropertyPlaybackRate] as? NSNumber)?.doubleValue
            ?? (KaraokePlaybackTracker.shared.isPlaying() ? 1 : 0)
        guard rate > 0 else { previousStamp = nil; return }
        let key = artist.lowercased() + "\u{001F}" + title.lowercased()
        let changed = previousKey != key
        if changed {
            previousKey = key
            currentPlaySeconds = 0
            countedCurrentPlay = false
            previousStamp = nil
        }
        // Never backfill missing time or count time spent in background.
        let seconds = changed ? 0 : min(12, max(0, now - (priorStamp ?? now)))
        previousStamp = now
        guard seconds > 0 else { return }
        currentPlaySeconds += seconds
        let date = Date()
        let idx = archive.tracks.firstIndex { $0.id == key }
        let uri: String? = {
            guard let id = KaraokePlaybackTracker.shared.playerReportedTrackId(), !id.isEmpty else { return nil }
            return "spotify:track:" + id
        }()
        if let idx = idx {
            archive.tracks[idx].seconds += seconds
            archive.tracks[idx].lastPlayed = date
            if uri != nil { archive.tracks[idx].spotifyURI = uri }
        } else {
            archive.tracks.append(ShrubifyTrackRecord(id: key, title: title, artist: artist, seconds: seconds, plays: 0, lastPlayed: date, spotifyURI: uri))
        }
        if currentPlaySeconds >= 25 && !countedCurrentPlay {
            countedCurrentPlay = true
            if let idx = archive.tracks.firstIndex(where: { $0.id == key }) { archive.tracks[idx].plays += 1 }
        }
        archive.dailySeconds[Self.dayKey(date), default: 0] += seconds
        // Bounded data, bounded encoding cost. No disk writes on every sample.
        if archive.tracks.count > Self.maxTracks {
            archive.tracks.sort { $0.lastPlayed > $1.lastPlayed }
            archive.tracks = Array(archive.tracks.prefix(Self.maxTracks))
        }
        if archive.dailySeconds.count > 400 {
            let recent = archive.dailySeconds.keys.sorted().suffix(400)
            archive.dailySeconds = archive.dailySeconds.filter { recent.contains($0.key) }
        }
        publish()
        if now - lastSave >= 40 { persist() }
    }

    func topArtists(limit: Int = 10) -> [ShrubifyArtistTotal] {
        var sums: [String: Double] = [:]
        for track in tracks { sums[track.artist, default: 0] += track.seconds }
        return Array(sums.map { ShrubifyArtistTotal(name: $0.key, seconds: $0.value) }
            .sorted { $0.seconds > $1.seconds }.prefix(limit))
    }

    func recentDays() -> [ShrubifyDailyTotal] {
        (0..<7).reversed().compactMap { offset -> ShrubifyDailyTotal? in
            guard let day = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            let key = Self.dayKey(day)
            return ShrubifyDailyTotal(day: key, seconds: archive.dailySeconds[key] ?? 0)
        }
    }

    func recentTracks(limit: Int = 15) -> [ShrubifyTrackRecord] {
        Array(tracks.sorted { $0.lastPlayed > $1.lastPlayed }.prefix(limit))
    }

    func bookmarkCurrent() -> Bool {
        guard let info = MPNowPlayingInfoCenter.default().nowPlayingInfo,
              let title = info[MPMediaItemPropertyTitle] as? String,
              let artist = info[MPMediaItemPropertyArtist] as? String,
              !title.isEmpty, !artist.isEmpty else { return false }
        let key = artist.lowercased() + "\u{001F}" + title.lowercased()
        var entry = archive.tracks.first(where: { $0.id == key }) ?? ShrubifyTrackRecord(id: key, title: title, artist: artist, seconds: 0, plays: 0, lastPlayed: Date(), spotifyURI: nil)
        if let id = KaraokePlaybackTracker.shared.playerReportedTrackId(), !id.isEmpty { entry.spotifyURI = "spotify:track:" + id }
        if !archive.tracks.contains(where: { $0.id == key }) { archive.tracks.append(entry) }
        let snapshot = ShrubifySession(id: UUID(), savedAt: Date(), title: "Saved track · \(title)", tracks: [entry])
        archive.sessions.insert(snapshot, at: 0)
        archive.sessions = Array(archive.sessions.prefix(30))
        persist()
        return true
    }

    func saveRecentSession() -> Bool {
        let entries = recentTracks(limit: 20)
        guard !entries.isEmpty else { return false }
        archive.sessions.insert(ShrubifySession(id: UUID(), savedAt: Date(), title: "Listening snapshot", tracks: entries), at: 0)
        archive.sessions = Array(archive.sessions.prefix(30))
        persist()
        return true
    }

    func removeSession(_ id: UUID) {
        archive.sessions.removeAll { $0.id == id }
        persist()
    }

    func clear() {
        archive = ShrubifyReplayArchive()
        previousKey = nil
        previousStamp = nil
        currentPlaySeconds = 0
        countedCurrentPlay = false
        persist()
    }

    private func persist() {
        lastSave = ProcessInfo.processInfo.systemUptime
        if let data = try? JSONEncoder().encode(archive) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
        publish()
    }

    private func publish() {
        tracks = archive.tracks
        sessions = archive.sessions
        todaySeconds = archive.dailySeconds[Self.dayKey(Date())] ?? 0
        totalSeconds = archive.dailySeconds.values.reduce(0, +)
    }

    private static func dayKey(_ date: Date) -> String {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }
}
