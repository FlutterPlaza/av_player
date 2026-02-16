import 'package:av_player/av_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_helpers.dart';

void main() {
  late TestMockPlatform mockPlatform;

  setUp(() {
    mockPlatform = TestMockPlatform();
    AvPlayerPlatform.instance = mockPlatform;
  });

  // ---------------------------------------------------------------------------
  // Error state
  // ---------------------------------------------------------------------------

  group('Error state', () {
    testWidgets('displays error icon and message', (tester) async {
      final controller = AVPlayerController(
        const AVVideoSource.network('https://example.com/video.mp4'),
      );
      await controller.initialize();
      // Set error state directly (avoids FakeAsync stream issues)
      controller.value =
          controller.value.copyWith(errorDescription: 'Decode failed');

      await tester.pumpWidget(wrapWithApp(AVVideoPlayer(controller)));

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Decode failed'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('displays "Unknown error" when description is generic',
        (tester) async {
      final controller = AVPlayerController(
        const AVVideoSource.network('https://example.com/video.mp4'),
      );
      await controller.initialize();
      controller.value =
          controller.value.copyWith(errorDescription: 'Unknown error');

      await tester.pumpWidget(wrapWithApp(AVVideoPlayer(controller)));

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Unknown error'), findsOneWidget);

      controller.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // Loading state
  // ---------------------------------------------------------------------------

  group('Loading state', () {
    testWidgets('shows CircularProgressIndicator before initialization',
        (tester) async {
      final controller = AVPlayerController(
        const AVVideoSource.network('https://example.com/video.mp4'),
      );

      await tester.pumpWidget(wrapWithApp(AVVideoPlayer(controller)));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      controller.dispose();
    });

    testWidgets('loading indicator disappears after initialization',
        (tester) async {
      final controller = await createInitializedController(mockPlatform);

      await tester.pumpWidget(wrapWithApp(AVVideoPlayer(controller)));

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(Texture), findsOneWidget);

      controller.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // Initialized state
  // ---------------------------------------------------------------------------

  group('Initialized state', () {
    testWidgets('renders Texture widget with correct textureId',
        (tester) async {
      final controller = await createInitializedController(mockPlatform);

      await tester.pumpWidget(wrapWithApp(AVVideoPlayer(controller)));

      final texture = tester.widget<Texture>(find.byType(Texture));
      expect(texture.textureId, 42);

      controller.dispose();
    });

    testWidgets('uses AspectRatio from controller state', (tester) async {
      final controller = await createInitializedController(
        mockPlatform,
        width: 1280.0,
        height: 720.0,
      );

      await tester.pumpWidget(wrapWithApp(AVVideoPlayer(controller)));

      expect(find.byType(Texture), findsOneWidget);
      expect(controller.value.aspectRatio, closeTo(1280 / 720, 0.01));

      controller.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // Layer composition
  // ---------------------------------------------------------------------------

  group('Layer composition', () {
    testWidgets('no controls or gestures by default', (tester) async {
      final controller = await createInitializedController(mockPlatform);

      await tester.pumpWidget(wrapWithApp(AVVideoPlayer(controller)));

      expect(find.byType(AVControls), findsNothing);
      expect(find.byType(AVGestures), findsNothing);

      controller.dispose();
    });

    testWidgets('adds AVControls when showControls is true', (tester) async {
      final controller = await createInitializedController(mockPlatform);

      await tester.pumpWidget(wrapWithApp(
        AVVideoPlayer(controller, showControls: true),
      ));
      await tester.pump();

      expect(find.byType(AVControls), findsOneWidget);

      controller.dispose();
    });

    testWidgets('adds AVGestures when gestureConfig is provided',
        (tester) async {
      final controller = await createInitializedController(mockPlatform);

      await tester.pumpWidget(wrapWithApp(
        AVVideoPlayer(
          controller,
          gestureConfig: const AVGestureConfig(),
        ),
      ));
      await tester.pump();

      expect(find.byType(AVGestures), findsOneWidget);

      controller.dispose();
    });

    testWidgets('adds both controls and gestures', (tester) async {
      final controller = await createInitializedController(mockPlatform);

      await tester.pumpWidget(wrapWithApp(
        AVVideoPlayer(
          controller,
          showControls: true,
          gestureConfig: const AVGestureConfig(),
        ),
      ));
      await tester.pump();

      expect(find.byType(AVControls), findsOneWidget);
      expect(find.byType(AVGestures), findsOneWidget);

      controller.dispose();
    });

    testWidgets('custom controlsBuilder replaces default controls',
        (tester) async {
      final controller = await createInitializedController(mockPlatform);

      await tester.pumpWidget(wrapWithApp(
        AVVideoPlayer(
          controller,
          showControls: true,
          controlsBuilder: (context, ctrl) => const Text('Custom Controls'),
        ),
      ));
      await tester.pump();

      expect(find.text('Custom Controls'), findsOneWidget);
      expect(find.byType(AVControls), findsNothing);

      controller.dispose();
    });

    testWidgets('.video() preset adds controls and gestures', (tester) async {
      final controller = await createInitializedController(mockPlatform);

      await tester.pumpWidget(wrapWithApp(AVVideoPlayer.video(controller)));
      await tester.pump();

      expect(find.byType(AVControls), findsOneWidget);
      expect(find.byType(AVGestures), findsOneWidget);

      controller.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  group('Lifecycle', () {
    testWidgets('pauses on AppLifecycleState.paused', (tester) async {
      final controller = await createInitializedController(
        mockPlatform,
        playing: true,
      );

      await tester.pumpWidget(wrapWithApp(AVVideoPlayer(controller)));

      // Simulate app going to background
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      expect(mockPlatform.log, contains('pause'));

      controller.dispose();
    });

    testWidgets('skips pause in PIP mode', (tester) async {
      final controller = await createInitializedController(
        mockPlatform,
        playing: true,
      );

      // Enter PIP mode directly via value
      controller.value = controller.value.copyWith(isInPipMode: true);

      await tester.pumpWidget(wrapWithApp(AVVideoPlayer(controller)));

      // Clear the log to only track new calls
      mockPlatform.log.clear();

      // Simulate app going to background while in PIP
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      expect(mockPlatform.log, isNot(contains('pause')));

      controller.dispose();
    });
  });
}
