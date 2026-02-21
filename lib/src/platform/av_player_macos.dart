import 'av_player_platform.dart';
import 'pigeon_av_player.dart';

/// The macOS implementation of [AvPlayerPlatform].
///
/// Uses AVPlayer for video playback, AVPictureInPictureController for
/// Picture-in-Picture, and standard macOS APIs for system controls.
class AvPlayerMacOS extends PigeonAvPlayer {
  AvPlayerMacOS()
      : super(eventChannelPrefix: 'com.flutterplaza.av_player_macos');

  /// Registers this class as the default instance of [AvPlayerPlatform].
  static void registerWith() {
    AvPlayerPlatform.instance = AvPlayerMacOS();
  }
}
