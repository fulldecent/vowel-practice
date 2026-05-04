// Vowel Practice
// (c) William Entriken
// See LICENSE

#if os(macOS)

import XCTest

/// macOS screenshot capture for Mac App Store submission.
///
/// Fastlane's `snapshot` action does not actually capture on macOS, so we
/// drive the host app via launch arguments: it resizes its own window to an
/// App Store-acceptable aspect ratio and writes a PNG to the path we give
/// it. The test simply waits for the file to appear, then attaches it to
/// the test result bundle so fastlane can collect it via `xcresulttool`.
final class Vowel_PracticeScreenshotsMacUITests: XCTestCase {

    private static let outputDirectory: URL = {
        // Use a system-wide path so the host app (unsandboxed) and the test
        // runner (sandboxed inside xctrunner.app's container) can both
        // see it.
        let dir = URL(fileURLWithPath: "/tmp/vowel-practice-mac-screenshots")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testTakeScreenshots() throws {
        try captureScreen(named: "01-Formants", viewMode: "formant")
        try captureScreen(named: "02-Charts",   viewMode: "chart")
        try captureScreen(named: "03-Help",     viewMode: "help")
    }

    // MARK: - Helpers

    private func captureScreen(named name: String, viewMode: String) throws {
        let outputURL = Self.outputDirectory.appendingPathComponent("Mac-\(name).png")
        try? FileManager.default.removeItem(at: outputURL)

        let app = XCUIApplication()
        app.launchArguments = [
            "-viewMode", viewMode,
            "-mockAudio", "arm",
            "-screenshotSize", "1440x900",
            "-captureScreenshotTo", outputURL.path
        ]
        app.launch()
        app.activate()

        // Wait for the host app to write the PNG (it does so 2.5s after
        // launch). Allow up to 15s for slow CI or first-launch overhead.
        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline && !FileManager.default.fileExists(atPath: outputURL.path) {
            Thread.sleep(forTimeInterval: 0.25)
        }
        guard FileManager.default.fileExists(atPath: outputURL.path) else {
            XCTFail("Host app never wrote screenshot to \(outputURL.path)")
            app.terminate()
            return
        }

        let data = try Data(contentsOf: outputURL)
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        attachment.name = "Mac-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
        NSLog("snapshot: %@ (%d bytes)", outputURL.path, data.count)

        app.terminate()
        Thread.sleep(forTimeInterval: 0.5)
    }
}

#endif
