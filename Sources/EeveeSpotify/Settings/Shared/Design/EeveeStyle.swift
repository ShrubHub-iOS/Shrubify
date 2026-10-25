import SwiftUI

enum EeveeTheme {
    static var accent: Color {
        Color(Theme.color(Theme.accentOrGreen(UserDefaults.accentRGB)))
    }
}

struct EeveeSettingsStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listStyle(InsetGroupedListStyle())
            .toggleStyle(SwitchToggleStyle(tint: EeveeTheme.accent))
            .accentColor(EeveeTheme.accent)
    }
}

extension View {
    func eeveeSettingsStyle() -> some View {
        modifier(EeveeSettingsStyle())
    }
}

struct SettingsIcon: View {
    let systemName: String
    let color: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 30, height: 30)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(colors: [color.opacity(0.85), color], startPoint: .top, endPoint: .bottom))
            )
    }
}

struct SettingsLabel: View {
    let title: String
    var subtitle: String?
    let icon: String
    let color: Color
    var chevron = false

    var body: some View {
        HStack(spacing: 14) {
            SettingsIcon(systemName: icon, color: color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundColor(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if chevron { ChevronRightView() }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 5)
    }
}

struct SettingsToggle: View {
    let title: String
    var subtitle: String?
    let icon: String
    let color: Color
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            SettingsLabel(title: title, subtitle: subtitle, icon: icon, color: color)
        }
    }
}

struct SettingsHero: View {

    @ViewBuilder private var logo: some View {
        if let image = BundleHelper.shared.uiImage("ShrubifyLogo") {
            Image(uiImage: image).resizable()
        } else {
            Image(systemName: "music.note")
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            logo
                .aspectRatio(contentMode: .fit)
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.primary.opacity(0.08), lineWidth: 1))
                .accessibilityHidden(true)
            Text("Shrubify")
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .tracking(-0.6)
                .foregroundColor(.primary)
            Text("Made by shrubbery & the ShrubHub team")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("v\(EeveeSpotify.version) · Spotify \(EeveeSpotify.spotifyVersion)")
                .font(.footnote.monospacedDigit())
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .modifier(ShrubifyGlassSurface())
        .padding(.horizontal, 14)
        .padding(.bottom, 5)
        .accessibilityElement(children: .combine)
    }
}

struct SettingsEntry: Identifiable {
    let key: String
    let icon: String
    let color: Color
    let make: () -> AnyView

    var id: String { key }
}

struct SettingsGroup: Identifiable {
    let key: String
    let entries: [SettingsEntry]

    var id: String { key }
}

struct SettingsGroupSection: View {
    let group: SettingsGroup
    let open: (SettingsEntry) -> Void

    var body: some View {
        Section(header: Text(group.key.localized)) {
            ForEach(group.entries) { entry in
                Button {
                    open(entry)
                } label: {
                    SettingsLabel(
                        title: entry.key == "Shrubify diagnostics" ? "Shrubify diagnostics" : entry.key.localized,
                        subtitle: entry.key == "Shrubify diagnostics"
                            ? "Compatibility, crash reports & build information"
                            : entry.key == "liquid_glass"
                            ? (LiquidGlassSettingsView.supported ? "Native iOS 26 glass surfaces" : "Requires iOS 26")
                            : "\(entry.key)_subtitle".localized,
                        icon: entry.icon,
                        color: entry.color,
                        chevron: true
                    )
                }
            }
        }
    }
}

enum SettingsNavigator {
    static weak var navigationController: UINavigationController?

    static func push<V: View>(_ view: V, title: String) {
        guard let navigationController else { return }
        navigationController.pushViewController(
            EeveeSettingsViewController(navigationController.view.frame, settingsView: AnyView(view), navigationTitle: title),
            animated: true
        )
    }
}

struct SettingsLink<Destination: View>: View {
    let title: String
    var subtitle: String?
    let icon: String
    let color: Color
    let destination: () -> Destination

    var body: some View {
        Button {
            SettingsNavigator.push(destination(), title: title)
        } label: {
            SettingsLabel(title: title, subtitle: subtitle, icon: icon, color: color, chevron: true)
        }
    }
}

struct SettingsResetSection: View {
    let visible: Bool
    let action: () -> Void

    var body: some View {
        if visible {
            Section {
                Button {
                    confirmDestructive(title: "reset_page_title".localized, confirm: "reset_page".localized) { withAnimation { action() } }
                } label: {
                    SettingsLabel(title: "reset_page".localized, icon: "arrow.counterclockwise", color: .red)
                }
            }
        }
    }
}

struct RestartSection: View {
    let visible: Bool

    var body: some View {
        if visible {
            Section {
                Button(action: exitApplication) {
                    Text("restart_now".localized).fontWeight(.semibold).frame(maxWidth: .infinity)
                }
                .foregroundColor(EeveeTheme.accent)
            }
        }
    }
}

func confirmDestructive(title: String, message: String? = nil, confirm: String, action: @escaping () -> Void) {
    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "Cancel".uiKitLocalized, style: .cancel))
    alert.addAction(UIAlertAction(title: confirm, style: .destructive) { _ in action() })
    WindowHelper.shared.present(alert)
}

// Preserve native material on iOS 15+ with an iOS 14-compatible fallback.
struct ShrubifyIconMaterial: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 15.0, *) {
            content.background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        } else {
            content.background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
        }
    }
}

// Native Liquid Glass on iOS 26, quiet material on earlier iOS releases.
// No forced tint: the app keeps its Spotify/user-selected accent color.
struct ShrubifyGlassSurface: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: 26))
        } else if #available(iOS 15.0, *) {
            content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        } else {
            content.background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
        }
    }
}
