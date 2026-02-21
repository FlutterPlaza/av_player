import 'platform/types.dart';

/// Pure Dart parser for SRT and WebVTT subtitle files.
///
/// No HTTP or native dependencies — the caller provides the raw content
/// string and receives a sorted list of [AVSubtitleCue]s.
///
/// ```dart
/// final cues = AVSubtitleParser.parse(srtContent);
/// ```
class AVSubtitleParser {
  AVSubtitleParser._();

  /// Parses SRT subtitle content into a list of cues.
  static List<AVSubtitleCue> parseSrt(String content) {
    final normalized = _normalize(content);
    final blocks = normalized.split(RegExp(r'\n\n+'));
    final cues = <AVSubtitleCue>[];

    for (final block in blocks) {
      final lines = block.trim().split('\n');
      if (lines.length < 3) continue;

      // Line 0: sequence number (skip)
      // Line 1: timestamps
      final timestamps = _parseSrtTimestamps(lines[1]);
      if (timestamps == null) continue;

      // Lines 2+: text
      final text = _stripHtmlTags(lines.sublist(2).join('\n'));
      if (text.isEmpty) continue;

      cues.add(AVSubtitleCue(
        startTime: timestamps.$1,
        endTime: timestamps.$2,
        text: text,
      ));
    }

    cues.sort((a, b) => a.startTime.compareTo(b.startTime));
    return cues;
  }

  /// Parses WebVTT subtitle content into a list of cues.
  static List<AVSubtitleCue> parseWebVtt(String content) {
    final normalized = _normalize(content);

    // Must start with WEBVTT header
    if (!normalized.startsWith('WEBVTT')) return [];

    final blocks = normalized.split(RegExp(r'\n\n+'));
    final cues = <AVSubtitleCue>[];

    for (final block in blocks) {
      final lines = block.trim().split('\n');

      // Skip WEBVTT header, STYLE, NOTE blocks
      if (lines[0].startsWith('WEBVTT') ||
          lines[0].startsWith('STYLE') ||
          lines[0].startsWith('NOTE')) {
        continue;
      }

      // Find the timestamp line
      int timestampLine = -1;
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].contains('-->')) {
          timestampLine = i;
          break;
        }
      }
      if (timestampLine < 0 || timestampLine + 1 >= lines.length) continue;

      final timestamps = _parseWebVttTimestamps(lines[timestampLine]);
      if (timestamps == null) continue;

      final text = _stripHtmlTags(lines.sublist(timestampLine + 1).join('\n'));
      if (text.isEmpty) continue;

      cues.add(AVSubtitleCue(
        startTime: timestamps.$1,
        endTime: timestamps.$2,
        text: text,
      ));
    }

    cues.sort((a, b) => a.startTime.compareTo(b.startTime));
    return cues;
  }

  /// Auto-detects format and parses. Returns SRT if no WEBVTT header found.
  static List<AVSubtitleCue> parse(String content) {
    final trimmed = _normalize(content).trimLeft();
    if (trimmed.startsWith('WEBVTT')) {
      return parseWebVtt(content);
    }
    return parseSrt(content);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Normalizes line endings and strips BOM.
  static String _normalize(String content) {
    var result = content;
    // Strip BOM
    if (result.isNotEmpty && result.codeUnitAt(0) == 0xFEFF) {
      result = result.substring(1);
    }
    // Normalize line endings
    return result.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  }

  /// Strips HTML tags like `<b>`, `<i>`, `<u>`, `<font>`, etc.
  static String _stripHtmlTags(String text) {
    return text.replaceAll(RegExp(r'<[^>]+>'), '').trim();
  }

  /// Parses SRT timestamp line: `HH:MM:SS,mmm --> HH:MM:SS,mmm`
  static (Duration, Duration)? _parseSrtTimestamps(String line) {
    final parts = line.split('-->');
    if (parts.length != 2) return null;
    final start = _parseSrtTime(parts[0].trim());
    final end = _parseSrtTime(parts[1].trim());
    if (start == null || end == null) return null;
    return (start, end);
  }

  /// Parses SRT time: `HH:MM:SS,mmm`
  static Duration? _parseSrtTime(String time) {
    // Support both HH:MM:SS,mmm and HH:MM:SS.mmm
    final match =
        RegExp(r'(\d{1,2}):(\d{2}):(\d{2})[,.](\d{3})').firstMatch(time);
    if (match == null) return null;
    return Duration(
      hours: int.parse(match.group(1)!),
      minutes: int.parse(match.group(2)!),
      seconds: int.parse(match.group(3)!),
      milliseconds: int.parse(match.group(4)!),
    );
  }

  /// Parses WebVTT timestamp line: `HH:MM:SS.mmm --> HH:MM:SS.mmm`
  /// (with optional positioning settings after the end time)
  static (Duration, Duration)? _parseWebVttTimestamps(String line) {
    final parts = line.split('-->');
    if (parts.length != 2) return null;
    final start = _parseWebVttTime(parts[0].trim());
    // End time may have positioning settings after it
    final endPart = parts[1].trim().split(RegExp(r'\s+')).first;
    final end = _parseWebVttTime(endPart);
    if (start == null || end == null) return null;
    return (start, end);
  }

  /// Parses WebVTT time: `HH:MM:SS.mmm` or `MM:SS.mmm`
  static Duration? _parseWebVttTime(String time) {
    // Full format: HH:MM:SS.mmm
    final fullMatch =
        RegExp(r'(\d{1,2}):(\d{2}):(\d{2})\.(\d{3})').firstMatch(time);
    if (fullMatch != null) {
      return Duration(
        hours: int.parse(fullMatch.group(1)!),
        minutes: int.parse(fullMatch.group(2)!),
        seconds: int.parse(fullMatch.group(3)!),
        milliseconds: int.parse(fullMatch.group(4)!),
      );
    }
    // Short format: MM:SS.mmm
    final shortMatch = RegExp(r'(\d{2}):(\d{2})\.(\d{3})').firstMatch(time);
    if (shortMatch != null) {
      return Duration(
        minutes: int.parse(shortMatch.group(1)!),
        seconds: int.parse(shortMatch.group(2)!),
        milliseconds: int.parse(shortMatch.group(3)!),
      );
    }
    return null;
  }
}
