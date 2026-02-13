import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../av_video_player.dart';
import 'av_theme.dart';

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

/// Configuration for [AVGestures].
class AVGestureConfig {
  const AVGestureConfig({
    this.doubleTapToSeek = true,
    this.seekDuration = const Duration(seconds: 10),
    this.swipeToVolume = true,
    this.swipeToBrightness = true,
    this.longPressSpeed = true,
    this.longPressSpeedMultiplier = 2.0,
    this.horizontalSwipeToSeek = false,
  });

  /// Whether double-tapping the left/right side skips backward/forward.
  final bool doubleTapToSeek;

  /// Duration to skip on double-tap.
  final Duration seekDuration;

  /// Whether vertical swipe on the right side adjusts volume.
  final bool swipeToVolume;

  /// Whether vertical swipe on the left side adjusts brightness.
  final bool swipeToBrightness;

  /// Whether long-pressing plays at [longPressSpeedMultiplier] speed.
  final bool longPressSpeed;

  /// Playback speed while long-pressing. Defaults to 2x.
  final double longPressSpeedMultiplier;

  /// Whether horizontal swipe seeks through the video.
  final bool horizontalSwipeToSeek;
}

// ---------------------------------------------------------------------------
// Gesture widget
// ---------------------------------------------------------------------------

/// Detects gestures over a video player and routes them to the controller.
///
/// Place this in a [Stack] on top of the video:
///
/// ```dart
/// Stack(
///   children: [
///     AVVideoPlayer(controller),
///     AVGestures(
///       controller: controller,
///       onTap: () => controlsVisible.toggle(),
///       child: const SizedBox.expand(),
///     ),
///   ],
/// )
/// ```
class AVGestures extends StatefulWidget {
  const AVGestures({
    super.key,
    required this.controller,
    this.config = const AVGestureConfig(),
    this.onTap,
    this.child,
  });

  /// The player controller to send commands to.
  final AVPlayerController controller;

  /// Gesture configuration.
  final AVGestureConfig config;

  /// Called on single tap. Typically toggles controls visibility.
  final VoidCallback? onTap;

  /// Optional child widget to render underneath the gesture detector.
  final Widget? child;

  @override
  State<AVGestures> createState() => _AVGesturesState();
}

class _AVGesturesState extends State<AVGestures> {
  // Double-tap animation state
  _DoubleTapSide? _doubleTapSide;
  int _doubleTapCount = 0;
  Timer? _doubleTapResetTimer;

  // Long-press state
  double? _speedBeforeLongPress;
  bool _isLongPressing = false;

  // Swipe state
  double? _swipeStartValue;
  bool _isSwiping = false;
  _SwipeDirection? _swipeDirection;

  AVGestureConfig get _config => widget.config;

  @override
  Widget build(BuildContext context) {
    final theme = AVPlayerTheme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // Gesture detector covering the full area
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: widget.onTap,
              onDoubleTapDown: _config.doubleTapToSeek
                  ? (details) => _onDoubleTapDown(details, constraints)
                  : null,
              onDoubleTap:
                  _config.doubleTapToSeek ? () => _onDoubleTap() : null,
              onLongPressStart:
                  _config.longPressSpeed ? _onLongPressStart : null,
              onLongPressEnd:
                  _config.longPressSpeed ? _onLongPressEnd : null,
              onVerticalDragStart:
                  (_config.swipeToVolume || _config.swipeToBrightness)
                      ? (d) => _onVerticalDragStart(d, constraints)
                      : null,
              onVerticalDragUpdate:
                  (_config.swipeToVolume || _config.swipeToBrightness)
                      ? _onVerticalDragUpdate
                      : null,
              onVerticalDragEnd:
                  (_config.swipeToVolume || _config.swipeToBrightness)
                      ? _onVerticalDragEnd
                      : null,
              child: widget.child ?? const SizedBox.expand(),
            ),

            // Double-tap ripple animation
            if (_doubleTapSide != null)
              Positioned(
                left: _doubleTapSide == _DoubleTapSide.left ? 0 : null,
                right: _doubleTapSide == _DoubleTapSide.right ? 0 : null,
                top: 0,
                bottom: 0,
                width: constraints.maxWidth / 2,
                child: _DoubleTapRipple(
                  key: ValueKey('${_doubleTapSide}_$_doubleTapCount'),
                  side: _doubleTapSide!,
                  seconds: _config.seekDuration.inSeconds * _doubleTapCount,
                  iconColor: theme.iconColor,
                ),
              ),

            // Long-press speed indicator
            if (_isLongPressing)
              Positioned(
                top: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.indicatorBackgroundColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${_config.longPressSpeedMultiplier}x',
                      style: TextStyle(
                        color: theme.iconColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

            // Swipe indicator
            if (_isSwiping && _swipeDirection != null)
              Positioned(
                top: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: _SwipeIndicator(
                    direction: _swipeDirection!,
                    iconColor: theme.iconColor,
                    backgroundColor: theme.indicatorBackgroundColor,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // Double-tap to skip
  // -------------------------------------------------------------------------

  Offset? _doubleTapPosition;

  void _onDoubleTapDown(TapDownDetails details, BoxConstraints constraints) {
    _doubleTapPosition = details.localPosition;
  }

  void _onDoubleTap() {
    if (_doubleTapPosition == null) return;
    final state = widget.controller.value;
    final constraints = context.size;
    if (constraints == null) return;

    final isLeftSide = _doubleTapPosition!.dx < constraints.width / 2;
    final side =
        isLeftSide ? _DoubleTapSide.left : _DoubleTapSide.right;

    // Accumulate consecutive double-taps on the same side
    if (side == _doubleTapSide) {
      _doubleTapCount++;
    } else {
      _doubleTapCount = 1;
    }

    final delta = isLeftSide ? -_config.seekDuration : _config.seekDuration;
    final newPos = state.position + delta;
    widget.controller.seekTo(
      newPos < Duration.zero
          ? Duration.zero
          : newPos > state.duration
              ? state.duration
              : newPos,
    );

    setState(() => _doubleTapSide = side);

    _doubleTapResetTimer?.cancel();
    _doubleTapResetTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _doubleTapSide = null;
          _doubleTapCount = 0;
        });
      }
    });
  }

  // -------------------------------------------------------------------------
  // Long-press for speed
  // -------------------------------------------------------------------------

  void _onLongPressStart(LongPressStartDetails details) {
    _speedBeforeLongPress = widget.controller.value.playbackSpeed;
    widget.controller.setPlaybackSpeed(_config.longPressSpeedMultiplier);
    HapticFeedback.mediumImpact();
    setState(() => _isLongPressing = true);
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (_speedBeforeLongPress != null) {
      widget.controller.setPlaybackSpeed(_speedBeforeLongPress!);
      _speedBeforeLongPress = null;
    }
    setState(() => _isLongPressing = false);
  }

  // -------------------------------------------------------------------------
  // Vertical swipe for volume / brightness
  // -------------------------------------------------------------------------

  void _onVerticalDragStart(
    DragStartDetails details,
    BoxConstraints constraints,
  ) {
    final isRightSide =
        details.localPosition.dx > constraints.maxWidth / 2;
    if (isRightSide && _config.swipeToVolume) {
      _swipeDirection = _SwipeDirection.volume;
      widget.controller.getSystemVolume().then((v) => _swipeStartValue = v);
    } else if (!isRightSide && _config.swipeToBrightness) {
      _swipeDirection = _SwipeDirection.brightness;
      widget.controller
          .getScreenBrightness()
          .then((b) => _swipeStartValue = b);
    } else {
      _swipeDirection = null;
    }
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_swipeDirection == null || _swipeStartValue == null) return;
    setState(() => _isSwiping = true);

    // Swipe up increases, swipe down decreases
    // Scale: full height swipe = full range change (0.0 to 1.0)
    final screenHeight = MediaQuery.sizeOf(context).height;
    final delta = -details.delta.dy / screenHeight;
    final newValue = (_swipeStartValue! + delta).clamp(0.0, 1.0);
    _swipeStartValue = newValue;

    switch (_swipeDirection!) {
      case _SwipeDirection.volume:
        widget.controller.setSystemVolume(newValue);
      case _SwipeDirection.brightness:
        widget.controller.setScreenBrightness(newValue);
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    _swipeStartValue = null;
    _swipeDirection = null;
    setState(() => _isSwiping = false);
  }

  @override
  void dispose() {
    _doubleTapResetTimer?.cancel();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Double-tap enums and ripple
// ---------------------------------------------------------------------------

enum _DoubleTapSide { left, right }

enum _SwipeDirection { volume, brightness }

class _DoubleTapRipple extends StatefulWidget {
  const _DoubleTapRipple({
    super.key,
    required this.side,
    required this.seconds,
    this.iconColor = Colors.white,
  });

  final _DoubleTapSide side;
  final int seconds;
  final Color iconColor;

  @override
  State<_DoubleTapRipple> createState() => _DoubleTapRippleState();
}

class _DoubleTapRippleState extends State<_DoubleTapRipple>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _opacity = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    final isLeft = widget.side == _DoubleTapSide.left;
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: isLeft
                ? Alignment.centerRight
                : Alignment.centerLeft,
            radius: 0.8,
            colors: [
              widget.iconColor.withValues(alpha: 0.15),
              Colors.transparent,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isLeft ? Icons.fast_rewind : Icons.fast_forward,
                color: widget.iconColor,
                size: 36,
              ),
              const SizedBox(height: 4),
              Text(
                isLeft ? '-${widget.seconds}s' : '+${widget.seconds}s',
                style: TextStyle(
                  color: widget.iconColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Swipe indicator
// ---------------------------------------------------------------------------

class _SwipeIndicator extends StatelessWidget {
  const _SwipeIndicator({
    required this.direction,
    this.iconColor = Colors.white,
    this.backgroundColor = const Color(0x8A000000),
  });

  final _SwipeDirection direction;
  final Color iconColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final icon = direction == _SwipeDirection.volume
        ? Icons.volume_up
        : Icons.brightness_6;
    final label =
        direction == _SwipeDirection.volume ? 'Volume' : 'Brightness';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: iconColor, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
