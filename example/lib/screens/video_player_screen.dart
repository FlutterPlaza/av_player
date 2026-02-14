import 'package:av_player/av_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({super.key});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final AVPlayerController _controller;
  bool _isFullscreen = false;

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
    if (_isFullscreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: ValueListenableBuilder<AVPlayerState>(
          valueListenable: _controller,
          builder: (context, state, _) {
            return Center(
              child: AspectRatio(
                aspectRatio: state.aspectRatio,
                child: AVVideoPlayer.video(
                  _controller,
                  title: 'Bee Video',
                  onFullscreen: _exitFullscreen,
                ),
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Video Player')),
      body: ValueListenableBuilder<AVPlayerState>(
        valueListenable: _controller,
        builder: (context, state, _) {
          return Column(
            children: [
              AspectRatio(
                aspectRatio: state.aspectRatio,
                child: AVVideoPlayer.video(
                  _controller,
                  title: 'Bee Video',
                  onFullscreen: _enterFullscreen,
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'The .video() preset enables all controls: play/pause, '
                  'seek, skip, speed, loop, PIP, and fullscreen. '
                  'Gestures include double-tap to skip, long-press for 2x speed, '
                  'and vertical swipes for volume/brightness.',
                  style: TextStyle(color: Colors.white60),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _enterFullscreen() {
    setState(() => _isFullscreen = true);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void _exitFullscreen() {
    setState(() => _isFullscreen = false);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  @override
  void dispose() {
    _controller.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }
}
