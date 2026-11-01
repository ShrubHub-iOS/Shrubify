import SwiftUI

struct ShrubifyBetaView: View {
    var body: some View {
        List {
            Section(header: Text("V4 · Beta 2"), footer: Text("This is v4 beta 2. It preserves existing settings and history; please keep a copy of the last working IPA when testing.")) {
                SettingsLabel(title: "Built on the existing player", subtitle: "Playback and the current glass integration remain in place.", icon: "play.circle", color: .blue)
            }
            Section(header: Text("Beta 2 fixes")) {
                Text("Lyric taps now update the clock and scroll position. The header has its own space, and ShrubPanel no longer nests navigation bars when opened from Settings.")
                Text("Lyrics providers can fall back in your chosen order. Taurus-inspired prominent surfaces are available above Vitrine in Liquid Glass settings; both share Apple’s underlying glass material.")
                Text("Additional crash guards and background-rendering limits are included. Please report remaining crashes with a device .ips report.")
            }
            Section(header: Text("V4 tools")) {
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
                Text("Full Taurus redesign, actual queue editing, manual lyric matching, and broader player redesign remain under evaluation.")
                Text("Performance changes reduce repeated work; battery and speed improvements require device measurements.")
            }
        }
        .eeveeSettingsStyle()
    }
}
