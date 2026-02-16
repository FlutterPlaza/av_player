import 'dart:async';
import 'dart:io';

import 'package:av_player/av_player.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// Network test video — publicly hosted 10s Big Buck Bunny clip (~1MB).
const _networkUrl =
    'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/360/Big_Buck_Bunny_360_10s_1MB.mp4';

/// A second network video for multi-player test.
const _networkUrl2 = 'https://www.w3schools.com/html/mov_bbb.mp4';

/// Polls [condition] every [interval] until it returns `true` or [timeout]
/// elapses. Throws a [TimeoutException] on timeout.
Future<void> waitForCondition(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 15),
  Duration interval = const Duration(milliseconds: 200),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException(
        'Condition not met within ${timeout.inSeconds}s',
        timeout,
      );
    }
    await Future<void>.delayed(interval);
  }
}

/// Initializes [controller] and waits for the initialized event.
/// Must be called inside [WidgetTester.runAsync].
Future<void> _initAndWait(AVPlayerController controller) async {
  await controller.initialize();
  await waitForCondition(
    () => controller.value.isInitialized || controller.value.hasError,
  );
  if (controller.value.hasError) {
    fail(
      'Controller initialization failed: '
      '${controller.value.errorDescription}',
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // -------------------------------------------------------------------------
  // 1. Network video loads and plays
  // -------------------------------------------------------------------------

  group('Network video loads and plays', () {
    testWidgets('initializes with duration > 0', (tester) async {
      await tester.runAsync(() async {
        final controller = AVPlayerController(
          const AVVideoSource.network(_networkUrl),
        );

        try {
          await _initAndWait(controller);

          expect(controller.value.isInitialized, isTrue);
          expect(controller.textureId, isNotNull);
          expect(controller.value.duration, greaterThan(Duration.zero));
        } finally {
          controller.dispose();
        }
      });
    });

    testWidgets('play causes position to advance', (tester) async {
      await tester.runAsync(() async {
        final controller = AVPlayerController(
          const AVVideoSource.network(_networkUrl),
        );

        try {
          await _initAndWait(controller);
          await controller.play();
          await waitForCondition(
            () => controller.value.position > Duration.zero,
            timeout: const Duration(seconds: 10),
          );

          expect(controller.value.isPlaying, isTrue);
          expect(controller.value.position, greaterThan(Duration.zero));
        } finally {
          controller.dispose();
        }
      });
    });
  });

  // -------------------------------------------------------------------------
  // 2. Asset video loads
  // -------------------------------------------------------------------------

  group('Asset video loads', () {
    testWidgets('initializes from bundled asset', (tester) async {
      await tester.runAsync(() async {
        final controller = AVPlayerController(
          const AVVideoSource.asset('assets/test_video.mp4'),
        );

        try {
          await _initAndWait(controller);

          expect(controller.value.isInitialized, isTrue);
          expect(controller.textureId, isNotNull);
          expect(controller.value.duration, greaterThan(Duration.zero));
        } finally {
          controller.dispose();
        }
      });
    });
  });

  // -------------------------------------------------------------------------
  // 3. File video loads
  // -------------------------------------------------------------------------

  group('File video loads', () {
    testWidgets('initializes from local file', (tester) async {
      if (kIsWeb) return;

      await tester.runAsync(() async {
        // Download a small video to a temp file for file-source testing.
        final tempDir = await getTemporaryDirectory();
        if (!tempDir.existsSync()) {
          tempDir.createSync(recursive: true);
        }
        final file = File('${tempDir.path}/test_video.mp4');
        final httpClient = HttpClient();
        try {
          final request = await httpClient.getUrl(Uri.parse(_networkUrl2));
          final response = await request.close();
          final bytes = await response.fold<List<int>>(
            <int>[],
            (prev, chunk) => prev..addAll(chunk),
          );
          await file.writeAsBytes(bytes);
        } finally {
          httpClient.close();
        }

        final controller = AVPlayerController(
          AVVideoSource.file(file.path),
        );

        try {
          await _initAndWait(controller);

          expect(controller.value.isInitialized, isTrue);
          expect(controller.textureId, isNotNull);
          expect(controller.value.duration, greaterThan(Duration.zero));
        } finally {
          controller.dispose();
          if (file.existsSync()) file.deleteSync();
        }
      });
    });
  });

  // -------------------------------------------------------------------------
  // 4. PIP enters/exits
  // -------------------------------------------------------------------------

  group('PIP enters/exits', () {
    testWidgets('isPipAvailable returns a bool', (tester) async {
      if (kIsWeb || Platform.isLinux || Platform.isWindows) return;

      await tester.runAsync(() async {
        final controller = AVPlayerController(
          const AVVideoSource.network(_networkUrl),
        );

        try {
          await _initAndWait(controller);
          final available = await controller.isPipAvailable();
          expect(available, isA<bool>());
        } finally {
          controller.dispose();
        }
      });
    });

    testWidgets('enterPip and exitPip do not throw', (tester) async {
      if (kIsWeb || Platform.isLinux || Platform.isWindows) return;

      await tester.runAsync(() async {
        final controller = AVPlayerController(
          const AVVideoSource.network(_networkUrl),
        );

        try {
          await _initAndWait(controller);

          final available = await controller.isPipAvailable();
          if (!available) return;

          await controller.play();
          await Future<void>.delayed(const Duration(seconds: 1));

          // Should not throw even if the OS declines.
          await controller.enterPip();
          await Future<void>.delayed(const Duration(seconds: 1));
          await controller.exitPip();
        } finally {
          controller.dispose();
        }
      });
    });
  });

  // -------------------------------------------------------------------------
  // 5. Playlist advances on completion
  // -------------------------------------------------------------------------

  group('Playlist advances on completion', () {
    testWidgets('onTrackCompleted advances to next source', (tester) async {
      AVVideoSource? changedSource;

      final playlist = AVPlaylistController(
        sources: const [
          AVVideoSource.network(_networkUrl),
          AVVideoSource.network(_networkUrl2),
        ],
        onSourceChanged: (source) => changedSource = source,
      );

      expect(playlist.value.currentIndex, 0);

      playlist.onTrackCompleted();

      expect(playlist.value.currentIndex, 1);
      expect(changedSource, isNotNull);

      playlist.dispose();
    });
  });

  // -------------------------------------------------------------------------
  // 6. Position/duration reporting
  // -------------------------------------------------------------------------

  group('Position/duration reporting', () {
    testWidgets('position advances and stays within duration', (tester) async {
      await tester.runAsync(() async {
        final controller = AVPlayerController(
          const AVVideoSource.network(_networkUrl),
        );

        try {
          await _initAndWait(controller);
          await controller.play();

          await waitForCondition(
            () => controller.value.position > Duration.zero,
            timeout: const Duration(seconds: 10),
          );

          // Allow a little more playback.
          await Future<void>.delayed(const Duration(seconds: 1));

          expect(controller.value.position, greaterThan(Duration.zero));
          expect(
            controller.value.position,
            lessThanOrEqualTo(controller.value.duration),
          );
        } finally {
          controller.dispose();
        }
      });
    });
  });

  // -------------------------------------------------------------------------
  // 7. Media notification (smoke)
  // -------------------------------------------------------------------------

  group('Media notification (smoke)', () {
    testWidgets('setMediaMetadata and setNotificationEnabled complete',
        (tester) async {
      await tester.runAsync(() async {
        final controller = AVPlayerController(
          const AVVideoSource.network(_networkUrl),
        );

        try {
          await _initAndWait(controller);

          await controller.setMediaMetadata(const AVMediaMetadata(
            title: 'Test Title',
            artist: 'Test Artist',
            album: 'Test Album',
          ));

          await controller.setNotificationEnabled(true);
          await controller.setNotificationEnabled(false);
        } finally {
          controller.dispose();
        }
      });
    });
  });

  // -------------------------------------------------------------------------
  // 8. Lock screen controls — SKIPPED (manual verification)
  // -------------------------------------------------------------------------

  group('Lock screen controls', () {
    // Lock screen media control integration requires manual testing:
    //
    // 1. Run the example app on a physical device.
    // 2. Start playing a video.
    // 3. Call setMediaMetadata() with title/artist.
    // 4. Call setNotificationEnabled(true).
    // 5. Lock the screen.
    // 6. Verify that lock screen shows media controls (play/pause, skip).
    // 7. Tap play/pause on the lock screen and verify the player responds.
    //
    // This cannot be automated because lock screen interaction is outside
    // the app's process boundary.
  });

  // -------------------------------------------------------------------------
  // 9. System volume roundtrip
  // -------------------------------------------------------------------------

  group('System volume roundtrip', () {
    testWidgets('get → set → get roundtrip', (tester) async {
      if (kIsWeb) return;

      await tester.runAsync(() async {
        final controller = AVPlayerController(
          const AVVideoSource.network(_networkUrl),
        );

        try {
          await _initAndWait(controller);

          final original = await controller.getSystemVolume();
          expect(original, inInclusiveRange(0.0, 1.0));

          await controller.setSystemVolume(0.3);
          final after = await controller.getSystemVolume();
          expect(after, closeTo(0.3, 0.15));

          // Restore original volume.
          await controller.setSystemVolume(original);
        } finally {
          controller.dispose();
        }
      });
    });
  });

  // -------------------------------------------------------------------------
  // 10. Brightness roundtrip
  // -------------------------------------------------------------------------

  group('Brightness roundtrip', () {
    testWidgets('get → set → get roundtrip', (tester) async {
      if (kIsWeb) return;

      await tester.runAsync(() async {
        final controller = AVPlayerController(
          const AVVideoSource.network(_networkUrl),
        );

        try {
          await _initAndWait(controller);

          final original = await controller.getScreenBrightness();
          expect(original, inInclusiveRange(0.0, 1.0));

          await controller.setScreenBrightness(0.3);
          final after = await controller.getScreenBrightness();
          // macOS has coarser brightness quantization, use wider tolerance.
          expect(after, closeTo(0.3, 0.25));

          // Restore original brightness.
          await controller.setScreenBrightness(original);
        } finally {
          controller.dispose();
        }
      });
    });
  });

  // -------------------------------------------------------------------------
  // 11. Wakelock (smoke)
  // -------------------------------------------------------------------------

  group('Wakelock (smoke)', () {
    testWidgets('setWakelock true/false completes without error',
        (tester) async {
      await tester.runAsync(() async {
        final controller = AVPlayerController(
          const AVVideoSource.network(_networkUrl),
        );

        try {
          await _initAndWait(controller);

          await controller.setWakelock(true);
          await controller.setWakelock(false);
        } finally {
          controller.dispose();
        }
      });
    });
  });

  // -------------------------------------------------------------------------
  // 12. Multiple simultaneous players
  // -------------------------------------------------------------------------

  group('Multiple simultaneous players', () {
    testWidgets('two controllers initialize with distinct textureIds',
        (tester) async {
      await tester.runAsync(() async {
        final controller1 = AVPlayerController(
          const AVVideoSource.network(_networkUrl),
        );
        final controller2 = AVPlayerController(
          const AVVideoSource.network(_networkUrl2),
        );

        try {
          await _initAndWait(controller1);
          await _initAndWait(controller2);

          expect(controller1.textureId, isNotNull);
          expect(controller2.textureId, isNotNull);
          expect(controller1.textureId, isNot(controller2.textureId));

          await controller1.play();
          await controller2.play();

          await waitForCondition(
            () => controller1.value.position > Duration.zero,
            timeout: const Duration(seconds: 10),
          );
          await waitForCondition(
            () => controller2.value.position > Duration.zero,
            timeout: const Duration(seconds: 10),
          );

          expect(controller1.value.isPlaying, isTrue);
          expect(controller2.value.isPlaying, isTrue);
        } finally {
          controller1.dispose();
          controller2.dispose();
        }
      });
    });
  });
}
