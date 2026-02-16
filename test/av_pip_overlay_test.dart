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

  /// Wraps AVPipOverlay in a Stack inside MaterialApp with known MediaQuery.
  Widget buildPipOverlay({
    required AVPlayerController controller,
    AVPipSize size = AVPipSize.medium,
    AVPipCorner corner = AVPipCorner.bottomRight,
    VoidCallback? onClose,
    VoidCallback? onExpand,
    AVPlayerThemeData? themeData,
  }) {
    final stack = Stack(
      children: [
        const SizedBox.expand(),
        AVPipOverlay(
          controller: controller,
          initialSize: size,
          initialCorner: corner,
          onClose: onClose,
          onExpand: onExpand,
        ),
      ],
    );
    return MediaQuery(
      data: const MediaQueryData(
        size: Size(800, 600),
        padding: EdgeInsets.only(top: 24, bottom: 24),
      ),
      child: MaterialApp(
        home: Scaffold(
          body: themeData != null
              ? AVPlayerTheme(data: themeData, child: stack)
              : stack,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Rendering
  // ---------------------------------------------------------------------------

  group('Rendering', () {
    testWidgets('initial width matches AVPipSize.medium (250)', (tester) async {
      final controller = await createInitializedController(mockPlatform);

      await tester.pumpWidget(buildPipOverlay(controller: controller));
      await tester.pump();

      // Find the SizedBox inside the Material that constrains the PIP
      final sizedBox = tester.widgetList<SizedBox>(find.byType(SizedBox)).where(
            (sb) => sb.width == 250,
          );
      expect(sizedBox, isNotEmpty);

      controller.dispose();
    });

    testWidgets('AVPipSize.small uses width 150', (tester) async {
      final controller = await createInitializedController(mockPlatform);

      await tester.pumpWidget(buildPipOverlay(
        controller: controller,
        size: AVPipSize.small,
      ));
      await tester.pump();

      final sizedBox = tester.widgetList<SizedBox>(find.byType(SizedBox)).where(
            (sb) => sb.width == 150,
          );
      expect(sizedBox, isNotEmpty);

      controller.dispose();
    });

    testWidgets('shows loading indicator when uninitialized', (tester) async {
      final controller = AVPlayerController(
        const AVVideoSource.network('https://example.com/video.mp4'),
      );

      await tester.pumpWidget(buildPipOverlay(controller: controller));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      controller.dispose();
    });

    testWidgets('shows Texture when initialized', (tester) async {
      final controller = await createInitializedController(mockPlatform);

      await tester.pumpWidget(buildPipOverlay(controller: controller));
      await tester.pump();

      expect(find.byType(Texture), findsOneWidget);

      controller.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // Mini controls
  // ---------------------------------------------------------------------------

  group('Mini controls', () {
    testWidgets('tap toggles controls overlay', (tester) async {
      final controller = await createInitializedController(
        mockPlatform,
        playing: true,
      );

      await tester.pumpWidget(buildPipOverlay(
        controller: controller,
        onClose: () {},
      ));
      await tester.pump();

      // Controls should not be visible initially
      expect(find.byIcon(Icons.pause_rounded), findsNothing);

      // Tap to show controls
      await tester.tap(find.byType(AVPipOverlay));
      await tester.pump();

      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      // Tap again to hide
      await tester.tap(find.byType(AVPipOverlay));
      await tester.pump();

      expect(find.byIcon(Icons.pause_rounded), findsNothing);

      controller.dispose();
    });

    testWidgets('shows play icon when paused', (tester) async {
      final controller = await createInitializedController(mockPlatform);

      await tester.pumpWidget(buildPipOverlay(
        controller: controller,
        onClose: () {},
      ));
      await tester.pump();

      // Tap to show controls
      await tester.tap(find.byType(AVPipOverlay));
      await tester.pump();

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      controller.dispose();
    });

    testWidgets('tapping play/pause toggles playback', (tester) async {
      final controller = await createInitializedController(mockPlatform);
      mockPlatform.log.clear();

      await tester.pumpWidget(buildPipOverlay(
        controller: controller,
        onClose: () {},
      ));
      await tester.pump();

      // Show controls
      await tester.tap(find.byType(AVPipOverlay));
      await tester.pump();

      // Tap play
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();

      expect(mockPlatform.log, contains('play'));

      controller.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // Close/expand
  // ---------------------------------------------------------------------------

  group('Close/expand', () {
    testWidgets('close button fires onClose', (tester) async {
      final controller = await createInitializedController(mockPlatform);
      bool closed = false;

      await tester.pumpWidget(buildPipOverlay(
        controller: controller,
        onClose: () => closed = true,
      ));
      await tester.pump();

      // Show controls
      await tester.tap(find.byType(AVPipOverlay));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(closed, isTrue);

      controller.dispose();
    });

    testWidgets('expand button fires onExpand', (tester) async {
      final controller = await createInitializedController(mockPlatform);
      bool expanded = false;

      await tester.pumpWidget(buildPipOverlay(
        controller: controller,
        onClose: () {},
        onExpand: () => expanded = true,
      ));
      await tester.pump();

      // Show controls
      await tester.tap(find.byType(AVPipOverlay));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.open_in_full));
      await tester.pump();

      expect(expanded, isTrue);

      controller.dispose();
    });

    testWidgets('expand button hidden when onExpand is null', (tester) async {
      final controller = await createInitializedController(mockPlatform);

      await tester.pumpWidget(buildPipOverlay(
        controller: controller,
        onClose: () {},
      ));
      await tester.pump();

      // Show controls
      await tester.tap(find.byType(AVPipOverlay));
      await tester.pump();

      expect(find.byIcon(Icons.open_in_full), findsNothing);

      controller.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // Drag
  // ---------------------------------------------------------------------------

  group('Drag', () {
    testWidgets('drag updates position', (tester) async {
      final controller = await createInitializedController(mockPlatform);

      await tester.pumpWidget(buildPipOverlay(controller: controller));
      await tester.pump();

      final initialPos = tester.getTopLeft(find.byType(AVPipOverlay));

      // Drag the PIP overlay
      await tester.drag(find.byType(AVPipOverlay), const Offset(50, 50));
      await tester.pump();

      final newPos = tester.getTopLeft(find.byType(AVPipOverlay));
      // Position should have changed (note: snap animation may adjust it)
      expect(newPos, isNot(equals(initialPos)));

      controller.dispose();
    });

    testWidgets('progress bar reflects position', (tester) async {
      final controller = await createInitializedController(mockPlatform);
      // Set position to half of 5-minute duration
      controller.value = controller.value.copyWith(
        position: const Duration(minutes: 2, seconds: 30),
      );

      await tester.pumpWidget(buildPipOverlay(
        controller: controller,
        onClose: () {},
      ));
      await tester.pump();

      // Show controls to see progress bar
      await tester.tap(find.byType(AVPipOverlay));
      await tester.pump();

      final progressBar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progressBar.value, closeTo(0.5, 0.01));

      controller.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // Snap to corner
  // ---------------------------------------------------------------------------

  group('Snap to corner', () {
    testWidgets('snaps to nearest corner after drag to top-left quadrant',
        (tester) async {
      final controller = await createInitializedController(mockPlatform);

      // Start at bottom-right corner
      await tester.pumpWidget(buildPipOverlay(
        controller: controller,
        corner: AVPipCorner.bottomRight,
      ));
      await tester.pump();

      // Drag far toward top-left
      await tester.drag(
        find.byType(AVPipOverlay),
        const Offset(-400, -300),
      );
      // Let the snap animation complete (250ms)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final newPos = tester.getTopLeft(find.byType(AVPipOverlay));
      // Should be near top-left corner: margin (16) for left, margin + padding (16+24) for top
      expect(newPos.dx, lessThan(100));
      expect(newPos.dy, lessThan(100));

      controller.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // Theme colors
  // ---------------------------------------------------------------------------

  group('Theme colors', () {
    const customTheme = AVPlayerThemeData(
      progressBarColor: Color(0xFFFF0000),
      iconColor: Color(0xFF00FF00),
    );

    testWidgets('progress bar uses theme progressBarColor', (tester) async {
      final controller = await createInitializedController(mockPlatform);
      controller.value = controller.value.copyWith(
        position: const Duration(minutes: 1),
      );

      await tester.pumpWidget(buildPipOverlay(
        controller: controller,
        onClose: () {},
        themeData: customTheme,
      ));
      await tester.pump();

      // Show controls
      await tester.tap(find.byType(AVPipOverlay));
      await tester.pump();

      final progressBar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      final valueColor =
          progressBar.valueColor as AlwaysStoppedAnimation<Color>;
      expect(valueColor.value, const Color(0xFFFF0000));

      controller.dispose();
    });

    testWidgets('play/pause icon uses theme iconColor', (tester) async {
      final controller = await createInitializedController(mockPlatform);

      await tester.pumpWidget(buildPipOverlay(
        controller: controller,
        onClose: () {},
        themeData: customTheme,
      ));
      await tester.pump();

      // Show controls
      await tester.tap(find.byType(AVPipOverlay));
      await tester.pump();

      final icon = tester.widget<Icon>(
        find.byIcon(Icons.play_arrow_rounded),
      );
      expect(icon.color, const Color(0xFF00FF00));

      controller.dispose();
    });
  });
}
