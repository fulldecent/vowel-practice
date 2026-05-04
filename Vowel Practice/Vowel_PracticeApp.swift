// Vowel Practice
// (c) William Entriken
// See LICENSE

import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct Vowel_PracticeApp: App {
    @StateObject private var viewModel = AppViewModel()
    #if os(macOS)
    @NSApplicationDelegateAdaptor(ScreenshotAppDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(viewModel)
        }
        #if os(macOS)
        // App Store screenshots on macOS must match a supported aspect
        // ratio (1280×800, 1440×900, 2560×1600 or 2880×1800).
        .defaultSize(width: 1440, height: 900)
        #endif
    }
}

#if os(macOS)
/// Handles `-screenshotSize WxH` and `-captureScreenshotTo PATH` launch
/// arguments used by the macOS UI test target. The app resizes its main
/// window to a screenshot-friendly aspect ratio and writes a PNG of the
/// window's content view to the requested path.
final class ScreenshotAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = CommandLine.arguments
        NSLog("ScreenshotAppDelegate: args=\(args)")

        var targetSize: NSSize?
        if let i = args.firstIndex(of: "-screenshotSize"), i + 1 < args.count {
            let parts = args[i + 1].lowercased().split(separator: "x")
            if parts.count == 2,
               let w = Double(parts[0]), let h = Double(parts[1]) {
                targetSize = NSSize(width: w, height: h)
            }
        }

        var capturePath: String?
        if let i = args.firstIndex(of: "-captureScreenshotTo"), i + 1 < args.count {
            capturePath = args[i + 1]
        }

        guard targetSize != nil || capturePath != nil else { return }

        // Run several resize passes — SwiftUI restores window state
        // asynchronously and may overwrite our setFrame() if we resize too
        // early.
        let resizeDelays: [TimeInterval] = [0.0, 0.25, 0.5, 1.0, 1.5, 2.0]
        for delay in resizeDelays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                if let size = targetSize { Self.resizeFrontWindow(to: size) }
            }
        }
        if let path = capturePath {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                Self.captureFrontWindow(to: path)
            }
        }
    }

    static func resizeFrontWindow(to size: NSSize) {
        for window in NSApplication.shared.windows where window.isVisible && window.contentView != nil {
            let screenFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
            let origin = NSPoint(
                x: screenFrame.minX + (screenFrame.width - size.width) / 2,
                y: screenFrame.minY + (screenFrame.height - size.height) / 2
            )
            window.setFrame(NSRect(origin: origin, size: size), display: true)
            NSLog("resizeFrontWindow: set frame to \(NSStringFromRect(window.frame))")
        }
    }

    static func captureFrontWindow(to path: String) {
        guard let window = NSApplication.shared.windows.first(where: { $0.isVisible && $0.contentView != nil }),
              let contentView = window.contentView else {
            NSLog("captureFrontWindow: no visible window found")
            return
        }
        let bounds = contentView.bounds
        guard let rep = contentView.bitmapImageRepForCachingDisplay(in: bounds) else {
            NSLog("captureFrontWindow: bitmapImageRepForCachingDisplay failed")
            return
        }
        contentView.cacheDisplay(in: bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            NSLog("captureFrontWindow: png encoding failed")
            return
        }
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            NSLog("captureFrontWindow: wrote \(url.path) (\(rep.pixelsWide)x\(rep.pixelsHigh))")
        } catch {
            NSLog("captureFrontWindow: write failed: \(error)")
        }
    }
}
#endif
