import 'package:av_player/av_player.dart';
import 'package:flutter/material.dart';

const _chatMessages = [
  (
    username: 'StreamFan42',
    message: 'Just got here, what did I miss?',
    time: '2m ago'
  ),
  (username: 'NightOwl', message: 'This is amazing!', time: '2m ago'),
  (
    username: 'TechGuru99',
    message: 'Great quality stream today',
    time: '1m ago'
  ),
  (username: 'PixelMaster', message: 'Can you zoom in?', time: '1m ago'),
  (
    username: 'CoolVibes',
    message: 'Love the content, keep it up!',
    time: '1m ago'
  ),
  (
    username: 'GamerPro',
    message: 'First time watching, this is lit',
    time: '45s ago'
  ),
  (
    username: 'MusicLover',
    message: 'The audio is crystal clear',
    time: '30s ago'
  ),
  (username: 'WatcherX', message: 'Hello from Brazil!', time: '20s ago'),
  (
    username: 'SuperChat',
    message: 'Donated \$5 — awesome stream!',
    time: '10s ago'
  ),
  (username: 'LateJoiner', message: 'Hey everyone!', time: 'just now'),
];

class LiveStreamScreen extends StatefulWidget {
  const LiveStreamScreen({super.key});

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen> {
  late final AVPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AVPlayerController(
      const AVVideoSource.network(
        'https://download.blender.org/durian/trailer/sintel_trailer-480p.mp4',
      ),
    )..initialize().then((_) {
        _controller.setLooping(true);
        _controller.play();
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Stream')),
      body: Column(
        children: [
          ValueListenableBuilder<AVPlayerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              return AspectRatio(
                aspectRatio: state.aspectRatio,
                child: AVVideoPlayer.live(
                  _controller,
                  title: 'LIVE',
                ),
              );
            },
          ),
          // Viewer count row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  '1.2K watching now',
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Chat feed
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _chatMessages.length,
              itemBuilder: (context, index) {
                final msg = _chatMessages[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors
                            .primaries[index % Colors.primaries.length]
                            .withValues(alpha: 0.7),
                        child: Text(
                          msg.username[0],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: msg.username,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors
                                      .primaries[
                                          index % Colors.primaries.length]
                                      .shade200,
                                  fontSize: 13,
                                ),
                              ),
                              const TextSpan(text: '  '),
                              TextSpan(
                                text: msg.message,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        msg.time,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Chat input (non-functional)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    readOnly: true,
                    decoration: InputDecoration(
                      hintText: 'Send a message...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.08),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.white38),
                  onPressed: () {},
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
