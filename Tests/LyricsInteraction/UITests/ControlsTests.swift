import XCTest
import UIKit

final class ControlsTests: XCTestCase {
    @MainActor
    func testInlineLyricKeepsItsTapTargetAsTheLineChanges() {
        let app = XCUIApplication()
        app.launchArguments.append("inline-lyric-fixture")
        app.launch()
        let preview = app.buttons["shrubify.player.current-lyric"]
        XCTAssertTrue(preview.waitForExistence(timeout: 10))
        XCTAssertEqual(preview.label, "First lyric")
        let frame = preview.frame
        app.buttons["Advance lyric"].tap()
        XCTAssertEqual(preview.label, "Next lyric")
        XCTAssertEqual(preview.frame, frame)
        preview.tap()
        XCTAssertEqual(app.staticTexts["live-preview-status"].label, "Lyrics opened")
    }

    @MainActor
    func testFullscreenReturnsTheSameInteractivePlayer() {
        let app = XCUIApplication()
        app.launchArguments.append("inline-lyric-fixture")
        app.launch()
        let button = app.buttons["fixture-player-fullscreen"]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        app.buttons["Advance lyric"].tap()
        for _ in 0..<2 {
            button.tap()
            XCTAssertEqual(button.label, "Exit fullscreen")
            XCTAssertEqual(app.buttons["shrubify.player.current-lyric"].label, "Next lyric")
            button.tap()
            XCTAssertEqual(button.label, "Enter fullscreen")
            XCTAssertEqual(app.buttons["shrubify.player.current-lyric"].label, "Next lyric")
        }
        button.tap()
        app.buttons["Minimize"].tap()
        XCTAssertEqual(button.label, "Enter fullscreen")
        XCTAssertEqual(app.staticTexts["live-preview-status"].label, "Ready for native action")
        button.tap()
        app.buttons["Open artist page"].tap()
        XCTAssertEqual(button.label, "Enter fullscreen")
        XCTAssertEqual(app.staticTexts["live-preview-status"].label, "Artist opened in app")
        app.buttons["shrubify.player.current-lyric"].tap()
        XCTAssertEqual(app.staticTexts["live-preview-status"].label, "Lyrics opened")
    }

    @MainActor
    func testTimingAndDismissalAtButtonEdgesDuringLiveUpdates() {
        let app = XCUIApplication(); app.launch()
        for cycle in 1...3 {
            app.buttons["open-lyrics"].tap()
            let close = app.buttons["shrubify.lyrics.close"]
            XCTAssertTrue(close.waitForExistence(timeout: 10))
            let earlier = app.buttons["shrubify.lyrics.earlier"]
            let later = app.buttons["shrubify.lyrics.later"]
            let reset = app.buttons["shrubify.lyrics.reset"]
            let value = app.staticTexts["offset-value"]
            XCTAssertFalse(later.exists)
            app.buttons["shrubify.lyrics.sync"].tap()
            // These points are deliberately away from the small symbol strokes.
            later.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.15)).tap()
            XCTAssertEqual(value.label, "100")
            earlier.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.85)).tap()
            XCTAssertEqual(value.label, "0")
            earlier.tap(); XCTAssertEqual(value.label, "-100")
            reset.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5)).tap()
            XCTAssertEqual(value.label, "0")
            // Keep the existing production play and slider controls functional.
            app.buttons["Play"].coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5)).tap()
            XCTAssertTrue(app.buttons["Pause"].exists)
            let slider = app.sliders["Song position"]
            // Keep the touch at its destination long enough for hosted simulators
            // to deliver the final drag update before the slider commits its seek.
            slider.coordinate(withNormalizedOffset: CGVector(dx: 1.0 / 3.0, dy: 0.5))
                .press(forDuration: 0.2,
                       thenDragTo: slider.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)),
                       withVelocity: .slow, thenHoldForDuration: 0.4)
            let seek = Int(app.staticTexts["seek-value"].label.filter { $0.isNumber }) ?? 0
            // XCUITest coordinates are normalized against the accessibility
            // frame, whose track insets vary. Check that playback moved forward
            // from the 60-second fixture position and stayed within the song.
            XCTAssertGreaterThan(seek, 75_000)
            XCTAssertLessThan(seek, 180_000)
            let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "lyrics-controls-cycle-\(cycle)"; capture.lifetime = .keepAlways; add(capture)
            close.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5)).tap()
            XCTAssertTrue(app.buttons["open-lyrics"].waitForExistence(timeout: 10))
            XCTAssertEqual(app.staticTexts["close-count"].label, "\(cycle)")
        }
    }

    @MainActor
    func testBrowseAndReturnToPlayingLine() {
        let app = XCUIApplication(); app.launch()
        app.buttons["open-lyrics"].tap()
        let lines = app.scrollViews["shrubify.lyrics.lines"]
        XCTAssertTrue(lines.waitForExistence(timeout: 10))
        let resume = app.buttons["shrubify.lyrics.resume-follow"]
        XCTAssertFalse(resume.exists)
        lines.swipeUp()
        XCTAssertTrue(resume.waitForExistence(timeout: 5))
        resume.tap()
        XCTAssertFalse(resume.exists)
        // `resume-follow` animates the list back to the playing line. Asking for
        // hittability while that line is still off-screen is not a `false`:
        // XCUITest records "Failed to determine hittability … activation point
        // invalid" as a hard failure, so the assertion used to race the
        // animation and fail the whole run. Wait (bounded) for the line to land
        // inside the scroll view, then assert the same thing as before.
        let playingLine = lines.staticTexts["Lyric line 20"]
        XCTAssertTrue(
            waitUntilInside(playingLine, in: lines),
            "the lyrics did not scroll back to the playing line"
        )
        XCTAssertTrue(app.buttons["Play"].isHittable)
    }

    /// Bounded wait until `element` sits fully inside `container`. Frames are
    /// safe to read at any time, while `isHittable` on a line that is still
    /// off-screen raises a hard XCUITest issue ("activation point invalid")
    /// instead of returning false — which is what failed this test.
    @MainActor
    private func waitUntilInside(
        _ element: XCUIElement,
        in container: XCUIElement,
        timeout: TimeInterval = 5
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists, element.frame.height > 1, container.frame.contains(element.frame) {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return false
    }

    @MainActor
    private func assertSharpCover(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        // Sample the rendered pixels, not UIImage identity: a glass layer over
        // an unchanged image still destroys this checkerboard's local contrast.
        guard element.waitForExistence(timeout: 5), let image = element.screenshot().image.cgImage,
              let gray = CGContext(data: nil, width: 80, height: 80, bitsPerComponent: 8, bytesPerRow: 80,
                                   space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue),
              let pixels = gray.data?.assumingMemoryBound(to: UInt8.self) else {
            return XCTFail("Could not sample cover", file: file, line: line)
        }
        gray.draw(image, in: CGRect(x: 0, y: 0, width: 80, height: 80))
        var contrast = 0
        for y in 4..<12 { for x in 4..<12 {
            let index = (5 * y + 2) * gray.bytesPerRow + 5 * x + 2
            contrast += abs(Int(pixels[index]) - Int(pixels[index + 5]))
        } }
        XCTAssertGreaterThan(contrast / 64, 220, "Cover is obscured", file: file, line: line)
    }

    @MainActor
    func testSavedGlassPreferenceLeavesCoversSharpAndRecycledShelfNative() {
        let app = XCUIApplication(); app.launchArguments.append("saved-glass-on"); app.launch()
        let state = app.staticTexts["content-state"]
        XCTAssertTrue(state.waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["material-state"].label, "1/1 bars · 0 wells · intact · cleared")
        XCTAssertTrue(state.label.hasPrefix("0 effects · intact"))
        for id in ["Components.UI.CardLibrary.Artwork", "Encore.ImageView"] { assertSharpCover(app.images[id]) }
        let action = app.staticTexts["content-action"]
        for (id, value) in [("Shortcut.Card.Home", "shortcut"), ("track-0", "track 0"), ("SPTNowPlayingPlayButton", "play")] {
            app.buttons[id].tap(); XCTAssertEqual(action.label, value)
        }
        let shelf = app.collectionViews["native-shelf"]
        let last = app.buttons["track-15"]
        for _ in 0..<8 {
            if last.exists && shelf.frame.contains(last.frame) { break }
            shelf.swipeLeft()
        }
        XCTAssertTrue(waitUntilInside(last, in: shelf))
        XCTAssertTrue(last.isHittable); last.tap()
        XCTAssertEqual(action.label, "track 15")
        XCTAssertEqual(state.label, "0 effects · intact · reused")
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "unobscured-content-with-bars-on"; capture.lifetime = .keepAlways; add(capture)
        app.buttons["toggle-glass"].tap()
        XCTAssertEqual(state.label, "0 effects · intact · reused")
        for id in ["Components.UI.CardLibrary.Artwork", "Encore.ImageView"] { assertSharpCover(app.images[id]) }
        let first = app.buttons["track-0"]
        // Scroll all the way back instead of asking for hittability of a cell
        // the shelf has already carried off screen: XCTest fails that query
        // ("activation point invalid") rather than answering false.
        for _ in 0..<8 { shelf.swipeRight() }
        XCTAssertTrue(first.waitForExistence(timeout: 5)); XCTAssertTrue(first.isHittable)
        first.tap(); XCTAssertEqual(action.label, "track 0")
    }

    @MainActor
    func testOptionalBarBackingsDoNotReplaceActionsOrDecorateIcons() {
        let app = XCUIApplication(); app.launch()
        let state = app.staticTexts["material-state"]
        XCTAssertTrue(state.waitForExistence(timeout: 10))
        XCTAssertEqual(state.label, "1/1 bars · 0 wells · intact · cleared") // glass ships on
        XCTAssertEqual(app.staticTexts["selection-state"].label, "Tab 0 native-selected · 0 overlays")
        XCTAssertEqual(app.staticTexts["optical-selection"].label, "Lens under tab 0")
        let first = app.buttons["TabBar.Item.fixture-0"].frame
        let last = app.buttons["TabBar.Item.fixture-4"].frame
        let tile = app.buttons["TabBar.Item.fixture-2"].frame
        app.buttons["mini-play"].tap()
        XCTAssertEqual(state.label, "1/1 bars · 0 wells · intact · cleared")
        XCTAssertEqual(app.staticTexts["optical-selection"].label, "Lens under tab 0")
        XCTAssertEqual(app.buttons["TabBar.Item.fixture-0"].frame, first)
        XCTAssertEqual(app.buttons["TabBar.Item.fixture-4"].frame, last)
        // Use the controls to locate the capsule. Sample its center and both
        // sides in the same frame, well within the old full-width backing.
        let probes = [
            ("inside the glass", CGPoint(x: tile.minX + 14, y: tile.midY - 18)),
            ("left of the capsule", CGPoint(x: first.minX - 44, y: tile.midY - 18)),
            ("right of the capsule", CGPoint(x: last.maxX + 44, y: tile.midY - 18)),
        ]
        let window = app.frame
        let redFrame = app.screenshot().image
        app.buttons["swap-dock-backdrop"].tap()
        let blueFrame = app.screenshot().image
        for (location, point) in probes {
            guard let red = redMinusBlue(at: point, bounds: window, snapshot: redFrame),
                  let blue = redMinusBlue(at: point, bounds: window, snapshot: blueFrame) else {
                XCTFail("Could not sample \(location) at \(point) in \(window)")
                continue
            }
            XCTAssertGreaterThan(red - blue, 16,
                                 "Dock covers the changing page \(location): \(red) → \(blue) at \(point)")
        }
        app.buttons["TabBar.Item.fixture-2"].tap()
        XCTAssertEqual(app.staticTexts["selection-state"].label, "Tab 2 native-selected · 0 overlays")
        XCTAssertEqual(app.staticTexts["optical-selection"].label, "Lens under tab 2")
        XCTAssertEqual(app.staticTexts["tab-count"].label, "1")
        app.buttons["toggle-glass"].tap()
        XCTAssertEqual(state.label, "0/0 bars · 0 wells · intact · native", state.value as? String ?? "")
        XCTAssertEqual(app.staticTexts["selection-state"].label, "Tab 2 native-selected · 0 overlays")
        XCTAssertEqual(app.staticTexts["optical-selection"].label, "No selection lens")
        for index in 0..<5 { app.buttons["TabBar.Item.fixture-\(index)"].tap() }
        XCTAssertEqual(app.staticTexts["tab-count"].label, "6")
        XCTAssertEqual(app.buttons["mini-play"].label, "Pause")
        app.buttons["toggle-glass"].tap()
        XCTAssertEqual(state.label, "1/1 bars · 0 wells · intact · cleared")
        app.buttons["TabBar.Item.fixture-4"].tap()
        XCTAssertEqual(app.staticTexts["tab-count"].label, "7")
        XCTAssertEqual(app.staticTexts["selection-state"].label, "Tab 4 native-selected · 0 overlays")
        XCTAssertEqual(app.staticTexts["optical-selection"].label, "Lens under tab 4")
    }

    @MainActor
    private func redMinusBlue(at point: CGPoint, bounds: CGRect, snapshot: UIImage) -> Int? {
        guard bounds.width > 0, bounds.height > 0, bounds.contains(point),
              let image = snapshot.cgImage else { return nil }
        let x = (point.x - bounds.minX) * CGFloat(image.width) / bounds.width
        let y = (point.y - bounds.minY) * CGFloat(image.height) / bounds.height
        guard let area = image.cropping(to: CGRect(x: x - 3, y: y - 3, width: 6, height: 6)),
              let context = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let pixels = context.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        context.interpolationQuality = .high
        context.draw(area, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return Int(pixels[0]) - Int(pixels[2])
    }
}
