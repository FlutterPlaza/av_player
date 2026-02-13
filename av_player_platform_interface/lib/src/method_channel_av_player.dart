import 'package:av_player_platform_interface/av_player_platform_interface.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';

/// An implementation of [AvPlayerPlatform] that uses method channels.
///
/// This is the default fallback implementation. Platform-specific packages
/// (Android, iOS, etc.) register their own implementations that override this.
class MethodChannelAvPlayer extends AvPlayerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('av_player');

  /// The event channel used to receive player events from the native platform.
  @visibleForTesting
  EventChannel eventChannelFor(int playerId) =>
      EventChannel('av_player/events/$playerId');

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

  @override
  Future<bool> isPipAvailable() async {
    final result =
        await methodChannel.invokeMethod<bool>('isPipAvailable');
    return result ?? false;
  }

  @override
  Future<void> enterPip(int playerId, {double? aspectRatio}) {
    return methodChannel.invokeMethod('enterPip', {
      'playerId': playerId,
      if (aspectRatio != null) 'aspectRatio': aspectRatio,
    });
  }

  @override
  Future<void> exitPip(int playerId) {
    return methodChannel.invokeMethod('exitPip', {'playerId': playerId});
  }

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
    return methodChannel
        .invokeMethod('setWakelock', {'enabled': enabled});
  }

  @override
  Stream<AVPlayerEvent> playerEvents(int playerId) {
    return eventChannelFor(playerId)
        .receiveBroadcastStream()
        .map((event) => AVPlayerEvent.fromMap(event as Map<dynamic, dynamic>));
  }
}
