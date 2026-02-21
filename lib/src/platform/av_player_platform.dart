import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'method_channel_av_player.dart';
import 'types.dart';

export 'types.dart';

/// The interface that implementations of av_player must implement.
///
/// Platform implementations should extend this class rather than implement it.
/// Extending ensures that the subclass will get default implementations,
/// while `implements` would break when new methods are added.
abstract class AvPlayerPlatform extends PlatformInterface {
  AvPlayerPlatform() : super(token: _token);

  static final Object _token = Object();

  static AvPlayerPlatform _instance = MethodChannelAvPlayer();

  /// The default instance of [AvPlayerPlatform] to use.
  ///
  /// Defaults to [MethodChannelAvPlayer].
  static AvPlayerPlatform get instance => _instance;

  /// Platform-specific plugins should set this with their own platform-specific
  /// class that extends [AvPlayerPlatform] when they register themselves.
  static set instance(AvPlayerPlatform instance) {
    PlatformInterface.verify(instance, _token);
    _instance = instance;
  }

  // ===========================================================================
  // Lifecycle
  // ===========================================================================

  /// Creates a native player for [source] and returns a texture ID for
  /// rendering. The returned ID is used as the `playerId` in all other methods.
  Future<int> create(AVVideoSource source) {
    throw UnimplementedError('create() has not been implemented.');
  }

  /// Releases the native player identified by [playerId].
  Future<void> dispose(int playerId) {
    throw UnimplementedError('dispose() has not been implemented.');
  }

  // ===========================================================================
  // Playback
  // ===========================================================================

  /// Starts or resumes playback.
  Future<void> play(int playerId) {
    throw UnimplementedError('play() has not been implemented.');
  }

  /// Pauses playback.
  Future<void> pause(int playerId) {
    throw UnimplementedError('pause() has not been implemented.');
  }

  /// Seeks to the given [position].
  Future<void> seekTo(int playerId, Duration position) {
    throw UnimplementedError('seekTo() has not been implemented.');
  }

  /// Sets the playback speed. 1.0 is normal speed.
  Future<void> setPlaybackSpeed(int playerId, double speed) {
    throw UnimplementedError('setPlaybackSpeed() has not been implemented.');
  }

  /// Sets whether the video should loop.
  Future<void> setLooping(int playerId, bool looping) {
    throw UnimplementedError('setLooping() has not been implemented.');
  }

  /// Sets the player's volume. Range: 0.0 (mute) to 1.0 (max).
  Future<void> setVolume(int playerId, double volume) {
    throw UnimplementedError('setVolume() has not been implemented.');
  }

  // ===========================================================================
  // Picture-in-Picture
  // ===========================================================================

  /// Returns `true` if PIP mode is available on this device.
  Future<bool> isPipAvailable() {
    throw UnimplementedError('isPipAvailable() has not been implemented.');
  }

  /// Enters PIP mode for [playerId].
  Future<void> enterPip(int playerId, {double? aspectRatio}) {
    throw UnimplementedError('enterPip() has not been implemented.');
  }

  /// Exits PIP mode for [playerId].
  Future<void> exitPip(int playerId) {
    throw UnimplementedError('exitPip() has not been implemented.');
  }

  // ===========================================================================
  // Media session / Notifications
  // ===========================================================================

  /// Sets metadata for the media notification / lock screen display.
  Future<void> setMediaMetadata(int playerId, AVMediaMetadata metadata) {
    throw UnimplementedError('setMediaMetadata() has not been implemented.');
  }

  /// Enables or disables the media notification for [playerId].
  Future<void> setNotificationEnabled(int playerId, bool enabled) {
    throw UnimplementedError(
        'setNotificationEnabled() has not been implemented.');
  }

  // ===========================================================================
  // System controls
  // ===========================================================================

  /// Sets the system volume. Range: 0.0 to 1.0.
  Future<void> setSystemVolume(double volume) {
    throw UnimplementedError('setSystemVolume() has not been implemented.');
  }

  /// Returns the current system volume (0.0 to 1.0).
  Future<double> getSystemVolume() {
    throw UnimplementedError('getSystemVolume() has not been implemented.');
  }

  /// Sets the screen brightness. Range: 0.0 to 1.0.
  Future<void> setScreenBrightness(double brightness) {
    throw UnimplementedError('setScreenBrightness() has not been implemented.');
  }

  /// Returns the current screen brightness (0.0 to 1.0).
  Future<double> getScreenBrightness() {
    throw UnimplementedError('getScreenBrightness() has not been implemented.');
  }

  /// Enables or disables wakelock (prevents screen from turning off).
  Future<void> setWakelock(bool enabled) {
    throw UnimplementedError('setWakelock() has not been implemented.');
  }

  // ===========================================================================
  // Performance
  // ===========================================================================

  /// Sets the adaptive bitrate streaming configuration for [playerId].
  Future<void> setAbrConfig(int playerId, AVAbrConfig config) {
    throw UnimplementedError('setAbrConfig() has not been implemented.');
  }

  /// Returns decoder information for [playerId].
  Future<AVDecoderInfo> getDecoderInfo(int playerId) {
    throw UnimplementedError('getDecoderInfo() has not been implemented.');
  }

  // ===========================================================================
  // Events
  // ===========================================================================

  /// A stream of [AVPlayerEvent]s for the player identified by [playerId].
  Stream<AVPlayerEvent> playerEvents(int playerId) {
    throw UnimplementedError('playerEvents() has not been implemented.');
  }
}
