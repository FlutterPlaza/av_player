import 'av_player_platform.dart';
import 'pigeon_av_player.dart';

/// The Linux implementation of [AvPlayerPlatform].
///
/// Uses GStreamer for video playback, MPRIS2 D-Bus for media session,
/// PulseAudio for system volume, and sysfs for screen brightness.
class AvPlayerLinux extends PigeonAvPlayer {
  AvPlayerLinux()
      : super(eventChannelPrefix: 'com.flutterplaza.av_player_linux');

  /// Registers this class as the default instance of [AvPlayerPlatform].
  static void registerWith() {
    AvPlayerPlatform.instance = AvPlayerLinux();
  }

  // PIP is not available on Linux (no standard OS-level PIP API).
  // In-app PIP overlay works via Dart.

  @override
  Future<bool> isPipAvailable() async => false;

  @override
  Future<void> enterPip(int playerId, {double? aspectRatio}) async {}

  @override
  Future<void> exitPip(int playerId) async {}
}
