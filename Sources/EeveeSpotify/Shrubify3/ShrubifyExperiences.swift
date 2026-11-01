import SwiftUI
import UIKit

private func shrubTime(_ seconds: Double) -> String {
    let minutes = Int(max(0, seconds)) / 60
    if minutes >= 60 { return "\(minutes / 60)h \(minutes % 60)m" }
    return "\(minutes)m"
}

struct ShrubifyReplayView: View {
    var usesSettingsNavigation = false
    @ObservedObject private var history = ShrubifyReplayStore.shared
    @State private var showClear = false

    var body: some View {
        List {
            Section(header: Text("Shrubify Replay"), footer: Text("Opt-in, on-device estimates for listening while Shrubify is open. History starts when you enable tracking; it cannot import Spotify's past listening history.")) {
                Toggle(isOn: Binding(get: { history.enabled }, set: { history.setEnabled($0) })) {
                    SettingsLabel(title: "Record local listening", subtitle: "Never sent to a server", icon: "waveform", color: .blue)
                }
            }
            Section(header: Text("Your listening")) {
                replayMetric("Today", shrubTime(history.todaySeconds))
                replayMetric("All recorded", shrubTime(history.totalSeconds))
                replayMetric("Songs in history", "\(history.tracks.count)")
            }
            Section(header: Text("Replay details")) {
                HStack { Text("Recorded plays"); Spacer(); Text("\(history.tracks.reduce(0) { $0 + $1.plays })") }
                HStack { Text("Artists in history"); Spacer(); Text("\(Set(history.tracks.map { $0.artist.lowercased() }).count)") }
                HStack { Text("Last seven days"); Spacer(); Text(shrubTime(history.recentDays().reduce(0) { $0 + $1.seconds })) }
                Text("Plays and artists cover the songs retained on this device. Listening totals are estimates, not Spotify account history.")
                    .font(.footnote).foregroundColor(.secondary)
            }
            Section {
                if usesSettingsNavigation {
                    SettingsLink(title: "Listening history", subtitle: "Search, filter and export your local records", icon: "clock", color: .purple) { ShrubifyReplayHistoryView() }
                } else {
                    NavigationLink(destination: ShrubifyReplayHistoryView()) {
                        SettingsLabel(title: "Listening history", subtitle: "Search, filter and export your local records", icon: "clock", color: .purple)
                    }
                }
            }
            Section(header: Text("Most listened")) {
                if history.tracks.isEmpty {
                    Text("Your local listening stats will appear here after tracking is enabled and you play music in Shrubify.")
                        .font(.footnote).foregroundColor(.secondary)
                }
                ForEach(Array(history.rankedTracks.prefix(30))) { entry in
                    HStack(spacing: 10) {
                        Image(systemName: "music.note").foregroundColor(.secondary).frame(width: 24)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.title).fontWeight(.medium).lineLimit(1)
                            Text(entry.artist).font(.footnote).foregroundColor(.secondary).lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        VStack(alignment: .trailing) {
                            Text(shrubTime(entry.seconds)).font(.system(.footnote, design: .monospaced))
                            Text("\(entry.plays) plays").font(.caption).foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
            Section(header: Text("Top artists")) {
                if history.tracks.isEmpty { Text("Artists will appear here as you listen.").foregroundColor(.secondary) }
                ForEach(history.topArtists()) { artist in
                    HStack {
                        Text(artist.name).lineLimit(1)
                        Spacer()
                        Text(shrubTime(artist.seconds)).font(.footnote).foregroundColor(.secondary)
                    }
                }
            }
            Section(header: Text("Last seven days"), footer: Text("Listening time is estimated only while Shrubify is active and tracking is enabled.")) {
                ForEach(history.recentDays()) { day in
                    HStack(spacing: 10) {
                        Text(String(day.day.suffix(5)))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 48, alignment: .leading)
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(EeveeTheme.accent.opacity(0.7))
                                .frame(width: dayBarWidth(seconds: day.seconds, containerWidth: geo.size.width), height: 8)
                                .frame(maxHeight: .infinity, alignment: .center)
                        }
                        .frame(height: 22)
                        Text(shrubTime(day.seconds))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 45, alignment: .trailing)
                    }
                }
            }
            Section(header: Text("Recently heard")) {
                ForEach(history.recentTracks(limit: 8)) { track in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title).lineLimit(1)
                        Text(track.artist).font(.caption).foregroundColor(.secondary).lineLimit(1)
                    }
                }
            }
            Section(header: Text("Privacy")) {
                Button { showClear = true } label: {
                    SettingsLabel(title: "Erase Replay data", icon: "trash", color: .red)
                }
            }
            .alert(isPresented: $showClear) {
                Alert(title: Text("Erase your listening history?"), message: Text("This deletes Replay statistics and locally saved listening snapshots."), primaryButton: .destructive(Text("Erase"), action: { history.clear() }), secondaryButton: .cancel())
            }
            SpacerView()
        }
        .eeveeSettingsStyle()
    }

    // Keep view-builder expressions small and use one well-defined CGFloat
    // calculation; SwiftUI's generic type-checker handles this reliably.
    private func dayBarWidth(seconds: Double, containerWidth: CGFloat) -> CGFloat {
        guard seconds > 0, containerWidth > 0 else { return 0 }
        let maximum = max(1.0, history.recentDays().map { $0.seconds }.max() ?? 0)
        let ratio = min(1.0, max(0.0, seconds / maximum))
        return min(containerWidth, max(2, containerWidth * CGFloat(ratio)))
    }

    private func replayMetric(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundColor(.secondary)
            Spacer(minLength: 12)
            Text(value).font(.system(.headline, design: .monospaced))
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

struct ShrubifyQueueView: View {
    @ObservedObject private var history = ShrubifyReplayStore.shared
    @State private var message: String?
    @State private var query = ""

    private var matchingSessions: [ShrubifySession] {
        history.sessions.filter { session in
            ShrubifyBetaSupport.matches([session.title] + session.tracks.flatMap { [$0.title, $0.artist] }, query: query)
        }
    }

    var body: some View {
        List {
            Section(header: Text("ShrubQueue"), footer: Text("Queue shortcuts use Spotify's captured in-app navigator. Listening snapshots save locally recorded songs, not Spotify's live queue order.")) {
                Button { openSpotifyQueue() } label: {
                    SettingsLabel(title: "Open Spotify queue", subtitle: "Jump to the real queue when available", icon: "list.bullet", color: .blue, chevron: true)
                }
                Button { message = history.bookmarkCurrent() ? "Saved the playing track to your local snapshots." : "No song metadata is available yet." } label: {
                    SettingsLabel(title: "Bookmark current song", icon: "bookmark", color: .orange)
                }
                Button { message = history.saveRecentSession() ? "Saved your 20 most recent locally tracked songs." : "Enable Replay and listen to some music first." } label: {
                    SettingsLabel(title: "Save recent listening snapshot", icon: "square.stack.3d.up", color: .gray)
                }
            }
            if let message = message {
                Section { Text(message).font(.footnote).foregroundColor(.secondary) }
            }
            Section(header: Text("Find a snapshot")) {
                TextField("Search snapshots, songs or artists", text: $query)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            Section(header: Text("Saved listening snapshots")) {
                if history.sessions.isEmpty {
                    Text("No snapshots yet. Save the current song, or enable Replay to collect a recent listening list.")
                        .font(.footnote).foregroundColor(.secondary)
                }
                if !history.sessions.isEmpty && matchingSessions.isEmpty {
                    Text("No snapshots match your search.").foregroundColor(.secondary)
                }
                ForEach(matchingSessions) { session in
                    NavigationLink(destination: ShrubifySessionView(session: session)) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(session.title).fontWeight(.medium)
                            HStack(spacing: 4) {
                                Text("\(session.tracks.count) songs ·")
                                Text(session.savedAt, style: .date)
                            }
                                .font(.footnote).foregroundColor(.secondary)
                        }
                        .padding(.vertical, 3)
                    }
                }
                .onDelete { offsets in
                    let sessions = matchingSessions
                    for index in offsets where sessions.indices.contains(index) { history.removeSession(sessions[index].id) }
                }
            }
            SpacerView()
        }
        .eeveeSettingsStyle()
    }

    private func openSpotifyQueue() {
        guard CustomTabs.available, CustomTabs.dispatcher != nil else {
            message = "The in-app queue navigator isn't available with this Spotify version or configuration. Use Spotify's queue button instead."
            return
        }
        CustomTabs.open(CustomTab(title: "Queue", uri: "spotify:now-playing:queue", sfSymbol: "list.bullet"))
        message = "Requested Spotify's queue."
    }
}

struct ShrubifySessionView: View {
    let session: ShrubifySession
    @State private var note: String?

    var body: some View {
        List {
            Section(header: Text("Saved listening snapshot"), footer: Text("A snapshot is a list of songs, not a restored Spotify playback queue. A song opens only if a valid Spotify track URI was captured.")) {
                ForEach(session.tracks) { track in
                    Button {
                        guard let uri = track.spotifyURI, CustomTabs.available, CustomTabs.dispatcher != nil else {
                            note = "Can't navigate to this track in this Spotify build."
                            return
                        }
                        CustomTabs.open(CustomTab(title: track.title, uri: uri, sfSymbol: "music.note"))
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(track.title).foregroundColor(.primary).fontWeight(.medium)
                                Text(track.artist).font(.footnote).foregroundColor(.secondary)
                            }
                            Spacer()
                            if track.spotifyURI != nil { Image(systemName: "arrow.up.right").foregroundColor(.secondary) }
                        }
                    }
                }
            }
            if let note = note { Section { Text(note).font(.footnote) } }
        }
        .eeveeSettingsStyle()
        .navigationBarTitle("Listening snapshot", displayMode: .inline)
    }
}

/// Presented over the running player. This panel is an additive surface, not a
/// wholesale replacement for Spotify's dynamic player implementation.
struct ShrubifyPanelView: View {
    var embeddedInSettings = false
    let dismiss: () -> Void
    @AppStorage("ShrubPanelShowStudio4") private var showStudio = true
    @AppStorage("ShrubPanelShowReplay4") private var showReplay = true
    @AppStorage("ShrubPanelShowQueue4") private var showQueue = true

    @ViewBuilder var body: some View {
        if embeddedInSettings { panelContent }
        else {
            NavigationView {
                panelContent
                    .navigationBarTitle("ShrubPanel", displayMode: .inline)
                    .navigationBarItems(trailing: Button("Done", action: dismiss))
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }

    private var panelContent: some View {
            List {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 34))
                            .foregroundColor(EeveeTheme.accent)
                        VStack(alignment: .leading) {
                            Text("Your listening tools").font(.headline)
                            Text("Listening is easy with Shrubify.")
                                .font(.footnote).foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }
                Section(header: Text("Quick access")) {
                    if showStudio {
                        if embeddedInSettings {
                            Button { SettingsNavigator.push(ShrubifyStudioView(usesSettingsNavigation: true), title: "Studio") } label: { SettingsLabel(title: "Shrubify Studio", subtitle: "Player layouts and details", icon: "slider.horizontal.3", color: .blue) }
                        } else {
                        NavigationLink(destination: ShrubifyStudioView()) {
                            SettingsLabel(title: "Shrubify Studio", subtitle: "Player layouts and details", icon: "slider.horizontal.3", color: .blue)
                        }
                        }
                    }
                    if showReplay {
                        if embeddedInSettings {
                            Button { SettingsNavigator.push(ShrubifyReplayView(usesSettingsNavigation: true), title: "Replay") } label: { SettingsLabel(title: "Shrubify Replay", subtitle: "Private listening stats", icon: "chart.bar.xaxis", color: .purple) }
                        } else {
                        NavigationLink(destination: ShrubifyReplayView()) {
                            SettingsLabel(title: "Shrubify Replay", subtitle: "Private listening stats", icon: "chart.bar.xaxis", color: .purple)
                        }
                        }
                    }
                    if showQueue {
                        if embeddedInSettings {
                            Button { SettingsNavigator.push(NavigationView { ShrubifyQueueView() }.navigationViewStyle(StackNavigationViewStyle()), title: "Queue") } label: { SettingsLabel(title: "ShrubQueue", subtitle: "Queue and snapshots", icon: "list.bullet", color: .orange) }
                        } else {
                        NavigationLink(destination: ShrubifyQueueView()) {
                            SettingsLabel(title: "ShrubQueue", subtitle: "Queue and snapshots", icon: "list.bullet", color: .orange)
                        }
                        }
                    }
                }
                Section {
                    DisclosureGroup("Customize shortcuts") {
                        Toggle("Studio", isOn: $showStudio)
                        Toggle("Replay", isOn: $showReplay)
                        Toggle("Queue and snapshots", isOn: $showQueue)
                    }
                }
                Section(header: Text("Listening tools")) {
                    if KaraokeOverlayPresenter.isAvailableForCurrentTrack() {
                        Button {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { KaraokeOverlayPresenter.present() }
                        } label: {
                            SettingsLabel(title: "Word-synced lyrics", icon: "text.quote", color: .green)
                        }
                    }
                    Text("ShrubPanel never requires an account or sends your Replay history anywhere.")
                        .font(.footnote).foregroundColor(.secondary)
                }
            }
            .eeveeSettingsStyle()

    }
}

enum ShrubifyPanelPresenter {
    private static weak var presented: UIViewController?

    static func present() {
        guard Thread.isMainThread else { DispatchQueue.main.async { present() }; return }
        guard presented == nil,
              let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).flatMap({ $0.windows }).first(where: { $0.isKeyWindow }),
              let root = window.rootViewController else { return }
        var top = root
        while let next = top.presentedViewController { top = next }
        guard !(top is UIAlertController) else { return }
        let controller = UIHostingController(rootView: ShrubifyPanelView(dismiss: { dismiss() }))
        controller.modalPresentationStyle = .pageSheet
        presented = controller
        top.present(controller, animated: true)
    }

    static func dismiss() {
        guard Thread.isMainThread else { DispatchQueue.main.async { dismiss() }; return }
        presented?.dismiss(animated: true)
        presented = nil
    }
}
