import 'package:flutter/material.dart';

import 'av_theme.dart';
import 'platform/types.dart';

/// Renders the active subtitle cue at the bottom of the video.
///
/// Shows nothing when [currentCue] is null. Otherwise displays the cue
/// text in a semi-transparent rounded container, centered near the bottom.
///
/// Reads subtitle styling from the nearest [AVPlayerTheme].
class AVSubtitleOverlay extends StatelessWidget {
  const AVSubtitleOverlay({
    super.key,
    required this.currentCue,
    this.bottomPadding = 16,
  });

  /// The currently active subtitle cue, or null to show nothing.
  final AVSubtitleCue? currentCue;

  /// Distance from the bottom edge.
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final cue = currentCue;
    if (cue == null) return const SizedBox.shrink();

    final theme = AVPlayerTheme.of(context);
    return Positioned(
      left: 16,
      right: 16,
      bottom: bottomPadding,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.subtitleBackgroundColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            cue.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.subtitleTextColor,
              fontSize: theme.subtitleFontSize,
              height: 1.3,
            ),
          ),
        ),
      ),
    );
  }
}
