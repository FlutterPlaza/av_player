import 'package:av_player/src/platform/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---------------------------------------------------------------------------
  // AVVideoSource
  // ---------------------------------------------------------------------------

  group('AVVideoSource', () {
    group('network', () {
      test('toMap() serializes url and empty headers', () {
        const source = AVVideoSource.network('https://example.com/video.mp4');
        expect(source.toMap(), {
          'type': 'network',
          'url': 'https://example.com/video.mp4',
          'headers': <String, String>{},
        });
      });

      test('toMap() serializes url with headers', () {
        const source = AVVideoSource.network(
          'https://example.com/video.mp4',
          headers: {'Authorization': 'Bearer token123'},
        );
        expect(source.toMap(), {
          'type': 'network',
          'url': 'https://example.com/video.mp4',
          'headers': {'Authorization': 'Bearer token123'},
        });
      });

      test('is AVNetworkSource', () {
        const source = AVVideoSource.network('https://example.com/video.mp4');
        expect(source, isA<AVNetworkSource>());
        expect(
            (source as AVNetworkSource).url, 'https://example.com/video.mp4');
      });
    });

    group('asset', () {
      test('toMap() serializes assetPath', () {
        const source = AVVideoSource.asset('assets/video.mp4');
        expect(source.toMap(), {
          'type': 'asset',
          'assetPath': 'assets/video.mp4',
        });
      });

      test('is AVAssetSource', () {
        const source = AVVideoSource.asset('assets/video.mp4');
        expect(source, isA<AVAssetSource>());
        expect((source as AVAssetSource).assetPath, 'assets/video.mp4');
      });
    });

    group('file', () {
      test('toMap() serializes filePath', () {
        const source = AVVideoSource.file('/data/video.mp4');
        expect(source.toMap(), {
          'type': 'file',
          'filePath': '/data/video.mp4',
        });
      });

      test('is AVFileSource', () {
        const source = AVVideoSource.file('/data/video.mp4');
        expect(source, isA<AVFileSource>());
        expect((source as AVFileSource).filePath, '/data/video.mp4');
      });
    });
  });

  // ---------------------------------------------------------------------------
  // AVMediaMetadata
  // ---------------------------------------------------------------------------

  group('AVMediaMetadata', () {
    test('toMap() serializes all fields', () {
      const metadata = AVMediaMetadata(
        title: 'Title',
        artist: 'Artist',
        album: 'Album',
        artworkUrl: 'https://example.com/art.jpg',
      );
      expect(metadata.toMap(), {
        'title': 'Title',
        'artist': 'Artist',
        'album': 'Album',
        'artworkUrl': 'https://example.com/art.jpg',
      });
    });

    test('toMap() serializes null fields', () {
      const metadata = AVMediaMetadata();
      expect(metadata.toMap(), {
        'title': null,
        'artist': null,
        'album': null,
        'artworkUrl': null,
      });
    });

    test('fromMap() deserializes all fields', () {
      final metadata = AVMediaMetadata.fromMap({
        'title': 'Title',
        'artist': 'Artist',
        'album': 'Album',
        'artworkUrl': 'https://example.com/art.jpg',
      });
      expect(metadata.title, 'Title');
      expect(metadata.artist, 'Artist');
      expect(metadata.album, 'Album');
      expect(metadata.artworkUrl, 'https://example.com/art.jpg');
    });

    test('fromMap() handles null fields', () {
      final metadata = AVMediaMetadata.fromMap({});
      expect(metadata.title, isNull);
      expect(metadata.artist, isNull);
      expect(metadata.album, isNull);
      expect(metadata.artworkUrl, isNull);
    });

    test('roundtrip toMap/fromMap preserves data', () {
      const original = AVMediaMetadata(
        title: 'Song',
        artist: 'Band',
      );
      final restored = AVMediaMetadata.fromMap(original.toMap());
      expect(restored.title, original.title);
      expect(restored.artist, original.artist);
      expect(restored.album, original.album);
      expect(restored.artworkUrl, original.artworkUrl);
    });
  });

  // ---------------------------------------------------------------------------
  // AVPlayerEvent.fromMap
  // ---------------------------------------------------------------------------

  group('AVPlayerEvent.fromMap', () {
    test('parses initialized event', () {
      final event = AVPlayerEvent.fromMap({
        'type': 'initialized',
        'duration': 60000,
        'width': 1920,
        'height': 1080,
        'textureId': 42,
      });
      expect(event, isA<AVInitializedEvent>());
      final e = event as AVInitializedEvent;
      expect(e.duration, const Duration(seconds: 60));
      expect(e.width, 1920.0);
      expect(e.height, 1080.0);
      expect(e.textureId, 42);
    });

    test('parses positionChanged event', () {
      final event = AVPlayerEvent.fromMap({
        'type': 'positionChanged',
        'position': 5000,
      });
      expect(event, isA<AVPositionChangedEvent>());
      final e = event as AVPositionChangedEvent;
      expect(e.position, const Duration(seconds: 5));
    });

    test('parses playbackStateChanged event', () {
      for (final state in AVPlaybackState.values) {
        final event = AVPlayerEvent.fromMap({
          'type': 'playbackStateChanged',
          'state': state.name,
        });
        expect(event, isA<AVPlaybackStateChangedEvent>());
        expect((event as AVPlaybackStateChangedEvent).state, state);
      }
    });

    test('parses playbackStateChanged with unknown state defaults to idle', () {
      final event = AVPlayerEvent.fromMap({
        'type': 'playbackStateChanged',
        'state': 'nonexistent',
      });
      expect(event, isA<AVPlaybackStateChangedEvent>());
      expect(
          (event as AVPlaybackStateChangedEvent).state, AVPlaybackState.idle);
    });

    test('parses bufferingUpdate event', () {
      final event = AVPlayerEvent.fromMap({
        'type': 'bufferingUpdate',
        'buffered': 30000,
      });
      expect(event, isA<AVBufferingUpdateEvent>());
      expect(
        (event as AVBufferingUpdateEvent).buffered,
        const Duration(seconds: 30),
      );
    });

    test('parses pipChanged event', () {
      final enterEvent = AVPlayerEvent.fromMap({
        'type': 'pipChanged',
        'isInPipMode': true,
      });
      expect(enterEvent, isA<AVPipChangedEvent>());
      expect((enterEvent as AVPipChangedEvent).isInPipMode, true);

      final exitEvent = AVPlayerEvent.fromMap({
        'type': 'pipChanged',
        'isInPipMode': false,
      });
      expect((exitEvent as AVPipChangedEvent).isInPipMode, false);
    });

    test('parses completed event', () {
      final event = AVPlayerEvent.fromMap({'type': 'completed'});
      expect(event, isA<AVCompletedEvent>());
    });

    test('parses error event', () {
      final event = AVPlayerEvent.fromMap({
        'type': 'error',
        'message': 'Network error',
        'code': 'NET_ERR',
      });
      expect(event, isA<AVErrorEvent>());
      final e = event as AVErrorEvent;
      expect(e.message, 'Network error');
      expect(e.code, 'NET_ERR');
    });

    test('parses error event with missing message defaults to Unknown error',
        () {
      final event = AVPlayerEvent.fromMap({
        'type': 'error',
      });
      expect(event, isA<AVErrorEvent>());
      expect((event as AVErrorEvent).message, 'Unknown error');
    });

    test('parses mediaCommand play event', () {
      final event = AVPlayerEvent.fromMap({
        'type': 'mediaCommand',
        'command': 'play',
      });
      expect(event, isA<AVMediaCommandEvent>());
      final e = event as AVMediaCommandEvent;
      expect(e.command, AVMediaCommand.play);
      expect(e.seekPosition, isNull);
    });

    test('parses mediaCommand seekTo event with position', () {
      final event = AVPlayerEvent.fromMap({
        'type': 'mediaCommand',
        'command': 'seekTo',
        'seekPosition': 15000,
      });
      expect(event, isA<AVMediaCommandEvent>());
      final e = event as AVMediaCommandEvent;
      expect(e.command, AVMediaCommand.seekTo);
      expect(e.seekPosition, const Duration(seconds: 15));
    });

    test('parses all media command types', () {
      for (final cmd in AVMediaCommand.values) {
        final event = AVPlayerEvent.fromMap({
          'type': 'mediaCommand',
          'command': cmd.name,
        });
        expect((event as AVMediaCommandEvent).command, cmd);
      }
    });

    test('parses mediaCommand with unknown command defaults to play', () {
      final event = AVPlayerEvent.fromMap({
        'type': 'mediaCommand',
        'command': 'unknown_command',
      });
      expect(event, isA<AVMediaCommandEvent>());
      expect((event as AVMediaCommandEvent).command, AVMediaCommand.play);
    });

    test('parses abrInfo event', () {
      final event = AVPlayerEvent.fromMap({
        'type': 'abrInfo',
        'currentBitrateBps': 5000000,
        'availableBitrateBps': [2000000, 5000000, 8000000],
      });
      expect(event, isA<AVAbrInfoEvent>());
      final e = event as AVAbrInfoEvent;
      expect(e.currentBitrateBps, 5000000);
      expect(e.availableBitrateBps, [2000000, 5000000, 8000000]);
    });

    test('parses memoryPressure event', () {
      for (final level in AVMemoryPressureLevel.values) {
        final event = AVPlayerEvent.fromMap({
          'type': 'memoryPressure',
          'level': level.name,
        });
        expect(event, isA<AVMemoryPressureEvent>());
        expect((event as AVMemoryPressureEvent).level, level);
      }
    });

    test('parses memoryPressure with unknown level defaults to normal', () {
      final event = AVPlayerEvent.fromMap({
        'type': 'memoryPressure',
        'level': 'nonexistent',
      });
      expect(event, isA<AVMemoryPressureEvent>());
      expect((event as AVMemoryPressureEvent).level,
          AVMemoryPressureLevel.normal);
    });

    test('unknown event type returns error event', () {
      final event = AVPlayerEvent.fromMap({'type': 'unknownType'});
      expect(event, isA<AVErrorEvent>());
      expect(
        (event as AVErrorEvent).message,
        contains('Unknown event type: unknownType'),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Enums
  // ---------------------------------------------------------------------------

  group('AVPlaybackState', () {
    test('has all expected values', () {
      expect(AVPlaybackState.values, hasLength(8));
      expect(AVPlaybackState.values, contains(AVPlaybackState.idle));
      expect(AVPlaybackState.values, contains(AVPlaybackState.playing));
      expect(AVPlaybackState.values, contains(AVPlaybackState.paused));
      expect(AVPlaybackState.values, contains(AVPlaybackState.buffering));
      expect(AVPlaybackState.values, contains(AVPlaybackState.completed));
      expect(AVPlaybackState.values, contains(AVPlaybackState.error));
    });
  });

  group('AVMediaCommand', () {
    test('has all expected values', () {
      expect(AVMediaCommand.values, hasLength(6));
      expect(AVMediaCommand.values, contains(AVMediaCommand.play));
      expect(AVMediaCommand.values, contains(AVMediaCommand.pause));
      expect(AVMediaCommand.values, contains(AVMediaCommand.next));
      expect(AVMediaCommand.values, contains(AVMediaCommand.previous));
      expect(AVMediaCommand.values, contains(AVMediaCommand.seekTo));
      expect(AVMediaCommand.values, contains(AVMediaCommand.stop));
    });
  });

  // ---------------------------------------------------------------------------
  // AVAbrConfig
  // ---------------------------------------------------------------------------

  group('AVAbrConfig', () {
    test('stores all fields', () {
      const config = AVAbrConfig(
        maxBitrateBps: 5000000,
        minBitrateBps: 500000,
        preferredMaxWidth: 1920,
        preferredMaxHeight: 1080,
      );
      expect(config.maxBitrateBps, 5000000);
      expect(config.minBitrateBps, 500000);
      expect(config.preferredMaxWidth, 1920);
      expect(config.preferredMaxHeight, 1080);
    });

    test('all fields are optional', () {
      const config = AVAbrConfig();
      expect(config.maxBitrateBps, isNull);
      expect(config.minBitrateBps, isNull);
      expect(config.preferredMaxWidth, isNull);
      expect(config.preferredMaxHeight, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // AVDecoderInfo
  // ---------------------------------------------------------------------------

  group('AVDecoderInfo', () {
    test('stores all fields', () {
      const info = AVDecoderInfo(
        isHardwareAccelerated: true,
        decoderName: 'VideoToolbox',
        codec: 'HEVC',
      );
      expect(info.isHardwareAccelerated, true);
      expect(info.decoderName, 'VideoToolbox');
      expect(info.codec, 'HEVC');
    });

    test('unknown constant has sensible defaults', () {
      expect(AVDecoderInfo.unknown.isHardwareAccelerated, false);
      expect(AVDecoderInfo.unknown.decoderName, isNull);
      expect(AVDecoderInfo.unknown.codec, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // AVMemoryPressureLevel
  // ---------------------------------------------------------------------------

  group('AVMemoryPressureLevel', () {
    test('has all expected values', () {
      expect(AVMemoryPressureLevel.values, hasLength(3));
      expect(
          AVMemoryPressureLevel.values, contains(AVMemoryPressureLevel.normal));
      expect(AVMemoryPressureLevel.values,
          contains(AVMemoryPressureLevel.warning));
      expect(AVMemoryPressureLevel.values,
          contains(AVMemoryPressureLevel.critical));
    });
  });
}
