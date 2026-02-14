@TestOn('browser')
library;

import 'dart:async';

import 'package:av_player/src/platform/av_player_platform.dart';
import 'package:av_player/src/platform/av_player_web.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AvPlayerWeb', () {
    late AvPlayerWeb plugin;

    setUp(() {
      plugin = AvPlayerWeb();
    });

    // =========================================================================
    // Registration
    // =========================================================================

    test('registerWith() sets platform instance', () {
      AvPlayerWeb.registerWith();
      expect(
        AvPlayerPlatform.instance,
        isA<AvPlayerWeb>(),
      );
    });

    // =========================================================================
    // View type
    // =========================================================================

    test('viewType() returns correct prefix with player ID', () {
      expect(
        AvPlayerWeb.viewType(0),
        'com.flutterplaza.av_pip_video_0',
      );
      expect(
        AvPlayerWeb.viewType(42),
        'com.flutterplaza.av_pip_video_42',
      );
    });

    // =========================================================================
    // Lifecycle
    // =========================================================================

    test('create() returns incrementing IDs starting at 0', () async {
      final id0 = await plugin.create(
        const AVVideoSource.network('https://example.com/v1.mp4'),
      );
      final id1 = await plugin.create(
        const AVVideoSource.network('https://example.com/v2.mp4'),
      );
      expect(id0, 0);
      expect(id1, 1);
    });

    test('create() handles network source without headers', () async {
      final id = await plugin.create(
        const AVVideoSource.network('https://example.com/video.mp4'),
      );
      expect(id, isNonNegative);
    });

    test('create() handles network source with headers', () async {
      final id = await plugin.create(
        const AVVideoSource.network(
          'https://example.com/video.mp4',
          headers: {'Authorization': 'Bearer token'},
        ),
      );
      expect(id, isNonNegative);
    });

    test('create() handles asset source', () async {
      final id = await plugin.create(
        const AVVideoSource.asset('assets/video.mp4'),
      );
      expect(id, isNonNegative);
    });

    test('create() handles file source', () async {
      final id = await plugin.create(
        const AVVideoSource.file('/path/to/video.mp4'),
      );
      expect(id, isNonNegative);
    });

    test('dispose() completes without error for valid player', () async {
      final id = await plugin.create(
        const AVVideoSource.network('https://example.com/video.mp4'),
      );
      await expectLater(plugin.dispose(id), completes);
    });

    test('dispose() completes without error for non-existent player', () async {
      await expectLater(plugin.dispose(999), completes);
    });

    // =========================================================================
    // Playback
    // =========================================================================

    test('pause() completes for valid player', () async {
      final id = await plugin.create(
        const AVVideoSource.network('https://example.com/video.mp4'),
      );
      await expectLater(plugin.pause(id), completes);
    });

    test('pause() returns silently for non-existent player', () async {
      await expectLater(plugin.pause(999), completes);
    });

    test('seekTo() completes for valid player', () async {
      final id = await plugin.create(
        const AVVideoSource.network('https://example.com/video.mp4'),
      );
      await expectLater(
        plugin.seekTo(id, const Duration(seconds: 30)),
        completes,
      );
    });

    test('seekTo() returns silently for non-existent player', () async {
      await expectLater(
        plugin.seekTo(999, const Duration(seconds: 30)),
        completes,
      );
    });

    test('setPlaybackSpeed() completes for valid player', () async {
      final id = await plugin.create(
        const AVVideoSource.network('https://example.com/video.mp4'),
      );
      await expectLater(plugin.setPlaybackSpeed(id, 2.0), completes);
    });

    test('setLooping() completes for valid player', () async {
      final id = await plugin.create(
        const AVVideoSource.network('https://example.com/video.mp4'),
      );
      await expectLater(plugin.setLooping(id, true), completes);
    });

    test('setVolume() completes for valid player', () async {
      final id = await plugin.create(
        const AVVideoSource.network('https://example.com/video.mp4'),
      );
      await expectLater(plugin.setVolume(id, 0.5), completes);
    });

    // =========================================================================
    // PIP
    // =========================================================================

    test('isPipAvailable() returns a boolean', () async {
      final available = await plugin.isPipAvailable();
      expect(available, isA<bool>());
    });

    test('exitPip() completes without error', () async {
      // Should not throw even when no element is in PIP.
      await expectLater(plugin.exitPip(1), completes);
    });

    // =========================================================================
    // Media Session
    // =========================================================================

    test('setMediaMetadata() completes with full metadata', () async {
      final id = await plugin.create(
        const AVVideoSource.network('https://example.com/video.mp4'),
      );
      await expectLater(
        plugin.setMediaMetadata(
          id,
          const AVMediaMetadata(
            title: 'Test Video',
            artist: 'Test Artist',
            album: 'Test Album',
            artworkUrl: 'https://example.com/art.jpg',
          ),
        ),
        completes,
      );
    });

    test('setMediaMetadata() completes with null artwork', () async {
      final id = await plugin.create(
        const AVVideoSource.network('https://example.com/video.mp4'),
      );
      await expectLater(
        plugin.setMediaMetadata(
          id,
          const AVMediaMetadata(title: 'Test'),
        ),
        completes,
      );
    });

    test('setNotificationEnabled() registers and unregisters handlers',
        () async {
      final id = await plugin.create(
        const AVVideoSource.network('https://example.com/video.mp4'),
      );
      await expectLater(plugin.setNotificationEnabled(id, true), completes);
      await expectLater(plugin.setNotificationEnabled(id, false), completes);
    });

    test('setNotificationEnabled() returns silently for non-existent player',
        () async {
      await expectLater(plugin.setNotificationEnabled(999, true), completes);
    });

    // =========================================================================
    // System Controls
    // =========================================================================

    test('setSystemVolume() applies to all active players', () async {
      await plugin.create(
        const AVVideoSource.network('https://example.com/v1.mp4'),
      );
      await plugin.create(
        const AVVideoSource.network('https://example.com/v2.mp4'),
      );
      await expectLater(plugin.setSystemVolume(0.5), completes);
    });

    test('getSystemVolume() returns 1.0 with no players', () async {
      final volume = await plugin.getSystemVolume();
      expect(volume, 1.0);
    });

    test('getSystemVolume() returns volume of first player', () async {
      final id = await plugin.create(
        const AVVideoSource.network('https://example.com/video.mp4'),
      );
      await plugin.setVolume(id, 0.7);
      final volume = await plugin.getSystemVolume();
      expect(volume, closeTo(0.7, 0.01));
    });

    test('setScreenBrightness() completes (no-op on web)', () async {
      await expectLater(plugin.setScreenBrightness(0.8), completes);
    });

    test('getScreenBrightness() returns 0.5 default on web', () async {
      final brightness = await plugin.getScreenBrightness();
      expect(brightness, 0.5);
    });

    test('setWakelock() completes without throwing', () async {
      // Wake Lock API may not be available in all test browsers,
      // but the method should handle that gracefully.
      await expectLater(plugin.setWakelock(true), completes);
      await expectLater(plugin.setWakelock(false), completes);
    });

    // =========================================================================
    // Events
    // =========================================================================

    test('playerEvents() returns stream for valid player', () async {
      final id = await plugin.create(
        const AVVideoSource.network('https://example.com/video.mp4'),
      );
      final stream = plugin.playerEvents(id);
      expect(stream, isA<Stream<AVPlayerEvent>>());
    });

    test('playerEvents() returns empty stream for non-existent player',
        () async {
      final stream = plugin.playerEvents(999);
      expect(stream, isA<Stream<AVPlayerEvent>>());
      // Empty stream should complete immediately.
      final events = await stream.toList();
      expect(events, isEmpty);
    });
  });
}
