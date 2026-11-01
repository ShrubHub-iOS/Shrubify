import SwiftUI

struct ShrubifyBetaView: View {
    var body: some View {
        List {
            Section(header: Text("V4 · Beta 1"), footer: Text("This is the first v4 beta. It preserves existing settings and history; please keep a copy of the last working IPA when testing.")) {
                SettingsLabel(title: "Built on the existing player", subtitle: "Playback and the current glass integration remain in place.", icon: "play.circle", color: .blue)
            }
            Section(header: Text("New in this beta")) {
                SettingsLabel(title: "Find your listening", subtitle: "Search Replay by song or artist, filter by last-heard date, and export your local records.", icon: "clock", color: .purple)
                SettingsLabel(title: "Fine-tune lyrics", subtitle: "Adjust lyrics timing by up to five seconds in either direction. Positive values delay the lyrics.", icon: "text.quote", color: .green)
                SettingsLabel(title: "More useful snapshots", subtitle: "Search saved listening lists by their songs and artists.", icon: "list.bullet", color: .orange)
                SettingsLabel(title: "Studio and ShrubPanel", subtitle: "New layouts save artwork radius. Choose the shortcuts shown in ShrubPanel.", icon: "slider.horizontal.3", color: .blue)
            }
            Section(header: Text("Please test")) {
                Text("Check playback, lyric seeking, saved layouts, large text, history export and snapshot deletion. Report your exact Spotify and iOS versions with any issue.")
                Text("Replay remains opt-in and records only observed activity while Shrubify is active. Snapshots do not capture Spotify’s actual queue.")
            }
            Section(header: Text("Still being evaluated")) {
                Text("Taurus versus Vitrine, actual queue editing, lyrics-provider fallback and manual matching, and broader player redesign are not included in beta 1.")
                Text("Performance changes reduce repeated work; battery and speed improvements require device measurements.")
            }
        }
        .eeveeSettingsStyle()
    }
}
