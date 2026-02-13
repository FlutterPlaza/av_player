import 'package:av_player_platform_interface/av_player_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The Linux implementation of [AvPlayerPlatform].
///
/// Uses GStreamer for video playback, MPRIS2 D-Bus for media session,
/// PulseAudio for system volume, and sysfs for screen brightness.
class AvPlayerLinux extends AvPlayerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel =
      const MethodChannel('com.flutterplaza.av_player_linux');

  /// Registers this class as the default instance of [AvPlayerPlatform].
  static void registerWith() {
    AvPlayerPlatform.instance = AvPlayerLinux();
  }

  // ===========================================================================
  // Lifecycle
  // ===========================================================================

  @override
  Future<int> create(AVVideoSource source) async {
    final result = await methodChannel.invokeMethod<int>(
      'create',
      source.toMap(),
    );
    return result ?? -1;
  }

  @override
  Future<void> dispose(int playerId) {
    return methodChannel.invokeMethod('dispose', {'playerId': playerId});
  }

  // ===========================================================================
  // Playback
  // ===========================================================================

  @override
  Future<void> play(int playerId) {
    return methodChannel.invokeMethod('play', {'playerId': playerId});
  }

  @override
  Future<void> pause(int playerId) {
    return methodChannel.invokeMethod('pause', {'playerId': playerId});
  }

  @override
  Future<void> seekTo(int playerId, Duration position) {
    return methodChannel.invokeMethod('seekTo', {
      'playerId': playerId,
      'position': position.inMilliseconds,
    });
  }

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) {
    return methodChannel.invokeMethod('setPlaybackSpeed', {
      'playerId': playerId,
      'speed': speed,
    });
  }

  @override
  Future<void> setLooping(int playerId, bool looping) {
    return methodChannel.invokeMethod('setLooping', {
      'playerId': playerId,
      'looping': looping,
    });
  }

  @override
  Future<void> setVolume(int playerId, double volume) {
    return methodChannel.invokeMethod('setVolume', {
      'playerId': playerId,
      'volume': volume,
    });
  }

  // ===========================================================================
  // PIP
  // ===========================================================================

  @override
  Future<bool> isPipAvailable() async {
    // PIP is not available on Linux (no standard OS-level PIP API).
    // In-app PIP overlay works via Dart.
    return false;
  }

  @override
  Future<void> enterPip(int playerId, {double? aspectRatio}) async {
    // No-op on Linux. Use in-app PIP overlay instead.
  }

  @override
  Future<void> exitPip(int playerId) async {
    // No-op on Linux.
  }

  // ===========================================================================
  // System Controls
  // ===========================================================================

  @override
  Future<void> setSystemVolume(double volume) {
    return methodChannel.invokeMethod('setSystemVolume', {'volume': volume});
  }

  @override
  Future<double> getSystemVolume() async {
    final result =
        await methodChannel.invokeMethod<double>('getSystemVolume');
    return result ?? 0.0;
  }

  @override
  Future<void> setScreenBrightness(double brightness) {
    return methodChannel
        .invokeMethod('setScreenBrightness', {'brightness': brightness});
  }

  @override
  Future<double> getScreenBrightness() async {
    final result =
        await methodChannel.invokeMethod<double>('getScreenBrightness');
    return result ?? 0.5;
  }

  @override
  Future<void> setWakelock(bool enabled) {
    return methodChannel.invokeMethod('setWakelock', {'enabled': enabled});
  }

  // ===========================================================================
  // Media session / Notifications
  // ===========================================================================

  @override
  Future<void> setMediaMetadata(int playerId, AVMediaMetadata metadata) {
    return methodChannel.invokeMethod('setMediaMetadata', {
      'playerId': playerId,
      ...metadata.toMap(),
    });
  }

  @override
  Future<void> setNotificationEnabled(int playerId, bool enabled) {
    return methodChannel.invokeMethod('setNotificationEnabled', {
      'playerId': playerId,
      'enabled': enabled,
    });
  }

  // ===========================================================================
  // Events
  // ===========================================================================

  @override
  Stream<AVPlayerEvent> playerEvents(int playerId) {
    return EventChannel(
      'com.flutterplaza.av_player_linux/events/$playerId',
    )
        .receiveBroadcastStream()
        .map((event) =>
            AVPlayerEvent.fromMap(event as Map<dynamic, dynamic>));
  }
}
