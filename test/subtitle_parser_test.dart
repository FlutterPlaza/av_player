import 'package:av_player/av_player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---------------------------------------------------------------------------
  // SRT Parsing
  // ---------------------------------------------------------------------------

  group('AVSubtitleParser.parseSrt', () {
    test('parses basic SRT content', () {
      const srt = '''
1
00:00:01,000 --> 00:00:04,000
Hello, world!

2
00:00:05,000 --> 00:00:08,000
This is a subtitle.
''';
      final cues = AVSubtitleParser.parseSrt(srt);
      expect(cues, hasLength(2));
      expect(cues[0].text, 'Hello, world!');
      expect(cues[0].startTime, const Duration(seconds: 1));
      expect(cues[0].endTime, const Duration(seconds: 4));
      expect(cues[1].text, 'This is a subtitle.');
      expect(cues[1].startTime, const Duration(seconds: 5));
      expect(cues[1].endTime, const Duration(seconds: 8));
    });

    test('handles multi-line subtitle text', () {
      const srt = '''
1
00:00:01,000 --> 00:00:04,000
Line one
Line two
''';
      final cues = AVSubtitleParser.parseSrt(srt);
      expect(cues, hasLength(1));
      expect(cues[0].text, 'Line one\nLine two');
    });

    test('strips HTML tags', () {
      const srt = '''
1
00:00:01,000 --> 00:00:04,000
<b>Bold</b> and <i>italic</i>
''';
      final cues = AVSubtitleParser.parseSrt(srt);
      expect(cues, hasLength(1));
      expect(cues[0].text, 'Bold and italic');
    });

    test('handles BOM', () {
      const srt = '\uFEFF1\n00:00:01,000 --> 00:00:04,000\nHello\n';
      final cues = AVSubtitleParser.parseSrt(srt);
      expect(cues, hasLength(1));
      expect(cues[0].text, 'Hello');
    });

    test('handles \\r\\n line endings', () {
      const srt =
          '1\r\n00:00:01,000 --> 00:00:04,000\r\nHello\r\n\r\n2\r\n00:00:05,000 --> 00:00:08,000\r\nWorld\r\n';
      final cues = AVSubtitleParser.parseSrt(srt);
      expect(cues, hasLength(2));
    });

    test('returns sorted cues', () {
      const srt = '''
2
00:00:05,000 --> 00:00:08,000
Second

1
00:00:01,000 --> 00:00:04,000
First
''';
      final cues = AVSubtitleParser.parseSrt(srt);
      expect(cues, hasLength(2));
      expect(cues[0].text, 'First');
      expect(cues[1].text, 'Second');
    });

    test('skips blocks with invalid timestamps', () {
      const srt = '''
1
invalid timestamp
Hello

2
00:00:05,000 --> 00:00:08,000
Valid
''';
      final cues = AVSubtitleParser.parseSrt(srt);
      expect(cues, hasLength(1));
      expect(cues[0].text, 'Valid');
    });

    test('handles period separator for milliseconds', () {
      const srt = '''
1
00:00:01.500 --> 00:00:04.200
Dot-separated
''';
      final cues = AVSubtitleParser.parseSrt(srt);
      expect(cues, hasLength(1));
      expect(
        cues[0].startTime,
        const Duration(seconds: 1, milliseconds: 500),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // WebVTT Parsing
  // ---------------------------------------------------------------------------

  group('AVSubtitleParser.parseWebVtt', () {
    test('parses basic WebVTT content', () {
      const vtt = '''
WEBVTT

00:00:01.000 --> 00:00:04.000
Hello, world!

00:00:05.000 --> 00:00:08.000
This is a subtitle.
''';
      final cues = AVSubtitleParser.parseWebVtt(vtt);
      expect(cues, hasLength(2));
      expect(cues[0].text, 'Hello, world!');
      expect(cues[1].text, 'This is a subtitle.');
    });

    test('handles cue identifiers', () {
      const vtt = '''
WEBVTT

cue-1
00:00:01.000 --> 00:00:04.000
With identifier
''';
      final cues = AVSubtitleParser.parseWebVtt(vtt);
      expect(cues, hasLength(1));
      expect(cues[0].text, 'With identifier');
    });

    test('skips STYLE and NOTE blocks', () {
      const vtt = '''
WEBVTT

STYLE
::cue { color: red; }

NOTE This is a comment

00:00:01.000 --> 00:00:04.000
Visible text
''';
      final cues = AVSubtitleParser.parseWebVtt(vtt);
      expect(cues, hasLength(1));
      expect(cues[0].text, 'Visible text');
    });

    test('handles short timestamp format (MM:SS.mmm)', () {
      const vtt = '''
WEBVTT

01:30.000 --> 01:35.000
Short format
''';
      final cues = AVSubtitleParser.parseWebVtt(vtt);
      expect(cues, hasLength(1));
      expect(cues[0].startTime, const Duration(minutes: 1, seconds: 30));
    });

    test('returns empty list for non-WEBVTT content', () {
      const vtt = 'Not a valid WebVTT file';
      final cues = AVSubtitleParser.parseWebVtt(vtt);
      expect(cues, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Auto-detect
  // ---------------------------------------------------------------------------

  group('AVSubtitleParser.parse', () {
    test('auto-detects WebVTT', () {
      const vtt = '''
WEBVTT

00:00:01.000 --> 00:00:04.000
Hello
''';
      final cues = AVSubtitleParser.parse(vtt);
      expect(cues, hasLength(1));
    });

    test('falls back to SRT', () {
      const srt = '''
1
00:00:01,000 --> 00:00:04,000
Hello
''';
      final cues = AVSubtitleParser.parse(srt);
      expect(cues, hasLength(1));
    });

    test('handles empty content', () {
      final cues = AVSubtitleParser.parse('');
      expect(cues, isEmpty);
    });
  });
}
