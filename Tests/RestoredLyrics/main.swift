import Foundation

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
print("Original custom lyrics adapter: syllables, CJK/RTL, timing, line-only sources and credits passed")

// Conservative linear-light composition: every cover luminance must retain
// at least AAA normal-text contrast, including unsung words on a white cover.
for step in 0...1000 {
    let background = Double(step) / 1000 * (1 - KaraokeReadability.backgroundDimOpacity)
    let foreground = KaraokeReadability.unsungTextOpacity + background * (1 - KaraokeReadability.unsungTextOpacity)
    check((foreground + 0.05) / (background + 0.05) >= 7, "Lyrics must remain readable over every cover luminance")
}
print("Lyrics contrast passed for 1,001 cover luminances")
