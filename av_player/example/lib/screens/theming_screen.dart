import 'package:av_player/av_player.dart';
import 'package:flutter/material.dart';

class ThemingScreen extends StatefulWidget {
  const ThemingScreen({super.key});

  @override
  State<ThemingScreen> createState() => _ThemingScreenState();
}

class _ThemingScreenState extends State<ThemingScreen> {
  late final AVPlayerController _controller;
  int _selectedTheme = 0;

  static const _themes = <(String, AVPlayerThemeData)>[
    ('Default', AVPlayerThemeData()),
    (
      'Orange',
      AVPlayerThemeData(
        accentColor: Colors.deepOrange,
        sliderActiveColor: Colors.deepOrange,
        sliderThumbColor: Colors.deepOrange,
        progressBarColor: Colors.deepOrange,
      ),
    ),
    (
      'Teal',
      AVPlayerThemeData(
        accentColor: Colors.teal,
        sliderActiveColor: Colors.teal,
        sliderThumbColor: Colors.teal,
        progressBarColor: Colors.teal,
      ),
    ),
    (
      'Purple',
      AVPlayerThemeData(
        accentColor: Colors.purpleAccent,
        sliderActiveColor: Colors.purpleAccent,
        sliderThumbColor: Colors.purpleAccent,
        progressBarColor: Colors.purpleAccent,
      ),
    ),
  ];

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
      appBar: AppBar(title: const Text('Theming')),
      body: Column(
        children: [
          AVPlayerTheme(
            data: _themes[_selectedTheme].$2,
            child: ValueListenableBuilder<AVPlayerState>(
              valueListenable: _controller,
              builder: (context, state, _) {
                return AspectRatio(
                  aspectRatio: state.aspectRatio,
                  child: AVVideoPlayer.video(_controller, title: 'Bee Video'),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Theme', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: List.generate(_themes.length, (index) {
                    return ChoiceChip(
                      label: Text(_themes[index].$1),
                      selected: _selectedTheme == index,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedTheme = index);
                      },
                    );
                  }),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Wrap AVVideoPlayer in an AVPlayerTheme widget to customize '
                  'colors for the controls overlay, slider, icons, and more.',
                  style: TextStyle(color: Colors.white60),
                ),
              ],
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
