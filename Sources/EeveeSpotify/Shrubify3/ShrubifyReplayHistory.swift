import SwiftUI
import UniformTypeIdentifiers

struct ShrubifyReplayDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct ShrubifyReplayHistoryView: View {
    @ObservedObject private var history = ShrubifyReplayStore.shared
    @State private var query = ""
    @State private var days = 0
    @State private var document: ShrubifyReplayDocument?
    @State private var exporting = false
    @State private var exportError: String?

    private var entries: [ShrubifyTrackRecord] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? .distantPast
        return history.recentTracks(limit: 350).filter {
            (days == 0 || $0.lastPlayed >= cutoff) && ShrubifyBetaSupport.matches([$0.title, $0.artist], query: query)
        }
    }

    var body: some View {
        List {
            Section(header: Text("Find a song"), footer: Text("The date filter uses when a song was last heard. Each song’s duration and play count cover its entire retained history, not just the selected period.")) {
                TextField("Search songs or artists", text: $query)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                Picker("Last heard", selection: $days) {
                    Text("Any time").tag(0)
                    Text("Past 7 days").tag(7)
                    Text("Past 30 days").tag(30)
                }
            }
            Section(header: Text("Recorded songs")) {
                if entries.isEmpty {
                    Text("No recorded songs match. Replay only records while tracking is enabled and Shrubify is active.")
                        .font(.footnote).foregroundColor(.secondary)
                }
                ForEach(entries) { track in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(track.title).font(.headline)
                        Text(track.artist).font(.subheadline).foregroundColor(.secondary)
                        Text("\(Int(max(0, track.seconds) / 60)) min · \(track.plays) plays")
                            .font(.caption).foregroundColor(.secondary)
                        Text(track.lastPlayed, style: .date).font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                }
            }
            Section(header: Text("Your data"), footer: Text("Exports all retained Replay tracks, daily totals and saved snapshots, regardless of the current filter. Choose where to save or share the JSON file; nothing is uploaded automatically.")) {
                Button("Export Replay JSON") {
                    do {
                        document = ShrubifyReplayDocument(data: try history.exportData())
                        exporting = true
                    } catch { exportError = error.localizedDescription }
                }
            }
        }
        .eeveeSettingsStyle()
        .navigationBarTitle("Listening history", displayMode: .inline)
        .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: "Shrubify-Replay") { result in
            if case .failure(let error) = result { exportError = error.localizedDescription }
            document = nil
        }
        .alert(isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Alert(title: Text("Export unavailable"), message: Text(exportError ?? ""), dismissButton: .default(Text("OK")))
        }
    }
}
