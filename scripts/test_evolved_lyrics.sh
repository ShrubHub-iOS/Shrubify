#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_BUILD=$(mktemp -d)
trap 'rm -rf "$TEST_BUILD"' EXIT
echo 'SpicyLyrics v1 JSON mapping + syllable join + attribution'
swiftc Sources/EeveeSpotify/Lyrics/Repositories/SLObjPack.swift \
       Sources/EeveeSpotify/Lyrics/Models/LyricsWordDto.swift \
       Sources/EeveeSpotify/Lyrics/Models/SpicySyllableText.swift \
       Sources/EeveeSpotify/Lyrics/Models/SpicyLineFilter.swift \
       Sources/EeveeSpotify/Lyrics/Models/LyricsContributor.swift \
       Sources/EeveeSpotify/Lyrics/Models/SpicyLyricsAttribution.swift \
       Tests/SpicyLyricsJsonMapping/main.swift \
       -o "$TEST_BUILD/spicy-lyrics-json-mapping-tests"
"$TEST_BUILD/spicy-lyrics-json-mapping-tests"

echo 'Lyric interlude timeline + dots presentation'
swiftc Sources/EeveeSpotify/Lyrics/AppleMusic/LyricModels.swift \
       Sources/EeveeSpotify/Lyrics/AppleMusic/LyricInterlude.swift \
       Sources/EeveeSpotify/Lyrics/AppleMusic/LyricInterludeTimeline.swift \
       Sources/EeveeSpotify/Lyrics/AppleMusic/LyricVocalDurationEstimator.swift \
       Sources/EeveeSpotify/Lyrics/AppleMusic/AppleMusicInterludeMotionProfile.swift \
       Sources/EeveeSpotify/Lyrics/AppleMusic/AppleMusicInterludeDotsPresentation.swift \
       Tests/LyricInterludeTimeline/main.swift \
       -o "$TEST_BUILD/lyric-interlude-tests"
"$TEST_BUILD/lyric-interlude-tests"

echo 'Lyrics door phase rules (player lyrics layer)'
swiftc Sources/EeveeSpotify/Appearance/LyricsDoorPhase.swift \
       Tests/LyricsDoorPhase/main.swift \
       -o "$TEST_BUILD/lyrics-door-phase-tests"
"$TEST_BUILD/lyrics-door-phase-tests"

echo 'Lyric line break fitting (no extra line breaks)'
swiftc Sources/EeveeSpotify/Lyrics/AppleMusic/LyricLineBreakFitting.swift \
       Tests/LyricLineBreakFitting/main.swift \
       -o "$TEST_BUILD/lyric-line-break-fitting-tests"
"$TEST_BUILD/lyric-line-break-fitting-tests"

echo 'Lyrics line splitting (LRCLIB trailing newline)'
swiftc Sources/EeveeSpotify/Lyrics/Models/LyricsLineSplitting.swift \
       Tests/LrclibLineSplitting/main.swift \
       -o "$TEST_BUILD/lrclib-line-splitting-tests"
"$TEST_BUILD/lrclib-line-splitting-tests"

echo 'Lyrics match (title / artist / length)'
swiftc Sources/EeveeSpotify/Lyrics/Models/LyricsMatch.swift \
       Tests/LyricsMatch/main.swift \
       -o "$TEST_BUILD/lyrics-match-tests"
"$TEST_BUILD/lyrics-match-tests"

echo 'QQ QRC DES variant (decrypt + inflate)'
swiftc Sources/EeveeSpotify/Lyrics/Models/QrcDES.swift \
       Sources/EeveeSpotify/Lyrics/Models/ZlibInflate.swift \
       Tests/QrcDES/main.swift \
       -o "$TEST_BUILD/qrc-des-tests"
"$TEST_BUILD/qrc-des-tests"

echo 'QQ QRC payload wrapper (bare quotes in the attribute)'
swiftc Sources/EeveeSpotify/Lyrics/Models/QrcPayloadWrapper.swift \
       Tests/QrcPayloadWrapper/main.swift \
       -o "$TEST_BUILD/qrc-payload-wrapper-tests"
"$TEST_BUILD/qrc-payload-wrapper-tests"

echo 'KuGou KRC romaji repair (kana leftovers)'
swiftc Sources/EeveeSpotify/Lyrics/Models/JapaneseKanaRomanization.swift \
       Sources/EeveeSpotify/Lyrics/Models/JapaneseRomajiRepair.swift \
       Tests/KuGouRomaji/main.swift \
       -o "$TEST_BUILD/kugou-romaji-repair-tests"
"$TEST_BUILD/kugou-romaji-repair-tests"

echo 'AMLL TTML ruby annotations + background-vocal DTO'
swiftc Sources/EeveeSpotify/Lyrics/Models/Amll/AmllTtmlDocument.swift \
       Sources/EeveeSpotify/Lyrics/Models/Amll/AmllTtmlParser.swift \
       Sources/EeveeSpotify/Lyrics/Models/LyricsError.swift \
       Sources/EeveeSpotify/Lyrics/Models/LyricsWordDto.swift \
       Sources/EeveeSpotify/Lyrics/Models/LyricsBackgroundVocalDto.swift \
       Sources/EeveeSpotify/Lyrics/Models/LyricsMatch.swift \
       Sources/EeveeSpotify/Lyrics/Repositories/LyricsMarkers.swift \
       Tests/AmllTtmlRuby/main.swift \
       -o "$TEST_BUILD/amll-ttml-ruby-tests"
"$TEST_BUILD/amll-ttml-ruby-tests"

echo 'Apple Music official TTML compatibility'
swiftc Sources/EeveeSpotify/Lyrics/Models/Amll/AmllTtmlDocument.swift \
       Sources/EeveeSpotify/Lyrics/Models/Amll/AmllTtmlParser.swift \
       Sources/EeveeSpotify/Lyrics/Models/LyricsError.swift \
       Sources/EeveeSpotify/Lyrics/Models/LyricsWordDto.swift \
       Sources/EeveeSpotify/Lyrics/Models/LyricsBackgroundVocalDto.swift \
       Sources/EeveeSpotify/Lyrics/Models/LyricsMatch.swift \
       Sources/EeveeSpotify/Lyrics/Repositories/LyricsMarkers.swift \
       Tests/AmllTtmlApple/main.swift \
       -o "$TEST_BUILD/amll-ttml-apple-tests"
"$TEST_BUILD/amll-ttml-apple-tests"

echo 'Lyrics notice policy (what we say when there is nothing to draw)'
swiftc Sources/EeveeSpotify/Appearance/LyricsNoticePolicy.swift \
       Tests/LyricsNoticePolicy/main.swift \
       -o "$TEST_BUILD/lyrics-notice-policy-tests"
"$TEST_BUILD/lyrics-notice-policy-tests"
