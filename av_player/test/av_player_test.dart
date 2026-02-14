import 'dart:async';

import 'package:av_player/av_player.dart';
import 'package:av_player/src/platform/av_player_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Mock platform
// ---------------------------------------------------------------------------

class _MockPlatform extends AvPlayerPlatform {
  final log = <String>[];
  StreamController<AVPlayerEvent>? _eventController;

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
  Future<void> seekTo(int playerId, Duration position) async =>
      log.add('seekTo');

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async =>
      log.add('setPlaybackSpeed');

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
  Future<void> setSystemVolume(double volume) async =>
      log.add('setSystemVolume');

  @override
  Future<double> getSystemVolume() async => 0.5;

  @override
  Future<void> setScreenBrightness(double brightness) async =>
      log.add('setScreenBrightness');

  @override
  Future<double> getScreenBrightness() async => 0.5;

  @override
  Future<void> setWakelock(bool enabled) async => log.add('setWakelock');

  @override
  Stream<AVPlayerEvent> playerEvents(int playerId) {
    _eventController = StreamController<AVPlayerEvent>();
    return _eventController!.stream;
  }

  void emitEvent(AVPlayerEvent event) => _eventController?.add(event);
}

void main() {
  late _MockPlatform mockPlatform;

  setUp(() {
    mockPlatform = _MockPlatform();
    AvPlayerPlatform.instance = mockPlatform;
  });

  // ---------------------------------------------------------------------------
  // AVPlayerState
  // ---------------------------------------------------------------------------

  group('AVPlayerState', () {
    test('default constructor has sensible defaults', () {
      const state = AVPlayerState();
      expect(state.position, Duration.zero);
      expect(state.duration, Duration.zero);
      expect(state.isPlaying, false);
      expect(state.isBuffering, false);
      expect(state.isLooping, false);
      expect(state.isInitialized, false);
      expect(state.isInPipMode, false);
      expect(state.isCompleted, false);
      expect(state.playbackSpeed, 1.0);
      expect(state.volume, 1.0);
      expect(state.aspectRatio, 16 / 9);
      expect(state.errorDescription, isNull);
      expect(state.hasError, false);
    });

    test('copyWith replaces specified fields', () {
      const state = AVPlayerState();
      final updated = state.copyWith(
        position: const Duration(seconds: 10),
        isPlaying: true,
        volume: 0.5,
      );
      expect(updated.position, const Duration(seconds: 10));
      expect(updated.isPlaying, true);
      expect(updated.volume, 0.5);
      // Unchanged fields
      expect(updated.duration, Duration.zero);
      expect(updated.isBuffering, false);
    });

    test('copyWith preserves unspecified fields', () {
      const state = AVPlayerState(
        position: Duration(seconds: 30),
        duration: Duration(minutes: 5),
        isPlaying: true,
        playbackSpeed: 2.0,
      );
      final updated = state.copyWith(volume: 0.7);
      expect(updated.position, const Duration(seconds: 30));
      expect(updated.duration, const Duration(minutes: 5));
      expect(updated.isPlaying, true);
      expect(updated.playbackSpeed, 2.0);
      expect(updated.volume, 0.7);
    });

    test('hasError returns true when errorDescription is set', () {
      const state = AVPlayerState(errorDescription: 'Network error');
      expect(state.hasError, true);
    });
  });

  // ---------------------------------------------------------------------------
  // AVPlayerController
  // ---------------------------------------------------------------------------

  group('AVPlayerController', () {
    test('initial state is uninitialized', () {
      final controller = AVPlayerController(
        const AVVideoSource.network('https://example.com/video.mp4'),
      );
      expect(controller.value.isInitialized, false);
      expect(controller.textureId, isNull);
      expect(controller.playerId, isNull);
      controller.dispose();
    });

    test('initialize() sets textureId and listens to events', () async {
      final controller = AVPlayerController(
        const AVVideoSource.network('https://example.com/video.mp4'),
      );
      await controller.initialize();
      expect(controller.textureId, 42);
      expect(controller.playerId, 42);
      expect(mockPlatform.log, contains('create'));
      controller.dispose();
    });

    test('play() calls platform and updates state', () async {
      final controller = AVPlayerController(
        const AVVideoSource.network('https://example.com/video.mp4'),
      );
      await controller.initialize();
      await controller.play();
      expect(mockPlatform.log, contains('play'));
      expect(controller.value.isPlaying, true);
      controller.dispose();
    });

    test('pause() calls platform and updates state', () async {
      final controller = AVPlayerController(
        const AVVideoSource.network('https://example.com/video.mp4'),
      );
      await controller.initialize();
      await controller.play();
      await controller.pause();
      expect(mockPlatform.log, contains('pause'));
      expect(controller.value.isPlaying, false);
      controller.dispose();
    });

    test('seekTo() calls platform and updates position', () async {
      final controller = AVPlayerController(
        const AVVideoSource.network('https://example.com/video.mp4'),
      );
      await controller.initialize();
      await controller.seekTo(const Duration(seconds: 30));
      expect(mockPlatform.log, contains('seekTo'));
      expect(controller.value.position, const Duration(seconds: 30));
      controller.dispose();
    });

    test('setPlaybackSpeed() calls platform and updates state', () async {
      final controller = AVPlayerController(
        const AVVideoSource.network('https://example.com/video.mp4'),
      );
      await controller.initialize();
      await controller.setPlaybackSpeed(2.0);
      expect(controller.value.playbackSpeed, 2.0);
      controller.dispose();
    });

    test('setLooping() calls platform and updates state', () async {
      final controller = AVPlayerController(
        const AVVideoSource.network('https://example.com/video.mp4'),
      );
      await controller.initialize();
      await controller.setLooping(true);
      expect(controller.value.isLooping, true);
      controller.dispose();
    });

    test('setVolume() clamps and updates state', () async {
      final controller = AVPlayerController(
        const AVVideoSource.network('https://example.com/video.mp4'),
      );
      await controller.initialize();
      await controller.setVolume(1.5);
      expect(controller.value.volume, 1.0);
      await controller.setVolume(-0.5);
      expect(controller.value.volume, 0.0);
      controller.dispose();
    });

    test('handles initialized event', () async {
      final controller = AVPlayerController(
        const AVVideoSource.network('https://example.com/video.mp4'),
      );
      await controller.initialize();
      mockPlatform.emitEvent(const AVInitializedEvent(
        duration: Duration(minutes: 3),
        width: 1920,
        height: 1080,
        textureId: 42,
      ));
      await Future<void>.delayed(Duration.zero);
      expect(controller.value.isInitialized, true);
      expect(controller.value.duration, const Duration(minutes: 3));
      expect(controller.value.aspectRatio, closeTo(16 / 9, 0.01));
      controller.dispose();
    });

    test('handles completed event', () async {
      final controller = AVPlayerController(
        const AVVideoSource.network('https://example.com/video.mp4'),
      );
      await controller.initialize();
      mockPlatform.emitEvent(const AVCompletedEvent());
      await Future<void>.delayed(Duration.zero);
      expect(controller.value.isCompleted, true);
      expect(controller.value.isPlaying, false);
      controller.dispose();
    });

    test('handles pipChanged event', () async {
      final controller = AVPlayerController(
        const AVVideoSource.network('https://example.com/video.mp4'),
      );
      await controller.initialize();
      mockPlatform.emitEvent(const AVPipChangedEvent(isInPipMode: true));
      await Future<void>.delayed(Duration.zero);
      expect(controller.value.isInPipMode, true);
      controller.dispose();
    });

    test('handles error event', () async {
      final controller = AVPlayerController(
        const AVVideoSource.network('https://example.com/video.mp4'),
      );
      await controller.initialize();
      mockPlatform.emitEvent(const AVErrorEvent(message: 'Decode error'));
      await Future<void>.delayed(Duration.zero);
      expect(controller.value.hasError, true);
      expect(controller.value.errorDescription, 'Decode error');
      controller.dispose();
    });

    test('onMediaCommand callback fires on media command event', () async {
      AVMediaCommand? receivedCommand;
      Duration? receivedPosition;
      final controller = AVPlayerController(
        const AVVideoSource.network('https://example.com/video.mp4'),
        onMediaCommand: (command, {seekPosition}) {
          receivedCommand = command;
          receivedPosition = seekPosition;
        },
      );
      await controller.initialize();
      mockPlatform.emitEvent(const AVMediaCommandEvent(
        command: AVMediaCommand.seekTo,
        seekPosition: Duration(seconds: 42),
      ));
      await Future<void>.delayed(Duration.zero);
      expect(receivedCommand, AVMediaCommand.seekTo);
      expect(receivedPosition, const Duration(seconds: 42));
      controller.dispose();
    });

    test('methods are no-ops before initialize', () async {
      final controller = AVPlayerController(
        const AVVideoSource.network('https://example.com/video.mp4'),
      );
      await controller.play();
      await controller.pause();
      await controller.seekTo(Duration.zero);
      // No platform calls should have been made
      expect(mockPlatform.log, isEmpty);
      controller.dispose();
    });

    test('dispose cleans up subscription and platform', () async {
      final controller = AVPlayerController(
        const AVVideoSource.network('https://example.com/video.mp4'),
      );
      await controller.initialize();
      controller.dispose();
      expect(mockPlatform.log, contains('dispose'));
    });
  });

  // ---------------------------------------------------------------------------
  // AVPlaylistController
  // ---------------------------------------------------------------------------

  group('AVPlaylistController', () {
    const s1 = AVVideoSource.network('https://example.com/1.mp4');
    const s2 = AVVideoSource.network('https://example.com/2.mp4');
    const s3 = AVVideoSource.network('https://example.com/3.mp4');

    test('initial state with sources', () {
      final playlist = AVPlaylistController(sources: [s1, s2, s3]);
      expect(playlist.value.queue, hasLength(3));
      expect(playlist.value.currentIndex, 0);
      expect(playlist.value.currentSource, isA<AVNetworkSource>());
      expect(playlist.value.hasNext, true);
      expect(playlist.value.hasPrevious, false);
    });

    test('initial state empty', () {
      final playlist = AVPlaylistController();
      expect(playlist.value.queue, isEmpty);
      expect(playlist.value.currentIndex, -1);
      expect(playlist.value.currentSource, isNull);
      expect(playlist.value.hasNext, false);
      expect(playlist.value.hasPrevious, false);
    });

    test('add() adds to queue and triggers source changed on first add', () {
      AVVideoSource? changed;
      final playlist = AVPlaylistController(
        onSourceChanged: (s) => changed = s,
      );
      playlist.add(s1);
      expect(playlist.value.queue, hasLength(1));
      expect(playlist.value.currentIndex, 0);
      expect(changed, isNotNull);
    });

    test('next() advances and wraps with repeat all', () {
      AVVideoSource? changed;
      final playlist = AVPlaylistController(
        sources: [s1, s2],
        onSourceChanged: (s) => changed = s,
      );
      playlist.setRepeatMode(AVRepeatMode.all);

      expect(playlist.next(), true);
      expect(playlist.value.currentIndex, 1);

      // Wraps around
      expect(playlist.next(), true);
      expect(playlist.value.currentIndex, 0);
      expect(changed, isNotNull);
    });

    test('next() returns false at end with no repeat', () {
      final playlist = AVPlaylistController(sources: [s1, s2]);
      expect(playlist.next(), true);
      expect(playlist.next(), false);
      expect(playlist.value.currentIndex, 1);
    });

    test('previous() goes back', () {
      final playlist = AVPlaylistController(sources: [s1, s2, s3]);
      playlist.next();
      playlist.next();
      expect(playlist.value.currentIndex, 2);

      expect(playlist.previous(), true);
      expect(playlist.value.currentIndex, 1);
    });

    test('previous() returns false at start with no repeat', () {
      final playlist = AVPlaylistController(sources: [s1, s2]);
      expect(playlist.previous(), false);
    });

    test('repeat one restarts current track on next()', () {
      int callCount = 0;
      final playlist = AVPlaylistController(
        sources: [s1, s2],
        onSourceChanged: (_) => callCount++,
      );
      playlist.setRepeatMode(AVRepeatMode.one);
      playlist.next();
      expect(playlist.value.currentIndex, 0);
      expect(callCount, 1);
    });

    test('removeAt() adjusts currentIndex', () {
      final playlist = AVPlaylistController(sources: [s1, s2, s3]);
      playlist.jumpTo(2);
      playlist.removeAt(0);
      expect(playlist.value.currentIndex, 1);
      expect(playlist.value.queue, hasLength(2));
    });

    test('clear() resets everything', () {
      final playlist = AVPlaylistController(sources: [s1, s2, s3]);
      playlist.clear();
      expect(playlist.value.queue, isEmpty);
      expect(playlist.value.currentIndex, -1);
    });

    test('shuffle keeps current track at front', () {
      final playlist = AVPlaylistController(sources: [s1, s2, s3]);
      playlist.jumpTo(1); // s2 is current
      playlist.setShuffle(true);
      expect(playlist.value.isShuffled, true);
      expect(playlist.value.currentIndex, 0);
      expect(playlist.value.currentSource, isA<AVNetworkSource>());
    });

    test('unshuffle restores original order', () {
      final playlist = AVPlaylistController(sources: [s1, s2, s3]);
      playlist.setShuffle(true);
      playlist.setShuffle(false);
      expect(playlist.value.isShuffled, false);
      expect(playlist.value.queue, hasLength(3));
    });

    test('onTrackCompleted() calls next()', () {
      int callCount = 0;
      final playlist = AVPlaylistController(
        sources: [s1, s2],
        onSourceChanged: (_) => callCount++,
      );
      playlist.onTrackCompleted();
      expect(playlist.value.currentIndex, 1);
      expect(callCount, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // AVPlayerThemeData
  // ---------------------------------------------------------------------------

  group('AVPlayerThemeData', () {
    test('default constructor provides sensible defaults', () {
      const theme = AVPlayerThemeData();
      expect(theme.iconColor, Colors.white);
      expect(theme.accentColor, Colors.blue);
      expect(theme.popupMenuColor, isNull);
    });

    test('copyWith replaces specified fields', () {
      const theme = AVPlayerThemeData();
      final updated = theme.copyWith(accentColor: Colors.red);
      expect(updated.accentColor, Colors.red);
      expect(updated.iconColor, Colors.white); // unchanged
    });

    test('equality works correctly', () {
      const a = AVPlayerThemeData();
      const b = AVPlayerThemeData();
      const c = AVPlayerThemeData(accentColor: Colors.red);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('hashCode is consistent with equality', () {
      const a = AVPlayerThemeData();
      const b = AVPlayerThemeData();
      expect(a.hashCode, b.hashCode);
    });
  });

  // ---------------------------------------------------------------------------
  // AVPlayerTheme InheritedWidget
  // ---------------------------------------------------------------------------

  group('AVPlayerTheme', () {
    testWidgets('of() returns default when no ancestor', (tester) async {
      late AVPlayerThemeData result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              result = AVPlayerTheme.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(result.iconColor, Colors.white);
      expect(result.accentColor, Colors.blue);
    });

    testWidgets('of() returns ancestor theme data', (tester) async {
      late AVPlayerThemeData result;
      await tester.pumpWidget(
        MaterialApp(
          home: AVPlayerTheme(
            data: const AVPlayerThemeData(accentColor: Colors.red),
            child: Builder(
              builder: (context) {
                result = AVPlayerTheme.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(result.accentColor, Colors.red);
    });

    testWidgets('maybeOf() returns null when no ancestor', (tester) async {
      AVPlayerThemeData? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              result = AVPlayerTheme.maybeOf(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(result, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // AVVideoPlayer presets
  // ---------------------------------------------------------------------------

  group('AVVideoPlayer presets', () {
    test('.video() enables all controls and gestures', () {
      final controller = AVPlayerController(
        const AVVideoSource.network('https://example.com/video.mp4'),
      );
      final widget = AVVideoPlayer.video(controller);
      expect(widget.showControls, true);
      expect(widget.controlsConfig, isNotNull);
      expect(widget.controlsConfig!.showSkipButtons, true);
      expect(widget.controlsConfig!.showPipButton, true);
      expect(widget.controlsConfig!.showSpeedButton, true);
      expect(widget.controlsConfig!.showFullscreenButton, true);
      expect(widget.controlsConfig!.showLoopButton, true);
      expect(widget.gestureConfig, isNotNull);
      expect(widget.gestureConfig!.doubleTapToSeek, true);
      expect(widget.gestureConfig!.longPressSpeed, true);
      expect(widget.gestureConfig!.swipeToVolume, true);
      expect(widget.gestureConfig!.swipeToBrightness, true);
      controller.dispose();
    });

    test('.music() has simple controls, no gestures', () {
      final controller = AVPlayerController(
        const AVVideoSource.network('https://example.com/song.mp3'),
      );
      final widget = AVVideoPlayer.music(controller);
      expect(widget.showControls, true);
      expect(widget.controlsConfig!.showPipButton, false);
      expect(widget.controlsConfig!.showFullscreenButton, false);
      expect(widget.gestureConfig, isNull);
      expect(widget.onFullscreen, isNull);
      controller.dispose();
    });

    test('.live() has no seek/skip, PIP + fullscreen', () {
      final controller = AVPlayerController(
        const AVVideoSource.network('https://example.com/live'),
      );
      final widget = AVVideoPlayer.live(controller);
      expect(widget.showControls, true);
      expect(widget.controlsConfig!.showSkipButtons, false);
      expect(widget.controlsConfig!.showSpeedButton, false);
      expect(widget.controlsConfig!.showLoopButton, false);
      expect(widget.controlsConfig!.showPipButton, true);
      expect(widget.controlsConfig!.showFullscreenButton, true);
      expect(widget.gestureConfig, isNull);
      expect(widget.onNext, isNull);
      expect(widget.onPrevious, isNull);
      controller.dispose();
    });

    test('.short() has minimal controls', () {
      final controller = AVPlayerController(
        const AVVideoSource.network('https://example.com/short'),
      );
      final widget = AVVideoPlayer.short(controller);
      expect(widget.showControls, true);
      expect(widget.controlsConfig!.showSkipButtons, false);
      expect(widget.controlsConfig!.showPipButton, false);
      expect(widget.controlsConfig!.showSpeedButton, false);
      expect(widget.controlsConfig!.showFullscreenButton, false);
      expect(widget.controlsConfig!.showLoopButton, false);
      expect(widget.gestureConfig, isNotNull);
      expect(widget.gestureConfig!.doubleTapToSeek, true);
      expect(widget.onFullscreen, isNull);
      controller.dispose();
    });
  });
}
