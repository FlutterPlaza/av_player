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
  // Visibility toggle
  // ---------------------------------------------------------------------------

  group('Visibility toggle', () {
    testWidgets('controls are visible initially', (tester) async {
      final controller = await createInitializedController(mockPlatform);

      await tester.pumpWidget(wrapWithApp(SizedBox.expand(
        child: AVControls(controller: controller),
      )));
      await tester.pump();

      // Play/pause icon should be visible
      expect(find.byIcon(Icons.play_circle_filled), findsOneWidget);

      controller.dispose();
    });

    testWidgets('tap hides controls', (tester) async {
      final controller = await createInitializedController(mockPlatform);

      await tester.pumpWidget(wrapWithApp(SizedBox.expand(
        child: AVControls(controller: controller),
      )));
      await tester.pump();

      // Tap to hide
      await tester.tap(find.byType(AVControls));
      // Advance past the fade animation (250ms)
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 50));

      // Controls should be hidden
      expect(find.byIcon(Icons.play_circle_filled), findsNothing);

      controller.dispose();
    });

    testWidgets('tap again shows controls', (tester) async {
      final controller = await createInitializedController(mockPlatform);

      await tester.pumpWidget(wrapWithApp(SizedBox.expand(
        child: AVControls(controller: controller),
      )));
      await tester.pump();

      // Hide
      await tester.tap(find.byType(AVControls));
      await tester.pump(const Duration(milliseconds: 300));

      // Show
      await tester.tap(find.byType(AVControls));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();

      expect(find.byIcon(Icons.play_circle_filled), findsOneWidget);

      controller.dispose();
    });

    testWidgets('auto-hides after default duration (3s)', (tester) async {
      final controller = await createInitializedController(mockPlatform);

      await tester.pumpWidget(wrapWithApp(SizedBox.expand(
        child: AVControls(controller: controller),
      )));
      await tester.pump();

      expect(find.byIcon(Icons.play_circle_filled), findsOneWidget);

      // Wait for auto-hide timer (3s) then let fade animation settle
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.play_circle_filled), findsNothing);

      controller.dispose();
    });

    testWidgets('custom autoHideDuration is respected', (tester) async {
      final controller = await createInitializedController(mockPlatform);

      await tester.pumpWidget(wrapWithApp(SizedBox.expand(
        child: AVControls(
          controller: controller,
          config: const AVControlsConfig(
            autoHideDuration: Duration(seconds: 1),
          ),
        ),
      )));
      await tester.pump();

      expect(find.byIcon(Icons.play_circle_filled), findsOneWidget);

      // After 1s it should start hiding, then settle the fade animation
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.play_circle_filled), findsNothing);

      controller.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // Play/pause button
  // ---------------------------------------------------------------------------

  group('Play/pause button', () {
    testWidgets('shows play icon when paused', (tester) async {
      final controller = await createInitializedController(mockPlatform);

      await tester.pumpWidget(wrapWithApp(SizedBox.expand(
        child: AVControls(controller: controller),
      )));
      await tester.pump();

      expect(find.byIcon(Icons.play_circle_filled), findsOneWidget);

      controller.dispose();
    });

    testWidgets('shows pause icon when playing', (tester) async {
      final controller = await createInitializedController(
        mockPlatform,
        playing: true,
      );

      await tester.pumpWidget(wrapWithApp(SizedBox.expand(
        child: AVControls(controller: controller),
      )));
      await tester.pump();

      expect(find.byIcon(Icons.pause_circle_filled), findsOneWidget);

      controller.dispose();
    });

    testWidgets('shows replay icon when completed', (tester) async {
      final controller = await createInitializedController(mockPlatform);
      controller.value = controller.value.copyWith(
        isCompleted: true,
        isPlaying: false,
      );

      await tester.pumpWidget(wrapWithApp(SizedBox.expand(
        child: AVControls(controller: controller),
      )));
      await tester.pump();

      expect(find.byIcon(Icons.replay), findsOneWidget);

      controller.dispose();
    });

    testWidgets('shows buffering indicator when buffering', (tester) async {
      final controller = await createInitializedController(mockPlatform);
      controller.value = controller.value.copyWith(isBuffering: true);

      await tester.pumpWidget(wrapWithApp(SizedBox.expand(
        child: AVControls(controller: controller),
      )));
      await tester.pump();

      // The center play/pause area should have a CircularProgressIndicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      controller.dispose();
    });

    testWidgets('tapping play button calls play()', (tester) async {
      final controller = await createInitializedController(mockPlatform);
      mockPlatform.log.clear();

      await tester.pumpWidget(wrapWithApp(SizedBox.expand(
        child: AVControls(controller: controller),
      )));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.play_circle_filled));
      await tester.pump();

      expect(mockPlatform.log, contains('play'));

      controller.dispose();
    });

    testWidgets('tapping pause button calls pause()', (tester) async {
      final controller = await createInitializedController(
        mockPlatform,
        playing: true,
      );
      mockPlatform.log.clear();

      await tester.pumpWidget(wrapWithApp(SizedBox.expand(
        child: AVControls(controller: controller),
      )));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.pause_circle_filled));
      await tester.pump();

      expect(mockPlatform.log, contains('pause'));

      controller.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // Skip buttons
  // ---------------------------------------------------------------------------

  group('Skip buttons', () {
    testWidgets('skip forward and backward buttons are visible',
        (tester) async {
      final controller = await createInitializedController(mockPlatform);

      await tester.pumpWidget(wrapWithApp(SizedBox.expand(
        child: AVControls(controller: controller),
      )));
      await tester.pump();

      expect(find.byIcon(Icons.replay_10), findsOneWidget);
      expect(find.byIcon(Icons.forward_10), findsOneWidget);

      controller.dispose();
    });

    testWidgets('skip forward calls seekTo with correct offset',
        (tester) async {
      final controller = await createInitializedController(mockPlatform);
      controller.value = controller.value.copyWith(
        position: const Duration(seconds: 30),
      );
      mockPlatform.log.clear();
      mockPlatform.seekLog.clear();

      await tester.pumpWidget(wrapWithApp(SizedBox.expand(
        child: AVControls(controller: controller),
      )));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.forward_10));
      await tester.pump();

      expect(mockPlatform.log, contains('seekTo'));
      expect(mockPlatform.seekLog.last, const Duration(seconds: 40));

      controller.dispose();
    });

    testWidgets('skip backward calls seekTo with correct offset',
        (tester) async {
      final controller = await createInitializedController(mockPlatform);
      controller.value = controller.value.copyWith(
        position: const Duration(seconds: 30),
      );
      mockPlatform.log.clear();
      mockPlatform.seekLog.clear();

      await tester.pumpWidget(wrapWithApp(SizedBox.expand(
        child: AVControls(controller: controller),
      )));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.replay_10));
      await tester.pump();

      expect(mockPlatform.log, contains('seekTo'));
      expect(mockPlatform.seekLog.last, const Duration(seconds: 20));

      controller.dispose();
    });

    testWidgets('skip buttons hidden when showSkipButtons is false',
        (tester) async {
      final controller = await createInitializedController(mockPlatform);

      await tester.pumpWidget(wrapWithApp(SizedBox.expand(
        child: AVControls(
          controller: controller,
          config: const AVControlsConfig(showSkipButtons: false),
        ),
      )));
      await tester.pump();

      expect(find.byIcon(Icons.replay_10), findsNothing);
      expect(find.byIcon(Icons.forward_10), findsNothing);

      controller.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // Seek bar
  // ---------------------------------------------------------------------------

  group('Seek bar', () {
    testWidgets('slider is present', (tester) async {
      final controller = await createInitializedController(mockPlatform);

      await tester.pumpWidget(wrapWithApp(SizedBox.expand(
        child: AVControls(controller: controller),
      )));
      await tester.pump();

      expect(find.byType(Slider), findsOneWidget);

      controller.dispose();
    });

    testWidgets('slider reflects position', (tester) async {
      final controller = await createInitializedController(mockPlatform);
      controller.value = controller.value.copyWith(
        position: const Duration(seconds: 60),
      );

      await tester.pumpWidget(wrapWithApp(SizedBox.expand(
        child: AVControls(controller: controller),
      )));
      await tester.pump();

      final slider = tester.widget<Slider>(find.byType(Slider));
      // Position is 60s = 60000ms
      expect(slider.value, closeTo(60000.0, 1.0));

      controller.dispose();
    });

    testWidgets('dragging slider calls seekTo', (tester) async {
      final controller = await createInitializedController(mockPlatform);
      mockPlatform.log.clear();

      await tester.pumpWidget(wrapWithApp(SizedBox.expand(
        child: AVControls(controller: controller),
      )));
      await tester.pump();

      // Drag the slider
      final sliderFinder = find.byType(Slider);
      await tester.drag(sliderFinder, const Offset(100, 0));
      await tester.pump();

      expect(mockPlatform.log, contains('seekTo'));

      controller.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // Speed button
  // ---------------------------------------------------------------------------

  group('Speed button', () {
    testWidgets('shows current speed', (tester) async {
      final controller = await createInitializedController(mockPlatform);

      await tester.pumpWidget(wrapWithApp(SizedBox.expand(
        child: AVControls(controller: controller),
      )));
      await tester.pump();

      expect(find.text('1.0x'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('popup opens with speed options', (tester) async {
      final controller = await createInitializedController(mockPlatform);

      await tester.pumpWidget(wrapWithApp(SizedBox.expand(
        child: AVControls(controller: controller),
      )));
      await tester.pump();

      // Tap speed button to open popup
      await tester.tap(find.text('1.0x'));
      await tester.pumpAndSettle();

      // Default speeds: 0.5, 0.75, 1.0, 1.25, 1.5, 2.0
      expect(find.text('0.5x'), findsWidgets);
      expect(find.text('2.0x'), findsWidgets);

      controller.dispose();
    });

    testWidgets('selecting speed calls setPlaybackSpeed', (tester) async {
      final controller = await createInitializedController(mockPlatform);
      mockPlatform.log.clear();
      mockPlatform.speedLog.clear();

      await tester.pumpWidget(wrapWithApp(SizedBox.expand(
        child: AVControls(controller: controller),
      )));
      await tester.pump();

      // Open popup
      await tester.tap(find.text('1.0x'));
      await tester.pumpAndSettle();

      // Select 2.0x from the popup menu
      await tester.tap(find.text('2.0x').last);
      await tester.pumpAndSettle();

      expect(mockPlatform.log, contains('setPlaybackSpeed'));
      expect(mockPlatform.speedLog, contains(2.0));

      controller.dispose();
    });

    testWidgets('speed button hidden when showSpeedButton is false',
        (tester) async {
      final controller = await createInitializedController(mockPlatform);

      await tester.pumpWidget(wrapWithApp(SizedBox.expand(
        child: AVControls(
          controller: controller,
          config: const AVControlsConfig(showSpeedButton: false),
        ),
      )));
      await tester.pump();

      expect(find.byType(PopupMenuButton<double>), findsNothing);

      controller.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // Loop button
  // ---------------------------------------------------------------------------

  group('Loop button', () {
    testWidgets('shows repeat icon when not looping', (tester) async {
      final controller = await createInitializedController(mockPlatform);

      await tester.pumpWidget(wrapWithApp(SizedBox.expand(
        child: AVControls(controller: controller),
      )));
      await tester.pump();

      expect(find.byIcon(Icons.repeat), findsOneWidget);

      controller.dispose();
    });

    testWidgets('shows repeat_one icon when looping', (tester) async {
      final controller = await createInitializedController(mockPlatform);
      await controller.setLooping(true);

      await tester.pumpWidget(wrapWithApp(SizedBox.expand(
        child: AVControls(controller: controller),
      )));
      await tester.pump();

      expect(find.byIcon(Icons.repeat_one), findsOneWidget);

      controller.dispose();
    });

    testWidgets('tapping loop button calls setLooping', (tester) async {
      final controller = await createInitializedController(mockPlatform);
      mockPlatform.log.clear();

      await tester.pumpWidget(wrapWithApp(SizedBox.expand(
        child: AVControls(controller: controller),
      )));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.repeat));
      await tester.pump();

      expect(mockPlatform.log, contains('setLooping'));

      controller.dispose();
    });

    testWidgets('loop button hidden when showLoopButton is false',
        (tester) async {
      final controller = await createInitializedController(mockPlatform);

      await tester.pumpWidget(wrapWithApp(SizedBox.expand(
        child: AVControls(
          controller: controller,
          config: const AVControlsConfig(showLoopButton: false),
        ),
      )));
      await tester.pump();

      expect(find.byIcon(Icons.repeat), findsNothing);

      controller.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // PIP button
  // ---------------------------------------------------------------------------

  group('PIP button', () {
    testWidgets('tapping PIP button calls enterPip', (tester) async {
      final controller = await createInitializedController(mockPlatform);
      mockPlatform.log.clear();

      await tester.pumpWidget(wrapWithApp(SizedBox.expand(
        child: AVControls(controller: controller),
      )));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.picture_in_picture_alt));
      await tester.pump();

      expect(mockPlatform.log, contains('enterPip'));

      controller.dispose();
    });

    testWidgets('PIP button hidden when showPipButton is false',
        (tester) async {
      final controller = await createInitializedController(mockPlatform);

      await tester.pumpWidget(wrapWithApp(SizedBox.expand(
        child: AVControls(
          controller: controller,
          config: const AVControlsConfig(showPipButton: false),
        ),
      )));
      await tester.pump();

      expect(find.byIcon(Icons.picture_in_picture_alt), findsNothing);

      controller.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // Fullscreen button
  // ---------------------------------------------------------------------------

  group('Fullscreen button', () {
    testWidgets('visible when onFullscreen callback is provided',
        (tester) async {
      final controller = await createInitializedController(mockPlatform);

      await tester.pumpWidget(wrapWithApp(SizedBox.expand(
        child: AVControls(
          controller: controller,
          onFullscreen: () {},
        ),
      )));
      await tester.pump();

      expect(find.byIcon(Icons.fullscreen), findsOneWidget);

      controller.dispose();
    });

    testWidgets('hidden when onFullscreen is null', (tester) async {
      final controller = await createInitializedController(mockPlatform);

      await tester.pumpWidget(wrapWithApp(SizedBox.expand(
        child: AVControls(controller: controller),
      )));
      await tester.pump();

      expect(find.byIcon(Icons.fullscreen), findsNothing);

      controller.dispose();
    });

    testWidgets('tapping fullscreen button fires callback', (tester) async {
      final controller = await createInitializedController(mockPlatform);
      bool called = false;

      await tester.pumpWidget(wrapWithApp(SizedBox.expand(
        child: AVControls(
          controller: controller,
          onFullscreen: () => called = true,
        ),
      )));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.fullscreen));
      await tester.pump();

      expect(called, isTrue);

      controller.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // Title and back button
  // ---------------------------------------------------------------------------

  group('Title and back button', () {
    testWidgets('title text is displayed', (tester) async {
      final controller = await createInitializedController(mockPlatform);

      await tester.pumpWidget(wrapWithApp(SizedBox.expand(
        child: AVControls(
          controller: controller,
          title: 'Test Video',
        ),
      )));
      await tester.pump();

      expect(find.text('Test Video'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('back button fires onBack callback', (tester) async {
      final controller = await createInitializedController(mockPlatform);
      bool called = false;

      await tester.pumpWidget(wrapWithApp(SizedBox.expand(
        child: AVControls(
          controller: controller,
          onBack: () => called = true,
        ),
      )));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();

      expect(called, isTrue);

      controller.dispose();
    });

    testWidgets('back button hidden when onBack is null', (tester) async {
      final controller = await createInitializedController(mockPlatform);

      await tester.pumpWidget(wrapWithApp(SizedBox.expand(
        child: AVControls(controller: controller),
      )));
      await tester.pump();

      expect(find.byIcon(Icons.arrow_back), findsNothing);

      controller.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // Next/Previous buttons
  // ---------------------------------------------------------------------------

  group('Next/Previous buttons', () {
    testWidgets('next button visible when onNext is provided', (tester) async {
      final controller = await createInitializedController(mockPlatform);

      await tester.pumpWidget(wrapWithApp(SizedBox.expand(
        child: AVControls(
          controller: controller,
          onNext: () {},
        ),
      )));
      await tester.pump();

      expect(find.byIcon(Icons.skip_next), findsOneWidget);

      controller.dispose();
    });

    testWidgets('previous button visible when onPrevious is provided',
        (tester) async {
      final controller = await createInitializedController(mockPlatform);

      await tester.pumpWidget(wrapWithApp(SizedBox.expand(
        child: AVControls(
          controller: controller,
          onPrevious: () {},
        ),
      )));
      await tester.pump();

      expect(find.byIcon(Icons.skip_previous), findsOneWidget);

      controller.dispose();
    });

    testWidgets('next button hidden when onNext is null', (tester) async {
      final controller = await createInitializedController(mockPlatform);

      await tester.pumpWidget(wrapWithApp(SizedBox.expand(
        child: AVControls(controller: controller),
      )));
      await tester.pump();

      expect(find.byIcon(Icons.skip_next), findsNothing);

      controller.dispose();
    });

    testWidgets('previous button hidden when onPrevious is null',
        (tester) async {
      final controller = await createInitializedController(mockPlatform);

      await tester.pumpWidget(wrapWithApp(SizedBox.expand(
        child: AVControls(controller: controller),
      )));
      await tester.pump();

      expect(find.byIcon(Icons.skip_previous), findsNothing);

      controller.dispose();
    });

    testWidgets('tapping next fires onNext callback', (tester) async {
      final controller = await createInitializedController(mockPlatform);
      bool called = false;

      await tester.pumpWidget(wrapWithApp(SizedBox.expand(
        child: AVControls(
          controller: controller,
          onNext: () => called = true,
        ),
      )));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.skip_next));
      await tester.pump();

      expect(called, isTrue);

      controller.dispose();
    });

    testWidgets('tapping previous fires onPrevious callback', (tester) async {
      final controller = await createInitializedController(mockPlatform);
      bool called = false;

      await tester.pumpWidget(wrapWithApp(SizedBox.expand(
        child: AVControls(
          controller: controller,
          onPrevious: () => called = true,
        ),
      )));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.skip_previous));
      await tester.pump();

      expect(called, isTrue);

      controller.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // Theme colors
  // ---------------------------------------------------------------------------

  group('Theme colors', () {
    const customTheme = AVPlayerThemeData(
      iconColor: Color(0xFFFF0000),
      sliderActiveColor: Color(0xFF00FF00),
      sliderThumbColor: Color(0xFF0000FF),
      accentColor: Color(0xFFFFFF00),
      overlayColor: Color(0x80FF00FF),
    );

    testWidgets('play/pause icon uses theme iconColor', (tester) async {
      final controller = await createInitializedController(mockPlatform);

      await tester.pumpWidget(wrapWithThemedApp(
        SizedBox.expand(child: AVControls(controller: controller)),
        customTheme,
      ));
      await tester.pump();

      final icon = tester.widget<Icon>(find.byIcon(Icons.play_circle_filled));
      expect(icon.color, const Color(0xFFFF0000));

      controller.dispose();
    });

    testWidgets('slider uses theme sliderActiveColor', (tester) async {
      final controller = await createInitializedController(mockPlatform);

      await tester.pumpWidget(wrapWithThemedApp(
        SizedBox.expand(child: AVControls(controller: controller)),
        customTheme,
      ));
      await tester.pump();

      final sliderTheme = SliderTheme.of(
        tester.element(find.byType(Slider)),
      );
      expect(sliderTheme.activeTrackColor, const Color(0xFF00FF00));

      controller.dispose();
    });

    testWidgets('slider uses theme sliderThumbColor', (tester) async {
      final controller = await createInitializedController(mockPlatform);

      await tester.pumpWidget(wrapWithThemedApp(
        SizedBox.expand(child: AVControls(controller: controller)),
        customTheme,
      ));
      await tester.pump();

      final sliderTheme = SliderTheme.of(
        tester.element(find.byType(Slider)),
      );
      expect(sliderTheme.thumbColor, const Color(0xFF0000FF));

      controller.dispose();
    });

    testWidgets('loop button uses theme accentColor when active',
        (tester) async {
      final controller = await createInitializedController(mockPlatform);
      await controller.setLooping(true);

      await tester.pumpWidget(wrapWithThemedApp(
        SizedBox.expand(child: AVControls(controller: controller)),
        customTheme,
      ));
      await tester.pump();

      final icon = tester.widget<Icon>(find.byIcon(Icons.repeat_one));
      expect(icon.color, const Color(0xFFFFFF00));

      controller.dispose();
    });

    testWidgets('overlay uses theme overlayColor', (tester) async {
      final controller = await createInitializedController(mockPlatform);

      await tester.pumpWidget(wrapWithThemedApp(
        SizedBox.expand(child: AVControls(controller: controller)),
        customTheme,
      ));
      await tester.pump();

      // Find the Container with the overlay background color
      final containers = tester.widgetList<Container>(find.byType(Container));
      final overlayContainer = containers.where(
        (c) => c.color == const Color(0x80FF00FF),
      );
      expect(overlayContainer, isNotEmpty);

      controller.dispose();
    });
  });
}
