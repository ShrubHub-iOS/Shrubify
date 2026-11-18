import SwiftUI

struct ShrubifyStudioView: View {
    var usesSettingsNavigation = false
    @AppStorage("ShrubifyNativeTabletGlass") private var nativeGlass = true
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
            if EvolvedInterfaceAvailability.usesNativeTabletInterface {
                Section(header: Text("iPad player & pages"), footer: Text("Spotify keeps its native layout and controls. Glass decorates supported Home tiles, album artwork, track rows, buttons and the player without changing what a tap does.")) {
                    if #available(iOS 26.0, *) {
                        Toggle("Liquid Glass", isOn: $nativeGlass)
                            .onChange(of: nativeGlass) { _ in NativeTabletGlass.reapply() }
                    } else {
                        Text("Liquid Glass requires iPadOS 26 or later.").font(.footnote)
                    }
                }
            } else {
                Section(header: Text("Player & pages")) {
                    studioLink(title: "Player design", subtitle: "Spotify or Apple Music layout", icon: "play.rectangle", color: .blue) { NowPlayingSettingsView() }
                    studioLink(title: "Tabs and mini-player", icon: "rectangle.bottomthird.inset.filled", color: .purple) { TabBarAndMiniBarSettingsView() }
                    studioLink(title: "Pages and library", icon: "square.grid.2x2", color: .orange) { PagesAppearanceSettingsView() }
                }
            }
            Section(header: Text("App appearance")) {
                studioLink(title: "Theme and colors", icon: "drop.fill", color: .teal) { EeveeUISettingsView() }
                studioLink(title: "appIcon".localized, icon: "app.badge.fill", color: .pink) { EeveeAppIconPickerView() }
            }
        }
        .eeveeSettingsStyle()
    }
}
