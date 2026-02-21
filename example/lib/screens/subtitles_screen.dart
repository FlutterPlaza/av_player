import 'package:av_player/av_player.dart';
import 'package:flutter/material.dart';

/// Demonstrates subtitle/caption support with external SRT and WebVTT tracks.
class SubtitlesScreen extends StatefulWidget {
  const SubtitlesScreen({super.key});

  @override
  State<SubtitlesScreen> createState() => _SubtitlesScreenState();
}

class _SubtitlesScreenState extends State<SubtitlesScreen> {
  late final AVPlayerController _controller;

  // Sample SRT subtitle content (Sintel trailer)
  static const _englishSrt = '''
1
00:00:01,000 --> 00:00:04,000
This blade has a dark past.

2
00:00:05,000 --> 00:00:08,500
It has shed much innocent blood.

3
00:00:09,500 --> 00:00:13,000
You're a fool for traveling alone,
so completely unprepared.

4
00:00:14,000 --> 00:00:17,000
You're lucky your blood's
still flowing.

5
00:00:18,000 --> 00:00:20,500
Thank you.

6
00:00:21,000 --> 00:00:24,500
So... what are you doing here?

7
00:00:25,500 --> 00:00:29,000
I'm searching for someone.

8
00:00:30,000 --> 00:00:33,500
Someone very dear to me.

9
00:00:35,000 --> 00:00:39,000
I've been searching for
a very long time.
''';

  // Sample WebVTT subtitle content (Spanish translation)
  static const _spanishVtt = '''
WEBVTT

00:00:01.000 --> 00:00:04.000
Esta espada tiene un pasado oscuro.

00:00:05.000 --> 00:00:08.500
Ha derramado mucha sangre inocente.

00:00:09.500 --> 00:00:13.000
Eres un tonto por viajar solo,
tan completamente desprevenido.

00:00:14.000 --> 00:00:17.000
Tienes suerte de que tu sangre
aún fluya.

00:00:18.000 --> 00:00:20.500
Gracias.

00:00:21.000 --> 00:00:24.500
Entonces... ¿qué haces aquí?

00:00:25.500 --> 00:00:29.000
Estoy buscando a alguien.

00:00:30.000 --> 00:00:33.500
Alguien muy querido para mí.

00:00:35.000 --> 00:00:39.000
He estado buscando
durante mucho tiempo.
''';

  // Sample French subtitles
  static const _frenchSrt = '''
1
00:00:01,000 --> 00:00:04,000
Cette lame a un passé sombre.

2
00:00:05,000 --> 00:00:08,500
Elle a versé beaucoup de sang innocent.

3
00:00:09,500 --> 00:00:13,000
Tu es un fou de voyager seul,
si complètement non préparé.

4
00:00:14,000 --> 00:00:17,000
Tu as de la chance que ton sang
coule encore.

5
00:00:18,000 --> 00:00:20,500
Merci.

6
00:00:21,000 --> 00:00:24,500
Alors... que fais-tu ici ?

7
00:00:25,500 --> 00:00:29,000
Je cherche quelqu'un.

8
00:00:30,000 --> 00:00:33,500
Quelqu'un qui m'est très cher.

9
00:00:35,000 --> 00:00:39,000
Je cherche depuis
très longtemps.
''';

  @override
  void initState() {
    super.initState();
    _controller = AVPlayerController(
      const AVVideoSource.network(
        'https://download.blender.org/durian/trailer/sintel_trailer-480p.mp4',
      ),
    );
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    await _controller.initialize();

    // Add external subtitle tracks (SRT and WebVTT formats)
    _controller.addSubtitle(
      _englishSrt,
      label: 'English',
      language: 'en',
    );
    _controller.addSubtitle(
      _spanishVtt,
      label: 'Español',
      language: 'es',
    );
    _controller.addSubtitle(
      _frenchSrt,
      label: 'Français',
      language: 'fr',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subtitles & Captions')),
      body: ValueListenableBuilder<AVPlayerState>(
        valueListenable: _controller,
        builder: (context, state, _) {
          return ListView(
            children: [
              // Video player with subtitles enabled
              AspectRatio(
                aspectRatio: state.aspectRatio,
                child: AVVideoPlayer.video(
                  _controller,
                  title: 'Sintel Trailer',
                  showSubtitles: true,
                ),
              ),

              const SizedBox(height: 16),

              // Info card
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'How It Works',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Use the CC button in the player controls to '
                          'select a subtitle track. Subtitles are loaded '
                          'from SRT and WebVTT content and synced with '
                          'playback position.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Subtitle status
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Subtitle Status',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _StatusRow(
                          label: 'Subtitles',
                          value:
                              state.subtitlesEnabled ? 'Enabled' : 'Disabled',
                          color: state.subtitlesEnabled
                              ? Colors.green
                              : Colors.white54,
                        ),
                        const SizedBox(height: 8),
                        _StatusRow(
                          label: 'Active Track',
                          value: _activeTrackLabel(state),
                          color: state.activeSubtitleTrackId != null
                              ? Colors.blue
                              : Colors.white54,
                        ),
                        const SizedBox(height: 8),
                        _StatusRow(
                          label: 'Available Tracks',
                          value: '${state.availableSubtitleTracks.length}',
                          color: Colors.white70,
                        ),
                        const SizedBox(height: 8),
                        _StatusRow(
                          label: 'Current Cue',
                          value: state.currentSubtitleCue?.text ?? '—',
                          color: Colors.white70,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Track list
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          'Subtitle Tracks',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // Off option
                      ListTile(
                        leading: Icon(
                          Icons.closed_caption_disabled,
                          color: !state.subtitlesEnabled
                              ? Colors.blue
                              : Colors.white54,
                        ),
                        title: const Text('Off'),
                        trailing: !state.subtitlesEnabled
                            ? const Icon(Icons.check, color: Colors.blue)
                            : null,
                        onTap: () => _controller.selectSubtitleTrack(null),
                      ),
                      // Track options
                      ...state.availableSubtitleTracks.map(
                        (track) {
                          final isActive =
                              state.activeSubtitleTrackId == track.id;
                          return ListTile(
                            leading: Icon(
                              Icons.closed_caption,
                              color: isActive ? Colors.blue : Colors.white54,
                            ),
                            title: Text(track.label),
                            subtitle: Text(
                              track.language ?? 'Unknown language',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            trailing: isActive
                                ? const Icon(Icons.check, color: Colors.blue)
                                : null,
                            onTap: () =>
                                _controller.selectSubtitleTrack(track.id),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Supported formats
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Supported Formats',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 12),
                        _FormatChip(label: 'SRT', description: 'SubRip Text'),
                        SizedBox(height: 8),
                        _FormatChip(
                            label: 'WebVTT',
                            description: 'Web Video Text Tracks'),
                        SizedBox(height: 12),
                        Text(
                          'Both formats support multi-line text, HTML tag '
                          'stripping, and auto-detection. Embedded subtitle '
                          'tracks in HLS/DASH streams are also supported on '
                          'Android, iOS, and macOS.',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  String _activeTrackLabel(AVPlayerState state) {
    if (state.activeSubtitleTrackId == null) return 'None';
    final track = state.availableSubtitleTracks
        .where((t) => t.id == state.activeSubtitleTrackId);
    return track.isNotEmpty ? track.first.label : state.activeSubtitleTrackId!;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 13)),
        Flexible(
          child: Text(
            value,
            style: TextStyle(color: color, fontSize: 13),
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _FormatChip extends StatelessWidget {
  const _FormatChip({required this.label, required this.description});

  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.4)),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.blue,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          description,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    );
  }
}
