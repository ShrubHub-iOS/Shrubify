import SwiftUI

struct ShrubifyBetaView: View {
    var body: some View {
        List {
            Section {
                SettingsLabel(title: "Welcome to Shrubify 4.0", subtitle: "Your music, with fewer interruptions.", icon: "sparkles", color: .green)
            }
            Section(header: Text("Lyrics that keep up")) {
                SettingsLabel(title: "Listen and follow", subtitle: "Jump to a lyric, pause, resume or scrub without leaving the lyrics view.", icon: "play.circle", color: .blue)
                SettingsLabel(title: "Read at your pace", subtitle: "Turn Follow lyrics off to browse freely, then turn it back on to return to the current line.", icon: "text.alignleft", color: .purple)
                SettingsLabel(title: "Your sources, your order", subtitle: "Missing lyrics use your chosen fallbacks. Loading stays visible, with a retry when timed lyrics are unavailable.", icon: "arrow.triangle.branch", color: .orange)
            }
            Section(header: Text("Made for daily use")) {
                SettingsLabel(title: "More dependable settings", subtitle: "A separate settings window keeps your customizations together.", icon: "gearshape", color: .gray)
                SettingsLabel(title: "Artwork that follows the music", subtitle: "Lyrics backgrounds refresh as tracks change and honor Reduce Motion and Low Power Mode.", icon: "photo", color: .pink)
                SettingsLabel(title: "Keep your style", subtitle: "Studio layouts, ShrubPanel shortcuts and your glass choices remain available.", icon: "slider.horizontal.3", color: .blue)
            }
            Section(header: Text("Private Replay"), footer: Text("Replay remains opt-in and records estimates while Shrubify is active. Listening snapshots are not a capture of Spotify’s actual queue.")) {
                SettingsLabel(title: "Find your listening", subtitle: "Search history, filter by last heard, export your records and keep separate track identities where available.", icon: "clock", color: .purple)
                SettingsLabel(title: "Repeat recognition", subtitle: "Natural song repeats can count as another play instead of being counted only once.", icon: "repeat", color: .green)
            }
        }
        .eeveeSettingsStyle()
    }
}
