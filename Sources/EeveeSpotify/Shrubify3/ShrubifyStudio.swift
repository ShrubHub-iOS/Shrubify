import SwiftUI

/// Presets control already-existing, version-gated player hooks rather than
/// replacing Spotify's view hierarchy with a fragile custom layout.
enum ShrubifyPreset: String, CaseIterable, Identifiable {
    case classic = "Classic", minimal = "Minimal", immersive = "Immersive", custom = "Custom"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .classic: return "music.note"
        case .minimal: return "rectangle.compress.vertical"
        case .immersive: return "square.expand"
        case .custom: return "slider.horizontal.3"
        }
    }
    var summary: String {
        switch self {
        case .classic: return "Spotify's familiar layout, no extra visual hooks"
        case .minimal: return "Fewer panels and distractions around your music"
        case .immersive: return "Artwork-focused backdrop and supported glass effects"
        case .custom: return "Keep the controls you have chosen below"
        }
    }
}

private struct ShrubifySavedLayout: Codable, Identifiable {
    var id = UUID()
    var name: String
    var player: PlayerOptions
    var glass: LiquidGlassOptions
    var bar: NowPlayingBarOptions
}

struct ShrubifyStudioView: View {
    @State private var savedLayouts: [ShrubifySavedLayout] = {
        guard let data = UserDefaults.standard.data(forKey: "ShrubifySavedLayouts3") else { return [] }
        return (try? JSONDecoder().decode([ShrubifySavedLayout].self, from: data)) ?? []
    }()
    @State private var newLayoutName = "My layout"
    @State private var preset = ShrubifyPreset(rawValue: UserDefaults.standard.string(forKey: "ShrubifyPreset3") ?? "Custom") ?? .custom
    @State private var player = UserDefaults.playerOptions
    @State private var glass = UserDefaults.liquidGlassOptions
    @State private var bar = UserDefaults.nowPlayingBarOptions
    @State private var showRestart = false
    @State private var artworkRadius = UserDefaults.standard.object(forKey: "ShrubifyArtworkRadius3") == nil ? 12.0 : UserDefaults.standard.double(forKey: "ShrubifyArtworkRadius3")

    var body: some View {
        List {
            presetSection
            playerDetailsSection
            appearanceSection
            savedLayoutsSection
            restartSection
            SpacerView()
        }
        .eeveeSettingsStyle()
        .onChange(of: artworkRadius) { radius in
            UserDefaults.standard.set(radius, forKey: "ShrubifyArtworkRadius3")
            saveCustom()
        }
        .onChange(of: player) { saveCustom(); UserDefaults.playerOptions = $0 }
        .onChange(of: glass) { saveCustom(); UserDefaults.liquidGlassOptions = $0 }
        .onChange(of: bar) { saveCustom(); UserDefaults.nowPlayingBarOptions = $0; NotificationCenter.default.post(name: .eeveeNowPlayingBarOptionsChanged, object: nil) }
    }

    // Splitting the SwiftUI builder keeps compile-time generic inference bounded.
    @ViewBuilder private var presetSection: some View {
        Section(header: Text("Shrubify Studio"), footer: Text("Presets reuse Spotify's player controls and existing Shrubify effects. Restart to apply layout changes.")) {
            ForEach(ShrubifyPreset.allCases) { mode in
                Button { apply(mode) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: mode.symbol).frame(width: 26)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(mode.rawValue).foregroundColor(.primary).fontWeight(.semibold)
                            Text(mode.summary).font(.footnote).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        if preset == mode { Image(systemName: "checkmark.circle.fill").foregroundColor(EeveeTheme.accent) }
                    }
                    .padding(.vertical, 5)
                }
            }
        }
    }

    @ViewBuilder private var playerDetailsSection: some View {
        Section(header: Text("Player details")) {
            Toggle("Artwork backdrop", isOn: $player.backdrop)
            Toggle("Glass lyrics card", isOn: $player.glassLyricsCard)
            Toggle("Round mini-player artwork", isOn: $bar.roundArtwork)
            Toggle("Hide mini-player Connect button", isOn: $bar.hideConnect)
            Toggle("Modern player layout", isOn: $glass.newPlayerDesign)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Artwork corner radius")
                    Spacer()
                    Text("\(Int(artworkRadius)) pt").font(.footnote).foregroundColor(.secondary)
                }
                Slider(value: $artworkRadius, in: 0...30, step: 2)
                Text("Affects the Now Playing artwork only when the backdrop hook is active.")
                    .font(.caption).foregroundColor(.secondary)
            }
            NavigationLink(destination: PlayerHideSettingsView()) {
                SettingsLabel(title: "Player elements", subtitle: "Choose visible buttons and cards", icon: "eye", color: .gray)
            }
        }
    }

    @ViewBuilder private var appearanceSection: some View {
        Section(header: Text("Appearance")) {
            Text("Shrubify follows Spotify's existing light/dark palette and your chosen accent. Liquid Glass is only enabled on supported versions of iOS.")
                .font(.footnote).foregroundColor(.secondary)
            NavigationLink(destination: LiquidGlassSettingsView()) {
                SettingsLabel(title: "Liquid Glass", icon: "circle.hexagongrid.fill", color: .gray)
            }
        }
    }

    @ViewBuilder private var savedLayoutsSection: some View {
        Section(header: Text("Your saved layouts"), footer: Text("Saved layouts are stored on this device. Delete or restore them any time.")) {
            HStack {
                TextField("Layout name", text: $newLayoutName)
                    .autocapitalization(.words)
                Button("Save") { saveLayout() }
                    .disabled(newLayoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || savedLayouts.count >= 12)
            }
            ForEach(savedLayouts) { item in
                HStack {
                    Button { restore(item) } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.name).foregroundColor(.primary)
                            Text("Tap to restore").font(.caption).foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Button { deleteLayout(item.id) } label: {
                        Image(systemName: "trash").foregroundColor(.red)
                    }
                }
            }
        }
    }

    @ViewBuilder private var restartSection: some View {
        if showRestart {
            Section {
                Button("Restart to apply changes", action: exitApplication).fontWeight(.semibold)
            }
        }
    }


    private func persistLayouts() {
        if let data = try? JSONEncoder().encode(savedLayouts) {
            UserDefaults.standard.set(data, forKey: "ShrubifySavedLayouts3")
        }
    }

    private func saveLayout() {
        let name = String(newLayoutName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(36))
        guard !name.isEmpty, savedLayouts.count < 12 else { return }
        savedLayouts.append(ShrubifySavedLayout(name: name, player: player, glass: glass, bar: bar))
        persistLayouts()
    }

    private func deleteLayout(_ id: UUID) {
        savedLayouts.removeAll { $0.id == id }
        persistLayouts()
    }

    private func restore(_ layout: ShrubifySavedLayout) {
        preset = .custom
        UserDefaults.standard.set(ShrubifyPreset.custom.rawValue, forKey: "ShrubifyPreset3")
        player = layout.player
        glass = layout.glass
        bar = layout.bar
        UserDefaults.playerOptions = player
        UserDefaults.liquidGlassOptions = glass
        UserDefaults.nowPlayingBarOptions = bar
        NotificationCenter.default.post(name: .eeveeNowPlayingBarOptionsChanged, object: nil)
        showRestart = true
    }

    private func saveCustom() {
        guard !showRestart else { return }
        preset = .custom
        UserDefaults.standard.set(ShrubifyPreset.custom.rawValue, forKey: "ShrubifyPreset3")
        showRestart = true
    }

    private func apply(_ mode: ShrubifyPreset) {
        preset = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "ShrubifyPreset3")
        switch mode {
        case .classic:
            player.backdrop = false
            player.glassLyricsCard = false
            player.hiddenParts = []
            glass.newPlayerDesign = false
            bar.hideConnect = false
            bar.roundArtwork = false
        case .minimal:
            player.backdrop = false
            player.glassLyricsCard = false
            player.hiddenParts = [.lyricsPreview, .relatedVideos, .merch, .recommendations]
            glass.newPlayerDesign = false
            bar.hideConnect = true
            bar.roundArtwork = true
        case .immersive:
            player.backdrop = true
            player.glassLyricsCard = true
            player.hiddenParts = [.relatedVideos, .merch]
            glass.newPlayerDesign = true
            bar.hideConnect = false
            bar.roundArtwork = true
        case .custom: break
        }
        // Persist together; onChange also reflects the edited values in the UI.
        UserDefaults.playerOptions = player
        UserDefaults.liquidGlassOptions = glass
        UserDefaults.nowPlayingBarOptions = bar
        NotificationCenter.default.post(name: .eeveeNowPlayingBarOptionsChanged, object: nil)
        showRestart = true
    }
}
