import 'package:flutter/material.dart';

import 'screens/gestures_screen.dart';
import 'screens/live_stream_screen.dart';
import 'screens/music_player_screen.dart';
import 'screens/pip_screen.dart';
import 'screens/playlist_screen.dart';
import 'screens/shorts_screen.dart';
import 'screens/subtitles_screen.dart';
import 'screens/theming_screen.dart';
import 'screens/video_player_screen.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AV Player Examples',
      theme: ThemeData.dark(useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _features = <({
    IconData icon,
    String title,
    String subtitle,
    Widget Function() builder,
  })>[
    (
      icon: Icons.play_circle_outline,
      title: 'Video Player',
      subtitle: '.video() preset — full controls & gestures',
      builder: VideoPlayerScreen.new,
    ),
    (
      icon: Icons.short_text,
      title: 'Shorts',
      subtitle: '.short() preset — vertical, looping, minimal UI',
      builder: ShortsScreen.new,
    ),
    (
      icon: Icons.music_note,
      title: 'Music Player',
      subtitle: '.music() preset — skip, speed, no PIP/fullscreen',
      builder: MusicPlayerScreen.new,
    ),
    (
      icon: Icons.live_tv,
      title: 'Live Stream',
      subtitle: '.live() preset — no seek bar, no skip, no speed',
      builder: LiveStreamScreen.new,
    ),
    (
      icon: Icons.picture_in_picture,
      title: 'Picture-in-Picture',
      subtitle: 'Native PIP & in-app floating overlay',
      builder: PipScreen.new,
    ),
    (
      icon: Icons.queue_music,
      title: 'Playlist',
      subtitle: 'AVPlaylistController — queue, repeat, shuffle',
      builder: PlaylistScreen.new,
    ),
    (
      icon: Icons.closed_caption,
      title: 'Subtitles & Captions',
      subtitle: 'SRT, WebVTT, embedded tracks, CC button',
      builder: SubtitlesScreen.new,
    ),
    (
      icon: Icons.gesture,
      title: 'Gesture Controls',
      subtitle: 'Double-tap, long-press, swipe gestures',
      builder: GesturesScreen.new,
    ),
    (
      icon: Icons.palette,
      title: 'Theming',
      subtitle: 'AVPlayerTheme color customization',
      builder: ThemingScreen.new,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AV Player Examples')),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _features.length,
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (context, index) {
          final feature = _features[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            child: ListTile(
              leading: Icon(feature.icon, size: 28),
              title: Text(feature.title),
              subtitle: Text(feature.subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => feature.builder(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
