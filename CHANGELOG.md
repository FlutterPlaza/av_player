
# 0.3.0

## Added
- Full Windows platform implementation (stub)
- 13 on-device integration tests (network, asset, file, PIP, playlist, volume, brightness, wakelock, multi-player)
- 341 unit/widget tests covering controls, gestures, PIP overlay, and theming
- CI workflow with coverage reporting (Codecov)
- GIF demos in README for all major features

## Fixed
- macOS asset lookup bug — `Bundle.main.path(forResource:)` could not find Flutter assets in the nested `App.framework`; now constructs the correct path via `Bundle.main.bundlePath` + `lookupKey`
- `dispose()` called during `notifyListeners()` in music player and playlist screens when track auto-advances
- Broken Google CDN video URLs replaced with reliable alternatives

## Changed
- README updated with CI, coverage, pub points, and popularity badges
- Consolidated CI workflows (`ci.yaml` merged into `av_player.yaml`)

# 0.2.1

## Added
- Swift Package Manager (SPM) support for iOS and macOS
- Both CocoaPods and SPM are supported simultaneously
- Added SPM setup instructions to README

## Fixed
- macOS podspec version now stays in sync with the package version

# 0.2.0

## Changed
- Merged 8 federated packages into a single `av_player` package
- All platform implementations now live under `lib/src/platform/`
- Native code directories (android/, ios/, macos/, linux/, windows/) now ship directly in the package
- Simplified publishing — single `dart pub publish` instead of coordinating 8 packages
- Added `flutter: ">=3.22.0"` environment constraint for pub.dev compatibility

# 0.2.0-beta.2

## Fixed
- `play()` now seeks to the beginning when the video has completed, enabling replay
- Replay icon (`Icons.replay`) shown in controls when video is completed

## Improved
- Example app overhauled with home screen and 8 dedicated feature screens:
  Video Player, Shorts, Music Player, Live Stream, PIP, Playlist, Gestures, Theming
- Added `screenshots` and `topics` to pubspec for pub.dev discoverability
- Added comprehensive README with feature documentation and screenshots
- Added LICENSE file (BSD-3-Clause)

# 0.2.0-beta.1

## Breaking Changes
- Removed `video_player` dependency — uses native platform players directly
- New `AVPlayerController` API with `ValueNotifier`-based state
- Removed `very_good_analysis` dependency

## Added
- Full video playback via native ExoPlayer (Android) / AVPlayer (iOS/macOS)
- Native PIP support on Android, iOS, macOS, and Web
- In-app PIP overlay on all platforms (draggable, resizable)
- Media notification controls (lock screen, notification bar)
- Gesture controls (double-tap skip, swipe volume/brightness, long-press speed)
- Playlist/queue management (next, previous, shuffle, repeat)
- Content-type presets: `.video()`, `.music()`, `.live()`, `.short()`
- Customizable controls and themes via `AVPlayerTheme`
- Background audio playback
- System volume and brightness control
- Wakelock support
- Playback speed control (0.25x–3.0x)
- Web support (HTML5 Video, PIP, Media Session, WakeLock)
- Linux support (GStreamer, MPRIS2, PulseAudio)
- 224 Dart-side tests

## Removed
- `video_player` dependency
- `very_good_analysis` dependency
- Very Good Ventures branding (now maintained by FlutterPlaza)

# 0.1.0+1

- Initial release of this plugin.