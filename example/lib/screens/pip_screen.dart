import 'package:av_player/av_player.dart';
import 'package:flutter/material.dart';

class PipScreen extends StatefulWidget {
  const PipScreen({super.key});

  @override
  State<PipScreen> createState() => _PipScreenState();
}

class _PipScreenState extends State<PipScreen> {
  late final AVPlayerController _controller;
  bool _showInAppPip = false;

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
      appBar: AppBar(title: const Text('Picture-in-Picture')),
      body: Stack(
        children: [
          Column(
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
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.picture_in_picture_alt, size: 18),
                      label: const Text('Native PIP'),
                      onPressed: () => _controller.enterPip(),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      icon: const Icon(Icons.picture_in_picture, size: 18),
                      label: const Text('In-App PIP Overlay'),
                      onPressed: () => setState(() => _showInAppPip = true),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Native PIP uses the OS-level picture-in-picture window. '
                      'In-App PIP shows a draggable floating mini-player overlay '
                      'within the app.',
                      style: TextStyle(color: Colors.white60),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_showInAppPip)
            AVPipOverlay(
              controller: _controller,
              onClose: () => setState(() => _showInAppPip = false),
              onExpand: () => setState(() => _showInAppPip = false),
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
