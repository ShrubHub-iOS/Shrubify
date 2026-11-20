import SwiftUI
import UIKit

/// Liquid Glass for every device and every surface.
///
/// One master switch, one material and one intensity control drive the tab bar,
/// mini-player, player footer and the iPad bottom-bar backings, so the look is
/// consistent instead of being tuned page by page.
struct ShrubifyGlassSettingsView: View {
    @State private var enabled = ShrubifyLiquidGlass.isEnabled
    @State private var style = ShrubifyLiquidGlass.style
    @State private var intensity = Double(ShrubifyLiquidGlass.intensity)
    @State private var nativeBars = NativeTabletGlass.isOnForCurrentDevice

    var body: some View {
        List {
            Section(
                header: Text("Liquid Glass"),
                footer: Text("Applies to the player, the tab bar and the mini-player on iPhone and iPad.")
            ) {
                Toggle("Liquid Glass", isOn: $enabled)
                    .onChange(of: enabled) { value in
                        UserDefaults.container.set(value, forKey: ShrubifyLiquidGlass.enabledKey)
                        ShrubifyLiquidGlass.notifyChange()
                        NativeTabletGlass.reapply()
                    }

                Picker("Material", selection: $style) {
                    ForEach(ShrubifyGlassStyle.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: style) { value in
                    UserDefaults.container.set(value.rawValue, forKey: ShrubifyLiquidGlass.styleKey)
                    ShrubifyLiquidGlass.notifyChange()
                }

                Text(style.detail)
                    .font(.footnote)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Accent tint strength")
                        Spacer()
                        Text("\(Int((intensity * 100).rounded()))%")
                            .font(.footnote.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $intensity, in: 0...1)
                        .disabled(style != .tinted)
                    .onChange(of: intensity) { value in
                        UserDefaults.container.set(value, forKey: ShrubifyLiquidGlass.intensityKey)
                        ShrubifyLiquidGlass.notifyChange()
                    }
                }
            }

            if #available(iOS 26.0, *), UIDevice.current.userInterfaceIdiom == .pad {
                Section(
                    header: Text("iPad bottom bars"),
                    footer: Text("Adds native glass behind the tab bar and mini-player. Expanded playback controls stay clean.")
                ) {
                    Toggle("Glass on bottom bars", isOn: $nativeBars)
                        .onChange(of: nativeBars) { value in
                            UserDefaults.container.set(value, forKey: NativeTabletGlass.preferenceKey)
                            NativeTabletGlass.reapply()
                        }
                }
            }

            if #available(iOS 26.0, *), UIDevice.current.userInterfaceIdiom == .pad {
                Section(
                    header: Text("Glass status"),
                    footer: Text("What Shrubify actually found on this Spotify build. An unrecognized host retains the native interface.")
                ) {
                    ForEach(ShrubifyGlassChrome.statusLines, id: \.self) { line in
                        Text(line)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }

            SettingsResetSection(
                keys: ShrubifyLiquidGlass.allKeys + [NativeTabletGlass.preferenceKey],
                afterReset: {
                    enabled = ShrubifyLiquidGlass.isEnabled
                    style = ShrubifyLiquidGlass.style
                    intensity = Double(ShrubifyLiquidGlass.intensity)
                    nativeBars = NativeTabletGlass.isOnForCurrentDevice
                    ShrubifyLiquidGlass.notifyChange()
                    NativeTabletGlass.reapply()
                }
            )
        }
        .listStyle(InsetGroupedListStyle())
        .onAppear {
            enabled = ShrubifyLiquidGlass.isEnabled
            style = ShrubifyLiquidGlass.style
            intensity = Double(ShrubifyLiquidGlass.intensity)
            nativeBars = NativeTabletGlass.isOnForCurrentDevice
        }
    }
}
