// SPDX-License-Identifier: GPL-3.0-only
// Adapted from zbzxbg/EeveeSpotifyEvolved, Playback/SleepTimer.swift (GPL-3.0),
// revision 92d783486d527c20ccffb759de523d6c7b956547. See docs/EVOLVED-INTEGRATION.md.
import Foundation
import Combine
import UIKit
import EeveeSpotifyC

/// Main-queue ownership keeps cancellation, expiry and playback commands serialized.
/// GCD does not grant background execution: expiry is handled when iOS schedules us.
final class ShrubifySleepTimer: ObservableObject {
    static let shared = ShrubifySleepTimer()
    @Published private(set) var remaining: TimeInterval?
    @Published private(set) var message: String?
    @Published private(set) var duration: TimeInterval = 0
    private var countdown = SleepTimerCountdown()
    private var source: DispatchSourceTimer?
    private var generation: UInt64 = 0
    private var foregroundObserver: NSObjectProtocol?

    private init() {
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.tick() }
    }

    func start(minutes: Int) {
        assert(Thread.isMainThread)
        guard SleepTimerCountdown.presetMinutes.contains(minutes) else { return }
        stopSource()
        countdown.start(minutes: minutes, now: ProcessInfo.processInfo.systemUptime)
        duration = Double(minutes * 60)
        remaining = duration
        message = nil
        let token = generation
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 1, repeating: 1, leeway: .milliseconds(200))
        timer.setEventHandler { [weak self] in
            guard let self, token == self.generation else { return }
            self.tick()
        }
        source = timer
        timer.resume()
        writeDebugLog("[SleepTimer] started: \(minutes) minutes")
    }

    func cancel() {
        assert(Thread.isMainThread)
        stopSource()
        countdown.cancel()
        remaining = nil
        message = "Timer canceled."
    }

    private func stopSource() {
        generation &+= 1
        source?.cancel()
        source = nil
    }

    private func tick() {
        assert(Thread.isMainThread)
        let now = ProcessInfo.processInfo.systemUptime
        if countdown.consumeExpiry(at: now) {
            stopSource()
            remaining = nil
            let token = generation
            let track = statefulPlayer?.currentTrack()?.trackIdentifier
            confirmPause(token: token, trackID: track, until: now + 5)

        } else {
            remaining = countdown.remaining(at: now)
        }
    }

    private func confirmPause(token: UInt64, trackID: String?, until deadline: TimeInterval) {
        guard token == generation else { return }
        if let trackID, let current = statefulPlayer?.currentTrack()?.trackIdentifier, current != trackID {
            message = "Timer ended. Track changed before pause could be confirmed."
            return
        }
        if let player = statefulPlayer,
           let facts = ShrubReadLivePlayback(player), (facts["paused"] as? NSNumber)?.boolValue == true {
            message = "Timer ended. Playback paused."
            return
        }
        guard ProcessInfo.processInfo.systemUptime < deadline else {
            message = "Timer ended, but playback could not be confirmed paused in this Spotify build."
            return
        }
        KaraokeSeek.player = statefulPlayer as AnyObject?
        let supported = KaraokeSeek.setPaused(true)
        message = supported ? "Timer ended. Confirming pause…" : "Timer ended. Waiting for playback controls…"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.confirmPause(token: token, trackID: trackID, until: deadline)
        }
    }

}
