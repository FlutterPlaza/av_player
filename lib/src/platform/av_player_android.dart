import 'av_player_platform.dart';
import 'pigeon_av_player.dart';

/// The Android implementation of [AvPlayerPlatform].
///
/// Uses ExoPlayer (Media3) for video playback, Android PIP APIs for
/// Picture-in-Picture, and standard Android APIs for system controls.
class AvPlayerAndroid extends PigeonAvPlayer {
  AvPlayerAndroid()
      : super(eventChannelPrefix: 'com.flutterplaza.av_player_android');

  /// Registers this class as the default instance of [AvPlayerPlatform].
  static void registerWith() {
    AvPlayerPlatform.instance = AvPlayerAndroid();
  }
}
