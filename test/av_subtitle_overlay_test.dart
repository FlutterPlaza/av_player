import 'package:av_player/av_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_helpers.dart';

void main() {
  group('AVSubtitleOverlay', () {
    testWidgets('shows nothing when currentCue is null', (tester) async {
      await tester.pumpWidget(wrapWithApp(
        const Stack(
          children: [
            AVSubtitleOverlay(currentCue: null),
          ],
        ),
      ));

      expect(find.byType(Text), findsNothing);
    });

    testWidgets('shows text when currentCue is set', (tester) async {
      const cue = AVSubtitleCue(
        startTime: Duration(seconds: 1),
        endTime: Duration(seconds: 4),
        text: 'Hello, world!',
      );

      await tester.pumpWidget(wrapWithApp(
        const Stack(
          children: [
            AVSubtitleOverlay(currentCue: cue),
          ],
        ),
      ));

      expect(find.text('Hello, world!'), findsOneWidget);
    });

    testWidgets('respects theme colors', (tester) async {
      const cue = AVSubtitleCue(
        startTime: Duration(seconds: 1),
        endTime: Duration(seconds: 4),
        text: 'Themed text',
      );

      await tester.pumpWidget(wrapWithThemedApp(
        const Stack(
          children: [
            AVSubtitleOverlay(currentCue: cue),
          ],
        ),
        const AVPlayerThemeData(
          subtitleTextColor: Colors.yellow,
          subtitleFontSize: 24.0,
        ),
      ));

      final textWidget = tester.widget<Text>(find.text('Themed text'));
      expect(textWidget.style?.color, Colors.yellow);
      expect(textWidget.style?.fontSize, 24.0);
    });

    testWidgets('uses custom bottom padding', (tester) async {
      const cue = AVSubtitleCue(
        startTime: Duration(seconds: 1),
        endTime: Duration(seconds: 4),
        text: 'Padded',
      );

      await tester.pumpWidget(wrapWithApp(
        const Stack(
          children: [
            AVSubtitleOverlay(currentCue: cue, bottomPadding: 80),
          ],
        ),
      ));

      final positioned = tester.widget<Positioned>(
        find.byType(Positioned),
      );
      expect(positioned.bottom, 80);
    });

    testWidgets('renders multi-line subtitle text', (tester) async {
      const cue = AVSubtitleCue(
        startTime: Duration(seconds: 1),
        endTime: Duration(seconds: 4),
        text: 'Line 1\nLine 2',
      );

      await tester.pumpWidget(wrapWithApp(
        const Stack(
          children: [
            AVSubtitleOverlay(currentCue: cue),
          ],
        ),
      ));

      expect(find.text('Line 1\nLine 2'), findsOneWidget);
    });
  });
}
