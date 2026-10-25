import SwiftUI
import UIKit

struct ShrubifyDiagnosticsView: View {
    @State private var stabilityMode = UserDefaults.standard.bool(forKey: "ShrubifyStabilityMode")
    @State private var showRestartNotice = false

    var body: some View {
        List {
            Section(header: Text("Compatibility"), footer: Text("Stability Mode disables experimental interface hooks, karaoke, remote flag overrides, and other optional hooks the next time Spotify starts. It cannot prevent every crash.")) {
                Toggle(isOn: $stabilityMode) {
                    SettingsLabel(title: "Stability Mode", subtitle: "Prefer compatibility over extra effects", icon: "shield.lefthalf.filled", color: .blue)
                }
                .onChange(of: stabilityMode) { newValue in
                    UserDefaults.standard.set(newValue, forKey: "ShrubifyStabilityMode")
                    showRestartNotice = true
                }
                if showRestartNotice {
                    Text("Restart Shrubify to apply this change.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            Section(header: Text("Installation")) {
                info("App", Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Shrubify")
                info("Bundle ID", Bundle.main.bundleIdentifier ?? "Unknown")
                info("Spotify", EeveeSpotify.spotifyVersion)
                info("Shrubify", EeveeSpotify.version)
                info("iOS", UIDevice.current.systemVersion)
            }
            Section(header: Text("Help & source")) {
                Link(destination: URL(string: "https://github.com/zoinkdoggie94/Shrubify/issues")!) {
                    SettingsLabel(title: "Report a crash", subtitle: "Include your iOS and Spotify versions", icon: "ladybug.fill", color: .orange, chevron: true)
                }
                Link(destination: URL(string: "https://github.com/zoinkdoggie94/Shrubify")!) {
                    SettingsLabel(title: "Shrubify on GitHub", icon: "chevron.left.forwardslash.chevron.right", color: .gray, chevron: true)
                }
            }
        }
        .eeveeSettingsStyle()
    }

    private func info(_ name: String, _ value: String) -> some View {
        HStack {
            Text(name)
            Spacer()
            Text(value).foregroundColor(.secondary).lineLimit(1).minimumScaleFactor(0.75)
        }
    }
}
