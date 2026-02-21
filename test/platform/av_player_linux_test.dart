import 'package:av_player/src/platform/av_player_linux.dart';
import 'package:av_player/src/platform/av_player_platform.dart';
import 'package:av_player/src/platform/generated/messages.g.dart';
import 'package:flutter_test/flutter_test.dart';

import 'method_channel_av_player_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AvPlayerLinux', () {
    late AvPlayerLinux platform;
    late MockAvPlayerHostApi mock;

    setUp(() {
      platform = AvPlayerLinux();
      mock = MockAvPlayerHostApi();
      mock.setHandler('create', (_) => 42);
      mock.setHandler('getSystemVolume', (_) => 0.75);
      mock.setHandler('getScreenBrightness', (_) => 0.6);
      mock.setHandler('getDecoderInfo', (_) => DecoderInfoMessage(
            isHardwareAccelerated: true,
            decoderName: 'TestDecoder',
            codec: 'H.264',
          ));
      mock.install();
    });

    tearDown(() {
      mock.uninstall();
    });

    // -----------------------------------------------------------------------
    // Registration
    // -----------------------------------------------------------------------

    test('registerWith() sets platform instance', () {
      AvPlayerLinux.registerWith();
      expect(AvPlayerPlatform.instance, isA<AvPlayerLinux>());
    });

    // -----------------------------------------------------------------------
    // Lifecycle
    // -----------------------------------------------------------------------

    test('create() sends source and returns textureId', () async {
      final id = await platform.create(
        const AVVideoSource.network('https://example.com/video.mp4'),
      );
      expect(id, 42);
      expect(mock.log, ['create']);
    });

    test('dispose() sends playerId', () async {
      await platform.dispose(42);
      expect(mock.log, ['dispose']);
    });

    // -----------------------------------------------------------------------
    // Playback
    // -----------------------------------------------------------------------

    test('play() sends playerId', () async {
      await platform.play(1);
      expect(mock.log, ['play']);
    });

    test('pause() sends playerId', () async {
      await platform.pause(1);
      expect(mock.log, ['pause']);
    });

    test('seekTo() sends playerId and position in ms', () async {
      await platform.seekTo(1, const Duration(seconds: 30));
      expect(mock.log, ['seekTo']);
    });

    test('setPlaybackSpeed() sends playerId and speed', () async {
      await platform.setPlaybackSpeed(1, 2.0);
      expect(mock.log, ['setPlaybackSpeed']);
    });

    test('setLooping() sends playerId and looping', () async {
      await platform.setLooping(1, true);
      expect(mock.log, ['setLooping']);
    });

    test('setVolume() sends playerId and volume', () async {
      await platform.setVolume(1, 0.5);
      expect(mock.log, ['setVolume']);
    });

    // -----------------------------------------------------------------------
    // PIP (not available on Linux)
    // -----------------------------------------------------------------------

    test('isPipAvailable() returns false without native call', () async {
      final available = await platform.isPipAvailable();
      expect(available, false);
      // Should NOT call native — handled in Dart
      expect(mock.log, isEmpty);
    });

    test('enterPip() is a no-op without native call', () async {
      await platform.enterPip(1);
      expect(mock.log, isEmpty);
    });

    test('exitPip() is a no-op without native call', () async {
      await platform.exitPip(1);
      expect(mock.log, isEmpty);
    });

    // -----------------------------------------------------------------------
    // Media session
    // -----------------------------------------------------------------------

    test('setMediaMetadata() sends playerId and metadata', () async {
      await platform.setMediaMetadata(
        1,
        const AVMediaMetadata(
          title: 'Song',
          artist: 'Band',
          album: 'Album',
          artworkUrl: 'https://example.com/art.jpg',
        ),
      );
      expect(mock.log, ['setMediaMetadata']);
    });

    test('setNotificationEnabled() sends playerId and enabled', () async {
      await platform.setNotificationEnabled(1, true);
      expect(mock.log, ['setNotificationEnabled']);
    });

    // -----------------------------------------------------------------------
    // System controls
    // -----------------------------------------------------------------------

    test('setSystemVolume() sends volume', () async {
      await platform.setSystemVolume(0.5);
      expect(mock.log, ['setSystemVolume']);
    });

    test('getSystemVolume() returns native result', () async {
      final volume = await platform.getSystemVolume();
      expect(volume, 0.75);
    });

    test('setScreenBrightness() sends brightness', () async {
      await platform.setScreenBrightness(0.8);
      expect(mock.log, ['setScreenBrightness']);
    });

    test('getScreenBrightness() returns native result', () async {
      final brightness = await platform.getScreenBrightness();
      expect(brightness, 0.6);
    });

    test('setWakelock() sends enabled', () async {
      await platform.setWakelock(true);
      expect(mock.log, ['setWakelock']);
    });

    // -----------------------------------------------------------------------
    // Performance
    // -----------------------------------------------------------------------

    test('setAbrConfig() sends request', () async {
      await platform.setAbrConfig(
        1,
        const AVAbrConfig(maxBitrateBps: 5000000),
      );
      expect(mock.log, ['setAbrConfig']);
    });

    test('getDecoderInfo() returns native result', () async {
      final info = await platform.getDecoderInfo(1);
      expect(info.isHardwareAccelerated, true);
      expect(info.decoderName, 'TestDecoder');
      expect(info.codec, 'H.264');
      expect(mock.log, ['getDecoderInfo']);
    });

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    test('playerEvents() returns stream from correct event channel', () {
      final stream = platform.playerEvents(42);
      expect(stream, isA<Stream<AVPlayerEvent>>());
    });
  });
}
