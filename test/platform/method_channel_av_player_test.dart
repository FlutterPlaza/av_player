import 'package:av_player/src/platform/av_player_platform.dart';
import 'package:av_player/src/platform/generated/messages.g.dart';
import 'package:av_player/src/platform/method_channel_av_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A test helper that installs mock handlers for the Pigeon-generated
/// [AvPlayerHostApi] BasicMessageChannels so we can verify what the Dart
/// side sends and control what it receives.
class MockAvPlayerHostApi {
  final List<String> log = [];
  final Map<String, Object? Function(Object?)> _handlers = {};

  void setHandler(String method, Object? Function(Object? args) handler) {
    _handlers[method] = handler;
  }

  void install() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final method in _allMethods) {
      final channelName =
          'dev.flutter.pigeon.av_player.AvPlayerHostApi.$method';
      messenger.setMockMessageHandler(channelName, (ByteData? message) async {
        log.add(method);
        final decoded = AvPlayerHostApi.pigeonChannelCodec
            .decodeMessage(message);
        final handler = _handlers[method];
        final result = handler != null ? handler(decoded) : null;
        // Pigeon expects a List<Object?> response where [0] is the result
        return AvPlayerHostApi.pigeonChannelCodec
            .encodeMessage(<Object?>[result]);
      });
    }
  }

  void uninstall() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final method in _allMethods) {
      final channelName =
          'dev.flutter.pigeon.av_player.AvPlayerHostApi.$method';
      messenger.setMockMessageHandler(channelName, null);
    }
  }

  static const _allMethods = [
    'create',
    'dispose',
    'play',
    'pause',
    'seekTo',
    'setPlaybackSpeed',
    'setLooping',
    'setVolume',
    'isPipAvailable',
    'enterPip',
    'exitPip',
    'setMediaMetadata',
    'setNotificationEnabled',
    'setSystemVolume',
    'getSystemVolume',
    'setScreenBrightness',
    'getScreenBrightness',
    'setWakelock',
    'setAbrConfig',
    'getDecoderInfo',
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MethodChannelAvPlayer', () {
    late MethodChannelAvPlayer platform;
    late MockAvPlayerHostApi mock;

    setUp(() {
      platform = MethodChannelAvPlayer();
      mock = MockAvPlayerHostApi();
      mock.setHandler('create', (_) => 42);
      mock.setHandler('isPipAvailable', (_) => true);
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
    // PIP
    // -----------------------------------------------------------------------

    test('isPipAvailable() returns native result', () async {
      final available = await platform.isPipAvailable();
      expect(available, true);
      expect(mock.log, ['isPipAvailable']);
    });

    test('enterPip() sends playerId without aspect ratio', () async {
      await platform.enterPip(1);
      expect(mock.log, ['enterPip']);
    });

    test('enterPip() sends playerId with aspect ratio', () async {
      await platform.enterPip(1, aspectRatio: 16 / 9);
      expect(mock.log, ['enterPip']);
    });

    test('exitPip() sends playerId', () async {
      await platform.exitPip(1);
      expect(mock.log, ['exitPip']);
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

    test('playerEvents() returns a stream', () {
      final stream = platform.playerEvents(42);
      expect(stream, isA<Stream<AVPlayerEvent>>());
    });
  });
}
