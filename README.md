# AV Player

[![License: BSD-3-Clause][license_badge]][license_link]
[![Pub Version][pub_badge]][pub_link]
[![Flutter][flutter_badge]][flutter_link]

A powerful Flutter video player with **native Picture-in-Picture**, gesture controls, media notifications, playlist management, and theming — all with **zero external dependencies**. Uses native platform players directly (ExoPlayer, AVPlayer, GStreamer, HTML5 Video).

Built by [FlutterPlaza][flutterplaza_link].

![Home Screen](doc/images/home_screen.png)

---

## Features

- **Native PIP** on Android, iOS, macOS, and Web
- **In-app PIP overlay** on all platforms (draggable, corner-snapping)
- **Video playback** from network URL, HLS/DASH stream, asset, or file
- **Gesture controls** — double-tap skip, swipe volume/brightness, long-press speed, horizontal swipe seek
- **Media notifications** — lock screen and notification bar controls
- **Playlist management** — queue, shuffle, repeat (none / one / all)
- **Content-type presets** — `.video()`, `.music()`, `.live()`, `.short()`
- **Theming** — full color customization via `AVPlayerTheme`
- **Playback speed** — 0.25x to 3.0x
- **Background audio** playback
- **System volume & brightness** control
- **Wakelock** support
- **Zero external dependencies** — uses native platform players directly

---

## Platform Support

| Feature | Android | iOS | macOS | Linux | Windows | Web |
|---------|---------|-----|-------|-------|---------|-----|
| Video Playback | Yes | Yes | Yes | Yes | Stub | Yes |
| Native PIP | Yes | Yes | Yes | — | — | Yes |
| In-App PIP | Yes | Yes | Yes | Yes | Yes | Yes |
| Media Notifications | Yes | Yes | — | Yes | — | Yes |
| System Volume | Yes | Read-only | Yes | Yes | — | Per-element |
| Brightness | Yes | Yes | Built-in only | sysfs | — | — |
| Wakelock | Yes | Yes | Yes | Yes | — | Yes |

---

## Installation

```yaml
dependencies:
  av_player: ^0.2.1
```

```dart
import 'package:av_player/av_player.dart';
```

---

## iOS & macOS — Swift Package Manager

This plugin supports both **CocoaPods** and **Swift Package Manager (SPM)** for iOS and macOS.

### CocoaPods (default)

No extra setup is required. `flutter build` uses CocoaPods automatically.

### Swift Package Manager

Flutter 3.24.5+ can resolve iOS and macOS dependencies through SPM instead of CocoaPods. To enable it:

```bash
flutter config --enable-swift-package-manager
```

Then build as usual:

```bash
cd example
flutter build ios        # or: flutter build macos
```

Flutter detects the `Package.swift` files in `ios/av_player/` and `macos/av_player/` and resolves the plugin through SPM. No `Podfile` changes are needed — if SPM is enabled, Flutter prefers it; otherwise it falls back to CocoaPods.

To disable SPM and return to CocoaPods:

```bash
flutter config --no-enable-swift-package-manager
```

---

## Quick Start

```dart
class MyPlayer extends StatefulWidget {
  const MyPlayer({super.key});

  @override
  State<MyPlayer> createState() => _MyPlayerState();
}

class _MyPlayerState extends State<MyPlayer> {
  late final AVPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AVPlayerController(
      const AVVideoSource.network('https://example.com/video.mp4'),
    )..initialize();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AVPlayerState>(
      valueListenable: _controller,
      builder: (context, state, _) {
        return AspectRatio(
          aspectRatio: state.aspectRatio,
          child: AVVideoPlayer.video(_controller, title: 'My Video'),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

---

## Content-Type Presets

AV Player provides four presets that configure controls and gestures for different content types.

### Video Player — `.video()`

Full controls with all features enabled: play/pause, seek bar, skip forward/backward, speed selector, loop toggle, PIP button, fullscreen button, and gesture controls.

![Video Player](doc/images/video_player.png)

```dart
AVVideoPlayer.video(
  controller,
  title: 'My Video',
  onFullscreen: () => enterFullscreen(),
)
```

### Shorts — `.short()`

Minimal UI for vertical short-form content (TikTok/Reels/Shorts style). Only play/pause center button with double-tap and long-press gestures. Set looping for continuous replay.

![Shorts](doc/images/shorts.png)

```dart
// Enable looping after initialization
controller.setLooping(true);
controller.play();

AVVideoPlayer.short(controller)
```

### Music Player — `.music()`

Audio-focused controls with skip next/previous, speed, and loop. Disables PIP and fullscreen since the video surface is used for album art or visualizer.

![Music Player](doc/images/music_player.png)

```dart
AVVideoPlayer.music(
  controller,
  title: 'Song Name',
  onNext: () => playlist.next(),
  onPrevious: () => playlist.previous(),
)
```

### Live Stream — `.live()`

Live content preset. Disables seek bar, skip buttons, and speed control since live streams cannot be seeked. Only play/pause, PIP, and fullscreen remain.

![Live Stream](doc/images/live_stream.png)

```dart
AVVideoPlayer.live(controller, title: 'LIVE')
```

---

## Picture-in-Picture

### Native PIP

Uses the OS-level picture-in-picture window. Supported on Android, iOS, macOS, and Web.

![Native PIP](doc/images/pip_native.png)

```dart
// Enter native PIP
await controller.enterPip();

// Exit native PIP
await controller.exitPip();

// Check availability
final available = await controller.isPipAvailable();
```

### In-App PIP Overlay

A draggable, corner-snapping mini-player overlay that works on all platforms. Place it in your app's top-level `Stack`.

![In-App PIP](doc/images/pip_in_app.png)

```dart
Stack(
  children: [
    // Your app content
    Navigator(...),

    // Floating PIP overlay
    if (showPip)
      AVPipOverlay(
        controller: controller,
        initialSize: AVPipSize.medium,       // small, medium, large
        initialCorner: AVPipCorner.bottomRight,
        onClose: () => setState(() => showPip = false),
        onExpand: () => navigateToFullPlayer(),
      ),
  ],
)
```

---

## Gesture Controls

Gesture controls are enabled automatically with the `.video()` and `.short()` presets. You can also configure them manually.

![Gesture Controls](doc/images/gestures.png)

| Gesture | Action |
|---------|--------|
| Tap | Show/hide controls overlay |
| Double-tap right | Skip forward 10s |
| Double-tap left | Skip backward 10s |
| Long press | Play at 2x speed while held |
| Swipe up/down (right side) | Adjust volume |
| Swipe up/down (left side) | Adjust brightness |
| Horizontal swipe | Seek through video |

```dart
AVVideoPlayer(
  controller,
  showControls: true,
  gestureConfig: const AVGestureConfig(
    doubleTapToSeek: true,
    seekDuration: Duration(seconds: 10),
    longPressSpeed: true,
    longPressSpeedMultiplier: 2.0,
    swipeToVolume: true,
    swipeToBrightness: true,
    horizontalSwipeToSeek: false,
  ),
)
```

---

## Playlist Management

`AVPlaylistController` manages a queue of video sources with navigation, repeat modes, and shuffle.

![Playlist](doc/images/playlist.png)

```dart
final playlist = AVPlaylistController(
  sources: [
    const AVVideoSource.network('https://example.com/track1.mp4'),
    const AVVideoSource.network('https://example.com/track2.mp4'),
    const AVVideoSource.network('https://example.com/track3.mp4'),
  ],
  onSourceChanged: (source) async {
    // Reinitialize the player with the new source
    controller.dispose();
    controller = AVPlayerController(source);
    await controller.initialize();
    await controller.play();
  },
);

// Navigation
playlist.next();
playlist.previous();
playlist.jumpTo(2);

// Repeat modes: none, one, all
playlist.setRepeatMode(AVRepeatMode.all);

// Shuffle
playlist.setShuffle(true);

// Queue management
playlist.add(const AVVideoSource.network('https://example.com/track4.mp4'));
playlist.removeAt(1);
playlist.reorder(0, 2);

// Auto-advance on completion
controller.addListener(() {
  if (controller.value.isCompleted) {
    playlist.onTrackCompleted();
  }
});
```

---

## Theming

Customize the player's appearance with `AVPlayerTheme`. All controls, gestures, and PIP overlay respect the theme.

![Theming](doc/images/theming.png)

```dart
AVPlayerTheme(
  data: const AVPlayerThemeData(
    accentColor: Colors.deepOrange,
    iconColor: Colors.white,
    overlayColor: Color(0x61000000),
    sliderActiveColor: Colors.deepOrange,
    sliderThumbColor: Colors.deepOrange,
    sliderBufferColor: Color(0x62FFFFFF),
    sliderInactiveColor: Color(0x3DFFFFFF),
    progressBarColor: Colors.deepOrange,
  ),
  child: AVVideoPlayer.video(controller),
)
```

---

## Replay

When a video completes, the controls automatically show a replay icon. Tapping play (or the replay icon) seeks to the beginning and restarts playback.

![Replay Icon](doc/images/replay_icon.png)

---

## Media Notifications

Display playback info on the lock screen and notification bar with media command support.

```dart
// Set metadata
await controller.setMediaMetadata(const AVMediaMetadata(
  title: 'Video Title',
  artist: 'Artist Name',
  album: 'Album Name',
));

// Enable/disable notification
await controller.setNotificationEnabled(true);

// Handle media commands (next, previous, seek)
final controller = AVPlayerController(
  source,
  onMediaCommand: (command, {seekPosition}) {
    switch (command) {
      case AVMediaCommand.next:
        playlist.next();
      case AVMediaCommand.previous:
        playlist.previous();
      default:
        break;
    }
  },
);
```

---

## Custom Controls

Replace the built-in controls with your own widget using `controlsBuilder`.

```dart
AVVideoPlayer(
  controller,
  showControls: true,
  controlsBuilder: (context, controller) {
    return ValueListenableBuilder<AVPlayerState>(
      valueListenable: controller,
      builder: (context, state, _) {
        return Center(
          child: IconButton(
            iconSize: 64,
            icon: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: () {
              state.isPlaying ? controller.pause() : controller.play();
            },
          ),
        );
      },
    );
  },
)
```

---

## API Reference

### AVPlayerController

| Method | Description |
|--------|-------------|
| `initialize()` | Create the native player and start listening for events |
| `play()` | Start or resume playback (seeks to start if completed) |
| `pause()` | Pause playback |
| `seekTo(Duration)` | Seek to position |
| `setPlaybackSpeed(double)` | Set speed (0.25–3.0) |
| `setLooping(bool)` | Enable/disable looping |
| `setVolume(double)` | Set player volume (0.0–1.0) |
| `enterPip()` | Enter native Picture-in-Picture |
| `exitPip()` | Exit native Picture-in-Picture |
| `isPipAvailable()` | Check if PIP is supported |
| `setMediaMetadata(AVMediaMetadata)` | Set notification metadata |
| `setNotificationEnabled(bool)` | Toggle media notification |
| `setSystemVolume(double)` | Set system volume (0.0–1.0) |
| `getSystemVolume()` | Get current system volume |
| `setScreenBrightness(double)` | Set screen brightness (0.0–1.0) |
| `getScreenBrightness()` | Get current brightness |
| `setWakelock(bool)` | Prevent screen from sleeping |
| `dispose()` | Release native resources |

### AVPlayerState

| Property | Type | Description |
|----------|------|-------------|
| `position` | `Duration` | Current playback position |
| `duration` | `Duration` | Total video duration |
| `buffered` | `Duration` | Amount buffered |
| `isPlaying` | `bool` | Whether currently playing |
| `isBuffering` | `bool` | Whether buffering |
| `isLooping` | `bool` | Whether looping is enabled |
| `isInitialized` | `bool` | Whether the player is ready |
| `isInPipMode` | `bool` | Whether in native PIP |
| `isCompleted` | `bool` | Whether playback has finished |
| `playbackSpeed` | `double` | Current speed multiplier |
| `volume` | `double` | Player volume |
| `aspectRatio` | `double` | Video aspect ratio |
| `errorDescription` | `String?` | Error message if failed |

---

## Example App

The example app includes 8 dedicated screens showcasing each feature. Run it with:

```bash
cd example
flutter run
```

See [example/lib/main.dart](example/lib/main.dart) for the full source.

---

## Linux Build Dependencies

```bash
sudo apt-get install libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libpulse-dev libgtk-3-dev
```

---

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting a PR.

## License

This project is licensed under the BSD 3-Clause License — see the [LICENSE](LICENSE) file for details.

[license_badge]: https://img.shields.io/badge/license-BSD--3--Clause-blue.svg
[license_link]: https://opensource.org/licenses/BSD-3-Clause
[pub_badge]: https://img.shields.io/pub/v/av_player.svg
[pub_link]: https://pub.dev/packages/av_player
[flutter_badge]: https://img.shields.io/badge/Flutter-3.4+-blue.svg
[flutter_link]: https://flutter.dev
[flutterplaza_link]: https://github.com/FlutterPlaza
