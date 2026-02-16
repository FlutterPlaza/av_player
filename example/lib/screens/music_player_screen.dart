import 'package:av_player/av_player.dart';
import 'package:flutter/material.dart';

const _tracks = [
  (
    title: 'Sintel Trailer',
    artist: 'Blender Foundation',
    url: 'https://download.blender.org/durian/trailer/sintel_trailer-480p.mp4'
  ),
  (
    title: 'Big Buck Bunny',
    artist: 'Blender Foundation',
    url: 'https://www.w3schools.com/html/mov_bbb.mp4'
  ),
  (
    title: 'Sample Track 1',
    artist: 'SampleLib',
    url: 'https://samplelib.com/lib/preview/mp4/sample-15s.mp4'
  ),
  (
    title: 'Sample Track 2',
    artist: 'SampleLib',
    url: 'https://samplelib.com/lib/preview/mp4/sample-20s.mp4'
  ),
  (
    title: 'Sample Track 3',
    artist: 'SampleLib',
    url: 'https://samplelib.com/lib/preview/mp4/sample-30s.mp4'
  ),
];

class MusicPlayerScreen extends StatefulWidget {
  const MusicPlayerScreen({super.key});

  @override
  State<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen> {
  late AVPlayerController _controller;
  late final AVPlaylistController _playlist;

  @override
  void initState() {
    super.initState();
    _playlist = AVPlaylistController(
      sources: [
        for (final t in _tracks) AVVideoSource.network(t.url),
      ],
      onSourceChanged: _onSourceChanged,
    );
    _controller = _createController(AVVideoSource.network(_tracks.first.url));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Music Player')),
      body: ValueListenableBuilder<AVPlaylistState>(
        valueListenable: _playlist,
        builder: (context, plState, _) {
          final currentTrack =
              _tracks[plState.currentIndex.clamp(0, _tracks.length - 1)];
          return Column(
            children: [
              // Compact player
              SizedBox(
                height: 200,
                child: ValueListenableBuilder<AVPlayerState>(
                  valueListenable: _controller,
                  builder: (context, state, _) {
                    return AVVideoPlayer.music(
                      _controller,
                      title: currentTrack.title,
                      onNext: plState.hasNext ? () => _playlist.next() : null,
                      onPrevious: plState.hasPrevious
                          ? () => _playlist.previous()
                          : null,
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              // Now Playing info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Text(
                      currentTrack.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentTrack.artist,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Shuffle + repeat controls
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
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
                    const SizedBox(width: 16),
                    IconButton(
                      icon: Icon(_repeatIcon(plState.repeatMode)),
                      onPressed: () {
                        final modes = AVRepeatMode.values;
                        final next = modes[
                            (plState.repeatMode.index + 1) % modes.length];
                        _playlist.setRepeatMode(next);
                      },
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Track queue
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Queue',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _tracks.length,
                  itemBuilder: (context, index) {
                    final track = _tracks[index];
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
                        track.title,
                        style: TextStyle(
                          fontWeight:
                              isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: isCurrent
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                      ),
                      subtitle: Text(
                        track.artist,
                        style: TextStyle(
                          color: isCurrent
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.7)
                              : Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () => _playlist.jumpTo(index),
                    );
                  },
                ),
              ),
            ],
          );
        },
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
