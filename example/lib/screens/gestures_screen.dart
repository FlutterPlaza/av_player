import 'package:av_player/av_player.dart';
import 'package:flutter/material.dart';

class GesturesScreen extends StatefulWidget {
  const GesturesScreen({super.key});

  @override
  State<GesturesScreen> createState() => _GesturesScreenState();
}

class _GesturesScreenState extends State<GesturesScreen> {
  late final AVPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AVPlayerController(
      const AVVideoSource.network(
        'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
      ),
    )..initialize();
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
                child: AVVideoPlayer.video(_controller, title: 'Bee Video'),
              );
            },
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                _GestureRow(
                  icon: Icons.touch_app,
                  title: 'Tap',
                  description: 'Show or hide the controls overlay',
                ),
                _GestureRow(
                  icon: Icons.fast_forward,
                  title: 'Double-tap right',
                  description: 'Skip forward 10 seconds',
                ),
                _GestureRow(
                  icon: Icons.fast_rewind,
                  title: 'Double-tap left',
                  description: 'Skip backward 10 seconds',
                ),
                _GestureRow(
                  icon: Icons.speed,
                  title: 'Long press',
                  description: 'Play at 2x speed while held',
                ),
                _GestureRow(
                  icon: Icons.volume_up,
                  title: 'Swipe up/down (right side)',
                  description: 'Adjust volume',
                ),
                _GestureRow(
                  icon: Icons.brightness_6,
                  title: 'Swipe up/down (left side)',
                  description: 'Adjust brightness',
                ),
                _GestureRow(
                  icon: Icons.swipe,
                  title: 'Swipe left/right',
                  description: 'Seek through the video',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _GestureRow extends StatelessWidget {
  const _GestureRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 28, color: Colors.white54),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
