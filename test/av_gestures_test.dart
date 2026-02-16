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

  /// Wraps AVGestures in a known-size container for gesture testing.
  Widget buildGestures({
    required AVPlayerController controller,
    AVGestureConfig config = const AVGestureConfig(),
    VoidCallback? onTap,
    AVPlayerThemeData? themeData,
  }) {
    final child = SizedBox(
      width: 400,
      height: 300,
      child: AVGestures(
        controller: controller,
        config: config,
        onTap: onTap,
      ),
    );
    return MediaQuery(
      data: const MediaQueryData(size: Size(400, 600)),
      child: MaterialApp(
        home: Scaffold(
          body: themeData != null
              ? AVPlayerTheme(data: themeData, child: child)
              : child,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Double-tap seek
  // ---------------------------------------------------------------------------

  group('Double-tap seek', () {
    testWidgets('double-tap right side seeks forward', (tester) async {
      final controller = await createInitializedController(
        mockPlatform,
        playing: true,
      );
      controller.value = controller.value.copyWith(
        position: const Duration(seconds: 30),
      );
      mockPlatform.log.clear();
      mockPlatform.seekLog.clear();

      await tester.pumpWidget(buildGestures(controller: controller));
      await tester.pump();

      // Get the gesture area and tap on right side
      final gestureRect = tester.getRect(find.byType(AVGestures));
      final rightCenter = Offset(
        gestureRect.left + gestureRect.width * 0.75,
        gestureRect.top + gestureRect.height / 2,
      );

      await tester.tapAt(rightCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(rightCenter);
      await tester.pumpAndSettle();

      expect(mockPlatform.log, contains('seekTo'));
      // Should seek forward 10s from 30s = 40s
      expect(mockPlatform.seekLog.last, const Duration(seconds: 40));

      controller.dispose();
    });

    testWidgets('double-tap left side seeks backward', (tester) async {
      final controller = await createInitializedController(
        mockPlatform,
        playing: true,
      );
      controller.value = controller.value.copyWith(
        position: const Duration(seconds: 30),
      );
      mockPlatform.log.clear();
      mockPlatform.seekLog.clear();

      await tester.pumpWidget(buildGestures(controller: controller));
      await tester.pump();

      final gestureRect = tester.getRect(find.byType(AVGestures));
      final leftCenter = Offset(
        gestureRect.left + gestureRect.width * 0.25,
        gestureRect.top + gestureRect.height / 2,
      );

      await tester.tapAt(leftCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(leftCenter);
      await tester.pumpAndSettle();

      expect(mockPlatform.log, contains('seekTo'));
      // Should seek backward 10s from 30s = 20s
      expect(mockPlatform.seekLog.last, const Duration(seconds: 20));

      controller.dispose();
    });

    testWidgets('shows ripple animation on double-tap', (tester) async {
      final controller = await createInitializedController(
        mockPlatform,
        playing: true,
      );
      controller.value = controller.value.copyWith(
        position: const Duration(seconds: 30),
      );

      await tester.pumpWidget(buildGestures(controller: controller));
      await tester.pump();

      final gestureRect = tester.getRect(find.byType(AVGestures));
      final rightCenter = Offset(
        gestureRect.left + gestureRect.width * 0.75,
        gestureRect.top + gestureRect.height / 2,
      );

      await tester.tapAt(rightCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(rightCenter);
      await tester.pump();

      // Ripple should show with the seconds text
      expect(find.byIcon(Icons.fast_forward), findsOneWidget);
      expect(find.text('+10s'), findsOneWidget);

      await tester.pumpAndSettle();
      controller.dispose();
    });

    testWidgets('disabled via config', (tester) async {
      final controller = await createInitializedController(
        mockPlatform,
        playing: true,
      );
      controller.value = controller.value.copyWith(
        position: const Duration(seconds: 30),
      );
      mockPlatform.log.clear();

      await tester.pumpWidget(buildGestures(
        controller: controller,
        config: const AVGestureConfig(doubleTapToSeek: false),
      ));
      await tester.pump();

      final gestureRect = tester.getRect(find.byType(AVGestures));
      final rightCenter = Offset(
        gestureRect.left + gestureRect.width * 0.75,
        gestureRect.top + gestureRect.height / 2,
      );

      await tester.tapAt(rightCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(rightCenter);
      await tester.pumpAndSettle();

      expect(mockPlatform.log, isNot(contains('seekTo')));

      controller.dispose();
    });

    testWidgets('custom seekDuration is respected', (tester) async {
      final controller = await createInitializedController(
        mockPlatform,
        playing: true,
      );
      controller.value = controller.value.copyWith(
        position: const Duration(seconds: 30),
      );
      mockPlatform.seekLog.clear();

      await tester.pumpWidget(buildGestures(
        controller: controller,
        config: const AVGestureConfig(seekDuration: Duration(seconds: 15)),
      ));
      await tester.pump();

      final gestureRect = tester.getRect(find.byType(AVGestures));
      final rightCenter = Offset(
        gestureRect.left + gestureRect.width * 0.75,
        gestureRect.top + gestureRect.height / 2,
      );

      await tester.tapAt(rightCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(rightCenter);
      await tester.pumpAndSettle();

      // Should seek forward 15s from 30s = 45s
      expect(mockPlatform.seekLog.last, const Duration(seconds: 45));

      controller.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // Long-press speed
  // ---------------------------------------------------------------------------

  group('Long-press speed', () {
    testWidgets('sets speed to multiplier on long press', (tester) async {
      final controller = await createInitializedController(
        mockPlatform,
        playing: true,
      );
      mockPlatform.log.clear();
      mockPlatform.speedLog.clear();

      await tester.pumpWidget(buildGestures(controller: controller));
      await tester.pump();

      final center = tester.getCenter(find.byType(AVGestures));
      final gesture = await tester.startGesture(center);
      // Hold for > 500ms to trigger long press
      await tester.pump(const Duration(milliseconds: 600));

      expect(mockPlatform.speedLog, contains(2.0));

      await gesture.up();
      await tester.pump();

      controller.dispose();
    });

    testWidgets('restores speed on release', (tester) async {
      final controller = await createInitializedController(
        mockPlatform,
        playing: true,
      );
      mockPlatform.speedLog.clear();

      await tester.pumpWidget(buildGestures(controller: controller));
      await tester.pump();

      final center = tester.getCenter(find.byType(AVGestures));
      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 600));

      // Release
      await gesture.up();
      await tester.pump();

      // Should restore to 1.0
      expect(mockPlatform.speedLog.last, 1.0);

      controller.dispose();
    });

    testWidgets('shows speed indicator during long press', (tester) async {
      final controller = await createInitializedController(
        mockPlatform,
        playing: true,
      );

      await tester.pumpWidget(buildGestures(controller: controller));
      await tester.pump();

      final center = tester.getCenter(find.byType(AVGestures));
      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('2.0x'), findsOneWidget);

      await gesture.up();
      await tester.pump();

      controller.dispose();
    });

    testWidgets('disabled via config', (tester) async {
      final controller = await createInitializedController(
        mockPlatform,
        playing: true,
      );
      mockPlatform.log.clear();

      await tester.pumpWidget(buildGestures(
        controller: controller,
        config: const AVGestureConfig(longPressSpeed: false),
      ));
      await tester.pump();

      final center = tester.getCenter(find.byType(AVGestures));
      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 600));

      expect(mockPlatform.log, isNot(contains('setPlaybackSpeed')));

      await gesture.up();
      await tester.pump();

      controller.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // Volume swipe
  // ---------------------------------------------------------------------------

  group('Volume swipe', () {
    testWidgets('swipe up on right side increases volume', (tester) async {
      final controller = await createInitializedController(
        mockPlatform,
        playing: true,
      );
      mockPlatform.log.clear();

      await tester.pumpWidget(buildGestures(
        controller: controller,
        config: const AVGestureConfig(
          doubleTapToSeek: false,
          longPressSpeed: false,
          swipeToVolume: true,
          swipeToBrightness: false,
        ),
      ));
      await tester.pump();

      final gestureRect = tester.getRect(find.byType(AVGestures));
      final rightSide = Offset(
        gestureRect.left + gestureRect.width * 0.75,
        gestureRect.top + gestureRect.height / 2,
      );

      // Swipe up on right side
      await tester.dragFrom(rightSide, const Offset(0, -100));
      await tester.pump();

      expect(mockPlatform.log, contains('setSystemVolume'));

      controller.dispose();
    });

    testWidgets('swipe down on right side decreases volume', (tester) async {
      final controller = await createInitializedController(
        mockPlatform,
        playing: true,
      );
      mockPlatform.systemVolume = 0.8;
      mockPlatform.log.clear();

      await tester.pumpWidget(buildGestures(
        controller: controller,
        config: const AVGestureConfig(
          doubleTapToSeek: false,
          longPressSpeed: false,
          swipeToVolume: true,
          swipeToBrightness: false,
        ),
      ));
      await tester.pump();

      final gestureRect = tester.getRect(find.byType(AVGestures));
      final rightSide = Offset(
        gestureRect.left + gestureRect.width * 0.75,
        gestureRect.top + gestureRect.height / 2,
      );

      await tester.dragFrom(rightSide, const Offset(0, 100));
      await tester.pump();

      expect(mockPlatform.log, contains('setSystemVolume'));

      controller.dispose();
    });

    testWidgets('shows volume indicator during swipe', (tester) async {
      final controller = await createInitializedController(
        mockPlatform,
        playing: true,
      );

      await tester.pumpWidget(buildGestures(
        controller: controller,
        config: const AVGestureConfig(
          doubleTapToSeek: false,
          longPressSpeed: false,
          swipeToVolume: true,
          swipeToBrightness: false,
        ),
      ));
      await tester.pump();

      final gestureRect = tester.getRect(find.byType(AVGestures));
      final rightSide = Offset(
        gestureRect.left + gestureRect.width * 0.75,
        gestureRect.top + gestureRect.height / 2,
      );

      // Start a drag gesture manually to see the indicator mid-drag
      final gesture = await tester.startGesture(rightSide);
      await tester.pump();
      await gesture.moveBy(const Offset(0, -30));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -30));
      await tester.pump();

      expect(find.byIcon(Icons.volume_up), findsOneWidget);
      expect(find.text('Volume'), findsOneWidget);

      await gesture.up();
      await tester.pump();

      controller.dispose();
    });

    testWidgets('disabled via config', (tester) async {
      final controller = await createInitializedController(
        mockPlatform,
        playing: true,
      );
      mockPlatform.log.clear();

      await tester.pumpWidget(buildGestures(
        controller: controller,
        config: const AVGestureConfig(
          doubleTapToSeek: false,
          longPressSpeed: false,
          swipeToVolume: false,
          swipeToBrightness: false,
        ),
      ));
      await tester.pump();

      final gestureRect = tester.getRect(find.byType(AVGestures));
      final rightSide = Offset(
        gestureRect.left + gestureRect.width * 0.75,
        gestureRect.top + gestureRect.height / 2,
      );

      await tester.dragFrom(rightSide, const Offset(0, -100));
      await tester.pump();

      expect(mockPlatform.log, isNot(contains('setSystemVolume')));

      controller.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // Brightness swipe
  // ---------------------------------------------------------------------------

  group('Brightness swipe', () {
    testWidgets('swipe up on left side increases brightness', (tester) async {
      final controller = await createInitializedController(
        mockPlatform,
        playing: true,
      );
      mockPlatform.log.clear();

      await tester.pumpWidget(buildGestures(
        controller: controller,
        config: const AVGestureConfig(
          doubleTapToSeek: false,
          longPressSpeed: false,
          swipeToVolume: false,
          swipeToBrightness: true,
        ),
      ));
      await tester.pump();

      final gestureRect = tester.getRect(find.byType(AVGestures));
      final leftSide = Offset(
        gestureRect.left + gestureRect.width * 0.25,
        gestureRect.top + gestureRect.height / 2,
      );

      await tester.dragFrom(leftSide, const Offset(0, -100));
      await tester.pump();

      expect(mockPlatform.log, contains('setScreenBrightness'));

      controller.dispose();
    });

    testWidgets('swipe down on left side decreases brightness', (tester) async {
      final controller = await createInitializedController(
        mockPlatform,
        playing: true,
      );
      mockPlatform.screenBrightness = 0.8;
      mockPlatform.log.clear();

      await tester.pumpWidget(buildGestures(
        controller: controller,
        config: const AVGestureConfig(
          doubleTapToSeek: false,
          longPressSpeed: false,
          swipeToVolume: false,
          swipeToBrightness: true,
        ),
      ));
      await tester.pump();

      final gestureRect = tester.getRect(find.byType(AVGestures));
      final leftSide = Offset(
        gestureRect.left + gestureRect.width * 0.25,
        gestureRect.top + gestureRect.height / 2,
      );

      await tester.dragFrom(leftSide, const Offset(0, 100));
      await tester.pump();

      expect(mockPlatform.log, contains('setScreenBrightness'));

      controller.dispose();
    });

    testWidgets('shows brightness indicator during swipe', (tester) async {
      final controller = await createInitializedController(
        mockPlatform,
        playing: true,
      );

      await tester.pumpWidget(buildGestures(
        controller: controller,
        config: const AVGestureConfig(
          doubleTapToSeek: false,
          longPressSpeed: false,
          swipeToVolume: false,
          swipeToBrightness: true,
        ),
      ));
      await tester.pump();

      final gestureRect = tester.getRect(find.byType(AVGestures));
      final leftSide = Offset(
        gestureRect.left + gestureRect.width * 0.25,
        gestureRect.top + gestureRect.height / 2,
      );

      final gesture = await tester.startGesture(leftSide);
      await tester.pump();
      await gesture.moveBy(const Offset(0, -30));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -30));
      await tester.pump();

      expect(find.byIcon(Icons.brightness_6), findsOneWidget);
      expect(find.text('Brightness'), findsOneWidget);

      await gesture.up();
      await tester.pump();

      controller.dispose();
    });

    testWidgets('disabled via config', (tester) async {
      final controller = await createInitializedController(
        mockPlatform,
        playing: true,
      );
      mockPlatform.log.clear();

      await tester.pumpWidget(buildGestures(
        controller: controller,
        config: const AVGestureConfig(
          doubleTapToSeek: false,
          longPressSpeed: false,
          swipeToVolume: false,
          swipeToBrightness: false,
        ),
      ));
      await tester.pump();

      final gestureRect = tester.getRect(find.byType(AVGestures));
      final leftSide = Offset(
        gestureRect.left + gestureRect.width * 0.25,
        gestureRect.top + gestureRect.height / 2,
      );

      await tester.dragFrom(leftSide, const Offset(0, -100));
      await tester.pump();

      expect(mockPlatform.log, isNot(contains('setScreenBrightness')));

      controller.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // Single tap
  // ---------------------------------------------------------------------------

  group('Single tap', () {
    testWidgets('fires onTap callback', (tester) async {
      final controller = await createInitializedController(
        mockPlatform,
        playing: true,
      );
      bool tapped = false;

      await tester.pumpWidget(buildGestures(
        controller: controller,
        onTap: () => tapped = true,
        config: const AVGestureConfig(
          doubleTapToSeek: false,
          longPressSpeed: false,
          swipeToVolume: false,
          swipeToBrightness: false,
        ),
      ));
      await tester.pump();

      await tester.tap(find.byType(AVGestures));
      await tester.pump();

      expect(tapped, isTrue);

      controller.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // Config
  // ---------------------------------------------------------------------------

  group('Config', () {
    testWidgets('all gestures disabled prevents all actions', (tester) async {
      final controller = await createInitializedController(
        mockPlatform,
        playing: true,
      );
      controller.value = controller.value.copyWith(
        position: const Duration(seconds: 30),
      );
      mockPlatform.log.clear();

      await tester.pumpWidget(buildGestures(
        controller: controller,
        config: const AVGestureConfig(
          doubleTapToSeek: false,
          longPressSpeed: false,
          swipeToVolume: false,
          swipeToBrightness: false,
        ),
      ));
      await tester.pump();

      final gestureRect = tester.getRect(find.byType(AVGestures));
      final center = Offset(
        gestureRect.left + gestureRect.width * 0.75,
        gestureRect.top + gestureRect.height / 2,
      );

      // Double tap - should not seek
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(center);
      await tester.pumpAndSettle();

      // Long press - should not change speed
      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.up();
      await tester.pump();

      expect(mockPlatform.log, isNot(contains('seekTo')));
      expect(mockPlatform.log, isNot(contains('setPlaybackSpeed')));
      expect(mockPlatform.log, isNot(contains('setSystemVolume')));
      expect(mockPlatform.log, isNot(contains('setScreenBrightness')));

      controller.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // Consecutive double-tap accumulation
  // ---------------------------------------------------------------------------

  group('Double-tap seek clamp and direction', () {
    testWidgets('double-tap left near start clamps seek to zero',
        (tester) async {
      final controller = await createInitializedController(
        mockPlatform,
        playing: true,
      );
      // Position near start — seeking back 10s should clamp to 0
      controller.value = controller.value.copyWith(
        position: const Duration(seconds: 3),
      );
      mockPlatform.seekLog.clear();

      await tester.pumpWidget(buildGestures(controller: controller));
      await tester.pump();

      final gestureRect = tester.getRect(find.byType(AVGestures));
      final leftCenter = Offset(
        gestureRect.left + gestureRect.width * 0.25,
        gestureRect.top + gestureRect.height / 2,
      );

      await tester.tapAt(leftCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(leftCenter);
      await tester.pumpAndSettle();

      expect(mockPlatform.seekLog.last, Duration.zero);

      controller.dispose();
    });

    testWidgets('double-tap right near end clamps seek to duration',
        (tester) async {
      final controller = await createInitializedController(
        mockPlatform,
        playing: true,
        duration: const Duration(minutes: 5),
      );
      // Position near end — seeking forward 10s should clamp to duration
      controller.value = controller.value.copyWith(
        position: const Duration(minutes: 4, seconds: 55),
      );
      mockPlatform.seekLog.clear();

      await tester.pumpWidget(buildGestures(controller: controller));
      await tester.pump();

      final gestureRect = tester.getRect(find.byType(AVGestures));
      final rightCenter = Offset(
        gestureRect.left + gestureRect.width * 0.75,
        gestureRect.top + gestureRect.height / 2,
      );

      await tester.tapAt(rightCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(rightCenter);
      await tester.pumpAndSettle();

      expect(mockPlatform.seekLog.last, const Duration(minutes: 5));

      controller.dispose();
    });

    testWidgets('double-tap left shows rewind icon and negative text',
        (tester) async {
      final controller = await createInitializedController(
        mockPlatform,
        playing: true,
      );
      controller.value = controller.value.copyWith(
        position: const Duration(seconds: 30),
      );

      await tester.pumpWidget(buildGestures(controller: controller));
      await tester.pump();

      final gestureRect = tester.getRect(find.byType(AVGestures));
      final leftCenter = Offset(
        gestureRect.left + gestureRect.width * 0.25,
        gestureRect.top + gestureRect.height / 2,
      );

      await tester.tapAt(leftCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(leftCenter);
      await tester.pump();

      expect(find.byIcon(Icons.fast_rewind), findsOneWidget);
      expect(find.text('-10s'), findsOneWidget);

      await tester.pumpAndSettle();
      controller.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // Theme colors
  // ---------------------------------------------------------------------------

  group('Theme colors', () {
    const customTheme = AVPlayerThemeData(
      iconColor: Color(0xFFFF0000),
      indicatorBackgroundColor: Color(0xFF00FF00),
    );

    testWidgets('double-tap ripple icon uses theme iconColor', (tester) async {
      final controller = await createInitializedController(
        mockPlatform,
        playing: true,
      );
      controller.value = controller.value.copyWith(
        position: const Duration(seconds: 30),
      );

      await tester.pumpWidget(buildGestures(
        controller: controller,
        themeData: customTheme,
      ));
      await tester.pump();

      final gestureRect = tester.getRect(find.byType(AVGestures));
      final rightCenter = Offset(
        gestureRect.left + gestureRect.width * 0.75,
        gestureRect.top + gestureRect.height / 2,
      );

      await tester.tapAt(rightCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(rightCenter);
      await tester.pump();

      final icon = tester.widget<Icon>(find.byIcon(Icons.fast_forward));
      expect(icon.color, const Color(0xFFFF0000));

      await tester.pumpAndSettle();
      controller.dispose();
    });

    testWidgets('long-press indicator uses theme indicatorBackgroundColor',
        (tester) async {
      final controller = await createInitializedController(
        mockPlatform,
        playing: true,
      );

      await tester.pumpWidget(buildGestures(
        controller: controller,
        themeData: customTheme,
      ));
      await tester.pump();

      final center = tester.getCenter(find.byType(AVGestures));
      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 600));

      // Find the speed indicator container with the custom background color
      final containers = tester.widgetList<Container>(find.byType(Container));
      final indicatorContainer = containers.where((c) {
        final decoration = c.decoration;
        if (decoration is BoxDecoration) {
          return decoration.color == const Color(0xFF00FF00);
        }
        return false;
      });
      expect(indicatorContainer, isNotEmpty);

      await gesture.up();
      await tester.pump();

      controller.dispose();
    });
  });
}
