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
        'https://download.blender.org/durian/trailer/sintel_trailer-480p.mp4'),
    AVVideoSource.network('https://www.w3schools.com/html/mov_bbb.mp4'),
    AVVideoSource.network(
        'https://samplelib.com/lib/preview/mp4/sample-15s.mp4'),
    AVVideoSource.network(
        'https://samplelib.com/lib/preview/mp4/sample-20s.mp4'),
    AVVideoSource.network(
        'https://samplelib.com/lib/preview/mp4/sample-30s.mp4'),
  ];

  static const _titles = [
    'Big Buck Bunny',
    "Elephant's Dream",
    'Sintel',
    'Tears of Steel',
    'For Bigger Fun',
  ];

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
    final controller = AVPlayerController(source);
    controller.initialize().then((_) {
      if (mounted) {
        controller.play();
        setState(() {});
      }
    });
    controller.addListener(() {
      if (controller.value.isCompleted) {
        _playlist.onTrackCompleted();
      }
    });
    return controller;
  }

  void _onSourceChanged(AVVideoSource source) {
    final old = _controller;
    _controller = _createController(source);
    setState(() {});
    // Defer disposal so it doesn't happen during notifyListeners().
    Future.microtask(() => old.dispose());
  }

  String _repeatLabel(AVRepeatMode mode) {
    switch (mode) {
      case AVRepeatMode.none:
        return 'Repeat: Off';
      case AVRepeatMode.one:
        return 'Repeat: One';
      case AVRepeatMode.all:
        return 'Repeat: All';
    }
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
                    const SizedBox(width: 4),
                    Text(
                      _repeatLabel(plState.repeatMode),
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 12),
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
                      leading: SizedBox(
                        width: 32,
                        child: Center(
                          child: isCurrent
                              ? Icon(
                                  Icons.equalizer,
                                  color: Theme.of(context).colorScheme.primary,
                                )
                              : Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
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
                      subtitle: isCurrent
                          ? Text(
                              'Now Playing',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 12,
                              ),
                            )
                          : null,
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
