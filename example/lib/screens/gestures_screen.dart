import 'package:av_player/av_player.dart';
import 'package:flutter/material.dart';

const _gestures = [
  (
    icon: Icons.touch_app,
    title: 'Tap',
    description: 'Show or hide the controls overlay',
  ),
  (
    icon: Icons.fast_forward,
    title: 'Double-tap right',
    description: 'Skip forward 10 seconds',
  ),
  (
    icon: Icons.fast_rewind,
    title: 'Double-tap left',
    description: 'Skip backward 10 seconds',
  ),
  (
    icon: Icons.speed,
    title: 'Long press',
    description: 'Play at 2x speed while held',
  ),
  (
    icon: Icons.volume_up,
    title: 'Swipe up/down (right)',
    description: 'Adjust volume',
  ),
  (
    icon: Icons.brightness_6,
    title: 'Swipe up/down (left)',
    description: 'Adjust brightness',
  ),
  (
    icon: Icons.swipe,
    title: 'Swipe left/right',
    description: 'Seek through the video',
  ),
];

class GesturesScreen extends StatefulWidget {
  const GesturesScreen({super.key});

  @override
  State<GesturesScreen> createState() => _GesturesScreenState();
}

class _GesturesScreenState extends State<GesturesScreen> {
  late final AVPlayerController _controller;
  String _lastGesture = 'None yet — try a gesture!';
  final Set<int> _triedGestures = {};

  @override
  void initState() {
    super.initState();
    _controller = AVPlayerController(
      const AVVideoSource.network(
        'https://download.blender.org/durian/trailer/sintel_trailer-480p.mp4',
      ),
    )..initialize().then((_) {
        _controller.play();
      });
    _controller.addListener(_detectGestures);
  }

  Duration? _prevPosition;
  bool _wasPlaying = false;
  double _prevSpeed = 1.0;

  void _detectGestures() {
    final state = _controller.value;
    if (!state.isInitialized) return;

    // Detect speed change (long press)
    if (state.playbackSpeed != _prevSpeed) {
      if (state.playbackSpeed > 1.0) {
        _recordGesture(3, 'Long press → ${state.playbackSpeed}x speed');
      }
      _prevSpeed = state.playbackSpeed;
    }

    // Detect seek (double-tap or horizontal swipe)
    if (_prevPosition != null) {
      final diff =
          state.position.inMilliseconds - _prevPosition!.inMilliseconds;
      if (diff.abs() > 3000 && state.isPlaying) {
        if (diff > 0) {
          if (diff >= 9000 && diff <= 11000) {
            _recordGesture(1, 'Double-tap right → +10s');
          } else {
            _recordGesture(6, 'Swipe right → seek forward');
          }
        } else {
          if (diff >= -11000 && diff <= -9000) {
            _recordGesture(2, 'Double-tap left → -10s');
          } else {
            _recordGesture(6, 'Swipe left → seek backward');
          }
        }
      }
    }
    _prevPosition = state.position;

    // Detect play/pause toggle (tap)
    if (state.isPlaying != _wasPlaying) {
      _recordGesture(0, state.isPlaying ? 'Tap → Play' : 'Tap → Pause');
      _wasPlaying = state.isPlaying;
    }
  }

  void _recordGesture(int index, String label) {
    if (!mounted) return;
    setState(() {
      _lastGesture = label;
      _triedGestures.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gesture Controls')),
      body: Column(
        children: [
          ValueListenableBuilder<AVPlayerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              return AspectRatio(
                aspectRatio: state.aspectRatio,
                child: AVVideoPlayer(
                  _controller,
                  showControls: true,
                  gestureConfig: const AVGestureConfig(
                    doubleTapToSeek: true,
                    swipeToVolume: true,
                    swipeToBrightness: true,
                    longPressSpeed: true,
                    horizontalSwipeToSeek: true,
                  ),
                  title: 'Big Buck Bunny',
                ),
              );
            },
          ),
          // Last gesture banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Row(
              children: [
                Icon(
                  Icons.gesture,
                  size: 18,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _lastGesture,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  '${_triedGestures.length}/${_gestures.length}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _gestures.length,
              itemBuilder: (context, index) {
                final g = _gestures[index];
                final tried = _triedGestures.contains(index);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(g.icon, size: 28, color: Colors.white54),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              g.title,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              g.description,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (tried)
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 22,
                        )
                      else
                        const Icon(
                          Icons.radio_button_unchecked,
                          color: Colors.white24,
                          size: 22,
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_detectGestures);
    _controller.dispose();
    super.dispose();
  }
}
