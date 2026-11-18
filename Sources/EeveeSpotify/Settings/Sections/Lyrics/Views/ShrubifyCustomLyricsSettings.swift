import SwiftUI

struct KaraokeLaunchButton: View {
    @State private var loading = false
    @State private var unavailable = false
    @State private var visible = false
    @State private var generation = UUID()
    var body: some View {
        Button {
            guard let track = KaraokeOverlayPresenter.currentTrackId() else { unavailable = true; return }
            if KaraokeOverlayPresenter.isAvailableForCurrentTrack() { KaraokeOverlayPresenter.present(); return }
            loading = true
            let requestGeneration = generation
            loadLyricsDataAsync("/color-lyrics/v2/track/" + track, force: true) { _ in
                guard visible, generation == requestGeneration else { return }
                loading = false
                guard KaraokeOverlayPresenter.currentTrackId() == track,
                      KaraokeOverlayPresenter.isAvailableForCurrentTrack() else { unavailable = true; return }
                KaraokeOverlayPresenter.present()
            }
        } label: {
            Label(loading ? "Finding lyrics…" : "Open custom lyrics", systemImage: "text.quote")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .frame(minHeight: 32)
        }
        .buttonStyle(.borderedProminent)
        .tint(.white)
        .foregroundColor(.black)
        .disabled(loading || !UserDefaults.karaokeOptions.enabled || !UserDefaults.shouldReplaceLyrics)
        .onAppear { visible = true; generation = UUID() }
        .onDisappear { visible = false; generation = UUID(); loading = false }
        .alert(isPresented: $unavailable) {
            Alert(title: Text("Timed lyrics unavailable"), message: Text("Play a song and select a timed lyrics source, then try again."), dismissButton: .default(Text("OK")))
        }
    }
}

struct ShrubifyCustomLyricsSettingsSection: View {
    @State private var options = UserDefaults.karaokeOptions
    @AppStorage("ShrubifyCustomLyricsGlass") private var glass = true
    var body: some View {
        Section(header: Text("Shrubify custom lyrics"), footer: Text("Your original fullscreen lyrics view, independent of player and navigation styling. Reopen it after changing appearance.")) {
            Toggle("Custom lyrics view", isOn: $options.enabled)
            if options.enabled {
                KaraokeLaunchButton()
                Picker("Alignment", selection: $options.textAlignment) {
                    ForEach(KaraokeTextAlignment.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                Toggle("Reverse direction", isOn: $options.reversedDirection)
                VStack(alignment: .leading) {
                    Text("Text size: \(Int(options.resolvedFontSize)) pt")
                    Slider(value: $options.fontSize, in: 22...40, step: 1)
                }
                VStack(alignment: .leading) {
                    Text("Line spacing: \(Int(options.resolvedLineSpacing)) pt")
                    Slider(value: $options.lineSpacing, in: 8...32, step: 2)
                }
                Stepper("Lyrics delay: \(options.timingOffsetMs) ms", value: $options.timingOffsetMs, in: -5000...5000, step: 100)
                VStack(alignment: .leading) {
                    Text("Album background blur")
                    Slider(value: $options.blurIntensity, in: 0...4, step: 0.1)
                }
                if #available(iOS 26.0, *) { Toggle("Glass lyrics controls", isOn: $glass) }
            }
        }
        .onChange(of: options) { UserDefaults.karaokeOptions = $0; KaraokeLyricsStore.shared.notify() }
    }
}
