import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

func check(_ value: @autoclosure () -> Bool, _ message: String) {
    guard value() else { fatalError(message) }
}
let uploader = LyricsContributor(role: .uploader, name: "Contributor", url: URL(string: "https://example.org/uploader"))
let wordLine = LyricsLineDto(content: "Hello world", offsetMs: 100, endOffsetMs: 900,
    words: [LyricsWordDto(text: "Hel", startMs: 100, endMs: 200), LyricsWordDto(text: "lo", startMs: 200, endMs: 300),
            LyricsWordDto(text: "world", startMs: 500, endMs: 800)])
let rich = KaraokeLyricsAdapter.convert(lines: [wordLine], timeSynced: true, providerName: "AMLL", contributors: [uploader])!
check(rich.lines[0].plainText == "Hello world", "Syllables must preserve original word boundaries")
check(rich.lines[0].words.count == 2 && rich.lines[0].words[0].count == 2, "Grouped syllables must stay one rendered word")
check(rich.lines[0].syllables[2].startMs == 500 && rich.lines[0].syllables[2].endMs == 800, "Real word times must survive conversion")
check(rich.providerName == "AMLL" && rich.uploaderName == "Contributor" && rich.uploaderUrl == uploader.url?.absoluteString,
      "Actual provider and clickable community credits must survive")
let chinese = LyricsLineDto(content: "你好", offsetMs: 0, words: [LyricsWordDto(text: "你", startMs: 0, endMs: 200), LyricsWordDto(text: "好", startMs: 200, endMs: 400)])
let cjk = KaraokeLyricsAdapter.convert(lines: [chinese], timeSynced: true, providerName: "QQ Music")!
check(cjk.lines[0].plainText == "你好", "Do not insert spaces between CJK syllables")
let plain = [LyricsLineDto(content: "Second line", offsetMs: 2000), LyricsLineDto(content: "First line", offsetMs: 1000), LyricsLineDto(content: "", offsetMs: 3000)]
let lineOnly = KaraokeLyricsAdapter.convert(lines: plain, timeSynced: true, providerName: "LRCLIB")!
check(lineOnly.lines.count == 2 && lineOnly.lines[0].plainText == "First line", "Stable ordering and blank-line filtering")
check(lineOnly.lines[0].endMs == 2000 && lineOnly.lines[1].endMs == 3000, "Blank timing markers must still close the preceding line")
check(lineOnly.lines[0].syllables.allSatisfy { $0.startMs == 1000 && $0.endMs == 1000 }, "Do not invent word timing for line-only sources")
check(KaraokeLyricsAdapter.convert(lines: plain, timeSynced: false, providerName: "Genius") == nil, "Untimed text must not become fake karaoke")
let rtl = KaraokeLyricsAdapter.convert(lines: [LyricsLineDto(content: "שלום עולם", offsetMs: 0)], timeSynced: true, providerName: "PetitLyrics")!
check(rtl.isRTL && rtl.lines[0].plainText == "שלום עולם", "Restore the original RTL model")
let partialLine = LyricsLineDto(content: "Hello, missing words!", offsetMs: 500, endOffsetMs: 1400,
    words: [LyricsWordDto(text: "Hello", startMs: 600, endMs: 800), LyricsWordDto(text: "words", startMs: 1100, endMs: 1300)])
let partial = KaraokeLyricsAdapter.convert(lines: [partialLine, LyricsLineDto(content: "Next", offsetMs: 2000)],
                                           timeSynced: true, providerName: "Test")!
check(partial.lines[0].syllables.plainText == "Hello, missing words!", "Rendering retains untimed words and punctuation")
check(partial.lines[0].syllables.filter { $0.endMs > $0.startMs }.map(\.text) == ["Hello", "words"],
      "Preserved text does not gain fake word timing")
check(partial.timingLabel == "Partial word sync", "Mixed timing is labeled separately")
check(partial.activeLineIndex(at: 499, requiresActiveInterval: true) == nil
    && partial.activeLineIndex(at: 900, requiresActiveInterval: true) == 0
    && partial.activeLineIndex(at: 1500, requiresActiveInterval: true) == nil
    && partial.activeLineIndex(at: 2000, requiresActiveInterval: true) == 1, "Live lyric follows real intervals")
for time in stride(from: 1400, to: 2000, by: 100) {
    check(partial.previewLineIndex(at: time) == 0, "The live preview must not flash off between lines")
    check(partial.lines[0].highlightRange(at: time) == nil, "Do not extend word emphasis into the gap")
}
check(partial.previewLineIndex(at: 2000) == 1 && partial.previewLineIndex(at: 499) == nil,
      "The preview advances on time and rewinds on a backward seek")
var longGap = partial
longGap.lines[1].startMs = 12_000
longGap.lines[1].endMs = 15_000
check(longGap.previewLineIndex(at: 6000) == nil && longGap.previewLineIndex(at: 15_000) == nil,
      "The preview clears during long instrumental gaps and at the end of lyrics")
check(partial.lines[0].highlightRange(at: 500) == nil, "Untimed parts do not become active words")
if let range = partial.lines[0].highlightRange(at: 1150) {
    check(partial.lines[0].plainText[range] == "words", "A preview highlights the active provider-timed word")
} else { fatalError("Expected a timed word") }
let payload = try JSONDecoder().decode(LyricsPlusPayload.self, from: Data("""
{
    "type":"Word",
    "metadata":{"language":"en"},
    "processingTime":{"selectedSongMetadata":{"title":"Fixture","artist":"Artist","duration":"182.5"}},
    "lyrics":[{"time":1000,"duration":900,"text":"Wait up!","syllabus":[
        {"time":"1050","duration":200,"text":"Wait"},
        {"time":1500,"duration":300,"text":"up"}
    ]},{"time":2000,"duration":800,"text":"Partial","syllabus":[{"time":"NaN","text":"Partial"}]}]
}
""".utf8))
let query = LyricsSearchQuery(title: "Fixture", primaryArtist: "Artist", spotifyTrackId: "id", durationMs: 182_500)
check(payload.matches(query) && payload.isTimed && payload.language == "en", "Accept matching LyricsPlus replies")
var wrong = query
wrong.durationMs = 170_000
check(!payload.matches(wrong), "Reject the wrong recording even when the title and artist match")
check(payload.lines[0].offsetMs == 1000 && payload.lines[0].endOffsetMs == 1900
    && payload.lines[0].words?.last?.endMs == 1800, "LyricsPlus milliseconds preserve line and word boundaries")
check(payload.lines[1].words?.isEmpty == true, "Malformed tokens keep readable line timing")
let staticPayload = try JSONDecoder().decode(LyricsPlusPayload.self, from: Data(
    #"{"type":"None","lyrics":[{"time":0,"duration":0,"text":"Plain text"}]}"#.utf8))
check(!staticPayload.isTimed && staticPayload.lines.first?.offsetMs == nil, "Plain LyricsPlus text stays untimed")
print("Original custom lyrics adapter: syllables, CJK/RTL, timing, line-only sources and credits passed")

// Tone mapping preserves color while capping every background luminance.
for red in 0...10 { for green in 0...10 { for blue in 0...10 {
    let color = KaraokeReadability.toneMap(red: Double(red) / 10, green: Double(green) / 10, blue: Double(blue) / 10)
    let background = 0.2126 * KaraokeReadability.linear(color.red) + 0.7152 * KaraokeReadability.linear(color.green) + 0.0722 * KaraokeReadability.linear(color.blue)
    check(background <= KaraokeReadability.maximumBackgroundLuminance + 1e-9, "All artwork colors must meet the luminance cap")
    let foreground = KaraokeReadability.unsungTextOpacity + background * (1 - KaraokeReadability.unsungTextOpacity)
    check((foreground + 0.05) / (background + 0.05) >= 4.5, "Unsung lyrics must retain normal-text AA contrast without a black panel")
}}}
let vivid = KaraokeReadability.toneMap(red: 1, green: 0, blue: 0)
check(vivid.red > 0.7 && vivid.green == 0 && vivid.blue == 0, "Do not turn artwork into neutral black/gray")
check(KaraokeTiming.adjustedOffset(4900, step: 100) == 5000 && KaraokeTiming.adjustedOffset(5000, step: 100) == 5000, "Clamp later adjustment")
check(KaraokeTiming.adjustedOffset(-4900, step: -100) == -5000 && KaraokeTiming.adjustedOffset(-5000, step: -100) == -5000, "Clamp earlier adjustment")
check(KaraokeTiming.adjustedOffset(Int.max, step: 100) == 5000, "Invalid stored offset cannot overflow")
for (position, expected) in [(50, 0.0), (100, 0), (150, 0.5), (200, 1), (500, 1)] {
    check(KaraokeTiming.progress(position: position, start: 100, end: 200) == expected, "Real word timestamps drive the fill")
}
check(KaraokeTiming.progress(position: 120, start: 100, end: 200) == 0.2, "A backward seek must rewind word fill")
check(KaraokeTiming.progress(position: 99, start: 100, end: 100) == 0 && KaraokeTiming.progress(position: 100, start: 100, end: 100) == 1, "Line-only text switches at its real line start")
print("Artwork contrast: 1,331 RGB colors; live timing bounds and real word-fill progression passed")

for width in [320.0, 420, 768, 1024, 1366] {
    let bounds = CGRect(x: 0, y: 0, width: width, height: 64)
    let content = CGRect(x: 0, y: 4, width: min(400, width), height: 48)
    for mini in [false, true] {
        let frame = NativeGlassGeometry.frame(bounds: bounds, content: content, miniPlayer: mini)!
        check(bounds.contains(frame), "Glass must stay within its actual host after rotation or split-screen")
        check(frame.height <= 96 && frame.width <= 680, "No oversized glass backing")
    }
}
check(NativeGlassGeometry.frame(bounds: .zero, content: .zero, miniPlayer: false) == nil, "Ignore unmeasured views")
check(NativeGlassGeometry.frame(bounds: CGRect(x: 0, y: 0, width: 1366, height: 900), content: CGRect(x: 0, y: 0, width: 1366, height: 900), miniPlayer: false) == nil, "Never decorate a whole tablet page")
check(NativeGlassGeometry.frame(bounds: CGRect(x: 0, y: 0, width: 400, height: 64), content: CGRect(x: 0, y: 0, width: CGFloat.infinity, height: 48), miniPlayer: true) == nil, "Reject invalid measurements")
print("Native glass bounds: phone/tablet widths, split-screen and invalid geometry passed")

let dock = NativeGlassGeometry.frame(bounds: CGRect(x: 0, y: 0, width: 720, height: 84), content: CGRect(x: 0, y: 0, width: 666, height: 76), miniPlayer: false)
check(dock != nil && dock!.width <= 720, "The native five-tab tablet dock must receive glass")

let wideDockBounds = CGRect(x: 0, y: 0, width: 825, height: 84)
check(NativeGlassGeometry.frame(bounds: wideDockBounds, content: wideDockBounds, miniPlayer: false, tabCount: 5) == nil,
      "Never cover an uncompacted 825pt native dock with a grey glass slab")
let compactDock = CGRect(x: 192, y: 4, width: 441, height: 72)
let compactGlass = NativeGlassGeometry.frame(bounds: wideDockBounds, content: compactDock, miniPlayer: false, tabCount: 5)
check(compactGlass != nil && compactGlass!.width < 460 && wideDockBounds.contains(compactGlass!),
      "After native tab margins settle, one compact capsule must include all five tabs")
