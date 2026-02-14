import 'package:av_player/av_player.dart';
import 'package:flutter/material.dart';

class LiveStreamScreen extends StatefulWidget {
  const LiveStreamScreen({super.key});

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen> {
  late final AVPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AVPlayerController(
      const AVVideoSource.network(
        'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
      ),
    )..initialize().then((_) => _controller.play());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Stream')),
      body: Column(
        children: [
          ValueListenableBuilder<AVPlayerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              return AspectRatio(
                aspectRatio: state.aspectRatio,
                child: AVVideoPlayer.live(
                  _controller,
                  title: 'LIVE',
                ),
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'The .live() preset disables seek bar, skip buttons, and '
              'speed control since live streams cannot be seeked. '
              'Only play/pause, PIP, and fullscreen remain.',
              style: TextStyle(color: Colors.white60),
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
