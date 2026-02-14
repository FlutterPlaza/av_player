import 'dart:async';

import 'package:flutter/material.dart';

import '../av_video_player.dart';
import 'av_theme.dart';

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

/// Configuration for [AVControls].
class AVControlsConfig {
  const AVControlsConfig({
    this.showSkipButtons = true,
    this.skipDuration = const Duration(seconds: 10),
    this.showPipButton = true,
    this.showSpeedButton = true,
    this.showFullscreenButton = true,
    this.showLoopButton = true,
    this.autoHideDuration = const Duration(seconds: 3),
    this.speeds = const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
  });

  /// Whether to show the skip forward/backward buttons.
  final bool showSkipButtons;

  /// Duration to skip when the skip buttons are tapped.
  final Duration skipDuration;

  /// Whether to show the Picture-in-Picture button.
  final bool showPipButton;

  /// Whether to show the playback speed button.
  final bool showSpeedButton;

  /// Whether to show the fullscreen button.
  final bool showFullscreenButton;

  /// Whether to show the loop toggle button.
  final bool showLoopButton;

  /// How long before the controls auto-hide after interaction.
  final Duration autoHideDuration;

  /// Available playback speed options.
  final List<double> speeds;
}

// ---------------------------------------------------------------------------
// Controls widget
// ---------------------------------------------------------------------------

/// An animated controls overlay for [AVPlayerController].
///
/// Shows play/pause, seek slider with buffer indicator, timestamps,
/// skip forward/backward, speed selector, PIP, loop, and fullscreen buttons.
///
/// Tap to show/hide. Auto-hides after [AVControlsConfig.autoHideDuration].
///
/// ```dart
/// Stack(
///   children: [
///     AVVideoPlayer(controller),
///     AVControls(controller: controller),
///   ],
/// )
/// ```
class AVControls extends StatefulWidget {
  const AVControls({
    super.key,
    required this.controller,
    this.config = const AVControlsConfig(),
    this.title,
    this.onBack,
    this.onFullscreen,
    this.onNext,
    this.onPrevious,
  });

  /// The player controller to display controls for.
  final AVPlayerController controller;

  /// Controls configuration.
  final AVControlsConfig config;

  /// Optional title shown in the top bar.
  final String? title;

  /// Called when the back button in the top bar is pressed.
  final VoidCallback? onBack;

  /// Called when the fullscreen button is pressed.
  final VoidCallback? onFullscreen;

  /// Called when the next track button is pressed. Shows only when non-null.
  final VoidCallback? onNext;

  /// Called when the previous track button is pressed. Shows only when non-null.
  final VoidCallback? onPrevious;

  @override
  State<AVControls> createState() => _AVControlsState();
}

class _AVControlsState extends State<AVControls>
    with SingleTickerProviderStateMixin {
  bool _visible = true;
  Timer? _hideTimer;
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  bool _draggingSeekBar = false;
  double? _dragPosition;

  AVControlsConfig get _config => widget.config;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _startHideTimer();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_config.autoHideDuration, _hide);
  }

  void _show() {
    if (!_visible) {
      setState(() => _visible = true);
      _animationController.forward();
    }
    _startHideTimer();
  }

  void _hide() {
    if (_visible && !_draggingSeekBar) {
      _animationController.reverse().then((_) {
        if (mounted) setState(() => _visible = false);
      });
    }
  }

  void _toggle() {
    if (_visible) {
      _hideTimer?.cancel();
      _hide();
    } else {
      _show();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AVPlayerTheme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _toggle,
      child: ValueListenableBuilder<AVPlayerState>(
        valueListenable: widget.controller,
        builder: (context, state, _) {
          if (!_visible) return const SizedBox.expand();
          return FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              color: theme.overlayColor,
              child: Column(
                children: [
                  _buildTopBar(state, theme),
                  const Spacer(),
                  _buildCenterControls(state, theme),
                  const Spacer(),
                  _buildBottomBar(state, theme),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Top bar
  // -------------------------------------------------------------------------

  Widget _buildTopBar(AVPlayerState state, AVPlayerThemeData theme) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            if (widget.onBack != null)
              IconButton(
                icon: Icon(Icons.arrow_back, color: theme.iconColor),
                onPressed: widget.onBack,
              ),
            if (widget.title != null)
              Expanded(
                child: Text(
                  widget.title!,
                  style: TextStyle(
                    color: theme.iconColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              )
            else
              const Spacer(),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Center controls
  // -------------------------------------------------------------------------

  Widget _buildCenterControls(AVPlayerState state, AVPlayerThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.onPrevious != null)
          IconButton(
            iconSize: 36,
            icon: Icon(Icons.skip_previous, color: theme.iconColor),
            onPressed: () {
              widget.onPrevious?.call();
              _startHideTimer();
            },
          ),
        if (_config.showSkipButtons)
          IconButton(
            iconSize: 36,
            icon: Icon(Icons.replay_10, color: theme.iconColor),
            onPressed: () {
              _skip(state, -_config.skipDuration);
              _startHideTimer();
            },
          ),
        const SizedBox(width: 16),
        _PlayPauseButton(
          isPlaying: state.isPlaying,
          isBuffering: state.isBuffering,
          isCompleted: state.isCompleted,
          iconColor: theme.iconColor,
          onPressed: () {
            if (state.isPlaying) {
              widget.controller.pause();
            } else {
              widget.controller.play();
            }
            _startHideTimer();
          },
        ),
        const SizedBox(width: 16),
        if (_config.showSkipButtons)
          IconButton(
            iconSize: 36,
            icon: Icon(Icons.forward_10, color: theme.iconColor),
            onPressed: () {
              _skip(state, _config.skipDuration);
              _startHideTimer();
            },
          ),
        if (widget.onNext != null)
          IconButton(
            iconSize: 36,
            icon: Icon(Icons.skip_next, color: theme.iconColor),
            onPressed: () {
              widget.onNext?.call();
              _startHideTimer();
            },
          ),
      ],
    );
  }

  void _skip(AVPlayerState state, Duration delta) {
    final newPos = state.position + delta;
    if (newPos < Duration.zero) {
      widget.controller.seekTo(Duration.zero);
    } else if (newPos > state.duration) {
      widget.controller.seekTo(state.duration);
    } else {
      widget.controller.seekTo(newPos);
    }
  }

  // -------------------------------------------------------------------------
  // Bottom bar
  // -------------------------------------------------------------------------

  Widget _buildBottomBar(AVPlayerState state, AVPlayerThemeData theme) {
    final position = _dragPosition ??
        state.position.inMilliseconds.toDouble();
    final duration = state.duration.inMilliseconds.toDouble();
    final buffered = state.buffered.inMilliseconds.toDouble();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Seek slider with buffering indicator
            _buildSeekBar(position, duration, buffered, theme),
            // Timestamps + action buttons
            Row(
              children: [
                Text(
                  _formatDuration(
                    Duration(milliseconds: position.toInt()),
                  ),
                  style: TextStyle(color: theme.secondaryColor, fontSize: 12),
                ),
                Text(
                  ' / ',
                  style: TextStyle(
                    color: theme.secondaryColor.withValues(alpha: 0.54),
                    fontSize: 12,
                  ),
                ),
                Text(
                  _formatDuration(state.duration),
                  style: TextStyle(color: theme.secondaryColor, fontSize: 12),
                ),
                const Spacer(),
                if (_config.showLoopButton)
                  _SmallIconButton(
                    icon: state.isLooping ? Icons.repeat_one : Icons.repeat,
                    color: state.isLooping
                        ? theme.accentColor
                        : theme.secondaryColor,
                    onPressed: () {
                      widget.controller.setLooping(!state.isLooping);
                      _startHideTimer();
                    },
                  ),
                if (_config.showSpeedButton)
                  _SpeedButton(
                    currentSpeed: state.playbackSpeed,
                    speeds: _config.speeds,
                    accentColor: theme.accentColor,
                    iconColor: theme.iconColor,
                    secondaryColor: theme.secondaryColor,
                    popupMenuColor: theme.popupMenuColor,
                    onSpeedSelected: (speed) {
                      widget.controller.setPlaybackSpeed(speed);
                      _startHideTimer();
                    },
                  ),
                if (_config.showPipButton)
                  _SmallIconButton(
                    icon: Icons.picture_in_picture_alt,
                    color: theme.secondaryColor,
                    onPressed: () {
                      widget.controller.enterPip();
                      _startHideTimer();
                    },
                  ),
                if (_config.showFullscreenButton && widget.onFullscreen != null)
                  _SmallIconButton(
                    icon: Icons.fullscreen,
                    color: theme.secondaryColor,
                    onPressed: () {
                      widget.onFullscreen?.call();
                      _startHideTimer();
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeekBar(
    double position,
    double duration,
    double buffered,
    AVPlayerThemeData theme,
  ) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        activeTrackColor: theme.sliderActiveColor,
        inactiveTrackColor: theme.sliderInactiveColor,
        secondaryActiveTrackColor: theme.sliderBufferColor,
        thumbColor: theme.sliderThumbColor,
        overlayColor: theme.sliderInactiveColor,
      ),
      child: Slider(
        value: duration > 0 ? position.clamp(0, duration) : 0,
        secondaryTrackValue:
            duration > 0 ? buffered.clamp(0, duration) : 0,
        max: duration > 0 ? duration : 1,
        onChangeStart: (_) {
          _draggingSeekBar = true;
          _hideTimer?.cancel();
        },
        onChanged: (value) {
          setState(() => _dragPosition = value);
        },
        onChangeEnd: (value) {
          _draggingSeekBar = false;
          _dragPosition = null;
          widget.controller.seekTo(Duration(milliseconds: value.toInt()));
          _startHideTimer();
        },
      ),
    );
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Play/pause button with buffering indicator
// ---------------------------------------------------------------------------

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    required this.isPlaying,
    required this.isBuffering,
    required this.onPressed,
    this.isCompleted = false,
    this.iconColor = Colors.white,
  });

  final bool isPlaying;
  final bool isBuffering;
  final bool isCompleted;
  final VoidCallback onPressed;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    if (isBuffering) {
      return SizedBox(
        width: 56,
        height: 56,
        child: Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: iconColor,
            ),
          ),
        ),
      );
    }

    final IconData icon;
    if (isCompleted) {
      icon = Icons.replay;
    } else if (isPlaying) {
      icon = Icons.pause_circle_filled;
    } else {
      icon = Icons.play_circle_filled;
    }

    return IconButton(
      iconSize: 56,
      icon: Icon(icon, color: iconColor),
      onPressed: onPressed,
    );
  }
}

// ---------------------------------------------------------------------------
// Speed button
// ---------------------------------------------------------------------------

class _SpeedButton extends StatelessWidget {
  const _SpeedButton({
    required this.currentSpeed,
    required this.speeds,
    required this.onSpeedSelected,
    this.accentColor = Colors.blue,
    this.iconColor = Colors.white,
    this.secondaryColor = const Color(0xB3FFFFFF),
    this.popupMenuColor,
  });

  final double currentSpeed;
  final List<double> speeds;
  final ValueChanged<double> onSpeedSelected;
  final Color accentColor;
  final Color iconColor;
  final Color secondaryColor;
  final Color? popupMenuColor;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      tooltip: 'Playback speed',
      onSelected: onSpeedSelected,
      offset: const Offset(0, -200),
      color: popupMenuColor ?? Colors.grey[900],
      itemBuilder: (_) => speeds
          .map(
            (speed) => PopupMenuItem(
              value: speed,
              child: Text(
                '${speed}x',
                style: TextStyle(
                  color:
                      speed == currentSpeed ? accentColor : iconColor,
                  fontWeight: speed == currentSpeed
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
          )
          .toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Text(
          '${currentSpeed}x',
          style: TextStyle(color: secondaryColor, fontSize: 13),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small icon button
// ---------------------------------------------------------------------------

class _SmallIconButton extends StatelessWidget {
  const _SmallIconButton({
    required this.icon,
    required this.onPressed,
    this.color = Colors.white70,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      iconSize: 22,
      icon: Icon(icon, color: color),
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      onPressed: onPressed,
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _formatDuration(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) return '$hours:$minutes:$seconds';
  return '$minutes:$seconds';
}
