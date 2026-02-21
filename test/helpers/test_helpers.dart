import 'dart:async';

import 'package:av_player/av_player.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Mock platform
// ---------------------------------------------------------------------------

class TestMockPlatform extends AvPlayerPlatform {
  final log = <String>[];
  final seekLog = <Duration>[];
  final speedLog = <double>[];
  StreamController<AVPlayerEvent>? _eventController;

  double systemVolume = 0.5;
  double screenBrightness = 0.5;

  @override
  Future<int> create(AVVideoSource source) async {
    log.add('create');
    return 42;
  }

  @override
  Future<void> dispose(int playerId) async => log.add('dispose');

  @override
  Future<void> play(int playerId) async => log.add('play');

  @override
  Future<void> pause(int playerId) async => log.add('pause');

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    log.add('seekTo');
    seekLog.add(position);
  }

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {
    log.add('setPlaybackSpeed');
    speedLog.add(speed);
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async =>
      log.add('setLooping');

  @override
  Future<void> setVolume(int playerId, double volume) async =>
      log.add('setVolume');

  @override
  Future<bool> isPipAvailable() async => true;

  @override
  Future<void> enterPip(int playerId, {double? aspectRatio}) async =>
      log.add('enterPip');

  @override
  Future<void> exitPip(int playerId) async => log.add('exitPip');

  @override
  Future<void> setMediaMetadata(int playerId, AVMediaMetadata metadata) async =>
      log.add('setMediaMetadata');

  @override
  Future<void> setNotificationEnabled(int playerId, bool enabled) async =>
      log.add('setNotificationEnabled');

  @override
  Future<void> setSystemVolume(double volume) async {
    log.add('setSystemVolume');
    systemVolume = volume;
  }

  @override
  Future<double> getSystemVolume() async => systemVolume;

  @override
  Future<void> setScreenBrightness(double brightness) async {
    log.add('setScreenBrightness');
    screenBrightness = brightness;
  }

  @override
  Future<double> getScreenBrightness() async => screenBrightness;

  @override
  Future<void> setWakelock(bool enabled) async => log.add('setWakelock');

  @override
  Future<void> setAbrConfig(int playerId, AVAbrConfig config) async =>
      log.add('setAbrConfig');

  @override
  Future<AVDecoderInfo> getDecoderInfo(int playerId) async =>
      AVDecoderInfo.unknown;

  @override
  Stream<AVPlayerEvent> playerEvents(int playerId) {
    _eventController = StreamController<AVPlayerEvent>();
    return _eventController!.stream;
  }

  void emitEvent(AVPlayerEvent event) => _eventController?.add(event);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a controller, initializes it, and sets the state directly.
///
/// Uses direct value assignment instead of stream events to avoid
/// FakeAsync issues in widget tests.
Future<AVPlayerController> createInitializedController(
  TestMockPlatform platform, {
  Duration duration = const Duration(minutes: 5),
  double width = 1920,
  double height = 1080,
  bool playing = false,
}) async {
  final controller = AVPlayerController(
    const AVVideoSource.network('https://example.com/video.mp4'),
  );
  await controller.initialize();
  controller.value = controller.value.copyWith(
    isInitialized: true,
    duration: duration,
    aspectRatio: width > 0 && height > 0 ? width / height : 16 / 9,
  );
  if (playing) {
    await controller.play();
  }
  return controller;
}

/// Wraps a widget in MaterialApp + Scaffold + MediaQuery with known dimensions.
Widget wrapWithApp(
  Widget child, {
  Size size = const Size(800, 600),
  EdgeInsets padding = EdgeInsets.zero,
}) {
  return MediaQuery(
    data: MediaQueryData(size: size, padding: padding),
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

/// Wraps a widget in MaterialApp + Scaffold + AVPlayerTheme for theme-aware testing.
Widget wrapWithThemedApp(
  Widget child,
  AVPlayerThemeData themeData, {
  Size size = const Size(800, 600),
  EdgeInsets padding = EdgeInsets.zero,
}) {
  return MediaQuery(
    data: MediaQueryData(size: size, padding: padding),
    child: MaterialApp(
      home: Scaffold(
        body: AVPlayerTheme(
          data: themeData,
          child: child,
        ),
      ),
    ),
  );
}
