import 'package:flutter/services.dart';

import 'av_player_platform.dart';
import 'generated/messages.g.dart';

/// Base class that delegates all 18 platform methods to the Pigeon-generated
/// [AvPlayerHostApi]. Platform-specific subclasses extend this and only
/// provide the [eventChannelPrefix] used for EventChannel names.
///
/// EventChannel is kept manual because Pigeon does not generate
/// EventChannel code.
class PigeonAvPlayer extends AvPlayerPlatform {
  PigeonAvPlayer({required String eventChannelPrefix})
      : _eventChannelPrefix = eventChannelPrefix;

  final AvPlayerHostApi _api = AvPlayerHostApi();
  final String _eventChannelPrefix;

  // ===========================================================================
  // Lifecycle
  // ===========================================================================

  @override
  Future<int> create(AVVideoSource source) {
    return _api.create(_videoSourceToMessage(source));
  }

  @override
  Future<void> dispose(int playerId) {
    return _api.dispose(playerId);
  }

  // ===========================================================================
  // Playback
  // ===========================================================================

  @override
  Future<void> play(int playerId) => _api.play(playerId);

  @override
  Future<void> pause(int playerId) => _api.pause(playerId);

  @override
  Future<void> seekTo(int playerId, Duration position) {
    return _api.seekTo(playerId, position.inMilliseconds);
  }

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) {
    return _api.setPlaybackSpeed(playerId, speed);
  }

  @override
  Future<void> setLooping(int playerId, bool looping) {
    return _api.setLooping(playerId, looping);
  }

  @override
  Future<void> setVolume(int playerId, double volume) {
    return _api.setVolume(playerId, volume);
  }

  // ===========================================================================
  // PIP
  // ===========================================================================

  @override
  Future<bool> isPipAvailable() => _api.isPipAvailable();

  @override
  Future<void> enterPip(int playerId, {double? aspectRatio}) {
    return _api.enterPip(EnterPipRequest(
      playerId: playerId,
      aspectRatio: aspectRatio,
    ));
  }

  @override
  Future<void> exitPip(int playerId) => _api.exitPip(playerId);

  // ===========================================================================
  // Media session / Notifications
  // ===========================================================================

  @override
  Future<void> setMediaMetadata(int playerId, AVMediaMetadata metadata) {
    return _api.setMediaMetadata(MediaMetadataRequest(
      playerId: playerId,
      metadata: MediaMetadataMessage(
        title: metadata.title,
        artist: metadata.artist,
        album: metadata.album,
        artworkUrl: metadata.artworkUrl,
      ),
    ));
  }

  @override
  Future<void> setNotificationEnabled(int playerId, bool enabled) {
    return _api.setNotificationEnabled(playerId, enabled);
  }

  // ===========================================================================
  // System controls
  // ===========================================================================

  @override
  Future<void> setSystemVolume(double volume) => _api.setSystemVolume(volume);

  @override
  Future<double> getSystemVolume() => _api.getSystemVolume();

  @override
  Future<void> setScreenBrightness(double brightness) {
    return _api.setScreenBrightness(brightness);
  }

  @override
  Future<double> getScreenBrightness() => _api.getScreenBrightness();

  @override
  Future<void> setWakelock(bool enabled) => _api.setWakelock(enabled);

  // ===========================================================================
  // Performance
  // ===========================================================================

  @override
  Future<void> setAbrConfig(int playerId, AVAbrConfig config) {
    return _api.setAbrConfig(SetAbrConfigRequest(
      playerId: playerId,
      config: AbrConfigMessage(
        maxBitrateBps: config.maxBitrateBps,
        minBitrateBps: config.minBitrateBps,
        preferredMaxWidth: config.preferredMaxWidth,
        preferredMaxHeight: config.preferredMaxHeight,
      ),
    ));
  }

  @override
  Future<AVDecoderInfo> getDecoderInfo(int playerId) async {
    final msg = await _api.getDecoderInfo(playerId);
    return AVDecoderInfo(
      isHardwareAccelerated: msg.isHardwareAccelerated,
      decoderName: msg.decoderName,
      codec: msg.codec,
    );
  }

  // ===========================================================================
  // Events (manual EventChannel — Pigeon doesn't generate these)
  // ===========================================================================

  @override
  Stream<AVPlayerEvent> playerEvents(int playerId) {
    return EventChannel('$_eventChannelPrefix/events/$playerId')
        .receiveBroadcastStream()
        .map((event) => AVPlayerEvent.fromMap(event as Map<dynamic, dynamic>));
  }

  // ===========================================================================
  // Conversion helpers
  // ===========================================================================

  static VideoSourceMessage _videoSourceToMessage(AVVideoSource source) {
    return switch (source) {
      AVNetworkSource(:final url, :final headers) => VideoSourceMessage(
          type: SourceType.network,
          url: url,
          headers: headers,
        ),
      AVAssetSource(:final assetPath) => VideoSourceMessage(
          type: SourceType.asset,
          assetPath: assetPath,
        ),
      AVFileSource(:final filePath) => VideoSourceMessage(
          type: SourceType.file,
          filePath: filePath,
        ),
    };
  }
}
