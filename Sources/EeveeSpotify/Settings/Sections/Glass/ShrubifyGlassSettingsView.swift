import SwiftUI
import UIKit

/// Shared material settings for the surfaces that support system glass.
struct ShrubifyGlassSettingsView: View {
    @State private var enabled = ShrubifyLiquidGlass.isEnabled
    @State private var style = ShrubifyLiquidGlass.style
    @State private var intensity = Double(ShrubifyLiquidGlass.intensity)
    @State private var nativeBars = NativeTabletGlass.isOnForCurrentDevice

    var body: some View {
        List {
            Section(
                header: Text("Liquid Glass"),
                footer: Text(UIDevice.current.userInterfaceIdiom == .pad
                    ? "Applies to the iPad dock, mini-player, player controls and lyrics controls."
                    : "Applies to supported iPhone controls and bars.")
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

                if style == .tinted && ShrubifyLiquidGlass.accent != nil { VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Accent tint strength")
                        Spacer()
                        Text("\(Int((intensity * 100).rounded()))%")
                            .font(.footnote.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $intensity, in: 0...1)
                    .onChange(of: intensity) { value in
                        UserDefaults.container.set(value, forKey: ShrubifyLiquidGlass.intensityKey)
                        ShrubifyLiquidGlass.notifyChange()
                    }
                } }
            }

            if #available(iOS 26.0, *), UIDevice.current.userInterfaceIdiom == .pad {
                Section(
                    header: Text("iPad bottom bars"),
                    footer: Text("Adds native glass behind the tab bar and mini-player.")
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
                    footer: Text("Shows where Shrubify attached a system effect. The artwork-led player layout has its own setting in Studio.")
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
