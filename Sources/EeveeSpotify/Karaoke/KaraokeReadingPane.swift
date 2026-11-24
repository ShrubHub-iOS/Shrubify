import SwiftUI

/// Keep the transport outside this pane: browsing the words must never hide
/// playback or seek the song. Only a tap on a line changes playback time.
@available(iOS 15.0, *)
struct KaraokeReadingPane<Lines: View>: View {
    @Binding var offset: Int
    let activeLine: Int?
    var reversed = false
    @ViewBuilder var lines: (ScrollViewProxy) -> Lines

    @State private var follows = true
    @State private var showsTiming = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 8) {
                HStack {
                    Button { showsTiming.toggle() } label: {
                        Label("Sync", systemImage: "slider.horizontal.3")
                            .padding(.horizontal, 12).frame(minHeight: 44)
                            .background(KaraokeControlSurface())
                            .contentShape(Rectangle())
                    }
                    .accessibilityValue(showsTiming ? "Expanded" : "Collapsed")
                    .accessibilityIdentifier("shrubify.lyrics.sync")
                    Spacer(minLength: 4)
                    if follows, activeLine != nil {
                        Button { follows = false } label: {
                            Label("Following", systemImage: "location.fill")
                                .padding(.horizontal, 12).frame(minHeight: 44)
                                .background(KaraokeControlSurface())
                                .contentShape(Rectangle())
                        }
                        .accessibilityHint("Pause automatic scrolling")
                    } else if activeLine != nil {
                        Button { follows = true; scrollToCurrent(proxy) } label: {
                            Label("Back to current line", systemImage: "location.fill")
                                .padding(.horizontal, 12).frame(minHeight: 44)
                                .background(KaraokeControlSurface())
                                .contentShape(Rectangle())
                        }
                        .accessibilityIdentifier("shrubify.lyrics.resume-follow")
                    }
                }
                .font(.subheadline.weight(.semibold)).foregroundColor(.white).buttonStyle(.plain)
                if showsTiming { KaraokeTimingControls(offset: $offset) }
                observeBrowsing(ScrollView(showsIndicators: false) { lines(proxy) })
                    .accessibilityIdentifier("shrubify.lyrics.lines")
                    .scaleEffect(x: 1, y: reversed ? -1 : 1)
                    .onAppear { if let activeLine { proxy.scrollTo(activeLine, anchor: .center) } }
                    .onChange(of: activeLine) { _ in if follows { scrollToCurrent(proxy) } }
            }
        }
    }

    private func scrollToCurrent(_ proxy: ScrollViewProxy) {
        guard let activeLine else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.38)) {
            proxy.scrollTo(activeLine, anchor: .center)
        }
    }

    @ViewBuilder private func observeBrowsing<V: View>(_ scroll: V) -> some View {
        if #available(iOS 18.0, *) {
            scroll.onScrollPhaseChange { _, phase in
                if phase == .interacting { follows = false }
            }
        } else {
            // Observe, rather than consume, the native scroll gesture on iOS 17.
            scroll.simultaneousGesture(DragGesture(minimumDistance: 10).onChanged { drag in
                if abs(drag.translation.height) > abs(drag.translation.width) { follows = false }
            })
        }
    }
}
