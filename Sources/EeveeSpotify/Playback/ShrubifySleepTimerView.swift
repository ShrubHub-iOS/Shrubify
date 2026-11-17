import SwiftUI

struct ShrubifySleepTimerView: View {
    @ObservedObject private var timer = ShrubifySleepTimer.shared
    @AppStorage("ShrubifySleepTimerMinutes") private var minutes = 30

    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 36)).foregroundColor(EeveeTheme.accent)
                        .accessibilityHidden(true)
                    Text(timer.remaining.map(clock) ?? "Wind down")
                        .font(.system(size: 38, weight: .semibold, design: .rounded))
                        .minimumScaleFactor(0.6).lineLimit(1)
                    Text(timer.remaining == nil ? "A little more music. Then rest." : "Playback will pause when the timer ends.")
                        .font(.subheadline).foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    if let remaining = timer.remaining {
                        ProgressView(value: max(0, min(1, remaining / max(1, timer.duration))))
                            .accessibilityLabel("Time remaining")
                            .accessibilityValue(clock(remaining))
                    }
                }
                .frame(maxWidth: .infinity).padding(.vertical, 24)
            }
            Section(header: Text("Duration")) {
                Picker("Pause after", selection: $minutes) {
                    ForEach(SleepTimerCountdown.presetMinutes, id: \.self) { value in
                        Text("\(value) minutes").tag(value)
                    }
                }
                Button(timer.remaining == nil ? "Start sleep timer" : "Restart with selected duration") {
                    timer.start(minutes: minutes)
                }
                if timer.remaining != nil {
                    Button(action: timer.cancel) { Text("Cancel timer").foregroundColor(.red) }
                }
            }
            if let message = timer.message {
                Section { Text(message).font(.footnote).foregroundColor(.secondary) }
            }
            Section(footer: Text("The timer continues when you leave this page. During active background playback it runs when iOS allows; if the app is suspended, pause may be delayed until it resumes. Force-quitting cancels the timer. It does not change Spotify’s own sleep timer.")) {
                Label("One timer for this listening session", systemImage: "moon")
            }
        }
        .eeveeSettingsStyle()
        .navigationBarTitle("Sleep timer", displayMode: .inline)
        .onAppear {
            if !SleepTimerCountdown.presetMinutes.contains(minutes) { minutes = 30 }
        }
    }

    private func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
