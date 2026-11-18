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
            let seek = Int(app.staticTexts["seek-value"].label) ?? 0
            XCTAssertGreaterThan(seek, 100_000); XCTAssertLessThan(seek, 160_000)
            let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "lyrics-controls-cycle-\(cycle)"; capture.lifetime = .keepAlways; add(capture)
            close.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5)).tap()
            XCTAssertTrue(app.buttons["open-lyrics"].waitForExistence(timeout: 10))
            XCTAssertEqual(app.staticTexts["close-count"].label, "\(cycle)")
        }
    }

    @MainActor
    func testWideNativeGlassDoesNotReplaceActionsOrMoveControls() {
        let app = XCUIApplication(); app.launch()
        let state = app.staticTexts["material-state"]
        XCTAssertTrue(state.waitForExistence(timeout: 10))
        XCTAssertEqual(state.label, "glass · frames intact · backing cleared")
        for index in 0..<5 { app.buttons["native-tab-\(index)"].tap() }
        XCTAssertEqual(app.staticTexts["tab-count"].label, "5")
        app.buttons["toggle-glass"].tap()
        XCTAssertEqual(state.label, "native · frames intact · backing intact")
        app.buttons["native-tab-0"].tap()
        XCTAssertEqual(app.staticTexts["tab-count"].label, "6")
        app.buttons["toggle-glass"].tap()
        XCTAssertEqual(state.label, "glass · frames intact · backing cleared")
        app.buttons["native-tab-4"].tap()
        XCTAssertEqual(app.staticTexts["tab-count"].label, "7")
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "native-glass-wide-dock"; capture.lifetime = .keepAlways; add(capture)
    }
}
