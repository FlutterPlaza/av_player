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
  bool _descriptionExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = AVPlayerController(
      const AVVideoSource.network(
        'https://download.blender.org/durian/trailer/sintel_trailer-480p.mp4',
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
                  title: 'Big Buck Bunny',
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
          return ListView(
            children: [
              AspectRatio(
                aspectRatio: state.aspectRatio,
                child: AVVideoPlayer.video(
                  _controller,
                  title: 'Big Buck Bunny',
                  onFullscreen: _enterFullscreen,
                ),
              ),
              // Title
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  'Big Buck Bunny',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Channel row
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Blender Foundation  ·  10M views  ·  2008',
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
              // Action row
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ActionItem(icon: Icons.thumb_up_outlined, label: 'Like'),
                    _ActionItem(
                        icon: Icons.thumb_down_outlined, label: 'Dislike'),
                    _ActionItem(icon: Icons.share_outlined, label: 'Share'),
                    _ActionItem(icon: Icons.bookmark_border, label: 'Save'),
                  ],
                ),
              ),
              const Divider(height: 24),
              // Expandable description
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: () => setState(
                      () => _descriptionExpanded = !_descriptionExpanded),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Big Buck Bunny tells the story of a giant rabbit with a heart '
                        'bigger than himself. When one sunny day three bullies attempt '
                        'to harass him, something snaps and the rabbit goes on a quest '
                        'to find and punish the offenders. This short film was made '
                        'using Blender, a free and open-source 3D creation suite.',
                        maxLines: _descriptionExpanded ? null : 3,
                        overflow: _descriptionExpanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _descriptionExpanded ? 'Show less' : 'Show more',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 24),
              // Up next section
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Up next',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const ListTile(
                leading: Icon(Icons.play_circle_outline, size: 40),
                title: Text("Elephant's Dream"),
                subtitle: Text('Blender Foundation  ·  11M views'),
              ),
              const ListTile(
                leading: Icon(Icons.play_circle_outline, size: 40),
                title: Text('Sintel'),
                subtitle: Text('Blender Foundation  ·  8M views'),
              ),
              const ListTile(
                leading: Icon(Icons.play_circle_outline, size: 40),
                title: Text('Tears of Steel'),
                subtitle: Text('Blender Foundation  ·  6M views'),
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

class _ActionItem extends StatelessWidget {
  const _ActionItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
