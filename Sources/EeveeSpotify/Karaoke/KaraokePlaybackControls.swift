import SwiftUI

@available(iOS 15.0, *)
struct KaraokePlaybackControls: View {
    let playback: KaraokePlaybackSnapshot
    let seek: (Int) -> Bool
    let toggle: () -> Bool
    @State private var scrubbing = false
    @State private var scrubSeconds: Double?
    @State private var unavailable = false

    private var duration: Double { Double(playback.durationMs) / 1000 }
    private var position: Double {
        let value = max(0, scrubSeconds ?? Double(playback.positionMs) / 1000)
        return duration > 0 ? min(value, duration) : value
    }

    var body: some View {
        VStack(spacing: 6) {
            Slider(
                value: Binding(get: { min(position, max(0.001, duration)) }, set: { value in
                    if scrubbing { scrubSeconds = value }
                    else { commitSeek(to: value) }
                }),
                in: 0...max(0.001, duration),
                onEditingChanged: { editing in
                    scrubbing = editing
                    if !editing, let value = scrubSeconds {
                        scrubSeconds = nil
                        commitSeek(to: value)
                    }
                }
            )
            .disabled(playback.durationMs <= 0)
            .accessibilityLabel("Song position")
            HStack {
                Text(playback.hasPosition ? time(position) : "–:–")
                Spacer()
                Button {
                    unavailable = !toggle()
                } label: {
                    Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .frame(minWidth: 48, minHeight: 48)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(playback.isPlaying ? "Pause" : "Play")
                .disabled(!playback.isPlaybackStateKnown)
                Spacer()
                Text(playback.durationMs > 0 ? "−" + time(max(0, duration - position)) : "–:–")
            }
            .font(.system(.caption, design: .monospaced))
        }
        .onChange(of: playback.trackID) { _ in
            scrubSeconds = nil
        }
        .foregroundColor(.white)
        .accentColor(.white)
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(KaraokePlaybackSurface())
        .frame(maxWidth: 600)
        .padding(.horizontal, 24).padding(.bottom, 12)
        .alert(isPresented: $unavailable) {
            Alert(title: Text("Playback control unavailable"), message: Text("Spotify did not accept this command. Try its main player controls."), dismissButton: .default(Text("OK")))
        }
    }

    private func commitSeek(to seconds: Double) {
        guard duration > 0 else { return }
        let target = min(duration, max(0, seconds)) * 1000
        unavailable = !seek(Int(min(Double(Int.max / 2), target.rounded())))
    }

    private func time(_ seconds: Double) -> String {
        let value = Int(max(0, seconds))
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}
