import 'av_player_platform.dart';
import 'pigeon_av_player.dart';

/// The Windows implementation of [AvPlayerPlatform].
///
/// Uses Media Foundation for video playback, SystemMediaTransportControls
/// for media session, WASAPI for system volume, and Monitor Configuration
/// API for screen brightness.
class AvPlayerWindows extends PigeonAvPlayer {
  AvPlayerWindows()
      : super(eventChannelPrefix: 'com.flutterplaza.av_player_windows');

  /// Registers this class as the default instance of [AvPlayerPlatform].
  static void registerWith() {
    AvPlayerPlatform.instance = AvPlayerWindows();
  }

  // PIP is not available on Windows (no standard OS-level PIP API).
  // In-app PIP overlay works via Dart.

  @override
  Future<bool> isPipAvailable() async => false;

  @override
  Future<void> enterPip(int playerId, {double? aspectRatio}) async {}

  @override
  Future<void> exitPip(int playerId) async {}
}
