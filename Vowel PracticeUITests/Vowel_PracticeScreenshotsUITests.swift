// Vowel Practice
// (c) William Entriken
// See LICENSE

#if os(iOS)

import XCTest

final class Vowel_PracticeScreenshotsUITests: XCTestCase {

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-mockAudio", "arm"]
        setupSnapshot(app)
        app.launch()
    }

    @MainActor
    func testTakeScreenshots() throws {
        let app = XCUIApplication()

        // Give the analysis pipeline a moment to chew through the mocked
        // audio file (loaded automatically via the -mockAudio launch arg).
        sleep(2)

        // Main / formants page
        snapshot("01-Formants")

        // The view-mode toolbar is a segmented Picker. Its segments are
        // system-symbol images, so they are addressed via the picker's
        // segmented control rather than by labelled buttons.
        let segments = app.segmentedControls.firstMatch
        if segments.exists {
            let buttons = segments.buttons
            if buttons.count >= 2 {
                buttons.element(boundBy: 1).tap()
                sleep(1)
                snapshot("02-Charts")
            }
            if buttons.count >= 3 {
                buttons.element(boundBy: 2).tap()
                sleep(1)
                snapshot("03-Help")
            }
        }
    }
}

#endif
