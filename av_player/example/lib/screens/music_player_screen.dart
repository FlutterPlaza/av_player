import 'package:av_player/av_player.dart';
import 'package:flutter/material.dart';

class MusicPlayerScreen extends StatefulWidget {
  const MusicPlayerScreen({super.key});

  @override
  State<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen> {
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
      appBar: AppBar(title: const Text('Music Player')),
      body: Column(
        children: [
          ValueListenableBuilder<AVPlayerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              return AspectRatio(
                aspectRatio: state.aspectRatio,
                child: AVVideoPlayer.music(
                  _controller,
                  title: 'Bee Audio',
                  onNext: () => debugPrint('Next track'),
                  onPrevious: () => debugPrint('Previous track'),
                ),
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'The .music() preset shows play/pause, skip next/previous, '
              'speed control, and loop toggle. PIP and fullscreen are '
              'disabled since this is meant for audio content.',
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
