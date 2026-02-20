# AV Player — Roadmap & Development Plan

**Version:** 0.4.0
**Last Updated:** 2026-02-16
**Status:** Published on pub.dev — Android, iOS, macOS, Web, Linux, Windows fully implemented. Integration & widget tests complete.

---

## Table of Contents

1. [Current Status Summary](#1-current-status-summary)
2. [Known Limitations](#2-known-limitations)
3. [Deferred Work](#3-deferred-work)
4. [Phase 10: Windows Implementation](#4-phase-10-windows-implementation)
5. [Phase 11: Integration & Widget Tests](#5-phase-11-integration--widget-tests)
6. [Phase 12: Pigeon Migration](#6-phase-12-pigeon-migration)
7. [Future Improvements](#7-future-improvements)
8. [Execution Priority](#8-execution-priority)
9. [Completed Phases (Reference)](#9-completed-phases-reference)
10. [Test Coverage](#10-test-coverage)

---

## 1. Current Status Summary

### What's Done

| Component                | Status  | Platforms                        |
|--------------------------|---------|----------------------------------|
| Platform interface       | Done    | All (shared Dart)                |
| Types & events           | Done    | All (shared Dart)                |
| AVPlayerController       | Done    | All (shared Dart)                |
| AVPlaylistController     | Done    | All (shared Dart)                |
| UI widgets               | Done    | All (shared Dart)                |
| Theme system             | Done    | All (shared Dart)                |
| Content-type presets     | Done    | All (shared Dart)                |
| Android native           | Done    | ExoPlayer + PIP + MediaSession   |
| iOS native               | Done    | AVPlayer + PIP + MPNowPlaying    |
| macOS native             | Done    | AVPlayer + PIP + CoreAudio + IOKit |
| Web native               | Done    | HTML5 Video + PIP + MediaSession + WakeLock |
| Linux native             | Done    | GStreamer + MPRIS2 + PulseAudio + sysfs |
| Windows native           | Done    | Media Foundation + D3D11 + WASAPI + SMTC |
| CI/CD                    | Done    | GitHub Actions (analyze + test + codecov) |
| Dart-side tests          | Done    | 341 tests across 14 files, all passing |
| Integration tests        | Done    | 13 on-device tests (network, asset, file, PIP, playlist, etc.) |
| Widget interaction tests | Done    | AVControls (45), AVGestures (24), AVPipOverlay (15), AVVideoPlayer (14) |
| SPM support              | Done    | iOS and macOS (CocoaPods + SPM)  |
| Single-package structure | Done    | Merged 8 federated packages into one |
| Published to pub.dev     | Done    | v0.3.0                          |

### What's Not Done

| Component                | Status  | Planned Phase |
|--------------------------|---------|---------------|
| Pigeon codegen           | Manual  | Phase 12      |

---

## 2. Known Limitations

### iOS — System Volume Read-Only

Apple does not provide a public API to set system volume programmatically. `setSystemVolume()` returns a `FlutterError(UNSUPPORTED)` on iOS. `getSystemVolume()` works via `AVAudioSession.outputVolume`.

### iOS — Minimum Deployment Target 13.0

iOS deployment target is 13.0. Apps targeting iOS 12 or lower cannot use this plugin.

### macOS — External Display Brightness

`IODisplayGetFloatParameter`/`IODisplaySetFloatParameter` works on built-in MacBook displays. External monitors may not respond. No reliable fallback exists.

### macOS — CoreAudio Volume Channel Fallback

Some audio devices don't expose a combined volume channel (element 0). The implementation tries per-channel (elements 1/2) as fallback, but exotic audio hardware may not respond.

### All Platforms — Codec Support

Only OS-provided codecs are supported (H.264, H.265/HEVC, VP9, AV1 on newer OS). No software decoding fallback. This covers 99%+ of real-world video but exotic codecs (e.g., VP8, Theora) won't play.

### Web — Browser API Limitations

- **Volume:** Per-element only. No access to system volume from browsers.
- **Brightness:** Not available. `setScreenBrightness()` is a no-op, `getScreenBrightness()` returns 0.5.
- **PIP:** Requires user gesture to activate (browser security policy). Not all browsers support PIP (Safari iOS does not).
- **Autoplay:** Browsers may block autoplay with audio. Users may need to interact before `play()` succeeds.
- **Custom headers:** Network sources with custom headers use `fetch()` + Blob URL, which buffers the entire response before playback starts.

### Linux — PIP Not Available

Linux has no standard OS-level Picture-in-Picture API. The in-app PIP overlay (Dart) works on all platforms including Linux.

### Linux — Brightness Requires Permissions

Screen brightness uses `/sys/class/backlight/*/brightness` (sysfs). Writing requires root or appropriate permissions (e.g., `udev` rules). If unavailable, `getScreenBrightness()` returns 0.5 and `setScreenBrightness()` is a no-op.

### Linux — PulseAudio Required for Volume

System volume uses PulseAudio. PipeWire provides a PulseAudio compatibility layer, so most modern Linux desktops work. Systems without PulseAudio will not have volume control.

### Linux — Build Dependencies

Building the Linux plugin requires: `libgstreamer1.0-dev`, `libgstreamer-plugins-base1.0-dev`, `libpulse-dev`, `libgtk-3-dev`.

### Android — minSdk 21

Bumped from 19 to 21 for TextureRegistry support. Apps targeting API 19 cannot use this plugin.

---

## 3. Deferred Work

These were explicitly deferred during implementation:

### ~~3.1 Web Media Session (from Phase 4.4)~~ — DONE (Phase 8)

Implemented in `AvPlayerWeb`: Media Session API with `setActionHandler()` for play/pause/next/previous/seekto/stop, `MediaMetadata` with artwork, and PIP via `requestPictureInPicture()`.

### 3.2 Push Notification Deep Links (from Phase 4.5)

```
- Define URL scheme for video deep links
- "Continue watching" notification after app close
- Handle notification tap → open app at specific video with timestamp
```

**Deferred to:** Post-stable. Requires platform-specific notification handling and app routing integration that goes beyond the plugin scope.

### 3.3 Full Builder API (from Phase 5.3)

A monolithic `AVPlayerConfig` object combining `AVControlsConfig`, `AVGestureConfig`, and `AVPlayerThemeData` into one. Deferred because individual config classes provide all needed surface area. Revisit if user feedback requests a unified config.

---

## 4. Phase 10: Windows Implementation — DONE

**Interop:** C++ Flutter plugin (Media Foundation, D3D11, WASAPI, SMTC)
**Status:** Complete — Full native implementation with hardware-accelerated video

### 10.1 Media Foundation Video Playback

- [x] Media Foundation `IMFMediaEngine` with DXGI hardware acceleration
- [x] D3D11 render pipeline (render texture → staging texture → pixel buffer)
- [x] Texture integration via `FlutterDesktopTextureRegistrar` (PixelBufferTexture)
- [x] Support: MP4, HLS (Media Foundation built-in), local files, assets

### 10.2 Windows PIP

- [x] N/A — No standard Windows PIP API
- [x] In-app PIP overlay (Dart) already works

### 10.3 Windows Media Session

- [x] `SystemMediaTransportControls` via WRL/COM interop
- [x] Display info: title, artist, album via `IMusicDisplayProperties`
- [x] Button handling → `mediaCommand` events (play/pause/next/previous/stop)

### 10.4 Windows System Controls

- [x] Volume: `IAudioEndpointVolume` (WASAPI)
- [x] Brightness: Monitor Configuration API (`GetMonitorBrightness`/`SetMonitorBrightness`)
- [x] Wakelock: `SetThreadExecutionState(ES_CONTINUOUS | ES_DISPLAY_REQUIRED)`

### 10.5 Windows Dart-Side + Tests

- [x] `AvPlayerWindows` class extending platform interface
- [x] C++ native plugin (no FFI needed — uses Flutter plugin C++ API)
- [x] 25 Dart-side tests

---

## 5. Phase 11: Integration & Widget Tests — DONE

**Status:** Complete — 341 unit/widget tests + 13 integration tests, all passing.

### 11.1 Integration Tests (on-device) — `example/integration_test/player_test.dart`

- [x] Video loads and plays from network URL
- [x] Video loads from Flutter asset
- [x] Video loads from local file
- [x] PIP enters and exits correctly (Android/iOS/macOS)
- [x] Playlist advances on track completion
- [x] Position/duration reporting updates correctly
- [x] Media notification appears with correct metadata (smoke test)
- [x] Lock screen controls — skipped (requires manual verification, documented)
- [x] System volume get/set roundtrip
- [x] Brightness get/set roundtrip
- [x] Wakelock enables/disables (smoke test)
- [x] Multiple simultaneous players

### 11.2 Widget Interaction Tests

- [x] `AVControls` — tap play/pause, tap skip, drag slider, tap speed, tap PIP (45 tests)
- [x] `AVControls` — auto-hide after configured duration
- [x] `AVControls` — show/hide animation
- [x] `AVControls` — respects `AVPlayerTheme` colors
- [x] `AVGestures` — double-tap left/right detection + ripple (24 tests)
- [x] `AVGestures` — swipe up/down volume/brightness detection + indicator
- [x] `AVGestures` — long-press speed detection + badge
- [x] `AVGestures` — consecutive double-taps accumulate
- [x] `AVGestures` — respects `AVPlayerTheme` colors
- [x] `AVPipOverlay` — drag to position (15 tests)
- [x] `AVPipOverlay` — snap to nearest corner on release
- [x] `AVPipOverlay` — mini controls tap
- [x] `AVPipOverlay` — respects `AVPlayerTheme` colors

### 11.3 Coverage Target

Goal: >80% line coverage across all Dart code. CI uploads coverage to Codecov.

---

## 6. Phase 12: Pigeon Migration

**Priority:** Low — Current MethodChannel strings work fine, Pigeon adds type safety

### Why Migrate

- Type-safe codegen for method channels (no string typos)
- Generated Swift/Kotlin host API classes
- Generated Dart API classes
- Automatic argument serialization
- Eliminates `invokeMethod<Type>` casts

### Scope

- [ ] Define Pigeon schema (`.dart` file with `@HostApi()` annotations)
- [ ] Generate Android Kotlin bindings
- [ ] Generate iOS Swift bindings
- [ ] Generate macOS Swift bindings
- [ ] Update all native plugins to use generated host APIs
- [ ] Update all Dart-side implementations to use generated Dart APIs
- [ ] Update tests for new API signatures

### Risk

Medium — Large refactor touching all 3 native plugins + 3 Dart implementations. Should be done in a single coordinated pass.

---

## 7. Future Improvements

These are potential enhancements beyond the current roadmap:

### Performance

- [ ] Adaptive bitrate streaming (ABR) configuration API
- [ ] Hardware decode verification / fallback reporting
- [ ] Memory pressure monitoring + automatic quality reduction

### Features

- [ ] Subtitle/caption support (WebVTT, SRT)
- [ ] Audio track selection (multi-audio streams)
- [ ] DRM support (Widevine/FairPlay) — requires significant native work
- [ ] Cast/AirPlay integration
- [ ] Analytics hooks (play, pause, buffer, error event callbacks)

### Developer Experience

- [ ] Full Builder API (`AVPlayerConfig` combining all configs) — revisit based on user feedback
- [ ] `AVVideoPlayer.network()` convenience constructor
- [ ] DevTools extension for player state inspection
- [ ] Example app per platform (currently only one shared example)

---

## 8. Execution Priority

```
Phase 10 (Windows)           ← DONE
    ↓
Phase 12 (Pigeon migration)  ← Next priority, low urgency, quality-of-life
```

### Milestone: Stable Release

- [x] Android, iOS, macOS fully working
- [x] Web support
- [x] Linux support
- [x] SPM support for iOS and macOS
- [x] Single-package structure (merged federated packages)
- [x] Published to pub.dev (v0.3.0)
- [x] 341 Dart-side tests passing (14 test files)
- [x] 13 integration tests passing on macOS (network, asset, file, PIP, playlist, etc.)
- [x] Widget interaction tests (AVControls, AVGestures, AVPipOverlay, AVVideoPlayer)
- [ ] >80% coverage (Codecov integration in CI)

### Milestone: Full Platform Support

- [x] Windows support (Phase 10)
- [ ] All 6 platforms tested

---

## 9. Completed Phases (Reference)

| Phase | What                              | Status    | Tests |
|-------|-----------------------------------|-----------|-------|
| 0     | Rebrand & cleanup                 | Done      | —     |
| 1     | Platform interface + Android      | Done      | 92    |
| 2     | iOS native                        | Done      | 26    |
| 3     | Player UI & gestures              | Done      | —     |
| 4     | Media session & notifications     | Done      | —     |
| 5     | Configuration & themes            | Done      | —     |
| 6     | Testing                           | Done      | 169   |
| 7     | macOS native                      | Done      | 26    |
| 8     | Web native                        | Done      | 30    |
| 9     | Linux native                      | Done      | 25    |
| 10    | Windows native                    | Done      | 25    |

### Post-Phase Work

| Release | What                                          | Date       |
|---------|-----------------------------------------------|------------|
| 0.2.0   | Merged 8 federated packages into single package | 2026-02-13 |
| 0.2.1   | SPM support, iOS config updates, analysis fixes | 2026-02-14 |
| 0.3.0   | Full Windows stub, integration/widget tests, CI enhancements, README GIFs | 2026-02-16 |

**Total tests:** 341 across 14 test files + 13 integration tests, all passing.

---

## 10. Test Coverage

### Current Test Files

| File                                              | Tests | What's Covered                                              |
|---------------------------------------------------|-------|-------------------------------------------------------------|
| `test/platform/types_test.dart`                   | 28    | AVVideoSource, AVMediaMetadata, AVPlayerEvent, enums        |
| `test/platform/av_player_platform_interface_test.dart` | 20 | Default instance, 18 UnimplementedError verifications       |
| `test/platform/method_channel_av_player_test.dart` | 24   | All MethodChannel calls, null handling, EventChannel        |
| `test/av_player_test.dart`                        | 43    | State, controller, playlist, theme, presets                 |
| `test/platform/av_player_ios_test.dart`           | 26    | Registration, channel name, all 20 methods                  |
| `test/platform/av_player_android_test.dart`       | 26    | Registration, channel name, all 20 methods                  |
| `test/platform/av_player_macos_test.dart`         | 26    | Registration, channel name, all 20 methods                  |
| `test/platform/av_player_linux_test.dart`         | 25    | Registration, channel name, all 20 methods (PIP N/A)        |
| `test/platform/av_player_web_test.dart`           | 30    | Registration, channel name, all methods                     |
| `test/platform/av_player_windows_test.dart`       | 25    | Registration, channel name, all 20 methods                  |
| `test/av_controls_test.dart`                      | 45    | Play/pause, skip, slider, speed, PIP, auto-hide, themes    |
| `test/av_gestures_test.dart`                      | 24    | Double-tap, swipe volume/brightness, long-press, themes     |
| `test/av_pip_overlay_test.dart`                   | 15    | Drag, snap to corner, mini controls, themes                 |
| `test/av_video_player_test.dart`                  | 14    | Layer composition, presets, lifecycle, controlsBuilder       |
| `example/integration_test/player_test.dart`       | 13    | On-device: network/asset/file, PIP, playlist, volume, etc.  |
| `example/integration_test/app_test.dart`          | 38    | UI navigation across all example screens                    |

### Gaps

- No native-side unit tests (Kotlin/Swift/C++)
- Coverage percentage not yet measured (Codecov integration added to CI)

---

*Roadmap v4 — 2026-02-16*
*Maintained by FlutterPlaza*
