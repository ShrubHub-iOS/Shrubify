import SwiftUI
import MediaPlayer

@available(iOS 15.0, *)
struct KaraokeLyricsView: View {
    var onDismiss: () -> Void
    @StateObject private var model: KaraokeLyricsViewModel
    private let options = UserDefaults.karaokeOptions

    init(trackId: String?, lyrics: KaraokeLyricsDto, onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
        _model = StateObject(wrappedValue: KaraokeLyricsViewModel(trackId: trackId, lyrics: lyrics, onNoLyrics: onDismiss))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                if KaraokeGlass.isEnabled {
                    KaraokeGlassBackground().ignoresSafeArea()
                } else {
                    KaraokeBackgroundView().id(model.trackId)
                }
                VStack(spacing: 0) {
                    topBar
                    if let lyrics = model.lyrics {
                        content(lyrics: lyrics, layouts: model.layouts, screenWidth: geo.size.width)
                            .id(model.trackId)
                    } else {
                        VStack(spacing: 16) {
                            if model.loading {
                                ProgressView().tint(.white)
                                Text("Finding lyrics…").font(.headline)
                                Text("Trying your sources in order").foregroundColor(.secondary)
                            } else {
                                Image(systemName: "text.quote").font(.largeTitle)
                                Text("Timed lyrics unavailable").font(.headline)
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
        }
        .preferredColorScheme(.dark)
        .onAppear { model.startPlaybackUpdates() }
        .onDisappear { model.stopPlaybackUpdates() }
    }

    private func content(lyrics: KaraokeLyricsDto, layouts: [KaraokeLineLayout], screenWidth: CGFloat) -> some View {
        let currentMs = ShrubifyBetaSupport.lyricPosition(playbackMs: model.playback.positionMs, delayMs: options.timingOffsetMs)
        return KaraokeScrollingLines(
            lyrics: lyrics,
            layouts: layouts,
            options: options,
            currentMs: currentMs,
            activeLineIndex: activeLineIndex(in: lyrics, at: currentMs),
            screenWidth: screenWidth,
            seek: { model.seek(to: $0) }
        )
    }

    private func activeLineIndex(in lyrics: KaraokeLyricsDto, at currentMs: Int) -> Int? {
        guard !lyrics.lines.isEmpty else { return nil }
        var low = 0
        var high = lyrics.lines.count
        while low < high {
            let middle = low + (high - low) / 2
            if lyrics.lines[middle].startMs <= currentMs {
                low = middle + 1
            } else {
                high = middle
            }
        }
        return low > 0 ? low - 1 : nil
    }

    @ViewBuilder private var closeButtonBackground: some View {
        if KaraokeGlass.isEnabled {
            KaraokeGlassCapsule()
        } else {
            Circle().fill(Color.white.opacity(0.12))
        }
    }

    private var closeButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "chevron.down")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
                .padding(14)
                .background(closeButtonBackground)
        }
    }

    private var topBar: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Custom lyrics")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.72))
                Text(modelTitle)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                Text(modelSubtitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.72))
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
        if let saved = LyricsTrackMetadata.get(trackId: id) { return saved }
        guard KaraokePlaybackTracker.shared.playerReportedTrackId() == id,
              let info = MPNowPlayingInfoCenter.default().nowPlayingInfo,
              let title = info[MPMediaItemPropertyTitle] as? String,
              let artist = info[MPMediaItemPropertyArtist] as? String else { return nil }
        return (title, artist)
    }
    private var modelTitle: String { trackMetadata?.title ?? "Shrubify Lyrics" }
    private var modelSubtitle: String {
        let provider = model.lyrics?.providerName ?? "Lyrics"
        return trackMetadata.map { $0.artist + " • " + provider } ?? provider
    }

}

@available(iOS 15.0, *)
private struct KaraokeScrollingLines: View {
    let lyrics: KaraokeLyricsDto
    let layouts: [KaraokeLineLayout]
    let options: KaraokeOptions
    let currentMs: Int
    let activeLineIndex: Int?
    let screenWidth: CGFloat
    let seek: (Int) -> Bool

    @State private var seekUnavailable = false
    @State private var followLyrics = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let horizontalPadding: CGFloat = 24

    var body: some View {
        let alignment = options.textAlignment.horizontalAlignment
        let flip: CGFloat = options.reversedDirection ? -1 : 1

        ScrollViewReader { proxy in
            VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { followLyrics.toggle(); if followLyrics, let activeLineIndex { proxy.scrollTo(activeLineIndex, anchor: .center) } } label: {
                    Label(followLyrics ? "Following lyrics" : "Follow lyrics", systemImage: followLyrics ? "location.fill" : "location")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                }
                .accessibilityHint("Turn off to read lyrics without automatic scrolling")
            }
            .padding(.horizontal, 16)
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: alignment, spacing: 16) {
                    Spacer().frame(height: 24)

                    ForEach(0..<min(layouts.count, lyrics.lines.count), id: \.self) { index in
                        KaraokeLineView(
                            layout: layouts[index],
                            currentMs: currentMs,
                            isActiveLine: index == activeLineIndex,
                            availableWidth: max(0, screenWidth - horizontalPadding * 2),
                            alignment: alignment
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard lyrics.lines.indices.contains(index) else { return }
                            let succeeded = seek(ShrubifyBetaSupport.seekPosition(lineMs: lyrics.lines[index].startMs, delayMs: options.timingOffsetMs))
                            seekUnavailable = !succeeded
                            if succeeded { proxy.scrollTo(index, anchor: .center) }
                        }
                        .accessibilityLabel(lyrics.lines[index].plainText)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityHint("Jump to this lyric")
                        .id(index)
                        .padding(.horizontal, horizontalPadding)
                        .scaleEffect(x: 1, y: flip)
                    }

                    KaraokeCreditsFooterView(lyrics: lyrics)
                        .scaleEffect(x: 1, y: flip)

                    Spacer().frame(height: 200)
                }
                .frame(maxWidth: .infinity)
            }
            .onAppear {
                guard let activeLineIndex = activeLineIndex, activeLineIndex < lyrics.lines.count else { return }
                proxy.scrollTo(activeLineIndex, anchor: .center)
            }
            .onChange(of: activeLineIndex) { newIndex in
                guard followLyrics, let newIndex = newIndex, newIndex < lyrics.lines.count else { return }
                // Single-curve stand-in for SpicyLyrics' overshoot scroll.
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.38)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
            // Flip the list and counter-flip rows; y-only so leading/trailing alignment isn't mirrored.
            .scaleEffect(x: 1, y: flip)
            }
        }
        .environment(\.layoutDirection, lyrics.isRTL ? .rightToLeft : .leftToRight)
        .alert(isPresented: $seekUnavailable) {
            Alert(title: Text("Seeking unavailable"), message: Text("This Spotify build does not expose a supported playback seek method."), dismissButton: .default(Text("OK")))
        }
    }
}
