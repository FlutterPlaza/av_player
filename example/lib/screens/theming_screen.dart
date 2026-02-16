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

  static const _themes = <(String, Color, AVPlayerThemeData, String)>[
    (
      'Default',
      Colors.blue,
      AVPlayerThemeData(),
      'Blue accent, white slider and icons',
    ),
    (
      'Orange',
      Colors.deepOrange,
      AVPlayerThemeData(
        accentColor: Colors.deepOrange,
        sliderActiveColor: Colors.deepOrange,
        sliderThumbColor: Colors.deepOrange,
        progressBarColor: Colors.deepOrange,
      ),
      'Warm orange accent and slider',
    ),
    (
      'Teal',
      Colors.teal,
      AVPlayerThemeData(
        accentColor: Colors.teal,
        sliderActiveColor: Colors.teal,
        sliderThumbColor: Colors.teal,
        progressBarColor: Colors.teal,
      ),
      'Cool teal accent and slider',
    ),
    (
      'Purple',
      Colors.purpleAccent,
      AVPlayerThemeData(
        accentColor: Colors.purpleAccent,
        sliderActiveColor: Colors.purpleAccent,
        sliderThumbColor: Colors.purpleAccent,
        progressBarColor: Colors.purpleAccent,
      ),
      'Vibrant purple accent and slider',
    ),
    (
      'Red',
      Colors.red,
      AVPlayerThemeData(
        accentColor: Colors.red,
        sliderActiveColor: Colors.red,
        sliderThumbColor: Colors.red,
        progressBarColor: Colors.red,
      ),
      'YouTube-inspired red accent and slider',
    ),
    (
      'Green',
      Colors.green,
      AVPlayerThemeData(
        accentColor: Colors.green,
        sliderActiveColor: Colors.green,
        sliderThumbColor: Colors.green,
        progressBarColor: Colors.green,
      ),
      'Spotify-inspired green accent and slider',
    ),
  ];

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
    final selected = _themes[_selectedTheme];

    return Scaffold(
      appBar: AppBar(title: const Text('Theming')),
      body: ListView(
        children: [
          AVPlayerTheme(
            data: selected.$3,
            child: ValueListenableBuilder<AVPlayerState>(
              valueListenable: _controller,
              builder: (context, state, _) {
                return AspectRatio(
                  aspectRatio: state.aspectRatio,
                  child:
                      AVVideoPlayer.video(_controller, title: 'Big Buck Bunny'),
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
                    final theme = _themes[index];
                    return ChoiceChip(
                      avatar: CircleAvatar(
                        backgroundColor: theme.$2,
                        radius: 8,
                      ),
                      label: Text(theme.$1),
                      selected: _selectedTheme == index,
                      onSelected: (sel) {
                        if (sel) setState(() => _selectedTheme = index);
                      },
                    );
                  }),
                ),
                const SizedBox(height: 20),
                Text(
                  'Properties',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PropertyRow(
                        label: 'Accent Color',
                        color: selected.$2,
                      ),
                      const SizedBox(height: 6),
                      _PropertyRow(
                        label: 'Slider Active',
                        color: selected.$3.sliderActiveColor,
                      ),
                      const SizedBox(height: 6),
                      _PropertyRow(
                        label: 'Slider Thumb',
                        color: selected.$3.sliderThumbColor,
                      ),
                      const SizedBox(height: 6),
                      _PropertyRow(
                        label: 'Progress Bar',
                        color: selected.$3.progressBarColor,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        selected.$4,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
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

class _PropertyRow extends StatelessWidget {
  const _PropertyRow({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    );
  }
}
