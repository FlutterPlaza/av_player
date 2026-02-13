# AV Picture-in-Picture — API Reference (Part 2)

**Continued from [API_REFERENCE.md](API_REFERENCE.md)**

---

## Table of Contents

12. [Media Session & Notifications](#12-media-session--notifications)
13. [System Controls](#13-system-controls)
14. [Types Reference](#14-types-reference)
15. [Platform Notes](#15-platform-notes)

---

## 12. Media Session & Notifications

Show playback controls in the notification shade, lock screen, and Control Center.

```dart
// Set metadata (appears on lock screen / notification)
await controller.setMediaMetadata(AVMediaMetadata(
  title: 'Episode 1',
  artist: 'My Podcast',
  album: 'Season 1',
  artworkUrl: 'https://example.com/cover.jpg',
));

// Enable notification
await controller.setNotificationEnabled(true);

// Handle remote commands
final controller = AVPlayerController(
  source,
  onMediaCommand: (command, seekPosition) {
    // Handle play, pause, next, previous, seekTo, stop
  },
);
```

### What Appears Where

| Platform | Where Controls Appear                |
|----------|--------------------------------------|
| Android  | Notification shade, lock screen      |
| iOS      | Lock screen, Control Center          |
| macOS    | Menu bar Now Playing, Control Center |
| Linux    | MPRIS2 — desktop media controls (GNOME, KDE, etc.) |

---

## 13. System Controls

### Volume

```dart
await controller.setSystemVolume(0.5);             // 0.0–1.0
final volume = await controller.getSystemVolume();  // 0.0–1.0
```

> **iOS note:** System volume is read-only (Apple restriction). `setSystemVolume` will throw an error on iOS.

### Brightness

```dart
await controller.setScreenBrightness(0.8);                   // 0.0–1.0
final brightness = await controller.getScreenBrightness();    // 0.0–1.0
```

> **macOS note:** Brightness control works on built-in displays. May not work on all external monitors.

### Wakelock

```dart
await controller.setWakelock(true);   // Prevent screen from sleeping
await controller.setWakelock(false);  // Allow screen to sleep
```

---

## 14. Types Reference

### AVVideoSource

```dart
// Network video (supports HLS, DASH, MP4)
const AVVideoSource.network(
  'https://example.com/video.mp4',
  headers: {'Authorization': 'Bearer token'},
)

// Flutter asset
const AVVideoSource.asset('assets/video.mp4')

// Local file
const AVVideoSource.file('/path/to/video.mp4')
```

### AVPlaybackState

```dart
enum AVPlaybackState {
  idle,           // Not initialized
  initializing,   // Loading
  ready,          // Ready to play
  playing,        // Currently playing
  paused,         // Paused
  buffering,      // Buffering
  completed,      // Playback finished
  error,          // Error occurred
}
```

### AVMediaCommand

```dart
enum AVMediaCommand {
  play,
  pause,
  next,
  previous,
  seekTo,
  stop,
}
```

### AVMediaMetadata

```dart
AVMediaMetadata(
  title: 'Song Title',
  artist: 'Artist',
  album: 'Album',
  artworkUrl: 'https://example.com/art.jpg',  // Optional
)
```

### AVPlayerEvent (sealed class)

Events received from the native player via `EventChannel`:

| Event Type                   | Fields                                | When Fired                         |
|------------------------------|---------------------------------------|------------------------------------|
| `AVInitializedEvent`         | duration, width, height, textureId    | Video loaded and ready             |
| `AVPositionChangedEvent`     | position                              | Every 200ms during playback        |
| `AVPlaybackStateChangedEvent`| state (AVPlaybackState)               | Play/pause/buffer state change     |
| `AVBufferingUpdateEvent`     | buffered                              | Buffer progress update             |
| `AVPipChangedEvent`          | isInPipMode                           | PIP entered/exited                 |
| `AVCompletedEvent`           | —                                     | Playback reached end               |
| `AVErrorEvent`               | message, code                         | Error occurred                     |
| `AVMediaCommandEvent`        | command, seekPosition?                | Remote/notification command        |

### AVPlayerState

State object held by `AVPlayerController` (a `ValueNotifier`):

| Property       | Type             | Default         | Description                    |
|----------------|------------------|-----------------|--------------------------------|
| position       | `Duration`       | `Duration.zero` | Current playback position      |
| duration       | `Duration`       | `Duration.zero` | Total video duration           |
| buffered       | `Duration`       | `Duration.zero` | Buffered position              |
| playbackState  | `AVPlaybackState`| `idle`          | Current state                  |
| volume         | `double`         | `1.0`           | Player volume (0.0–1.0)       |
| speed          | `double`         | `1.0`           | Playback speed                 |
| isFullscreen   | `bool`           | `false`         | Fullscreen mode                |
| isPip          | `bool`           | `false`         | PIP mode                       |
| isLooping      | `bool`           | `false`         | Loop mode                      |
| textureId      | `int`            | `-1`            | Flutter texture ID             |
| errorMessage   | `String?`        | `null`          | Error message if any           |

---

## 15. Platform Notes

### Android

- **Minimum SDK:** 21 (Android 5.0)
- **Video engine:** ExoPlayer (Media3)
- **PIP:** Auto-enters on Android 12+ (API 31) when app goes to background. On older versions, call `enterPip()` explicitly.
- **PIP controls:** Previous, play/pause, next buttons shown in PIP window
- **Notifications:** `Notification.MediaStyle` with `MediaSession` token
- **Volume:** Full system volume read/write via `AudioManager`
- **Brightness:** Per-window via `WindowManager.LayoutParams.screenBrightness`
- **Wakelock:** `FLAG_KEEP_SCREEN_ON` on the activity window

### iOS

- **Minimum version:** iOS 13.0
- **Video engine:** AVPlayer/AVKit
- **PIP:** Auto-starts on iOS 14.2+ when app goes to background. Requires `AVAudioSession.category = .playback`.
- **Notifications:** `MPNowPlayingInfoCenter` + `MPRemoteCommandCenter`
- **Volume:** **Read-only** (`AVAudioSession.outputVolume`). Apple does not provide a public API to set system volume.
- **Brightness:** `UIScreen.main.brightness` (0.0–1.0)
- **Wakelock:** `UIApplication.shared.isIdleTimerDisabled`
- **Background audio:** Requires `audio` background mode in `Info.plist`

### macOS

- **Minimum version:** macOS 12.0
- **Video engine:** AVPlayer/AVKit
- **PIP:** Native `AVPictureInPictureController` support
- **Notifications:** `MPNowPlayingInfoCenter` (menu bar Now Playing widget)
- **Volume:** CoreAudio read/write. Tries combined channel first, falls back to per-channel (L/R) for devices without a combined volume control.
- **Brightness:** IOKit — works on built-in MacBook displays. External monitors may not respond.
- **Wakelock:** `IOPMAssertionCreateWithName` prevents display sleep

### Web

- **Video engine:** HTML5 `<video>` element via `package:web` + `dart:js_interop` (Wasm-compatible)
- **PIP:** Browser Picture-in-Picture API (`HTMLVideoElement.requestPictureInPicture()`)
- **Notifications:** Media Session API (`navigator.mediaSession`) — shows in browser/OS media controls
- **Volume:** Per-element only (`HTMLMediaElement.volume`). No system volume control in browsers.
- **Brightness:** Not available in browsers. Returns 0.5 default.
- **Wakelock:** Screen Wake Lock API (`navigator.wakeLock.request('screen')`). Graceful fallback if unsupported.
- **Custom headers:** Network sources with headers use `fetch()` + Blob URL instead of direct `src` assignment.
- **Rendering:** Uses `HtmlElementView` with registered platform view (not `Texture`)

### Linux

- **Video engine:** GStreamer (`playbin` with `appsink` for RGBA frame extraction)
- **PIP:** N/A — no standard Linux PIP API. In-app PIP overlay works via Dart.
- **Notifications:** MPRIS2 D-Bus interface (`org.mpris.MediaPlayer2.av_pip`) — integrates with GNOME, KDE, and other MPRIS-aware desktop environments
- **Volume:** PulseAudio read/write via `@DEFAULT_SINK@`. PipeWire provides PulseAudio compat layer on most modern desktops.
- **Brightness:** sysfs `/sys/class/backlight/*/brightness`. Requires appropriate permissions to write. Returns 0.5 default if unavailable.
- **Wakelock:** D-Bus `org.freedesktop.ScreenSaver.Inhibit` / `UnInhibit`
- **Build deps:** Requires `libgstreamer1.0-dev`, `libgstreamer-plugins-base1.0-dev`, `libpulse-dev`, `libgtk-3-dev`
- **Rendering:** Uses `FlPixelBufferTexture` with GStreamer RGBA frames (not platform view)

---

*AV Picture-in-Picture v0.2.0-beta.1 — by FlutterPlaza*
