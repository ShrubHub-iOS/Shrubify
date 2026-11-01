import SwiftUI

@available(iOS 15.0, *)
struct KaraokePlaybackControls: View {
    let playback: KaraokePlaybackSnapshot
    let seek: (Int) -> Bool
    let toggle: () -> Bool
    @State private var scrubbing = false
    @State private var scrubSeconds: Double = 0
    @State private var unavailable = false

    private var duration: Double { Double(playback.durationMs) / 1000 }
    private var position: Double {
        let value = max(0, scrubbing ? scrubSeconds : Double(playback.positionMs) / 1000)
        return duration > 0 ? min(value, duration) : value
    }

    var body: some View {
        VStack(spacing: 6) {
            Slider(value: Binding(get: { min(position, max(1, duration)) }, set: { scrubSeconds = $0 }), in: 0...max(1, duration), onEditingChanged: { editing in
                if editing {
                    scrubSeconds = Double(playback.positionMs) / 1000
                    scrubbing = true
                } else {
                    scrubbing = false
                    unavailable = !seek(Int(min(Double(Int.max / 2), max(0, scrubSeconds) * 1000)))
                }
            })
            .disabled(playback.durationMs <= 0)
            .accessibilityLabel("Song position")
            HStack {
                Text(time(position))
                Spacer()
                Button {
                    unavailable = !toggle()
                } label: {
                    Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .frame(minWidth: 48, minHeight: 48)
                }
                .accessibilityLabel(playback.isPlaying ? "Pause" : "Play")
                Spacer()
                Text(playback.durationMs > 0 ? "−" + time(max(0, duration - position)) : "–:–")
            }
            .font(.system(.caption, design: .monospaced))
        }
        .foregroundColor(.white)
        .accentColor(.white)
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Color.black.opacity(0.35))
        .alert(isPresented: $unavailable) {
            Alert(title: Text("Playback control unavailable"), message: Text("Spotify did not accept this command. Try its main player controls."), dismissButton: .default(Text("OK")))
        }
    }

    private func time(_ seconds: Double) -> String {
        let value = Int(max(0, seconds))
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}
