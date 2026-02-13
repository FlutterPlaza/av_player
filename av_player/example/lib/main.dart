import 'package:av_player/av_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const VideoApp());

class VideoApp extends StatefulWidget {
  const VideoApp({super.key});

  @override
  State<VideoApp> createState() => _VideoAppState();
}

class _VideoAppState extends State<VideoApp> {
  late final AVPlayerController _controller;
  bool _isFullscreen = false;
  bool _showPip = false;
  bool _notificationEnabled = false;
  bool _useCustomTheme = false;

  static const _customTheme = AVPlayerThemeData(
    accentColor: Colors.deepOrange,
    sliderActiveColor: Colors.deepOrange,
    sliderThumbColor: Colors.deepOrange,
    progressBarColor: Colors.deepOrange,
  );

  @override
  void initState() {
    super.initState();
    _controller = AVPlayerController(
      const AVVideoSource.network(
        'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
      ),
      onMediaCommand: _handleMediaCommand,
    )..initialize().then((_) {
        // Set metadata once initialized
        _controller.setMediaMetadata(const AVMediaMetadata(
          title: 'Bee Video',
          artist: 'Flutter',
          album: 'API Docs Assets',
        ));
      });
  }

  void _handleMediaCommand(AVMediaCommand command, {Duration? seekPosition}) {
    debugPrint('Media command: ${command.name}'
        '${seekPosition != null ? ' at ${seekPosition.inSeconds}s' : ''}');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AV Picture-in-Picture Demo',
      theme: ThemeData.dark(useMaterial3: true),
      home: AVPlayerTheme(
        data: _useCustomTheme ? _customTheme : const AVPlayerThemeData(),
        child: Stack(
          children: [
            // Main content
            if (_isFullscreen)
              _buildFullscreenPlayer()
            else
              _buildMainScreen(),

            // In-app PIP overlay
            if (_showPip)
              AVPipOverlay(
                controller: _controller,
                onClose: () => setState(() => _showPip = false),
                onExpand: () => setState(() {
                  _showPip = false;
                  _isFullscreen = true;
                }),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainScreen() {
    return Scaffold(
      appBar: AppBar(title: const Text('AV PIP Demo')),
      body: ValueListenableBuilder<AVPlayerState>(
        valueListenable: _controller,
        builder: (context, state, _) {
          // In native PIP mode, show minimal UI
          if (state.isInPipMode) {
            return Material(
              child: AspectRatio(
                aspectRatio: state.aspectRatio,
                child: AVVideoPlayer(_controller),
              ),
            );
          }

          return Column(
            children: [
              // Video player using the .video() preset
              AspectRatio(
                aspectRatio: state.aspectRatio,
                child: AVVideoPlayer.video(
                  _controller,
                  title: 'Bee Video',
                  onFullscreen: _enterFullscreen,
                ),
              ),

              const SizedBox(height: 24),

              // Additional actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gestures',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '  Double-tap left/right to skip 10s\n'
                      '  Long-press for 2x speed\n'
                      '  Swipe right side for volume\n'
                      '  Swipe left side for brightness',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Actions',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          icon: const Icon(Icons.picture_in_picture, size: 18),
                          label: const Text('In-App PIP'),
                          onPressed: () {
                            setState(() => _showPip = true);
                          },
                        ),
                        FilledButton.icon(
                          icon: const Icon(Icons.picture_in_picture_alt,
                              size: 18),
                          label: const Text('Native PIP'),
                          onPressed: () => _controller.enterPip(),
                        ),
                        FilledButton.icon(
                          icon: Icon(
                            _notificationEnabled
                                ? Icons.notifications_active
                                : Icons.notifications_off,
                            size: 18,
                          ),
                          label: Text(_notificationEnabled
                              ? 'Notification ON'
                              : 'Notification OFF'),
                          onPressed: () {
                            setState(() =>
                                _notificationEnabled = !_notificationEnabled);
                            _controller
                                .setNotificationEnabled(_notificationEnabled);
                          },
                        ),
                        FilledButton.icon(
                          icon: Icon(
                            _useCustomTheme
                                ? Icons.palette
                                : Icons.palette_outlined,
                            size: 18,
                          ),
                          label: Text(_useCustomTheme
                              ? 'Custom Theme'
                              : 'Default Theme'),
                          onPressed: () {
                            setState(
                                () => _useCustomTheme = !_useCustomTheme);
                          },
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

  Widget _buildFullscreenPlayer() {
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
                title: 'Bee Video',
                onFullscreen: _exitFullscreen,
              ),
            ),
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
