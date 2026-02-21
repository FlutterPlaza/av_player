import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// Video source
// ---------------------------------------------------------------------------

/// Describes where a video comes from.
sealed class AVVideoSource {
  const AVVideoSource();

  /// A video loaded from a network URL (HTTP/HTTPS, HLS, DASH).
  const factory AVVideoSource.network(
    String url, {
    Map<String, String> headers,
  }) = AVNetworkSource;

  /// A video loaded from a Flutter asset.
  const factory AVVideoSource.asset(String assetPath) = AVAssetSource;

  /// A video loaded from a local file path.
  const factory AVVideoSource.file(String filePath) = AVFileSource;

  /// Serializes this source to a map for platform channel transport.
  Map<String, dynamic> toMap();
}

/// A network video source.
class AVNetworkSource extends AVVideoSource {
  const AVNetworkSource(this.url, {this.headers = const {}});

  final String url;
  final Map<String, String> headers;

  @override
  Map<String, dynamic> toMap() => {
        'type': 'network',
        'url': url,
        'headers': headers,
      };
}

/// An asset video source.
class AVAssetSource extends AVVideoSource {
  const AVAssetSource(this.assetPath);

  final String assetPath;

  @override
  Map<String, dynamic> toMap() => {
        'type': 'asset',
        'assetPath': assetPath,
      };
}

/// A local file video source.
class AVFileSource extends AVVideoSource {
  const AVFileSource(this.filePath);

  final String filePath;

  @override
  Map<String, dynamic> toMap() => {
        'type': 'file',
        'filePath': filePath,
      };
}

// ---------------------------------------------------------------------------
// Media metadata
// ---------------------------------------------------------------------------

/// Metadata for media session / lock screen / notification display.
@immutable
class AVMediaMetadata {
  const AVMediaMetadata({
    this.title,
    this.artist,
    this.album,
    this.artworkUrl,
  });

  final String? title;
  final String? artist;
  final String? album;
  final String? artworkUrl;

  Map<String, dynamic> toMap() => {
        'title': title,
        'artist': artist,
        'album': album,
        'artworkUrl': artworkUrl,
      };

  factory AVMediaMetadata.fromMap(Map<String, dynamic> map) {
    return AVMediaMetadata(
      title: map['title'] as String?,
      artist: map['artist'] as String?,
      album: map['album'] as String?,
      artworkUrl: map['artworkUrl'] as String?,
    );
  }
}

// ---------------------------------------------------------------------------
// ABR config
// ---------------------------------------------------------------------------

/// Configuration for Adaptive Bitrate streaming.
@immutable
class AVAbrConfig {
  const AVAbrConfig({
    this.maxBitrateBps,
    this.minBitrateBps,
    this.preferredMaxWidth,
    this.preferredMaxHeight,
  });

  final int? maxBitrateBps;
  final int? minBitrateBps;
  final int? preferredMaxWidth;
  final int? preferredMaxHeight;
}

// ---------------------------------------------------------------------------
// Decoder info
// ---------------------------------------------------------------------------

/// Information about the active video decoder.
@immutable
class AVDecoderInfo {
  const AVDecoderInfo({
    required this.isHardwareAccelerated,
    this.decoderName,
    this.codec,
  });

  final bool isHardwareAccelerated;
  final String? decoderName;
  final String? codec;

  /// Default value for platforms that cannot query decoder state.
  static const unknown = AVDecoderInfo(isHardwareAccelerated: false);
}

// ---------------------------------------------------------------------------
// Memory pressure
// ---------------------------------------------------------------------------

/// Severity level of OS memory pressure.
enum AVMemoryPressureLevel { normal, warning, critical }

// ---------------------------------------------------------------------------
// Player events
// ---------------------------------------------------------------------------

/// Events emitted by the native player via EventChannel.
sealed class AVPlayerEvent {
  const AVPlayerEvent();

  /// Deserializes a platform event map into a typed event.
  factory AVPlayerEvent.fromMap(Map<dynamic, dynamic> map) {
    final type = map['type'] as String;
    return switch (type) {
      'initialized' => AVInitializedEvent(
          duration: Duration(milliseconds: map['duration'] as int),
          width: (map['width'] as num).toDouble(),
          height: (map['height'] as num).toDouble(),
          textureId: map['textureId'] as int,
        ),
      'positionChanged' => AVPositionChangedEvent(
          position: Duration(milliseconds: map['position'] as int),
        ),
      'playbackStateChanged' => AVPlaybackStateChangedEvent(
          state: AVPlaybackState.values.firstWhere(
            (s) => s.name == map['state'],
            orElse: () => AVPlaybackState.idle,
          ),
        ),
      'bufferingUpdate' => AVBufferingUpdateEvent(
          buffered: Duration(milliseconds: map['buffered'] as int),
        ),
      'pipChanged' => AVPipChangedEvent(
          isInPipMode: map['isInPipMode'] as bool,
        ),
      'completed' => const AVCompletedEvent(),
      'error' => AVErrorEvent(
          message: map['message'] as String? ?? 'Unknown error',
          code: map['code'] as String?,
        ),
      'mediaCommand' => AVMediaCommandEvent(
          command: AVMediaCommand.values.firstWhere(
            (c) => c.name == map['command'],
            orElse: () => AVMediaCommand.play,
          ),
          seekPosition: map['seekPosition'] != null
              ? Duration(milliseconds: map['seekPosition'] as int)
              : null,
        ),
      'abrInfo' => AVAbrInfoEvent(
          currentBitrateBps: map['currentBitrateBps'] as int,
          availableBitrateBps:
              (map['availableBitrateBps'] as List<dynamic>).cast<int>(),
        ),
      'memoryPressure' => AVMemoryPressureEvent(
          level: AVMemoryPressureLevel.values.firstWhere(
            (l) => l.name == map['level'],
            orElse: () => AVMemoryPressureLevel.normal,
          ),
        ),
      _ => AVErrorEvent(message: 'Unknown event type: $type'),
    };
  }
}

/// Player was initialized and is ready for playback.
class AVInitializedEvent extends AVPlayerEvent {
  const AVInitializedEvent({
    required this.duration,
    required this.width,
    required this.height,
    required this.textureId,
  });

  final Duration duration;
  final double width;
  final double height;
  final int textureId;
}

/// Playback position changed.
class AVPositionChangedEvent extends AVPlayerEvent {
  const AVPositionChangedEvent({required this.position});
  final Duration position;
}

/// Playback state changed.
class AVPlaybackStateChangedEvent extends AVPlayerEvent {
  const AVPlaybackStateChangedEvent({required this.state});
  final AVPlaybackState state;
}

/// Buffered range updated.
class AVBufferingUpdateEvent extends AVPlayerEvent {
  const AVBufferingUpdateEvent({required this.buffered});
  final Duration buffered;
}

/// PIP mode entered or exited.
class AVPipChangedEvent extends AVPlayerEvent {
  const AVPipChangedEvent({required this.isInPipMode});
  final bool isInPipMode;
}

/// Playback reached the end of the media.
class AVCompletedEvent extends AVPlayerEvent {
  const AVCompletedEvent();
}

/// An error occurred.
class AVErrorEvent extends AVPlayerEvent {
  const AVErrorEvent({required this.message, this.code});
  final String message;
  final String? code;
}

/// A media command was received from the notification or lock screen.
class AVMediaCommandEvent extends AVPlayerEvent {
  const AVMediaCommandEvent({required this.command, this.seekPosition});
  final AVMediaCommand command;

  /// Only set for [AVMediaCommand.seekTo].
  final Duration? seekPosition;
}

/// ABR info updated (current and available bitrates).
class AVAbrInfoEvent extends AVPlayerEvent {
  const AVAbrInfoEvent({
    required this.currentBitrateBps,
    required this.availableBitrateBps,
  });
  final int currentBitrateBps;
  final List<int> availableBitrateBps;
}

/// OS memory pressure level changed.
class AVMemoryPressureEvent extends AVPlayerEvent {
  const AVMemoryPressureEvent({required this.level});
  final AVMemoryPressureLevel level;
}

// ---------------------------------------------------------------------------
// Media commands
// ---------------------------------------------------------------------------

/// Commands that can be received from the media notification or lock screen.
enum AVMediaCommand {
  play,
  pause,
  next,
  previous,
  seekTo,
  stop,
}

// ---------------------------------------------------------------------------
// Playback state enum
// ---------------------------------------------------------------------------

/// The playback state of a player.
enum AVPlaybackState {
  idle,
  initializing,
  ready,
  playing,
  paused,
  buffering,
  completed,
  error,
}
