import SwiftUI

struct EeveeSettingsVersionView: View {
    @State private var isPresentingContributorsSheet = false

    private var releaseURL: URL {
        URL(string: "https://github.com/\(EeveeSpotify.repoSlug)/releases")!
    }

    var body: some View {
        Section {
            Link(destination: releaseURL) {
                SettingsLabel(
                    title: "Shrubify releases",
                    subtitle: "Updates, build details and IPA compatibility",
                    icon: "arrow.down.circle.fill",
                    color: EeveeTheme.accent,
                    chevron: true
                )
            }
            Button {
                isPresentingContributorsSheet = true
            } label: {
                SettingsLabel(title: "Upstream contributors", icon: "person.2.fill", color: .gray, chevron: true)
            }
        }
        .sheet(isPresented: $isPresentingContributorsSheet) {
            EeveeContributorsSheetView()
        }
    }
}
