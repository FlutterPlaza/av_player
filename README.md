# AV Player

[![Pub Version][pub_badge]][pub_link]
[![CI][ci_badge]][ci_link]
[![codecov][codecov_badge]][codecov_link]
[![License: BSD-3-Clause][license_badge]][license_link]
[![Pub Points][pub_points_badge]][pub_points_link]
[![Pub Popularity][pub_popularity_badge]][pub_link]
[![Flutter][flutter_badge]][flutter_link]

A powerful Flutter video player with **native Picture-in-Picture**, gesture controls, media notifications, playlist management, subtitles/captions, and theming — all with **zero external dependencies**. Uses native platform players directly (ExoPlayer, AVPlayer, GStreamer, HTML5 Video).

Built by [FlutterPlaza][flutterplaza_link].

---

## Features

- **Native PIP** on Android, iOS, macOS, and Web
- **In-app PIP overlay** on all platforms (draggable, corner-snapping)
- **Video playback** from network URL, HLS/DASH stream, asset, or file
- **Gesture controls** — double-tap skip, swipe volume/brightness, long-press speed, horizontal swipe seek
- **Media notifications** — lock screen and notification bar controls
- **Playlist management** — queue, shuffle, repeat (none / one / all)
- **Subtitles & captions** — SRT, WebVTT, embedded HLS/DASH tracks, CC button
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
| Video Playback | Yes | Yes | Yes | Yes | Yes | Yes |
| Native PIP | Yes | Yes | Yes | — | — | Yes |
| In-App PIP | Yes | Yes | Yes | Yes | Yes | Yes |
| Media Notifications | Yes | Yes | — | Yes | Yes | Yes |
| Subtitles (External) | Yes | Yes | Yes | Yes | Yes | Yes |
| Subtitles (Embedded) | Yes | Yes | Yes | — | — | Yes |
| System Volume | Yes | Read-only | Yes | Yes | Yes | Per-element |
| Brightness | Yes | Yes | Built-in only | sysfs | Monitor API | — |
| Wakelock | Yes | Yes | Yes | Yes | Yes | Yes |

---

## Installation

```yaml
dependencies:
  av_player: ^0.5.0
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

```dart
AVVideoPlayer.video(
  controller,
  title: 'My Video',
  onFullscreen: () => enterFullscreen(),
)
```

### Shorts — `.short()`

Minimal UI for vertical short-form content (TikTok/Reels/Shorts style). Only play/pause center button with double-tap and long-press gestures. Set looping for continuous replay.

<p align="center">
  <img src="https://raw.githubusercontent.com/FlutterPlaza/av_player/main/doc/gif/shorts-ezgif.com-video-to-gif-converter.gif" alt="Shorts" width="300"/>
</p>

```dart
// Enable looping after initialization
controller.setLooping(true);
controller.play();

AVVideoPlayer.short(controller)
```

### Music Player — `.music()`

Audio-focused controls with skip next/previous, speed, and loop. Disables PIP and fullscreen since the video surface is used for album art or visualizer.

<p align="center">
  <img src="https://raw.githubusercontent.com/FlutterPlaza/av_player/main/doc/gif/music_player-ezgif.com-video-to-gif-converter.gif" alt="Music Player" width="300"/>
</p>

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

<p align="center">
  <img src="https://raw.githubusercontent.com/FlutterPlaza/av_player/main/doc/gif/live_stream-ezgif.com-video-to-gif-converter.gif" alt="Live Stream" width="300"/>
</p>

```dart
AVVideoPlayer.live(controller, title: 'LIVE')
```

---

## Picture-in-Picture

### Native PIP

Uses the OS-level picture-in-picture window. Supported on Android, iOS, macOS, and Web.

<p align="center">
  <img src="https://raw.githubusercontent.com/FlutterPlaza/av_player/main/doc/gif/picture_in_picture-ezgif.com-video-to-gif-converter.gif" alt="Picture-in-Picture" width="300"/>
</p>

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

<p align="center">
  <img src="https://raw.githubusercontent.com/FlutterPlaza/av_player/main/doc/gif/gesture_control-ezgif.com-video-to-gif-converter.gif" alt="Gesture Controls" width="300"/>
</p>

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

<p align="center">
  <img src="https://raw.githubusercontent.com/FlutterPlaza/av_player/main/doc/gif/playlist-ezgif.com-video-to-gif-converter.gif" alt="Playlist" width="300"/>
</p>

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

<p align="center">
  <img src="https://raw.githubusercontent.com/FlutterPlaza/av_player/main/doc/gif/theming-ezgif.com-video-to-gif-converter.gif" alt="Theming" width="300"/>
</p>

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

---

## Subtitles & Captions

AV Player supports both **external subtitles** (SRT/WebVTT parsed in Dart) and **embedded subtitle tracks** detected from HLS/DASH streams on supported platforms.

### External Subtitles

Load subtitle content from SRT or WebVTT strings. The parser auto-detects the format.

```dart
// Add subtitle tracks after initialization
await controller.initialize();

controller.addSubtitle(
  srtContent,     // SRT or WebVTT string
  label: 'English',
  language: 'en',
);

controller.addSubtitle(
  webVttContent,
  label: 'Español',
  language: 'es',
);
```

### Track Selection

Select a subtitle track by ID, or pass `null` to disable subtitles.

```dart
// Select a track
final tracks = controller.subtitleTracks;
await controller.selectSubtitleTrack(tracks.first.id);

// Disable subtitles
await controller.selectSubtitleTrack(null);

// Toggle subtitles on/off
await controller.toggleSubtitles();
```

### Subtitle Overlay

The `AVVideoPlayer` widget renders subtitles automatically. Use `showSubtitles` to control visibility.

```dart
AVVideoPlayer.video(
  controller,
  showSubtitles: true,  // or false to hide
)
```

The CC button in the controls bar lets users select tracks or toggle subtitles interactively.

### Parsing Subtitles Directly

Use `AVSubtitleParser` to parse subtitle files without a controller.

```dart
// Auto-detect format
final cues = AVSubtitleParser.parse(content);

// Or specify format
final srtCues = AVSubtitleParser.parseSrt(srtContent);
final vttCues = AVSubtitleParser.parseWebVtt(vttContent);
```

### Subtitle Theming

Customize subtitle appearance via `AVPlayerThemeData`.

```dart
AVPlayerTheme(
  data: const AVPlayerThemeData(
    subtitleTextColor: Colors.yellow,
    subtitleBackgroundColor: Color(0xCC000000),
    subtitleFontSize: 20.0,
  ),
  child: AVVideoPlayer.video(controller, showSubtitles: true),
)
```

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
| `addSubtitle(String, {label, language})` | Add external SRT/WebVTT subtitle track |
| `selectSubtitleTrack(String?)` | Select a subtitle track (null to disable) |
| `toggleSubtitles()` | Toggle subtitles on/off |
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
| `subtitlesEnabled` | `bool` | Whether subtitles are active |
| `currentSubtitleCue` | `AVSubtitleCue?` | Currently displayed subtitle |
| `availableSubtitleTracks` | `List<AVSubtitleTrack>` | Available subtitle tracks |
| `activeSubtitleTrackId` | `String?` | ID of selected subtitle track |

---

## Example App

The example app includes 9 dedicated screens showcasing each feature. Run it with:

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

[pub_badge]: https://img.shields.io/pub/v/av_player.svg
[pub_link]: https://pub.dev/packages/av_player
[ci_badge]: https://github.com/FlutterPlaza/av_player/actions/workflows/av_player.yaml/badge.svg
[ci_link]: https://github.com/FlutterPlaza/av_player/actions/workflows/av_player.yaml
[codecov_badge]: https://codecov.io/gh/FlutterPlaza/av_player/branch/main/graph/badge.svg
[codecov_link]: https://codecov.io/gh/FlutterPlaza/av_player
[license_badge]: https://img.shields.io/badge/license-BSD--3--Clause-blue.svg
[license_link]: https://opensource.org/licenses/BSD-3-Clause
[pub_points_badge]: https://img.shields.io/pub/points/av_player
[pub_points_link]: https://pub.dev/packages/av_player/score
[pub_popularity_badge]: https://img.shields.io/pub/popularity/av_player
[flutter_badge]: https://img.shields.io/badge/Flutter-3.22+-02569B.svg?logo=flutter
[flutter_link]: https://flutter.dev
[flutterplaza_link]: https://github.com/FlutterPlaza
