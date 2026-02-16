import 'package:av_player/av_player.dart';
import 'package:flutter/material.dart';

const _recommendedVideos = [
  (title: "Elephant's Dream", subtitle: 'Blender Foundation'),
  (title: 'Sintel', subtitle: 'Blender Foundation'),
  (title: 'Tears of Steel', subtitle: 'Blender Foundation'),
  (title: 'For Bigger Blazes', subtitle: 'Google'),
  (title: 'For Bigger Escapes', subtitle: 'Google'),
  (title: 'For Bigger Fun', subtitle: 'Google'),
];

class PipScreen extends StatefulWidget {
  const PipScreen({super.key});

  @override
  State<PipScreen> createState() => _PipScreenState();
}

class _PipScreenState extends State<PipScreen> {
  late final AVPlayerController _controller;
  bool _showInAppPip = false;
  bool _showBrowse = false;

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
  }

  void _minimizeToPip() {
    setState(() {
      _showInAppPip = true;
      _showBrowse = true;
    });
  }

  void _expandFromPip() {
    setState(() {
      _showInAppPip = false;
      _showBrowse = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Picture-in-Picture')),
      body: Stack(
        children: [
          if (_showBrowse)
            // Browse mode: recommended video grid
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Text(
                    'Recommended',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 16 / 12,
                    ),
                    itemCount: _recommendedVideos.length,
                    itemBuilder: (context, index) {
                      final video = _recommendedVideos[index];
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Container(
                                color: Colors
                                    .primaries[index % Colors.primaries.length]
                                    .withValues(alpha: 0.3),
                                child: const Center(
                                  child: Icon(
                                    Icons.play_circle_outline,
                                    size: 40,
                                    color: Colors.white54,
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    video.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    video.subtitle,
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            )
          else
            // Full player view
            Column(
              children: [
                ValueListenableBuilder<AVPlayerState>(
                  valueListenable: _controller,
                  builder: (context, state, _) {
                    return AspectRatio(
                      aspectRatio: state.aspectRatio,
                      child: AVVideoPlayer.video(
                        _controller,
                        title: 'Big Buck Bunny',
                      ),
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
                        icon:
                            const Icon(Icons.picture_in_picture_alt, size: 18),
                        label: const Text('Native PIP'),
                        onPressed: () => _controller.enterPip(),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        icon: const Icon(Icons.picture_in_picture, size: 18),
                        label: const Text('Minimize to PIP'),
                        onPressed: _minimizeToPip,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Tap "Minimize to PIP" to browse recommended videos '
                        'while your video plays in a floating overlay. '
                        'Tap the expand button on the overlay to return.',
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
              onClose: _expandFromPip,
              onExpand: _expandFromPip,
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
