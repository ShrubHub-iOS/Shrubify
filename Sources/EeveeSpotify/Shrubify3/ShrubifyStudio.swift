import SwiftUI

struct ShrubifyStudioView: View {
    var usesSettingsNavigation = false
    @ViewBuilder private func studioLink<V: View>(title: String, subtitle: String? = nil, icon: String, color: Color, destination: @escaping () -> V) -> some View {
        if usesSettingsNavigation {
            SettingsLink(title: title, subtitle: subtitle, icon: icon, color: color, destination: destination)
        } else {
            NavigationLink(destination: destination()) {
                SettingsLabel(title: title, subtitle: subtitle, icon: icon, color: color, chevron: true)
            }
        }
    }
    var body: some View {
        List {
            Section(header: Text("Shrubify Studio"), footer: Text("Shrubify now uses Evolved’s player and page layouts. Saved layouts from the previous renderer are kept on this device but no longer applied.")) {
                studioLink(title: "Player design", subtitle: "Spotify or Apple Music layout", icon: "play.rectangle", color: .blue) { NowPlayingSettingsView() }
                studioLink(title: "Tabs and mini-player", icon: "rectangle.bottomthird.inset.filled", color: .purple) { TabBarAndMiniBarSettingsView() }
                studioLink(title: "Pages and library", icon: "square.grid.2x2", color: .orange) { PagesAppearanceSettingsView() }
                studioLink(title: "Lyrics appearance", icon: "textformat.size", color: .green) { EeveeLyricsAppearanceSettingsView() }
            }
        }
        .eeveeSettingsStyle()
    }
}
