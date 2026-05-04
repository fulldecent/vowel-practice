fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

### bump_version

```sh
[bundle exec] fastlane bump_version
```

Bump the marketing version. Pass bump:patch (default), bump:minor, or bump:major

### bump_build

```sh
[bundle exec] fastlane bump_build
```

Bump only the build number (used before each beta upload)

----


## iOS

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Generate App Store screenshots (iOS)

### ios upload_screenshots

```sh
[bundle exec] fastlane ios upload_screenshots
```

Upload locally captured iOS screenshots to App Store Connect

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build a signed iOS .ipa, upload to TestFlight, then bump the build number

### ios release

```sh
[bundle exec] fastlane ios release
```

Submit the latest TestFlight iOS build for App Store review

----


## Mac

### mac screenshots

```sh
[bundle exec] fastlane mac screenshots
```

Generate Mac App Store screenshots

### mac upload_screenshots

```sh
[bundle exec] fastlane mac upload_screenshots
```

Upload locally captured macOS screenshots to App Store Connect

### mac beta

```sh
[bundle exec] fastlane mac beta
```

Build a signed macOS .pkg, upload to TestFlight, then bump the build number

### mac release

```sh
[bundle exec] fastlane mac release
```

Submit the latest TestFlight macOS build for App Store review

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
