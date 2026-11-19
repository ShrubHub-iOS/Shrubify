import SwiftUI

struct ShrubifyStudioView: View {
    var usesSettingsNavigation = false
    @AppStorage(NativeTabletGlass.preferenceKey) private var nativeGlass = false
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
                Section(header: Text("iPad appearance"), footer: Text("Artwork, track lists and the full-screen player keep Spotify’s original appearance.")) {
                    if #available(iOS 26.0, *) {
                        if UserDefaults.standard.bool(forKey: "ShrubifyStabilityMode") {
                            Text("Stability Mode uses Spotify’s original bottom bars.").font(.footnote)
                        } else {
                            Toggle("Glass on bottom bars", isOn: $nativeGlass)
                                .onChange(of: nativeGlass) { _ in NativeTabletGlass.reapply() }
                        }
                    } else {
                        Text("Glass on bottom bars requires iPadOS 26 or later.").font(.footnote)
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
                studioLink(title: "Liquid Glass", subtitle: "Material, style and intensity on every surface", icon: "circle.hexagongrid.fill", color: .indigo) { ShrubifyGlassSettingsView() }
                studioLink(title: "Theme and colors", icon: "drop.fill", color: .teal) { EeveeUISettingsView() }
                studioLink(title: "appIcon".localized, icon: "app.badge.fill", color: .pink) { EeveeAppIconPickerView() }
            }
        }
        .eeveeSettingsStyle()
    }
}
