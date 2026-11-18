import UIKit
import SwiftUI

/// Presents the custom karaoke lyrics view as a full-screen modal, on top
/// of whatever screen is currently shown — the "overlay" approach (Option D)
/// rather than replacing Spotify's native LyricsViewControllerImplementation,
/// since that would need a live-runtime hook point we weren't able to find
/// safely (Spotify's anti-instrumentation protections crash on Frida attach
/// before enumeration/hooking can happen).
final class KaraokeOverlayPresenter {
    private(set) static var isPresented = false
    private static var presentationID: UUID?
    private static weak var displayedController: UIViewController?

    static func present() {
        guard Thread.isMainThread else { DispatchQueue.main.async { present() }; return }
        if isPresented, displayedController == nil || (displayedController?.viewIfLoaded?.window == nil
            && displayedController?.isBeingPresented == false && displayedController?.presentingViewController == nil) {
            isPresented = false; displayedController = nil
        }
        guard !isPresented else { return }
        guard UserDefaults.karaokeOptions.enabled, UserDefaults.shouldReplaceLyrics else {
            writeDebugLog("[Karaoke] present() skipped: custom lyrics view disabled in settings or unsupported by the lyrics source")
            return
        }
        guard #available(iOS 15.0, *) else {
            writeDebugLog("[Karaoke] present() skipped: requires iOS 15+")
            return
        }
        guard let trackId = currentTrackId(),
              let lyrics = KaraokeLyricsStore.shared.lyrics(forTrackId: trackId) else {
            writeDebugLog("[Karaoke] present() called but no karaoke (Syllable) data available for current track")
            return
        }

        onMainThreadSync {
            let id = UUID()
            presentationID = id
            let hosting = KaraokeModal.make(onDismiss: {
                guard presentationID == id else { return }
                isPresented = false
                displayedController = nil
                presentationID = nil
            }) { close in
                KaraokeLyricsView(trackId: trackId, lyrics: lyrics, onDismiss: close)
            }

            displayedController = hosting
            isPresented = true
            if !WindowHelper.shared.present(hosting) {
                isPresented = false
                displayedController = nil
                presentationID = nil
            }
        }
    }

    /// True if karaoke data exists for the current track — callers (e.g.
    /// whatever decides whether to show a "Karaoke" button at all) should
    /// check this rather than always presenting and risking a no-op.
    static func isAvailableForCurrentTrack() -> Bool {
        guard UserDefaults.karaokeOptions.enabled, UserDefaults.shouldReplaceLyrics else { return false }
        guard let trackId = currentTrackId() else { return false }
        return KaraokeLyricsStore.shared.lyrics(forTrackId: trackId) != nil
    }

    static func currentTrackId() -> String? {
        CurrentSpotifyTrack.identifier ?? KaraokePlaybackTracker.shared.playerReportedTrackId()
    }
}
