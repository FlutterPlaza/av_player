import 'package:av_player/src/platform/av_player_platform.dart';
import 'package:av_player/src/platform/method_channel_av_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MethodChannelAvPlayer', () {
    late MethodChannelAvPlayer platform;
    final log = <MethodCall>[];

    setUp(() {
      platform = MethodChannelAvPlayer();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        platform.methodChannel,
        (methodCall) async {
          log.add(methodCall);
          switch (methodCall.method) {
            case 'create':
              return 42;
            case 'isPipAvailable':
              return true;
            case 'getSystemVolume':
              return 0.75;
            case 'getScreenBrightness':
              return 0.6;
            default:
              return null;
          }
        },
      );
    });

    tearDown(() {
      log.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(platform.methodChannel, null);
    });

    // -----------------------------------------------------------------------
    // Lifecycle
    // -----------------------------------------------------------------------

    test('create() sends source map and returns textureId', () async {
      final id = await platform.create(
        const AVVideoSource.network('https://example.com/video.mp4'),
      );
      expect(id, 42);
      expect(log, <Matcher>[
        isMethodCall('create', arguments: {
          'type': 'network',
          'url': 'https://example.com/video.mp4',
          'headers': <String, String>{},
        }),
      ]);
    });

    test('create() returns -1 when native returns null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        platform.methodChannel,
        (methodCall) async {
          log.add(methodCall);
          return null;
        },
      );
      final id = await platform.create(
        const AVVideoSource.network('https://example.com/video.mp4'),
      );
      expect(id, -1);
    });

    test('dispose() sends playerId', () async {
      await platform.dispose(42);
      expect(log, <Matcher>[
        isMethodCall('dispose', arguments: {'playerId': 42}),
      ]);
    });

    // -----------------------------------------------------------------------
    // Playback
    // -----------------------------------------------------------------------

    test('play() sends playerId', () async {
      await platform.play(1);
      expect(log, <Matcher>[
        isMethodCall('play', arguments: {'playerId': 1}),
      ]);
    });

    test('pause() sends playerId', () async {
      await platform.pause(1);
      expect(log, <Matcher>[
        isMethodCall('pause', arguments: {'playerId': 1}),
      ]);
    });

    test('seekTo() sends playerId and position in ms', () async {
      await platform.seekTo(1, const Duration(seconds: 30));
      expect(log, <Matcher>[
        isMethodCall('seekTo', arguments: {
          'playerId': 1,
          'position': 30000,
        }),
      ]);
    });

    test('setPlaybackSpeed() sends playerId and speed', () async {
      await platform.setPlaybackSpeed(1, 2.0);
      expect(log, <Matcher>[
        isMethodCall('setPlaybackSpeed', arguments: {
          'playerId': 1,
          'speed': 2.0,
        }),
      ]);
    });

    test('setLooping() sends playerId and looping', () async {
      await platform.setLooping(1, true);
      expect(log, <Matcher>[
        isMethodCall('setLooping', arguments: {
          'playerId': 1,
          'looping': true,
        }),
      ]);
    });

    test('setVolume() sends playerId and volume', () async {
      await platform.setVolume(1, 0.5);
      expect(log, <Matcher>[
        isMethodCall('setVolume', arguments: {
          'playerId': 1,
          'volume': 0.5,
        }),
      ]);
    });

    // -----------------------------------------------------------------------
    // PIP
    // -----------------------------------------------------------------------

    test('isPipAvailable() returns native result', () async {
      final available = await platform.isPipAvailable();
      expect(available, true);
      expect(log, <Matcher>[
        isMethodCall('isPipAvailable', arguments: null),
      ]);
    });

    test('isPipAvailable() returns false when native returns null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        platform.methodChannel,
        (methodCall) async {
          log.add(methodCall);
          return null;
        },
      );
      final available = await platform.isPipAvailable();
      expect(available, false);
    });

    test('enterPip() sends playerId without aspect ratio', () async {
      await platform.enterPip(1);
      expect(log, <Matcher>[
        isMethodCall('enterPip', arguments: {'playerId': 1}),
      ]);
    });

    test('enterPip() sends playerId with aspect ratio', () async {
      await platform.enterPip(1, aspectRatio: 16 / 9);
      expect(log, <Matcher>[
        isMethodCall('enterPip', arguments: {
          'playerId': 1,
          'aspectRatio': 16 / 9,
        }),
      ]);
    });

    test('exitPip() sends playerId', () async {
      await platform.exitPip(1);
      expect(log, <Matcher>[
        isMethodCall('exitPip', arguments: {'playerId': 1}),
      ]);
    });

    // -----------------------------------------------------------------------
    // Media session
    // -----------------------------------------------------------------------

    test('setMediaMetadata() sends playerId and metadata fields', () async {
      await platform.setMediaMetadata(
        1,
        const AVMediaMetadata(
          title: 'Song',
          artist: 'Band',
          album: 'Album',
          artworkUrl: 'https://example.com/art.jpg',
        ),
      );
      expect(log, <Matcher>[
        isMethodCall('setMediaMetadata', arguments: {
          'playerId': 1,
          'title': 'Song',
          'artist': 'Band',
          'album': 'Album',
          'artworkUrl': 'https://example.com/art.jpg',
        }),
      ]);
    });

    test('setNotificationEnabled() sends playerId and enabled', () async {
      await platform.setNotificationEnabled(1, true);
      expect(log, <Matcher>[
        isMethodCall('setNotificationEnabled', arguments: {
          'playerId': 1,
          'enabled': true,
        }),
      ]);
    });

    // -----------------------------------------------------------------------
    // System controls
    // -----------------------------------------------------------------------

    test('setSystemVolume() sends volume', () async {
      await platform.setSystemVolume(0.5);
      expect(log, <Matcher>[
        isMethodCall('setSystemVolume', arguments: {'volume': 0.5}),
      ]);
    });

    test('getSystemVolume() returns native result', () async {
      final volume = await platform.getSystemVolume();
      expect(volume, 0.75);
    });

    test('getSystemVolume() returns 0.0 when native returns null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        platform.methodChannel,
        (methodCall) async {
          log.add(methodCall);
          return null;
        },
      );
      final volume = await platform.getSystemVolume();
      expect(volume, 0.0);
    });

    test('setScreenBrightness() sends brightness', () async {
      await platform.setScreenBrightness(0.8);
      expect(log, <Matcher>[
        isMethodCall('setScreenBrightness', arguments: {'brightness': 0.8}),
      ]);
    });

    test('getScreenBrightness() returns native result', () async {
      final brightness = await platform.getScreenBrightness();
      expect(brightness, 0.6);
    });

    test('getScreenBrightness() returns 0.5 when native returns null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        platform.methodChannel,
        (methodCall) async {
          log.add(methodCall);
          return null;
        },
      );
      final brightness = await platform.getScreenBrightness();
      expect(brightness, 0.5);
    });

    test('setWakelock() sends enabled', () async {
      await platform.setWakelock(true);
      expect(log, <Matcher>[
        isMethodCall('setWakelock', arguments: {'enabled': true}),
      ]);
    });

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    test('eventChannelFor() creates channel with correct name', () {
      final channel = platform.eventChannelFor(42);
      expect(channel, isA<EventChannel>());
      expect(channel.name, 'av_player/events/42');
    });
  });
}
