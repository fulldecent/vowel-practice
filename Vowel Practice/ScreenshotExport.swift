import SwiftUI

#if os(macOS)
  import AppKit
#endif

/// `-AppleLanguages` does not change `Locale.current` when the Mac app is
/// launched as a binary. Screenshot runs pass `-AppleLocale`.
func localeFromLaunchArguments() -> Locale? {
  let arguments = ProcessInfo.processInfo.arguments
  guard let index = arguments.firstIndex(of: "-AppleLocale"),
    arguments.indices.contains(index + 1)
  else { return nil }
  return Locale(identifier: arguments[index + 1])
}

extension View {
  @ViewBuilder
  func screenshotLocale() -> some View {
    if let locale = localeFromLaunchArguments() {
      environment(\.locale, locale)
    } else {
      self
    }
  }
}

#if os(macOS)
  @MainActor
  enum MacScreenshot {
    static let width: CGFloat = 1440
    static let height: CGFloat = 900

    /// Writes a 1440×900 PNG and exits when launched with `-screenshot-file`.
    /// A GitHub-hosted runner cannot list another app's windows. `-viewMode`
    /// selects the formant page or the chart page inside `MainView`.
    static func exportIfRequested() {
      let arguments = ProcessInfo.processInfo.arguments
      guard let index = arguments.firstIndex(of: "-screenshot-file"),
        arguments.indices.contains(index + 1)
      else { return }

      let renderer = ImageRenderer(
        content: MainView()
          .environmentObject(AppViewModel())
          .frame(width: width, height: height)
          .screenshotLocale()
      )
      renderer.scale = 1

      guard let image = renderer.nsImage,
        let tiff = image.tiffRepresentation,
        let rep = NSBitmapImageRep(data: tiff),
        rep.pixelsWide == Int(width),
        rep.pixelsHigh == Int(height),
        let png = rep.representation(using: .png, properties: [:])
      else {
        fputs("could not render a \(Int(width))×\(Int(height)) Mac screenshot\n", stderr)
        exit(1)
      }

      let url = URL(fileURLWithPath: arguments[index + 1])
      do {
        try FileManager.default.createDirectory(
          at: url.deletingLastPathComponent(),
          withIntermediateDirectories: true
        )
        try png.write(to: url)
      } catch {
        fputs("could not write Mac screenshot: \(error)\n", stderr)
        exit(1)
      }
      exit(0)
    }
  }
#endif
