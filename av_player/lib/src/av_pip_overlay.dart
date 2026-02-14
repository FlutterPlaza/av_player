import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../av_video_player.dart';
import 'av_theme.dart';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// The size of the in-app PIP window.
enum AVPipSize {
  /// 150 logical pixels wide.
  small(150),

  /// 250 logical pixels wide.
  medium(250),

  /// 350 logical pixels wide.
  large(350);

  const AVPipSize(this.width);
  final double width;
}

/// Which corner the PIP window snaps to.
enum AVPipCorner { topLeft, topRight, bottomLeft, bottomRight }

// ---------------------------------------------------------------------------
// PIP overlay widget
// ---------------------------------------------------------------------------

/// A floating, draggable mini-player overlay for in-app Picture-in-Picture.
///
/// Place this in the top-level [Stack] of your app (e.g. above the navigator).
///
/// ```dart
/// Stack(
///   children: [
///     Navigator(...),
///     if (showPip)
///       AVPipOverlay(
///         controller: controller,
///         onClose: () => setState(() => showPip = false),
///         onExpand: () => navigateToPlayer(),
///       ),
///   ],
/// )
/// ```
class AVPipOverlay extends StatefulWidget {
  const AVPipOverlay({
    super.key,
    required this.controller,
    this.initialSize = AVPipSize.medium,
    this.initialCorner = AVPipCorner.bottomRight,
    this.margin = 16.0,
    this.onClose,
    this.onExpand,
  });

  /// The player controller driving this mini-player.
  final AVPlayerController controller;

  /// Initial size of the PIP window.
  final AVPipSize initialSize;

  /// Which corner the PIP window starts in.
  final AVPipCorner initialCorner;

  /// Margin from screen edges.
  final double margin;

  /// Called when the user closes (dismisses) the PIP window.
  final VoidCallback? onClose;

  /// Called when the user taps expand to return to the full player.
  final VoidCallback? onExpand;

  @override
  State<AVPipOverlay> createState() => _AVPipOverlayState();
}

class _AVPipOverlayState extends State<AVPipOverlay>
    with SingleTickerProviderStateMixin {
  late double _left;
  late double _top;
  late double _width;
  late double _height;
  bool _positioned = false;
  bool _showControls = false;

  late final AnimationController _snapController;
  Animation<Offset>? _snapAnimation;

  @override
  void initState() {
    super.initState();
    _width = widget.initialSize.width;
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() {
        if (_snapAnimation != null) {
          setState(() {
            _left = _snapAnimation!.value.dx;
            _top = _snapAnimation!.value.dy;
          });
        }
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_positioned) {
      _calculateInitialPosition();
    }
  }

  void _calculateInitialPosition() {
    final screen = MediaQuery.sizeOf(context);
    final state = widget.controller.value;
    _height = _width / state.aspectRatio;

    switch (widget.initialCorner) {
      case AVPipCorner.topLeft:
        _left = widget.margin;
        _top = widget.margin + MediaQuery.paddingOf(context).top;
      case AVPipCorner.topRight:
        _left = screen.width - _width - widget.margin;
        _top = widget.margin + MediaQuery.paddingOf(context).top;
      case AVPipCorner.bottomLeft:
        _left = widget.margin;
        _top = screen.height -
            _height -
            widget.margin -
            MediaQuery.paddingOf(context).bottom;
      case AVPipCorner.bottomRight:
        _left = screen.width - _width - widget.margin;
        _top = screen.height -
            _height -
            widget.margin -
            MediaQuery.paddingOf(context).bottom;
    }
    _positioned = true;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _left,
      top: _top,
      child: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: _width,
            height: _height,
            child: Stack(
              children: [
                // Video
                ValueListenableBuilder<AVPlayerState>(
                  valueListenable: widget.controller,
                  builder: (context, state, _) {
                    final textureId = widget.controller.textureId;
                    if (textureId != null && state.isInitialized) {
                      if (kIsWeb) {
                        return HtmlElementView(
                          viewType: 'com.flutterplaza.av_pip_video_$textureId',
                        );
                      }
                      return Texture(textureId: textureId);
                    }
                    return const ColoredBox(
                      color: Colors.black,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                ),

                // Mini controls overlay
                if (_showControls)
                  Container(
                    color: AVPlayerTheme.of(context).overlayColor,
                    child: _buildMiniControls(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniControls() {
    final theme = AVPlayerTheme.of(context);
    return ValueListenableBuilder<AVPlayerState>(
      valueListenable: widget.controller,
      builder: (context, state, _) {
        return Stack(
          children: [
            // Center: play/pause
            Center(
              child: IconButton(
                iconSize: 36,
                icon: Icon(
                  state.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: theme.iconColor,
                ),
                onPressed: () {
                  if (state.isPlaying) {
                    widget.controller.pause();
                  } else {
                    widget.controller.play();
                  }
                },
              ),
            ),

            // Top-right: close button
            Positioned(
              top: 2,
              right: 2,
              child: IconButton(
                iconSize: 20,
                icon: Icon(Icons.close, color: theme.secondaryColor),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: widget.onClose,
              ),
            ),

            // Top-left: expand button
            if (widget.onExpand != null)
              Positioned(
                top: 2,
                left: 2,
                child: IconButton(
                  iconSize: 20,
                  icon: Icon(
                    Icons.open_in_full,
                    color: theme.secondaryColor,
                  ),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: widget.onExpand,
                ),
              ),

            // Bottom: thin progress bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LinearProgressIndicator(
                value: state.duration.inMilliseconds > 0
                    ? (state.position.inMilliseconds /
                            state.duration.inMilliseconds)
                        .clamp(0.0, 1.0)
                    : 0.0,
                backgroundColor: theme.progressBarBackgroundColor,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.progressBarColor,
                ),
                minHeight: 3,
              ),
            ),
          ],
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // Drag handling
  // -------------------------------------------------------------------------

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _left += details.delta.dx;
      _top += details.delta.dy;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    _snapToNearestCorner();
  }

  void _snapToNearestCorner() {
    final screen = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final m = widget.margin;
    final centerX = _left + _width / 2;
    final centerY = _top + _height / 2;

    // Find nearest corner
    double targetLeft;
    double targetTop;

    if (centerX < screen.width / 2) {
      targetLeft = m;
    } else {
      targetLeft = screen.width - _width - m;
    }

    if (centerY < screen.height / 2) {
      targetTop = m + padding.top;
    } else {
      targetTop = screen.height - _height - m - padding.bottom;
    }

    _snapAnimation = Tween<Offset>(
      begin: Offset(_left, _top),
      end: Offset(targetLeft, targetTop),
    ).animate(CurvedAnimation(
      parent: _snapController,
      curve: Curves.easeOut,
    ));

    _snapController.forward(from: 0);
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }
}
