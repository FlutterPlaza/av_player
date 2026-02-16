import 'package:av_player_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------------------------
  // App launch
  // ---------------------------------------------------------------------------

  group('App launch', () {
    testWidgets('home screen renders correct app bar title', (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      expect(find.text('AV Player Examples'), findsOneWidget);
    });

    testWidgets('home screen renders 8 feature cards', (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      expect(find.text('Video Player'), findsOneWidget);
      expect(find.text('Shorts'), findsOneWidget);
      expect(find.text('Music Player'), findsOneWidget);
      expect(find.text('Live Stream'), findsOneWidget);
      expect(find.text('Picture-in-Picture'), findsOneWidget);
      expect(find.text('Playlist'), findsOneWidget);
      expect(find.text('Gesture Controls'), findsOneWidget);
      expect(find.text('Theming'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  group('Navigation', () {
    testWidgets('navigates to Video Player screen', (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Video Player'));
      await tester.pumpAndSettle();

      expect(find.text('Video Player'), findsWidgets);
    });

    testWidgets('navigates to Shorts screen', (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Shorts'));
      await tester.pumpAndSettle();
    });

    testWidgets('navigates to Music Player screen', (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Music Player'));
      await tester.pumpAndSettle();

      expect(find.text('Music Player'), findsWidgets);
    });

    testWidgets('navigates to Live Stream screen', (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Live Stream'));
      await tester.pumpAndSettle();

      expect(find.text('Live Stream'), findsWidgets);
    });

    testWidgets('navigates to Picture-in-Picture screen', (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Picture-in-Picture'));
      await tester.pumpAndSettle();

      expect(find.text('Picture-in-Picture'), findsWidgets);
    });

    testWidgets('navigates to Playlist screen', (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Playlist'));
      await tester.pumpAndSettle();

      expect(find.text('Playlist'), findsWidgets);
    });

    testWidgets('navigates to Gesture Controls screen', (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gesture Controls'));
      await tester.pumpAndSettle();

      expect(find.text('Gesture Controls'), findsWidgets);
    });

    testWidgets('navigates to Theming screen', (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Theming'));
      await tester.pumpAndSettle();

      expect(find.text('Theming'), findsWidgets);
    });
  });

  // ---------------------------------------------------------------------------
  // Widget presence
  // ---------------------------------------------------------------------------

  group('Widget presence', () {
    testWidgets('Theming screen has theme choice chips', (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Theming'));
      await tester.pumpAndSettle();

      expect(find.byType(ChoiceChip), findsWidgets);
      expect(find.text('Default'), findsOneWidget);
      expect(find.text('Orange'), findsOneWidget);
      expect(find.text('Teal'), findsOneWidget);
    });

    testWidgets('Playlist screen has track list', (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Playlist'));
      await tester.pumpAndSettle();

      expect(find.text('Big Buck Bunny'), findsOneWidget);
      expect(find.text("Elephant's Dream"), findsOneWidget);
      expect(find.text('Sintel'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Back navigation
  // ---------------------------------------------------------------------------

  group('Back navigation', () {
    testWidgets('pressing back returns to home', (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      // Navigate forward
      await tester.tap(find.text('Theming'));
      await tester.pumpAndSettle();

      expect(find.text('AV Player Examples'), findsNothing);

      // Navigate back
      final backButton = find.byTooltip('Back');
      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton);
      } else {
        // Use the Navigator to pop
        final NavigatorState navigator = tester.state(find.byType(Navigator));
        navigator.pop();
      }
      await tester.pumpAndSettle();

      expect(find.text('AV Player Examples'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Shorts screen
  // ---------------------------------------------------------------------------

  group('Shorts screen', () {
    testWidgets('displays first short overlay text', (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Shorts'));
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('@action_clips'), findsOneWidget);
      expect(find.textContaining('For Bigger Blazes'), findsOneWidget);
    });

    testWidgets('displays action buttons', (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Shorts'));
      await tester.pump(const Duration(seconds: 2));

      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.text('45.2K'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
    });

    testWidgets('displays sound name', (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Shorts'));
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Original Sound - action_clips'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Playlist screen
  // ---------------------------------------------------------------------------

  group('Playlist screen', () {
    testWidgets('displays all 5 track titles', (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Playlist'));
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Big Buck Bunny'), findsWidgets);
      expect(find.text("Elephant's Dream"), findsOneWidget);
      expect(find.text('Sintel'), findsOneWidget);
      expect(find.text('Tears of Steel'), findsOneWidget);
      expect(find.text('For Bigger Fun'), findsOneWidget);
    });

    testWidgets('displays shuffle and repeat buttons', (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Playlist'));
      await tester.pump(const Duration(seconds: 2));

      expect(find.byIcon(Icons.shuffle), findsOneWidget);
      expect(find.byIcon(Icons.repeat), findsOneWidget);
    });

    testWidgets('displays track count', (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Playlist'));
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Track 1 of 5'), findsOneWidget);
    });

    testWidgets('displays repeat mode label', (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Playlist'));
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Repeat: Off'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Video Player screen
  // ---------------------------------------------------------------------------

  group('Video Player screen', () {
    testWidgets('displays video title and channel info', (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Video Player'));
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Big Buck Bunny'), findsWidgets);
      expect(find.textContaining('Blender Foundation'), findsWidgets);
    });

    testWidgets('displays action items', (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Video Player'));
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Like'), findsOneWidget);
      expect(find.text('Dislike'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('displays expandable description with Show more',
        (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Video Player'));
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Show more'), findsOneWidget);
    });

    testWidgets('displays Up next section with 3 recommendations',
        (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Video Player'));
      await tester.pump(const Duration(seconds: 2));

      // Scroll down to see the Up next section
      await tester.dragUntilVisible(
        find.text('Up next'),
        find.byType(SingleChildScrollView).first,
        const Offset(0, -200),
      );

      expect(find.text('Up next'), findsOneWidget);
      expect(find.text("Elephant's Dream"), findsOneWidget);
      expect(find.text('Sintel'), findsOneWidget);
      expect(find.text('Tears of Steel'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Music Player screen
  // ---------------------------------------------------------------------------

  group('Music Player screen', () {
    testWidgets('displays now-playing track info', (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Music Player'));
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Big Buck Bunny'), findsWidgets);
      expect(find.text('Blender Foundation'), findsWidgets);
    });

    testWidgets('displays shuffle and repeat controls', (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Music Player'));
      await tester.pump(const Duration(seconds: 2));

      expect(find.byIcon(Icons.shuffle), findsOneWidget);
      expect(find.byIcon(Icons.repeat), findsOneWidget);
    });

    testWidgets('displays Queue section with track list', (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Music Player'));
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Queue'), findsOneWidget);
      expect(find.text("Elephant's Dream"), findsOneWidget);
      expect(find.text('Sintel'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Live Stream screen
  // ---------------------------------------------------------------------------

  group('Live Stream screen', () {
    testWidgets('displays LIVE badge and viewer count', (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Live Stream'));
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('LIVE'), findsOneWidget);
      expect(find.text('1.2K watching now'), findsOneWidget);
    });

    testWidgets('displays chat messages', (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Live Stream'));
      await tester.pump(const Duration(seconds: 2));

      expect(find.textContaining('StreamFan42'), findsOneWidget);
      expect(find.textContaining('This is amazing!'), findsOneWidget);
    });

    testWidgets('displays chat input', (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Live Stream'));
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Send a message...'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // PIP screen
  // ---------------------------------------------------------------------------

  group('PIP screen', () {
    testWidgets('displays Native PIP and Minimize to PIP buttons',
        (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Picture-in-Picture'));
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Native PIP'), findsOneWidget);
      expect(find.text('Minimize to PIP'), findsOneWidget);
    });

    testWidgets('tapping Minimize shows recommended grid', (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Picture-in-Picture'));
      await tester.pump(const Duration(seconds: 2));

      await tester.tap(find.text('Minimize to PIP'));
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Recommended'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Gestures screen
  // ---------------------------------------------------------------------------

  group('Gestures screen', () {
    testWidgets('displays gesture feedback banner with None yet',
        (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gesture Controls'));
      await tester.pump(const Duration(seconds: 2));

      expect(find.textContaining('None yet'), findsOneWidget);
    });

    testWidgets('displays gesture list items', (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gesture Controls'));
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Tap'), findsOneWidget);
      expect(find.text('Long press'), findsOneWidget);
      expect(find.text('Double-tap right'), findsOneWidget);
      expect(find.text('Double-tap left'), findsOneWidget);
    });

    testWidgets('displays unchecked icons for untried gestures',
        (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gesture Controls'));
      await tester.pump(const Duration(seconds: 2));

      expect(find.byIcon(Icons.radio_button_unchecked), findsWidgets);
    });
  });

  // ---------------------------------------------------------------------------
  // Theming screen
  // ---------------------------------------------------------------------------

  group('Theming screen', () {
    testWidgets('displays all 6 theme chips', (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Theming'));
      await tester.pumpAndSettle();

      expect(find.text('Default'), findsOneWidget);
      expect(find.text('Orange'), findsOneWidget);
      expect(find.text('Teal'), findsOneWidget);
      expect(find.text('Purple'), findsOneWidget);
      expect(find.text('Red'), findsOneWidget);
      expect(find.text('Green'), findsOneWidget);
    });

    testWidgets('displays Properties section with color labels',
        (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Theming'));
      await tester.pumpAndSettle();

      expect(find.text('Properties'), findsOneWidget);
      expect(find.text('Accent Color'), findsOneWidget);
      expect(find.text('Slider Active'), findsOneWidget);
      expect(find.text('Slider Thumb'), findsOneWidget);
    });

    testWidgets('tapping Orange chip shows description', (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Theming'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Orange'));
      await tester.pumpAndSettle();

      expect(find.text('Warm orange accent and slider'), findsOneWidget);
    });
  });
}
