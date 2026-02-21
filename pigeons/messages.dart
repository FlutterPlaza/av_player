import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/platform/generated/messages.g.dart',
  dartTestOut: 'test/platform/generated/messages.g.dart',
  kotlinOut:
      'android/src/main/kotlin/com/flutterplaza/avplayer/Messages.g.kt',
  kotlinOptions: KotlinOptions(package: 'com.flutterplaza.avplayer'),
  swiftOut: 'ios/av_player/Sources/av_player/Messages.g.swift',
  cppHeaderOut: 'windows/messages.g.h',
  cppSourceOut: 'windows/messages.g.cpp',
  cppOptions: CppOptions(namespace: 'av_player_windows'),
  gobjectHeaderOut: 'linux/messages.g.h',
  gobjectSourceOut: 'linux/messages.g.cc',
  gobjectOptions: GObjectOptions(module: 'AvPlayer'),
))

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

enum SourceType {
  network,
  asset,
  file,
}

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------

class VideoSourceMessage {
  VideoSourceMessage({
    required this.type,
    this.url,
    this.headers,
    this.assetPath,
    this.filePath,
  });

  final SourceType type;
  final String? url;
  final Map<String?, String?>? headers;
  final String? assetPath;
  final String? filePath;
}

class MediaMetadataMessage {
  MediaMetadataMessage({
    this.title,
    this.artist,
    this.album,
    this.artworkUrl,
  });

  final String? title;
  final String? artist;
  final String? album;
  final String? artworkUrl;
}

class EnterPipRequest {
  EnterPipRequest({
    required this.playerId,
    this.aspectRatio,
  });

  final int playerId;
  final double? aspectRatio;
}

class MediaMetadataRequest {
  MediaMetadataRequest({
    required this.playerId,
    required this.metadata,
  });

  final int playerId;
  final MediaMetadataMessage metadata;
}

// ---------------------------------------------------------------------------
// Performance data classes
// ---------------------------------------------------------------------------

class AbrConfigMessage {
  AbrConfigMessage({
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

class SetAbrConfigRequest {
  SetAbrConfigRequest({
    required this.playerId,
    required this.config,
  });

  final int playerId;
  final AbrConfigMessage config;
}

class DecoderInfoMessage {
  DecoderInfoMessage({
    required this.isHardwareAccelerated,
    this.decoderName,
    this.codec,
  });

  final bool isHardwareAccelerated;
  final String? decoderName;
  final String? codec;
}

// ---------------------------------------------------------------------------
// Subtitle data classes
// ---------------------------------------------------------------------------

class SubtitleTrackMessage {
  SubtitleTrackMessage({required this.id, required this.label, this.language});
  final String id;
  final String label;
  final String? language;
}

class SelectSubtitleTrackRequest {
  SelectSubtitleTrackRequest({required this.playerId, this.trackId});
  final int playerId;
  final String? trackId; // null = disable subtitles
}

// ---------------------------------------------------------------------------
// Host API
// ---------------------------------------------------------------------------

@HostApi()
abstract class AvPlayerHostApi {
  // Lifecycle
  @async
  int create(VideoSourceMessage source);

  @async
  void dispose(int playerId);

  // Playback
  @async
  void play(int playerId);

  @async
  void pause(int playerId);

  @async
  void seekTo(int playerId, int positionMs);

  @async
  void setPlaybackSpeed(int playerId, double speed);

  @async
  void setLooping(int playerId, bool looping);

  @async
  void setVolume(int playerId, double volume);

  // PIP
  @async
  bool isPipAvailable();

  @async
  void enterPip(EnterPipRequest request);

  @async
  void exitPip(int playerId);

  // Media session
  @async
  void setMediaMetadata(MediaMetadataRequest request);

  @async
  void setNotificationEnabled(int playerId, bool enabled);

  // System controls
  @async
  void setSystemVolume(double volume);

  @async
  double getSystemVolume();

  @async
  void setScreenBrightness(double brightness);

  @async
  double getScreenBrightness();

  @async
  void setWakelock(bool enabled);

  // Performance
  @async
  void setAbrConfig(SetAbrConfigRequest request);

  @async
  DecoderInfoMessage getDecoderInfo(int playerId);

  // Subtitles
  @async
  List<SubtitleTrackMessage> getSubtitleTracks(int playerId);

  @async
  void selectSubtitleTrack(SelectSubtitleTrackRequest request);
}
