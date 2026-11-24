import SwiftUI

struct KaraokeLaunchButton: View {
    @State private var needsTrack = false

    var body: some View {
        Button {
            guard KaraokeOverlayPresenter.canOpenForCurrentTrack() else { needsTrack = true; return }
            KaraokeOverlayPresenter.present()
        } label: {
            Label("Open custom lyrics", systemImage: "text.quote")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .frame(minHeight: 32)
        }
        .buttonStyle(.borderedProminent)
        .tint(.white)
        .foregroundColor(.black)
        .disabled(!UserDefaults.karaokeOptions.enabled || !UserDefaults.shouldReplaceLyrics)
        .alert(isPresented: $needsTrack) {
            Alert(title: Text("Play a song to open lyrics"), dismissButton: .default(Text("OK")))
        }
    }
}

struct ShrubifyCustomLyricsSettingsSection: View {
    @State private var options = UserDefaults.karaokeOptions
    @AppStorage("ShrubifyCustomLyricsGlass") private var glass = true
    var body: some View {
        Section(header: Text("Shrubify custom lyrics"), footer: Text("Your original fullscreen lyrics view, independent of player and navigation styling. Reopen it after changing appearance.")) {
            Toggle("Custom lyrics view", isOn: preference(\.enabled))
            if options.enabled {
                KaraokeLaunchButton()
                Picker("Alignment", selection: preference(\.textAlignment)) {
                    ForEach(KaraokeTextAlignment.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                Toggle("Reverse direction", isOn: preference(\.reversedDirection))
                VStack(alignment: .leading) {
                    Text("Text size: \(Int(options.resolvedFontSize)) pt")
                    Slider(value: preference(\.fontSize), in: 22...40, step: 1)
                }
                VStack(alignment: .leading) {
                    Text("Line spacing: \(Int(options.resolvedLineSpacing)) pt")
                    Slider(value: preference(\.lineSpacing), in: 8...32, step: 2)
                }
                Stepper("Lyrics delay: \(options.timingOffsetMs) ms", value: preference(\.timingOffsetMs), in: -5000...5000, step: 100)
                VStack(alignment: .leading) {
                    Text("Album background blur")
                    Slider(value: preference(\.blurIntensity), in: 0...4, step: 0.1)
                }
                if #available(iOS 26.0, *) { Toggle("Glass lyrics controls", isOn: $glass) }
            }
        }
        .onAppear { refreshOptions() }
        .onReceive(NotificationCenter.default.publisher(for: .eeveeKaraokeLyricsChanged)) { _ in refreshOptions() }
    }

    private func refreshOptions() {
        let saved = UserDefaults.karaokeOptions
        if options != saved { options = saved }
    }

    private func preference<Value>(_ keyPath: WritableKeyPath<KaraokeOptions, Value>) -> Binding<Value> {
        Binding(get: { options[keyPath: keyPath] }, set: { value in
            var saved = UserDefaults.karaokeOptions
            saved[keyPath: keyPath] = value
            UserDefaults.karaokeOptions = saved
            options = saved
            KaraokeLyricsStore.shared.notify()
        })
    }
}
