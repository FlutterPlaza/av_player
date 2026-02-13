# 0.2.0-beta.1

## Breaking Changes
- Removed `video_player` dependency - uses native platform players directly
- New `AVPlayerController` API with `ValueNotifier`-based state
- Removed `very_good_analysis` dependency

## Added
- Full video playback via native ExoPlayer (Android) / AVPlayer (iOS)
- Native PIP support on Android and iOS
- In-app PIP overlay on all platforms (draggable, resizable)
- Media notification controls (lock screen, notification bar)
- Gesture controls (double-tap skip, swipe volume/brightness, long-press speed)
- Playlist/queue management (next, previous, shuffle, repeat)
- Customizable controls and themes
- Background audio playback
- System volume and brightness control
- Wakelock support
- Playback speed control (0.25x - 3.0x)

## Removed
- `video_player` dependency
- `very_good_analysis` dependency
- Very Good Ventures branding (now maintained by FlutterPlaza)

# 0.1.0+1

- Initial release of this plugin.