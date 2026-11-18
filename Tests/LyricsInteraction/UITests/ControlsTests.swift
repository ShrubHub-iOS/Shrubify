import XCTest

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
    func testContentGlassRestoresReusedViewsAndLeavesNativeScrollAndTaps() {
        let app = XCUIApplication(); app.launch()
        let material = app.staticTexts["content-material-count"]
        XCTAssertTrue(material.waitForExistence(timeout: 10))
        XCTAssertEqual(material.label, "4 · intact")
        let action = app.staticTexts["content-action"]
        for (id, value) in [("Shortcut.Card.Home", "shortcut"), ("Album.Row.Library", "track"), ("SPTNowPlayingPlayButton", "play")] {
            app.buttons[id].tap(); XCTAssertEqual(action.label, value)
        }
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "native-content-glass"; capture.lifetime = .keepAlways; add(capture)
        app.buttons["toggle-glass"].tap(); XCTAssertEqual(material.label, "0 · intact")
        app.buttons["toggle-glass"].tap(); XCTAssertEqual(material.label, "4 · intact")
        app.buttons["reuse-row"].tap(); XCTAssertEqual(material.label, "3 · intact")
        app.buttons["unknown-row"].tap(); XCTAssertEqual(action.label, "track")
        let shelf = app.scrollViews["native-content-scroll"]
        let end = app.buttons["shelf-end"]
        for _ in 0..<3 where !end.isHittable { shelf.swipeLeft() }
        XCTAssertTrue(end.isHittable)
        end.tap(); shelf.swipeRight()
        XCTAssertEqual(action.label, "shelf end")
    }

    @MainActor
    func testWideNativeGlassDoesNotReplaceActionsOrMoveControls() {
        let app = XCUIApplication(); app.launch()
        let state = app.staticTexts["material-state"]
        XCTAssertTrue(state.waitForExistence(timeout: 10))
        XCTAssertEqual(state.label, "glass · frames intact · backing cleared · 5 icons")
        for index in 0..<5 { app.buttons["TabBar.Item.fixture-\(index)"].tap() }
        XCTAssertEqual(app.staticTexts["tab-count"].label, "5")
        app.buttons["toggle-glass"].tap()
        XCTAssertEqual(state.label, "native · frames intact · backing intact · 0 icons")
        app.buttons["TabBar.Item.fixture-0"].tap()
        XCTAssertEqual(app.staticTexts["tab-count"].label, "6")
        app.buttons["toggle-glass"].tap()
        XCTAssertEqual(state.label, "glass · frames intact · backing cleared · 5 icons")
        app.buttons["TabBar.Item.fixture-4"].tap()
        XCTAssertEqual(app.staticTexts["tab-count"].label, "7")
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "native-glass-wide-dock"; capture.lifetime = .keepAlways; add(capture)
    }
}
