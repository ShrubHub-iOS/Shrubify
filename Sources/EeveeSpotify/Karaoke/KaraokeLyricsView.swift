import SwiftUI
import MediaPlayer

@available(iOS 15.0, *)
struct KaraokeLyricsView: View {
    var onDismiss: () -> Void
    @StateObject private var model: KaraokeLyricsViewModel
    @State private var options = UserDefaults.karaokeOptions

    init(trackId: String?, lyrics: KaraokeLyricsDto?, onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
        _model = StateObject(wrappedValue: KaraokeLyricsViewModel(trackId: trackId, lyrics: lyrics))
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            KaraokeBackgroundView().id(model.trackId)
                .allowsHitTesting(false)
                .blur(radius: options.resolvedBlurRadius)
            VStack(spacing: 0) {
                topBar
                    .padding(.top, 8)
                if let lyrics = model.lyrics {
                    content(lyrics: lyrics, layouts: model.layouts)
                        .frame(maxWidth: 900)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .id(model.trackId)
                } else {
                    VStack(spacing: 16) {
                        if model.loading {
                            ProgressView().tint(.white)
                            Text("Finding lyrics…").font(.headline)
                            Text("Trying your sources in order").foregroundColor(.white.opacity(0.86))
                        } else {
                            Image(systemName: "text.quote").font(.largeTitle)
                            Text("Could not load timed lyrics").font(.headline)
                            Button("Try again") { model.retryLyrics() }
                                .buttonStyle(.bordered)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(24)
                }
                KaraokePlaybackControls(playback: model.playback, seek: { model.seek(to: $0) }, toggle: { model.togglePlayback() })
                    .disabled(model.playback.trackID != nil && model.playback.trackID != model.trackId)
            }

        }
        .preferredColorScheme(.dark)
        .onAppear { model.startPlaybackUpdates() }
        .onDisappear { model.stopPlaybackUpdates() }
        .onChange(of: options.timingOffsetMs) { offset in
            var saved = UserDefaults.karaokeOptions
            saved.timingOffsetMs = offset
            UserDefaults.karaokeOptions = saved
            KaraokeLyricsStore.shared.notify()
        }
    }

    private func content(lyrics: KaraokeLyricsDto, layouts: [KaraokeLineLayout]) -> some View {
        let currentMs = model.playback.hasPosition
            ? ShrubifyBetaSupport.lyricPosition(playbackMs: model.playback.positionMs, delayMs: options.timingOffsetMs) : -1
        return KaraokeScrollingLines(
            lyrics: lyrics,
            layouts: layouts,
            options: options,
            timingOffsetMs: $options.timingOffsetMs,
            currentMs: currentMs,
            activeLineIndex: model.playback.hasPosition ? lyrics.activeLineIndex(at: currentMs) : nil,
            seek: { model.seek(to: $0) }
        )
    }

    private var closeButton: some View { KaraokeCloseButton(action: onDismiss) }

    private var topBar: some View {
        let metadata = trackMetadata
        return HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Custom lyrics")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.86))
                Text(metadata?.title ?? "Shrubify Lyrics")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                Text(subtitle(artist: metadata?.artist))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.86))
                    .lineLimit(1)
            }
            Spacer(minLength: 12)
            closeButton
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
    }

    private var trackMetadata: (title: String, artist: String)? {
        guard let id = model.trackId else { return nil }
        if let info = CurrentSpotifyTrack.snapshot, info.identifier == id {
            return (info.title, info.artist)
        }
        guard KaraokePlaybackTracker.shared.playerReportedTrackId() == id,
              let info = MPNowPlayingInfoCenter.default().nowPlayingInfo,
              let title = info[MPMediaItemPropertyTitle] as? String,
              let artist = info[MPMediaItemPropertyArtist] as? String else { return nil }
        return (title, artist)
    }
    private func subtitle(artist: String?) -> String {
        let provider = model.lyrics?.providerName ?? "Lyrics"
        let mode = model.lyrics?.timingLabel
        let source = provider + (mode.map { " • " + $0 } ?? "")
        return artist.flatMap { $0.isEmpty ? nil : $0 + " • " + source } ?? source
    }

}

@available(iOS 15.0, *)
private struct KaraokeScrollingLines: View {
    let lyrics: KaraokeLyricsDto
    let layouts: [KaraokeLineLayout]
    let options: KaraokeOptions
    @Binding var timingOffsetMs: Int
    let currentMs: Int
    let activeLineIndex: Int?
    let seek: (Int) -> Bool

    @State private var seekUnavailable = false
    var body: some View {
        let alignment = options.textAlignment.horizontalAlignment
        let flip: CGFloat = options.reversedDirection ? -1 : 1

        KaraokeReadingPane(offset: $timingOffsetMs, activeLine: activeLineIndex, reversed: options.reversedDirection) { proxy in
            LazyVStack(alignment: alignment, spacing: CGFloat(options.resolvedLineSpacing)) {
                Spacer().frame(height: 24)

                ForEach(0..<min(layouts.count, lyrics.lines.count), id: \.self) { index in
                    Button {
                        guard lyrics.lines.indices.contains(index) else { return }
                        let succeeded = seek(ShrubifyBetaSupport.seekPosition(lineMs: lyrics.lines[index].startMs, delayMs: options.timingOffsetMs))
                        seekUnavailable = !succeeded
                        if succeeded { proxy.scrollTo(index, anchor: .center) }
                    } label: {
                        KaraokeLineView(
                            layout: layouts[index],
                            currentMs: currentMs,
                            isActiveLine: index == activeLineIndex,
                            alignment: alignment,
                            fontSize: CGFloat(options.resolvedFontSize)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(lyrics.lines[index].plainText)
                    .accessibilityHint("Jump to this lyric")
                    .id(index)
                    .scaleEffect(x: 1, y: flip)
                }

                KaraokeCreditsFooterView(lyrics: lyrics)
                    .scaleEffect(x: 1, y: flip)

                Spacer().frame(height: 200)
            }
            .frame(maxWidth: .infinity)
        }
        .environment(\.layoutDirection, lyrics.isRTL ? .rightToLeft : .leftToRight)
        .alert(isPresented: $seekUnavailable) {
            Alert(title: Text("Seeking unavailable"), message: Text("This Spotify build does not expose a supported playback seek method."), dismissButton: .default(Text("OK")))
        }
    }
}
