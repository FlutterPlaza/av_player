# AV Player

[![License: BSD-3-Clause][license_badge]][license_link]
[![Pub Version][pub_badge]][pub_link]
[![Flutter][flutter_badge]][flutter_link]

A powerful Flutter video player with **native Picture-in-Picture**, gesture controls, media notifications, playlist management, and theming — all with **zero external dependencies**.

Built by [FlutterPlaza][flutterplaza_link].

![Home Screen](av_player/doc/images/home_screen.png)

## Features

- **Native PIP** on Android, iOS, macOS, and Web
- **In-app PIP overlay** on all platforms (draggable, corner-snapping)
- **Video playback** from network URL, HLS/DASH stream, asset, or file
- **Gesture controls** — double-tap skip, swipe volume/brightness, long-press speed
- **Media notifications** — lock screen and notification bar controls
- **Playlist management** — queue, shuffle, repeat (none / one / all)
- **Content-type presets** — `.video()`, `.music()`, `.live()`, `.short()`
- **Theming** — full color customization via `AVPlayerTheme`
- **Playback speed** — 0.25x to 3.0x
- **Zero external dependencies** — uses native platform players directly
- **6 platforms** — Android, iOS, macOS, Linux, Windows, Web

## Quick Start

```yaml
dependencies:
  av_player: ^0.2.0
```

```dart
import 'package:av_player/av_player.dart';

// Create a controller
final controller = AVPlayerController(
  const AVVideoSource.network('https://example.com/video.mp4'),
)..initialize();

// Use a preset
AVVideoPlayer.video(controller, title: 'My Video')
```

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

## Documentation

See the full documentation in [av_player/README.md](av_player/README.md), including:

- Content-type presets (video, shorts, music, live)
- Picture-in-Picture (native & in-app)
- Gesture controls configuration
- Playlist management
- Theming customization
- Media notifications
- Custom controls
- Full API reference

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
