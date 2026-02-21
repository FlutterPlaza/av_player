import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Theme data
// ---------------------------------------------------------------------------

/// Visual customization for all AV player widgets.
///
/// Controls the colors, text styles, and slider appearance used by
/// [AVControls], [AVGestures], and [AVPipOverlay].
///
/// Provide an [AVPlayerTheme] ancestor to customize the look:
///
/// ```dart
/// AVPlayerTheme(
///   data: AVPlayerThemeData(
///     accentColor: Colors.red,
///     iconColor: Colors.white,
///   ),
///   child: AVVideoPlayer(controller, showControls: true),
/// )
/// ```
@immutable
class AVPlayerThemeData {
  const AVPlayerThemeData({
    this.overlayColor = const Color(0x61000000),
    this.iconColor = Colors.white,
    this.secondaryColor = const Color(0xB3FFFFFF),
    this.accentColor = Colors.blue,
    this.sliderActiveColor = Colors.white,
    this.sliderInactiveColor = const Color(0x3DFFFFFF),
    this.sliderBufferColor = const Color(0x62FFFFFF),
    this.sliderThumbColor = Colors.white,
    this.indicatorBackgroundColor = const Color(0x8A000000),
    this.popupMenuColor,
    this.progressBarColor = Colors.white,
    this.progressBarBackgroundColor = const Color(0x3DFFFFFF),
    this.subtitleTextColor = Colors.white,
    this.subtitleBackgroundColor = const Color(0xAA000000),
    this.subtitleFontSize = 16.0,
  });

  /// Background color of the controls overlay.
  /// Defaults to `Colors.black38`.
  final Color overlayColor;

  /// Primary icon color (play/pause, skip, fullscreen, etc.).
  /// Defaults to `Colors.white`.
  final Color iconColor;

  /// Color for less prominent elements (timestamps, secondary icons).
  /// Defaults to `Colors.white70`.
  final Color secondaryColor;

  /// Accent color for active states (active loop toggle, selected speed).
  /// Defaults to `Colors.blue`.
  final Color accentColor;

  /// Seek slider active (played) track color.
  /// Defaults to `Colors.white`.
  final Color sliderActiveColor;

  /// Seek slider inactive (remaining) track color.
  /// Defaults to `Colors.white24`.
  final Color sliderInactiveColor;

  /// Seek slider buffered track color.
  /// Defaults to `Colors.white38`.
  final Color sliderBufferColor;

  /// Seek slider thumb color.
  /// Defaults to `Colors.white`.
  final Color sliderThumbColor;

  /// Background color of gesture indicator pills (speed, volume, brightness).
  /// Defaults to `Colors.black54`.
  final Color indicatorBackgroundColor;

  /// Background color of the speed popup menu.
  /// Defaults to `Colors.grey[900]` when null.
  final Color? popupMenuColor;

  /// PIP overlay progress bar fill color.
  /// Defaults to `Colors.white`.
  final Color progressBarColor;

  /// PIP overlay progress bar background color.
  /// Defaults to `Colors.white24`.
  final Color progressBarBackgroundColor;

  /// Subtitle text color.
  /// Defaults to `Colors.white`.
  final Color subtitleTextColor;

  /// Subtitle background color.
  /// Defaults to `Color(0xAA000000)` (semi-transparent black).
  final Color subtitleBackgroundColor;

  /// Subtitle font size.
  /// Defaults to `16.0`.
  final double subtitleFontSize;

  /// Creates a copy of this theme data with the given fields replaced.
  AVPlayerThemeData copyWith({
    Color? overlayColor,
    Color? iconColor,
    Color? secondaryColor,
    Color? accentColor,
    Color? sliderActiveColor,
    Color? sliderInactiveColor,
    Color? sliderBufferColor,
    Color? sliderThumbColor,
    Color? indicatorBackgroundColor,
    Color? popupMenuColor,
    Color? progressBarColor,
    Color? progressBarBackgroundColor,
    Color? subtitleTextColor,
    Color? subtitleBackgroundColor,
    double? subtitleFontSize,
  }) {
    return AVPlayerThemeData(
      overlayColor: overlayColor ?? this.overlayColor,
      iconColor: iconColor ?? this.iconColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      accentColor: accentColor ?? this.accentColor,
      sliderActiveColor: sliderActiveColor ?? this.sliderActiveColor,
      sliderInactiveColor: sliderInactiveColor ?? this.sliderInactiveColor,
      sliderBufferColor: sliderBufferColor ?? this.sliderBufferColor,
      sliderThumbColor: sliderThumbColor ?? this.sliderThumbColor,
      indicatorBackgroundColor:
          indicatorBackgroundColor ?? this.indicatorBackgroundColor,
      popupMenuColor: popupMenuColor ?? this.popupMenuColor,
      progressBarColor: progressBarColor ?? this.progressBarColor,
      progressBarBackgroundColor:
          progressBarBackgroundColor ?? this.progressBarBackgroundColor,
      subtitleTextColor: subtitleTextColor ?? this.subtitleTextColor,
      subtitleBackgroundColor:
          subtitleBackgroundColor ?? this.subtitleBackgroundColor,
      subtitleFontSize: subtitleFontSize ?? this.subtitleFontSize,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AVPlayerThemeData &&
        other.overlayColor == overlayColor &&
        other.iconColor == iconColor &&
        other.secondaryColor == secondaryColor &&
        other.accentColor == accentColor &&
        other.sliderActiveColor == sliderActiveColor &&
        other.sliderInactiveColor == sliderInactiveColor &&
        other.sliderBufferColor == sliderBufferColor &&
        other.sliderThumbColor == sliderThumbColor &&
        other.indicatorBackgroundColor == indicatorBackgroundColor &&
        other.popupMenuColor == popupMenuColor &&
        other.progressBarColor == progressBarColor &&
        other.progressBarBackgroundColor == progressBarBackgroundColor &&
        other.subtitleTextColor == subtitleTextColor &&
        other.subtitleBackgroundColor == subtitleBackgroundColor &&
        other.subtitleFontSize == subtitleFontSize;
  }

  @override
  int get hashCode => Object.hash(
        overlayColor,
        iconColor,
        secondaryColor,
        accentColor,
        sliderActiveColor,
        sliderInactiveColor,
        sliderBufferColor,
        sliderThumbColor,
        indicatorBackgroundColor,
        popupMenuColor,
        progressBarColor,
        progressBarBackgroundColor,
        subtitleTextColor,
        subtitleBackgroundColor,
        subtitleFontSize,
      );
}

// ---------------------------------------------------------------------------
// InheritedWidget
// ---------------------------------------------------------------------------

/// Provides [AVPlayerThemeData] to descendant AV player widgets.
///
/// Wrap your player widget tree with [AVPlayerTheme] to customize colors:
///
/// ```dart
/// AVPlayerTheme(
///   data: AVPlayerThemeData(accentColor: Colors.red),
///   child: AVVideoPlayer(controller, showControls: true),
/// )
/// ```
class AVPlayerTheme extends InheritedWidget {
  const AVPlayerTheme({
    super.key,
    required this.data,
    required super.child,
  });

  /// The theme data for this subtree.
  final AVPlayerThemeData data;

  /// Returns the nearest [AVPlayerThemeData], or null if none exists.
  static AVPlayerThemeData? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AVPlayerTheme>()?.data;
  }

  /// Returns the nearest [AVPlayerThemeData], or defaults if none exists.
  static AVPlayerThemeData of(BuildContext context) {
    return maybeOf(context) ?? const AVPlayerThemeData();
  }

  @override
  bool updateShouldNotify(AVPlayerTheme oldWidget) => data != oldWidget.data;
}
