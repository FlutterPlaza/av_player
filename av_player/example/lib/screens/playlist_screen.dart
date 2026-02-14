import 'package:av_player/av_player.dart';
import 'package:flutter/material.dart';

class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  late AVPlayerController _controller;
  late final AVPlaylistController _playlist;

  static const _sources = [
    AVVideoSource.network(
      'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
    ),
    AVVideoSource.network(
      'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
    ),
    AVVideoSource.network(
      'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
    ),
  ];

  static const _titles = ['Track 1 — Bee', 'Track 2 — Bee', 'Track 3 — Bee'];

  @override
  void initState() {
    super.initState();
    _playlist = AVPlaylistController(
      sources: _sources,
      onSourceChanged: _onSourceChanged,
    );
    _controller = _createController(_sources.first);
  }

  AVPlayerController _createController(AVVideoSource source) {
    return AVPlayerController(source)
      ..initialize().then((_) {
        if (mounted) setState(() {});
      });
  }

  void _onSourceChanged(AVVideoSource source) {
    _controller.dispose();
    _controller = _createController(source);
    _controller.addListener(() {
      if (_controller.value.isCompleted) {
        _playlist.onTrackCompleted();
      }
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Playlist')),
      body: Column(
        children: [
          ValueListenableBuilder<AVPlayerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              return AspectRatio(
                aspectRatio: state.aspectRatio,
                child: AVVideoPlayer.video(
                  _controller,
                  title: _titles[_playlist.value.currentIndex
                      .clamp(0, _titles.length - 1)],
                  onNext:
                      _playlist.value.hasNext ? () => _playlist.next() : null,
                  onPrevious: _playlist.value.hasPrevious
                      ? () => _playlist.previous()
                      : null,
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          // Playlist controls
          ValueListenableBuilder<AVPlaylistState>(
            valueListenable: _playlist,
            builder: (context, plState, _) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        plState.isShuffled
                            ? Icons.shuffle_on_outlined
                            : Icons.shuffle,
                      ),
                      onPressed: () =>
                          _playlist.setShuffle(!plState.isShuffled),
                    ),
                    IconButton(
                      icon: Icon(_repeatIcon(plState.repeatMode)),
                      onPressed: () {
                        final modes = AVRepeatMode.values;
                        final next = modes[
                            (plState.repeatMode.index + 1) % modes.length];
                        _playlist.setRepeatMode(next);
                      },
                    ),
                    const Spacer(),
                    Text(
                      'Track ${plState.currentIndex + 1} of ${plState.queue.length}',
                      style: const TextStyle(color: Colors.white60),
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(),
          // Queue list
          Expanded(
            child: ValueListenableBuilder<AVPlaylistState>(
              valueListenable: _playlist,
              builder: (context, plState, _) {
                return ListView.builder(
                  itemCount: plState.queue.length,
                  itemBuilder: (context, index) {
                    final isCurrent = index == plState.currentIndex;
                    return ListTile(
                      leading: Icon(
                        isCurrent ? Icons.play_arrow : Icons.music_note,
                        color: isCurrent
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      title: Text(
                        _titles[index],
                        style: TextStyle(
                          fontWeight:
                              isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: isCurrent
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                      ),
                      onTap: () => _playlist.jumpTo(index),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _repeatIcon(AVRepeatMode mode) {
    switch (mode) {
      case AVRepeatMode.none:
        return Icons.repeat;
      case AVRepeatMode.one:
        return Icons.repeat_one;
      case AVRepeatMode.all:
        return Icons.repeat_on_outlined;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _playlist.dispose();
    super.dispose();
  }
}
