# AV Picture-in-Picture

[![License: MIT][license_badge]][license_link]
[![Pub Version][pub_badge]][pub_link]

A powerful Flutter video player plugin with native Picture-in-Picture support, built by [FlutterPlaza][flutterplaza_link].

## Features

- Native PIP on Android and iOS
- In-app PIP overlay on all platforms (draggable, resizable)
- Video playback from any source (URL, HLS/DASH stream, asset, file)
- Gesture controls (double-tap skip, swipe volume/brightness, long-press speed)
- Media notification controls (lock screen, notification bar)
- Playlist/queue management with shuffle and repeat
- Customizable controls and themes
- Background audio playback
- Playback speed control (0.25x - 3.0x)
- Zero external dependencies - uses native platform players directly
- Supports Android, iOS, macOS, Linux, Windows, Web

## Getting Started

```yaml
dependencies:
  av_player: ^0.2.0
```

## Usage

```dart
import 'package:av_player/av_player.dart';

// Basic usage
AVVideoPlayer(
  source: AVVideoSource.network('https://example.com/video.mp4'),
)
```

## Platform Support

| Feature | Android | iOS | macOS | Linux | Windows | Web |
|---------|---------|-----|-------|-------|---------|-----|
| Video Playback | Yes | Yes | Yes | Yes | Yes | Yes |
| Native PIP | Yes | Yes | Yes | - | - | Yes |
| Notifications | Yes | Yes | - | - | - | Yes |

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting a PR.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[pub_badge]: https://img.shields.io/pub/v/av_player.svg
[pub_link]: https://pub.dev/packages/av_player
[flutterplaza_link]: https://github.com/FlutterPlaza
