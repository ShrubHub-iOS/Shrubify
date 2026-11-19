import XCTest
import UIKit

final class ControlsTests: XCTestCase {
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
            app.buttons["Play"].tap()
            XCTAssertTrue(app.buttons["Pause"].exists)
            let slider = app.sliders["Song position"]
            slider.coordinate(withNormalizedOffset: CGVector(dx: 1.0 / 3.0, dy: 0.5))
                .press(forDuration: 0.2, thenDragTo: slider.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)))
            let seek = Int(app.staticTexts["seek-value"].label.filter { $0.isNumber }) ?? 0
            XCTAssertGreaterThan(seek, 100_000); XCTAssertLessThan(seek, 160_000)
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
        XCTAssertTrue(lines.staticTexts["Lyric line 20"].isHittable)
        XCTAssertTrue(app.buttons["Play"].isHittable)
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
        for _ in 0..<8 where !last.isHittable { shelf.swipeLeft() }
        XCTAssertTrue(last.isHittable); last.tap()
        XCTAssertEqual(action.label, "track 15")
        XCTAssertEqual(state.label, "0 effects · intact · reused")
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "unobscured-content-with-bars-on"; capture.lifetime = .keepAlways; add(capture)
        app.buttons["toggle-glass"].tap()
        XCTAssertEqual(state.label, "0 effects · intact · reused")
        for id in ["Components.UI.CardLibrary.Artwork", "Encore.ImageView"] { assertSharpCover(app.images[id]) }
        let first = app.buttons["track-0"]
        for _ in 0..<8 where !first.isHittable { shelf.swipeRight() }
        XCTAssertTrue(first.isHittable); first.tap(); XCTAssertEqual(action.label, "track 0")
    }

    @MainActor
    func testOptionalBarBackingsDoNotReplaceActionsOrDecorateIcons() {
        let app = XCUIApplication(); app.launch()
        let state = app.staticTexts["material-state"]
        XCTAssertTrue(state.waitForExistence(timeout: 10))
        XCTAssertEqual(state.label, "0/0 bars · 0 wells · intact · native") // no preference set
        app.buttons["TabBar.Item.fixture-0"].tap()
        XCTAssertEqual(app.staticTexts["tab-count"].label, "1")
        app.buttons["toggle-glass"].tap()
        XCTAssertEqual(state.label, "1/1 bars · 0 wells · intact · cleared")
        for index in 0..<5 { app.buttons["TabBar.Item.fixture-\(index)"].tap() }
        XCTAssertEqual(app.staticTexts["tab-count"].label, "6")
        app.buttons["mini-play"].tap(); XCTAssertEqual(app.buttons["mini-play"].label, "Pause")
        app.buttons["toggle-glass"].tap()
        XCTAssertEqual(state.label, "0/0 bars · 0 wells · intact · native")
        app.buttons["TabBar.Item.fixture-4"].tap()
        XCTAssertEqual(app.staticTexts["tab-count"].label, "7")
    }
}
