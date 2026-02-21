import 'av_player_platform.dart';
import 'pigeon_av_player.dart';

/// The iOS implementation of [AvPlayerPlatform].
///
/// Uses AVPlayer for video playback, AVPictureInPictureController for
/// Picture-in-Picture, and standard iOS APIs for system controls.
class AvPlayerIOS extends PigeonAvPlayer {
  AvPlayerIOS() : super(eventChannelPrefix: 'com.flutterplaza.av_player_ios');

  /// Registers this class as the default instance of [AvPlayerPlatform].
  static void registerWith() {
    AvPlayerPlatform.instance = AvPlayerIOS();
  }
}
