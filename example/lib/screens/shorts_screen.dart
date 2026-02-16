import 'package:av_player/av_player.dart';
import 'package:flutter/material.dart';

const _shorts = [
  (
    url: 'https://download.blender.org/durian/trailer/sintel_trailer-480p.mp4',
    author: '@action_clips',
    description: 'For Bigger Blazes 🔥',
    soundName: 'Original Sound - action_clips',
    likes: 45200,
    comments: 1320,
  ),
  (
    url: 'https://www.w3schools.com/html/mov_bbb.mp4',
    author: '@adventure_co',
    description: 'The great escape begins here',
    soundName: 'Epic Adventure - SoundLib',
    likes: 128900,
    comments: 4510,
  ),
  (
    url: 'https://samplelib.com/lib/preview/mp4/sample-15s.mp4',
    author: '@fun_factory',
    description: 'When the fun never stops 🎉',
    soundName: 'Party Time - fun_factory',
    likes: 87600,
    comments: 2890,
  ),
  (
    url: 'https://samplelib.com/lib/preview/mp4/sample-20s.mp4',
    author: '@speed_demons',
    description: 'Hold on tight for this joyride',
    soundName: 'Adrenaline Rush - BeatDrop',
    likes: 234100,
    comments: 8920,
  ),
  (
    url: 'https://samplelib.com/lib/preview/mp4/sample-30s.mp4',
    author: '@drama_central',
    description: 'Total meltdown in 3... 2... 1...',
    soundName: 'Oh No - drama_central',
    likes: 56300,
    comments: 1780,
  ),
];

class ShortsScreen extends StatefulWidget {
  const ShortsScreen({super.key});

  @override
  State<ShortsScreen> createState() => _ShortsScreenState();
}

class _ShortsScreenState extends State<ShortsScreen> {
  final Map<int, AVPlayerController> _controllers = {};
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _ensureController(0);
  }

  AVPlayerController _ensureController(int index) {
    if (_controllers.containsKey(index)) return _controllers[index]!;
    final controller = AVPlayerController(
      AVVideoSource.network(_shorts[index].url),
    );
    controller.initialize().then((_) {
      controller.setLooping(true);
      if (index == _currentPage) controller.play();
    });
    _controllers[index] = controller;
    return controller;
  }

  void _onPageChanged(int index) {
    _controllers[_currentPage]?.pause();
    _currentPage = index;

    // Ensure controllers for current ±1
    _ensureController(index);
    if (index > 0) _ensureController(index - 1);
    if (index < _shorts.length - 1) _ensureController(index + 1);

    // Dispose controllers outside ±1
    final toRemove = <int>[];
    for (final key in _controllers.keys) {
      if ((key - index).abs() > 1) toRemove.add(key);
    }
    for (final key in toRemove) {
      _controllers[key]!.dispose();
      _controllers.remove(key);
    }

    _controllers[index]!.play();
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Shorts'),
      ),
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        itemCount: _shorts.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final short = _shorts[index];
          final controller = _ensureController(index);
          return Stack(
            fit: StackFit.expand,
            children: [
              // Video fills the page
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: 1080,
                  height: 1920,
                  child: AVVideoPlayer.short(controller),
                ),
              ),
              // Right-side action column
              Positioned(
                right: 12,
                bottom: 120,
                child: Column(
                  children: [
                    _ActionButton(
                      icon: Icons.favorite,
                      label: _formatCount(short.likes),
                      color: Colors.red,
                    ),
                    const SizedBox(height: 20),
                    _ActionButton(
                      icon: Icons.comment,
                      label: _formatCount(short.comments),
                    ),
                    const SizedBox(height: 20),
                    const _ActionButton(
                      icon: Icons.share,
                      label: 'Share',
                    ),
                  ],
                ),
              ),
              // Bottom overlay: author, description, sound
              Positioned(
                left: 12,
                right: 72,
                bottom: 32,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      short.author,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      short.description,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.music_note,
                            color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            short.soundName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color ?? Colors.white, size: 32),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    );
  }
}
