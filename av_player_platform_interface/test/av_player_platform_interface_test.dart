import 'package:av_player_platform_interface/av_player_platform_interface.dart';
import 'package:av_player_platform_interface/src/method_channel_av_player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AvPlayerPlatform', () {
    test('default instance is MethodChannelAvPlayer', () {
      expect(
        AvPlayerPlatform.instance,
        isA<MethodChannelAvPlayer>(),
      );
    });

    group('base class throws UnimplementedError', () {
      late _TestPlatform platform;

      setUp(() {
        platform = _TestPlatform();
      });

      test('create()', () {
        expect(
          () => platform.create(const AVVideoSource.network('url')),
          throwsUnimplementedError,
        );
      });

      test('dispose()', () {
        expect(() => platform.dispose(1), throwsUnimplementedError);
      });

      test('play()', () {
        expect(() => platform.play(1), throwsUnimplementedError);
      });

      test('pause()', () {
        expect(() => platform.pause(1), throwsUnimplementedError);
      });

      test('seekTo()', () {
        expect(
          () => platform.seekTo(1, Duration.zero),
          throwsUnimplementedError,
        );
      });

      test('setPlaybackSpeed()', () {
        expect(
          () => platform.setPlaybackSpeed(1, 1.0),
          throwsUnimplementedError,
        );
      });

      test('setLooping()', () {
        expect(() => platform.setLooping(1, true), throwsUnimplementedError);
      });

      test('setVolume()', () {
        expect(() => platform.setVolume(1, 0.5), throwsUnimplementedError);
      });

      test('isPipAvailable()', () {
        expect(() => platform.isPipAvailable(), throwsUnimplementedError);
      });

      test('enterPip()', () {
        expect(() => platform.enterPip(1), throwsUnimplementedError);
      });

      test('exitPip()', () {
        expect(() => platform.exitPip(1), throwsUnimplementedError);
      });

      test('setMediaMetadata()', () {
        expect(
          () => platform.setMediaMetadata(1, const AVMediaMetadata()),
          throwsUnimplementedError,
        );
      });

      test('setNotificationEnabled()', () {
        expect(
          () => platform.setNotificationEnabled(1, true),
          throwsUnimplementedError,
        );
      });

      test('setSystemVolume()', () {
        expect(
          () => platform.setSystemVolume(0.5),
          throwsUnimplementedError,
        );
      });

      test('getSystemVolume()', () {
        expect(() => platform.getSystemVolume(), throwsUnimplementedError);
      });

      test('setScreenBrightness()', () {
        expect(
          () => platform.setScreenBrightness(0.5),
          throwsUnimplementedError,
        );
      });

      test('getScreenBrightness()', () {
        expect(() => platform.getScreenBrightness(), throwsUnimplementedError);
      });

      test('setWakelock()', () {
        expect(() => platform.setWakelock(true), throwsUnimplementedError);
      });

      test('playerEvents()', () {
        expect(() => platform.playerEvents(1), throwsUnimplementedError);
      });
    });
  });
}

/// A minimal concrete subclass for testing the base class default behavior.
/// Uses the super constructor token via a helper.
class _TestPlatform extends AvPlayerPlatform {}
