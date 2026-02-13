# AV Picture-in-Picture — API Reference & Guide

**Package:** `av_player` by FlutterPlaza
**Version:** 0.2.0-beta.1
**Philosophy:** ZERO external dependencies. All features via native platform APIs.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Platform Support](#2-platform-support)
3. [Getting Started](#3-getting-started)
4. [AVPlayerController](#4-avplayercontroller)
5. [AVVideoPlayer Widget](#5-avvideoplayer-widget)
6. [Content-Type Presets](#6-content-type-presets)
7. [Controls](#7-controls)
8. [Gestures](#8-gestures)
9. [In-App PIP Overlay](#9-in-app-pip-overlay)
10. [Playlist](#10-playlist)
11. [Theme System](#11-theme-system)

**Continued in [API_REFERENCE_2.md](API_REFERENCE_2.md):** Media Session, System Controls, Types Reference, Platform Notes

---

## 1. Overview

A Flutter video player plugin with native Picture-in-Picture, media session controls, and system integration — built entirely on platform APIs with **zero external package dependencies**.

### Why Zero Dependencies?

Every third-party package is a maintenance liability. Packages get abandoned, break on Flutter upgrades, or bloat your dependency tree. This plugin replaces 7+ packages:

| What You'd Otherwise Need | What We Use Instead             |
|---------------------------|---------------------------------|
| `media_kit` (7 packages) | Native ExoPlayer/AVPlayer       |
| `just_audio`              | Same native players             |
| `audio_service`           | Native MediaSession/MPNowPlaying |
| `volume_controller`       | Native system APIs              |
| `screen_brightness`       | Native system APIs              |
| `wakelock_plus`           | Native system APIs              |
| `flutter_riverpod`/`bloc` | Built-in ValueNotifier          |

**Result:** 0 packages added, +0MB binary size, OS-optimized hardware decoding, native PIP that "just works".

---

## 2. Platform Support

### Feature Matrix

| Feature                                    | Android | iOS       | macOS | Linux     | Windows | Web     |
|--------------------------------------------|---------|-----------|-------|-----------|---------|---------|
| Video playback + controls + seek/speed     | Yes     | Yes       | Yes   | Yes       | —       | Yes     |
| Native OS PIP                              | Yes     | Yes       | Yes   | N/A       | N/A     | Yes     |
| Notification/lock screen + background audio | Yes    | Yes       | Yes   | Yes       | —       | Yes     |
| System volume / brightness / wakelock      | Yes     | Partial   | Yes   | Partial   | —       | Partial |
| In-app PIP, playlist, controls, gestures, presets, theme | Yes | Yes | Yes | Yes | Yes   | Yes     |

**Yes** = Implemented, **Partial** = Volume read-only on iOS; Linux: brightness requires sysfs perms; Web: volume per-element only, no brightness, **—** = Not yet, **N/A** = Not possible

### Minimum Platform Versions

| Platform | Minimum Version |
|----------|-----------------|
| Android  | API 21 (5.0)    |
| iOS      | 13.0            |
| macOS    | 12.0            |

---

## 3. Getting Started

### Installation

```yaml
dependencies:
  av_player: ^0.2.0-beta.1
```

### Quick Start

```dart
import 'package:av_player/av_player.dart';

// 1. Create controller
final controller = AVPlayerController(
  const AVVideoSource.network('https://example.com/video.mp4'),
);

// 2. Initialize
await controller.initialize();

// 3. Use in widget tree
AVVideoPlayer(controller);

// 4. Dispose when done
controller.dispose();
```

---

## 4. AVPlayerController

The core controller for video playback. Extends `ValueNotifier<AVPlayerState>` for reactive state.

### Constructor

```dart
AVPlayerController(AVVideoSource source, {
  void Function(AVMediaCommand command, Duration? seekPosition)? onMediaCommand,
})
```

### Lifecycle

```dart
await controller.initialize();   // Load video, get texture, start events
controller.dispose();             // Release resources
```

### Playback

```dart
await controller.play();
await controller.pause();
await controller.seekTo(Duration(seconds: 30));
await controller.setPlaybackSpeed(2.0);
await controller.setVolume(0.8);           // Per-player volume (0.0–1.0)
await controller.setLooping(true);
```

### Picture-in-Picture

```dart
final available = await controller.isPipAvailable();
await controller.enterPip(aspectRatio: 16 / 9);
await controller.exitPip();
```

### Media Session

```dart
await controller.setMediaMetadata(AVMediaMetadata(
  title: 'My Video',
  artist: 'Artist Name',
  album: 'Album',
  artworkUrl: 'https://example.com/art.jpg',
));
await controller.setNotificationEnabled(true);
```

### System Controls

```dart
await controller.setSystemVolume(0.5);        // 0.0–1.0
final volume = await controller.getSystemVolume();

await controller.setScreenBrightness(0.8);    // 0.0–1.0
final brightness = await controller.getScreenBrightness();

await controller.setWakelock(true);           // Keep screen on
```

### State (AVPlayerState)

Access via `controller.value` or listen with `ValueListenableBuilder<AVPlayerState>`.

Properties: `position`, `duration`, `buffered` (Duration), `playbackState` (AVPlaybackState), `volume`, `speed` (double), `isFullscreen`, `isPip`, `isLooping` (bool), `textureId` (int), `errorMessage` (String?).

See [API_REFERENCE_2.md](API_REFERENCE_2.md) for full AVPlayerState and AVPlayerEvent type tables.

### Media Command Callback

Receive commands from lock screen, notification, or remote controls:

```dart
final controller = AVPlayerController(source,
  onMediaCommand: (command, seekPosition) {
    // command: AVMediaCommand.play/pause/next/previous/seekTo/stop
  },
);
```

---

## 5. AVVideoPlayer Widget

Renders the video with optional controls and gestures.

### Basic Usage

```dart
AVVideoPlayer(controller)
```

### With Controls & Gestures

```dart
AVVideoPlayer(
  controller,
  showControls: true,
  controlsConfig: AVControlsConfig(
    showSkipButtons: true,
    showPipButton: true,
    showSpeedButton: true,
    showFullscreenButton: true,
  ),
  gestureConfig: AVGestureConfig(
    doubleTapToSeek: true,
    swipeToVolume: true,
    swipeToBrightness: true,
    longPressSpeed: true,
  ),
  title: 'My Video',
  onFullscreen: (isFullscreen) { /* handle fullscreen toggle */ },
)
```

### Custom Controls Builder

Replace the entire controls overlay:

```dart
AVVideoPlayer(
  controller,
  showControls: true,
  controlsBuilder: (context, controller) => MyCustomControls(controller),
)
```

---

## 6. Content-Type Presets

Pre-configured widget factories for common content types:

### Video (full-featured)

```dart
AVVideoPlayer.video(controller)
```

All controls, all gestures, PIP + fullscreen enabled.

### Music

```dart
AVVideoPlayer.music(controller)
```

Simple controls (play/skip/speed/loop), no gestures, no PIP/fullscreen.

### Live Stream

```dart
AVVideoPlayer.live(controller)
```

No seek/skip/speed/loop. PIP + fullscreen only.

### Short-Form

```dart
AVVideoPlayer.short(controller)
```

Minimal controls (play/pause only), double-tap + volume gestures.

### Override Preset Defaults

All presets accept optional overrides:

```dart
AVVideoPlayer.video(
  controller,
  controlsConfig: AVControlsConfig(showLoopButton: false),
  gestureConfig: AVGestureConfig(longPressSpeedMultiplier: 3.0),
)
```

---

## 7. Controls

### AVControlsConfig

```dart
AVControlsConfig(
  showSkipButtons: true,            // Show skip forward/back buttons
  skipDuration: Duration(seconds: 10),
  showPipButton: true,              // Show PIP button
  showSpeedButton: true,            // Show speed selector
  showFullscreenButton: true,       // Show fullscreen button
  showLoopButton: true,             // Show loop toggle
  autoHideDuration: Duration(seconds: 3),
  speeds: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
)
```

### AVControls Widget (standalone)

```dart
AVControls(
  controller: controller,
  config: AVControlsConfig(...),
  title: 'Video Title',
  onBack: () => Navigator.pop(context),
  onNext: () { /* next track */ },
  onPrevious: () { /* previous track */ },
  onFullscreen: (isFullscreen) { /* toggle */ },
)
```

### Layout

- **Top bar**: Title + back button
- **Center**: Play/pause (with buffering spinner), skip +/-10s, next/previous
- **Bottom bar**: Seek slider with buffer indicator, timestamps, loop, speed, PIP, fullscreen

---

## 8. Gestures

### AVGestureConfig

```dart
AVGestureConfig(
  doubleTapToSeek: true,
  seekDuration: Duration(seconds: 10),
  swipeToVolume: true,              // Swipe right-half up/down
  swipeToBrightness: true,          // Swipe left-half up/down
  longPressSpeed: true,             // Long-press for 2x speed
  longPressSpeedMultiplier: 2.0,
  horizontalSwipeToSeek: false,
)
```

### Gesture Behaviors

| Gesture                        | Action                                    |
|--------------------------------|-------------------------------------------|
| Double-tap right               | Skip forward (with ripple + "+10s" label) |
| Double-tap left                | Skip back (with ripple + "-10s" label)    |
| Swipe up/down (right half)     | Adjust system volume                      |
| Swipe up/down (left half)      | Adjust screen brightness                  |
| Long press                     | Temporarily play at 2x speed              |
| Single tap                     | Toggle controls visibility                |
| Consecutive double-taps        | Accumulate skip amount                    |

---

## 9. In-App PIP Overlay

A Dart-based floating mini-player — works on ALL platforms (including those without native PIP).

```dart
Stack(
  children: [
    // Your main content
    Scaffold(...),

    // PIP overlay (draggable, snaps to corners)
    AVPipOverlay(
      controller: controller,
      size: AVPipSize.medium,       // .small (150px), .medium (250px), .large (350px)
      onClose: () { /* exit PIP mode */ },
      onExpand: () { /* return to full player */ },
    ),
  ],
)
```

Features: drag to any position, snap to nearest corner on release, mini play/pause + close + expand controls, thin progress bar.

---

## 10. Playlist

### AVPlaylistController

```dart
final playlist = AVPlaylistController(
  onSourceChanged: (source) async {
    // Called when track changes — reinitialize the player
    controller.dispose();
    controller = AVPlayerController(source);
    await controller.initialize();
    await controller.play();
  },
);
```

### Queue Management

```dart
playlist.add(AVVideoSource.network('https://example.com/video1.mp4'));
playlist.addAll([source1, source2, source3]);
playlist.removeAt(2);
playlist.reorder(oldIndex: 1, newIndex: 3);
playlist.clear();
```

### Navigation

```dart
playlist.next();
playlist.previous();
playlist.jumpTo(5);
```

### Playback Modes

```dart
playlist.setRepeatMode(RepeatMode.all);   // .none, .one, .all
playlist.toggleShuffle();                  // Preserves original order
```

### Auto-Advance

```dart
// Call this when a track finishes
playlist.onTrackCompleted();  // Automatically advances based on repeat mode
```

### State

```dart
ValueListenableBuilder<AVPlaylistState>(
  valueListenable: playlist,
  builder: (context, state, _) {
    // state.queue          — List<AVVideoSource>
    // state.currentIndex   — int
    // state.repeatMode     — RepeatMode
    // state.isShuffled     — bool
  },
)
```

---

## 11. Theme System

Customize all widget colors via `AVPlayerTheme`.

### Default (no setup needed)

All widgets use sensible white-on-dark-overlay defaults.

### Custom Theme

```dart
AVPlayerTheme(
  data: AVPlayerThemeData(
    overlayColor: Colors.black54,
    iconColor: Colors.white,
    accentColor: Colors.blue,
    secondaryColor: Colors.white70,
    sliderActiveColor: Colors.blue,
    sliderInactiveColor: Colors.white24,
    sliderBufferedColor: Colors.white38,
    sliderThumbColor: Colors.blue,
    indicatorBackgroundColor: Colors.black87,
    popupMenuColor: Colors.grey.shade900,
    progressBarColor: Colors.blue,
    progressBarBackgroundColor: Colors.white24,
  ),
  child: AVVideoPlayer.video(controller),
)
```

### Partial Overrides

```dart
AVPlayerThemeData().copyWith(
  accentColor: Colors.red,
  iconColor: Colors.amber,
)
```

### Access in Custom Widgets

```dart
final theme = AVPlayerTheme.of(context);
// or
final theme = AVPlayerTheme.maybeOf(context); // nullable
```

---

*Continued in [API_REFERENCE_2.md](API_REFERENCE_2.md)*

*AV Picture-in-Picture v0.2.0-beta.1 — by FlutterPlaza*
