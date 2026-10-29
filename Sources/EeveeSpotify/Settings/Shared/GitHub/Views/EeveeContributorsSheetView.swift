import SwiftUI

// Shrubify is proudly maintained by shrubbery and the ShrubHub team.
// Original authorship and GPL notices remain with the project and linked upstream work.
private struct ShrubifyCredit: Identifiable {
    let username: String
    let title: String
    let role: String
    var id: String { username }
}

private struct ShrubifyCreditRow: View {
    let credit: ShrubifyCredit
    var prominent = false

    var body: some View {
        Link(destination: URL(string: "https://github.com/\(credit.username)")!) {
            HStack(spacing: 14) {
                ImageView(urlString: "https://github.com/\(credit.username).png?size=160")
                    .frame(width: prominent ? 62 : 44, height: prominent ? 62 : 44)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.primary.opacity(0.12), lineWidth: 1))
                VStack(alignment: .leading, spacing: 3) {
                    Text(credit.title)
                        .font(prominent ? .headline : .body)
                        .fontWeight(prominent ? .bold : .semibold)
                        .foregroundColor(.primary)
                    Text(credit.role)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 6)
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, prominent ? 6 : 3)
            .contentShape(Rectangle())
        }
    }
}

struct EeveeContributorsSheetView: View {
    @Environment(\.presentationMode) private var presentationMode

    private let upstream: [ShrubifyCredit] = [
        .init(username: "whoeevee", title: "whoeevee", role: "Original creator"),
        .init(username: "jaydenjcpy", title: "jaydenjcpy", role: "Upstream maintainer & developer"),
        .init(username: "estrogencat", title: "estrogencat", role: "Upstream artwork & fixes"),
        .init(username: "faroukbmiled", title: "faroukbmiled", role: "Upstream maintainer & developer"),
        .init(username: "M0d-4", title: "Mod4", role: "Upstream maintainer & developer"),
        .init(username: "Meeep1", title: "Meeep1", role: "Upstream contributions"),
        .init(username: "Spikerko", title: "Spikerko", role: "Spicy Lyrics developer")
    ]

    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(spacing: 8) {
                        if let logo = BundleHelper.shared.uiImage("ShrubifyLogo") {
                            Image(uiImage: logo)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 76, height: 76)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        Text("Shrubify")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("Made by shrubbery & the ShrubHub team")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .listRowBackground(Color.clear)
                }

                Section(header: Text("Shrubify development")) {
                    ShrubifyCreditRow(
                        credit: .init(username: "zoinkdoggie94", title: "shrubbery", role: "Shrubify owner & lead developer"),
                        prominent: true
                    )
                    ShrubifyCreditRow(credit: .init(username: "HakureiMango", title: "HakureiMango", role: "Co-Owner & contributor"), prominent: true)
                    ShrubifyCreditRow(credit: .init(username: "ShrubHub-iOS", title: "ShrubHub-iOS", role: "Official GitHub organization"))
                    HStack(spacing: 12) {
                        Image(systemName: "person.3.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .frame(width: 44, height: 44)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("ShrubHub team").fontWeight(.semibold)
                            Text("Core development, testing, community feedback and project support")
                                .font(.footnote).foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 5)
                }

                Section(header: Text("Liquid Glass integration")) {
                    ShrubifyCreditRow(credit: .init(username: "My-Name-Is-Jeff", title: "Vitrine", role: "Liquid Glass material and pane design · GPL-3.0"))
                }

                Section(header: Text("Upstream contributors"), footer: Text("Shrubify builds on open-source contributions. Original authors and licenses remain credited; the names above do not imply endorsement of Shrubify.")) {
                    ForEach(upstream) { credit in
                        ShrubifyCreditRow(credit: credit)
                    }
                    Link(destination: URL(string: "https://github.com/ShrubHub-iOS/Shrubify/blob/Master/contributors.json")!) {
                        HStack {
                            Text("All upstream contributors")
                            Spacer()
                            Image(systemName: "arrow.up.right").font(.caption)
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Developers & credits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Done") { presentationMode.wrappedValue.dismiss() }
            }
        }
    }
}
