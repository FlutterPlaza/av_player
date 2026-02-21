import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'src/av_controls.dart';
import 'src/av_gestures.dart';
import 'src/av_subtitle_overlay.dart';
import 'src/platform/av_player_platform.dart';
import 'src/subtitle_parser.dart';

// Re-export types from platform interface so users only need one import.
export 'src/platform/av_player_platform.dart'
    show
        AVVideoSource,
        AVNetworkSource,
        AVAssetSource,
        AVFileSource,
        AVMediaMetadata,
        AVPlayerEvent,
        AVInitializedEvent,
        AVPositionChangedEvent,
        AVPlaybackStateChangedEvent,
        AVBufferingUpdateEvent,
        AVPipChangedEvent,
        AVCompletedEvent,
        AVErrorEvent,
        AVMediaCommandEvent,
        AVMediaCommand,
        AVPlaybackState,
        AVAbrConfig,
        AVDecoderInfo,
        AVMemoryPressureLevel,
        AVAbrInfoEvent,
        AVMemoryPressureEvent,
        AVSubtitleCue,
        AVSubtitleTrack,
        AVSubtitleFormat,
        AVSubtitleTracksChangedEvent,
        AVSubtitleCueEvent;

export 'src/subtitle_parser.dart' show AVSubtitleParser;
export 'src/av_subtitle_overlay.dart';

/// View type prefix for the web platform view. Must match the prefix
/// used in [AvPlayerWeb] to register the `<video>` element.
const _kWebViewTypePrefix = 'com.flutterplaza.av_pip_video_';

// ---------------------------------------------------------------------------
// Player state
// ---------------------------------------------------------------------------

/// Immutable snapshot of a video player's state.
@immutable
class AVPlayerState {
  const AVPlayerState({
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffered = Duration.zero,
    this.isPlaying = false,
    this.isBuffering = false,
    this.isLooping = false,
    this.isInitialized = false,
    this.isInPipMode = false,
    this.isCompleted = false,
    this.playbackSpeed = 1.0,
    this.volume = 1.0,
    this.aspectRatio = 16 / 9,
    this.errorDescription,
    this.currentBitrateKbps,
    this.memoryPressureLevel,
    this.currentSubtitleCue,
    this.availableSubtitleTracks = const [],
    this.activeSubtitleTrackId,
    this.subtitlesEnabled = false,
  });

  final Duration position;
  final Duration duration;
  final Duration buffered;
  final bool isPlaying;
  final bool isBuffering;
  final bool isLooping;
  final bool isInitialized;
  final bool isInPipMode;
  final bool isCompleted;
  final double playbackSpeed;
  final double volume;
  final double aspectRatio;
  final String? errorDescription;
  final int? currentBitrateKbps;
  final AVMemoryPressureLevel? memoryPressureLevel;
  final AVSubtitleCue? currentSubtitleCue;
  final List<AVSubtitleTrack> availableSubtitleTracks;
  final String? activeSubtitleTrackId;
  final bool subtitlesEnabled;

  bool get hasError => errorDescription != null;

  AVPlayerState copyWith({
    Duration? position,
    Duration? duration,
    Duration? buffered,
    bool? isPlaying,
    bool? isBuffering,
    bool? isLooping,
    bool? isInitialized,
    bool? isInPipMode,
    bool? isCompleted,
    double? playbackSpeed,
    double? volume,
    double? aspectRatio,
    String? errorDescription,
    int? currentBitrateKbps,
    AVMemoryPressureLevel? memoryPressureLevel,
    AVSubtitleCue? currentSubtitleCue,
    List<AVSubtitleTrack>? availableSubtitleTracks,
    String? activeSubtitleTrackId,
    bool? subtitlesEnabled,
    // Sentinel to allow clearing nullable fields
    bool clearSubtitleCue = false,
    bool clearActiveSubtitleTrackId = false,
  }) {
    return AVPlayerState(
      position: position ?? this.position,
      duration: duration ?? this.duration,
      buffered: buffered ?? this.buffered,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      isLooping: isLooping ?? this.isLooping,
      isInitialized: isInitialized ?? this.isInitialized,
      isInPipMode: isInPipMode ?? this.isInPipMode,
      isCompleted: isCompleted ?? this.isCompleted,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      volume: volume ?? this.volume,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      errorDescription: errorDescription ?? this.errorDescription,
      currentBitrateKbps: currentBitrateKbps ?? this.currentBitrateKbps,
      memoryPressureLevel: memoryPressureLevel ?? this.memoryPressureLevel,
      currentSubtitleCue: clearSubtitleCue
          ? null
          : (currentSubtitleCue ?? this.currentSubtitleCue),
      availableSubtitleTracks:
          availableSubtitleTracks ?? this.availableSubtitleTracks,
      activeSubtitleTrackId: clearActiveSubtitleTrackId
          ? null
          : (activeSubtitleTrackId ?? this.activeSubtitleTrackId),
      subtitlesEnabled: subtitlesEnabled ?? this.subtitlesEnabled,
    );
  }
}

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

/// Controls a video player instance.
///
/// Communicates with the native platform through [AvPlayerPlatform]
/// to play video, manage PIP mode, and handle media session controls.
///
/// Exposes player state via [ValueNotifier] so widgets can rebuild reactively
/// with [ValueListenableBuilder].
///
/// ```dart
/// final controller = AVPlayerController(
///   const AVVideoSource.network('https://example.com/video.mp4'),
/// );
/// await controller.initialize();
/// await controller.play();
/// ```
class AVPlayerController extends ValueNotifier<AVPlayerState> {
  AVPlayerController(this.source, {this.onMediaCommand})
      : super(const AVPlayerState());

  final AVVideoSource source;

  /// Called when a media command is received from the notification or lock screen.
  /// Use this to handle next/previous track, or custom seek behavior.
  final void Function(AVMediaCommand command, {Duration? seekPosition})?
      onMediaCommand;

  static AvPlayerPlatform get _platform => AvPlayerPlatform.instance;

  int? _playerId;
  StreamSubscription<AVPlayerEvent>? _eventSubscription;

  // Subtitle state
  final List<AVSubtitleTrack> _externalTracks = [];
  final Map<String, List<AVSubtitleCue>> _externalCues = {};
  Timer? _subtitleSyncTimer;

  /// The texture ID used to render the video frame.
  /// Null until [initialize] completes successfully.
  int? get textureId => _playerId;

  /// The player ID (same as textureId). Null until initialized.
  int? get playerId => _playerId;

  /// Whether the controller has been initialized.
  bool get isInitialized => value.isInitialized;

  /// Initializes the player with the video source.
  ///
  /// This creates the native player, registers a texture for rendering,
  /// and starts listening for player events. Must be called before any
  /// playback methods.
  Future<void> initialize() async {
    try {
      final id = await _platform.create(source);
      _playerId = id;
      _listenToEvents(id);
    } catch (e) {
      value = value.copyWith(errorDescription: e.toString());
    }
  }

  void _listenToEvents(int playerId) {
    _eventSubscription = _platform.playerEvents(playerId).listen(
      _handleEvent,
      onError: (Object error) {
        value = value.copyWith(errorDescription: error.toString());
      },
    );
  }

  void _handleEvent(AVPlayerEvent event) {
    switch (event) {
      case AVInitializedEvent(:final duration, :final width, :final height):
        value = value.copyWith(
          isInitialized: true,
          duration: duration,
          aspectRatio: width > 0 && height > 0 ? width / height : 16 / 9,
        );
      case AVPositionChangedEvent(:final position):
        value = value.copyWith(position: position);
      case AVPlaybackStateChangedEvent(:final state):
        value = value.copyWith(
          isPlaying: state == AVPlaybackState.playing,
          isBuffering: state == AVPlaybackState.buffering,
          isCompleted: state == AVPlaybackState.completed,
        );
      case AVBufferingUpdateEvent(:final buffered):
        value = value.copyWith(buffered: buffered);
      case AVPipChangedEvent(:final isInPipMode):
        value = value.copyWith(isInPipMode: isInPipMode);
      case AVCompletedEvent():
        value = value.copyWith(isPlaying: false, isCompleted: true);
      case AVErrorEvent(:final message):
        value = value.copyWith(errorDescription: message);
      case AVMediaCommandEvent(:final command, :final seekPosition):
        onMediaCommand?.call(command, seekPosition: seekPosition);
      case AVAbrInfoEvent(:final currentBitrateBps):
        value = value.copyWith(
          currentBitrateKbps: (currentBitrateBps / 1000).round(),
        );
      case AVMemoryPressureEvent(:final level):
        value = value.copyWith(memoryPressureLevel: level);
        if (level == AVMemoryPressureLevel.critical) {
          _applyMemoryPressureReduction();
        }
      case AVSubtitleTracksChangedEvent(:final tracks):
        final merged = [...tracks, ..._externalTracks];
        value = value.copyWith(availableSubtitleTracks: merged);
      case AVSubtitleCueEvent(:final cue):
        // Only update if an embedded track is active
        final activeId = value.activeSubtitleTrackId;
        if (activeId != null && !_externalCues.containsKey(activeId)) {
          if (cue != null) {
            value = value.copyWith(currentSubtitleCue: cue);
          } else {
            value = value.copyWith(clearSubtitleCue: true);
          }
        }
    }
  }

  void _applyMemoryPressureReduction() {
    final id = _playerId;
    if (id == null) return;
    _platform.setAbrConfig(
      id,
      const AVAbrConfig(maxBitrateBps: 500000),
    );
  }

  /// Starts or resumes playback.
  ///
  /// If the video has completed, seeks to the beginning first.
  Future<void> play() async {
    final id = _playerId;
    if (id == null) return;
    if (value.isCompleted) {
      await _platform.seekTo(id, Duration.zero);
      value = value.copyWith(position: Duration.zero);
    }
    await _platform.play(id);
    value = value.copyWith(isPlaying: true, isCompleted: false);
  }

  /// Pauses playback.
  Future<void> pause() async {
    final id = _playerId;
    if (id == null) return;
    await _platform.pause(id);
    value = value.copyWith(isPlaying: false);
  }

  /// Seeks to the given [position].
  Future<void> seekTo(Duration position) async {
    final id = _playerId;
    if (id == null) return;
    await _platform.seekTo(id, position);
    value = value.copyWith(position: position, isCompleted: false);
  }

  /// Sets the playback speed. 1.0 is normal speed.
  Future<void> setPlaybackSpeed(double speed) async {
    final id = _playerId;
    if (id == null) return;
    await _platform.setPlaybackSpeed(id, speed);
    value = value.copyWith(playbackSpeed: speed);
  }

  /// Sets whether the video should loop.
  Future<void> setLooping(bool looping) async {
    final id = _playerId;
    if (id == null) return;
    await _platform.setLooping(id, looping);
    value = value.copyWith(isLooping: looping);
  }

  /// Sets the player's volume. Range: 0.0 (mute) to 1.0 (max).
  Future<void> setVolume(double volume) async {
    final id = _playerId;
    if (id == null) return;
    await _platform.setVolume(id, volume.clamp(0.0, 1.0));
    value = value.copyWith(volume: volume.clamp(0.0, 1.0));
  }

  /// Enters Picture-in-Picture mode.
  Future<void> enterPip({double? aspectRatio}) async {
    final id = _playerId;
    if (id == null) return;
    await _platform.enterPip(id, aspectRatio: aspectRatio);
  }

  /// Exits Picture-in-Picture mode.
  Future<void> exitPip() async {
    final id = _playerId;
    if (id == null) return;
    await _platform.exitPip(id);
  }

  /// Checks if PIP mode is available on this device.
  Future<bool> isPipAvailable() => _platform.isPipAvailable();

  /// Sets metadata for the media notification / lock screen display.
  Future<void> setMediaMetadata(AVMediaMetadata metadata) async {
    final id = _playerId;
    if (id == null) return;
    await _platform.setMediaMetadata(id, metadata);
  }

  /// Enables or disables the media notification.
  Future<void> setNotificationEnabled(bool enabled) async {
    final id = _playerId;
    if (id == null) return;
    await _platform.setNotificationEnabled(id, enabled);
  }

  /// Sets the system volume. Range: 0.0 to 1.0.
  Future<void> setSystemVolume(double volume) =>
      _platform.setSystemVolume(volume.clamp(0.0, 1.0));

  /// Returns the current system volume (0.0 to 1.0).
  Future<double> getSystemVolume() => _platform.getSystemVolume();

  /// Sets the screen brightness. Range: 0.0 to 1.0.
  Future<void> setScreenBrightness(double brightness) =>
      _platform.setScreenBrightness(brightness.clamp(0.0, 1.0));

  /// Returns the current screen brightness (0.0 to 1.0).
  Future<double> getScreenBrightness() => _platform.getScreenBrightness();

  /// Enables or disables wakelock (prevents screen from turning off).
  Future<void> setWakelock(bool enabled) => _platform.setWakelock(enabled);

  /// Sets the adaptive bitrate streaming configuration.
  Future<void> setAbrConfig(AVAbrConfig config) async {
    final id = _playerId;
    if (id == null) return;
    await _platform.setAbrConfig(id, config);
  }

  /// Returns decoder information for the current player.
  Future<AVDecoderInfo> getDecoderInfo() async {
    final id = _playerId;
    if (id == null) return AVDecoderInfo.unknown;
    return _platform.getDecoderInfo(id);
  }

  // ===========================================================================
  // Subtitles
  // ===========================================================================

  /// The currently available subtitle tracks (both embedded and external).
  List<AVSubtitleTrack> get subtitleTracks => value.availableSubtitleTracks;

  /// Adds an external subtitle from parsed content (SRT or WebVTT).
  ///
  /// The content is parsed immediately. The resulting track is added to
  /// [subtitleTracks] and can be selected via [selectSubtitleTrack].
  void addSubtitle(String content, {required String label, String? language}) {
    final cues = AVSubtitleParser.parse(content);
    final trackId = 'external_${_externalTracks.length}';
    final track = AVSubtitleTrack(
      id: trackId,
      label: label,
      language: language,
    );
    _externalTracks.add(track);
    _externalCues[trackId] = cues;

    // Merge with any embedded tracks
    final embedded =
        value.availableSubtitleTracks.where((t) => t.isEmbedded).toList();
    value = value.copyWith(
      availableSubtitleTracks: [...embedded, ..._externalTracks],
    );
  }

  /// Selects a subtitle track by ID. Pass null to disable subtitles.
  ///
  /// For embedded tracks, delegates to the native platform.
  /// For external tracks, starts a sync timer that matches cues to position.
  Future<void> selectSubtitleTrack(String? trackId) async {
    final id = _playerId;

    _subtitleSyncTimer?.cancel();
    _subtitleSyncTimer = null;

    if (trackId == null) {
      // Disable subtitles
      if (id != null) {
        try {
          await _platform.selectSubtitleTrack(id, null);
        } catch (_) {
          // Platform may not support embedded subtitles
        }
      }
      value = value.copyWith(
        clearActiveSubtitleTrackId: true,
        clearSubtitleCue: true,
        subtitlesEnabled: false,
      );
      return;
    }

    if (_externalCues.containsKey(trackId)) {
      // External track — use Dart-side sync
      value = value.copyWith(
        activeSubtitleTrackId: trackId,
        subtitlesEnabled: true,
      );
      _startSubtitleSync(trackId);
    } else {
      // Embedded track — delegate to native
      if (id != null) {
        try {
          await _platform.selectSubtitleTrack(id, trackId);
        } catch (_) {
          // Platform may not support embedded subtitles
        }
      }
      value = value.copyWith(
        activeSubtitleTrackId: trackId,
        subtitlesEnabled: true,
      );
    }
  }

  /// Toggles subtitles on/off.
  ///
  /// When toggling on, reuses the last active track or selects the first available.
  Future<void> toggleSubtitles() async {
    if (value.subtitlesEnabled) {
      await selectSubtitleTrack(null);
    } else {
      final tracks = value.availableSubtitleTracks;
      if (tracks.isNotEmpty) {
        final trackId = value.activeSubtitleTrackId ?? tracks.first.id;
        await selectSubtitleTrack(trackId);
      }
    }
  }

  void _startSubtitleSync(String trackId) {
    _subtitleSyncTimer?.cancel();
    _subtitleSyncTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _updateExternalCue(trackId),
    );
  }

  void _updateExternalCue(String trackId) {
    final cues = _externalCues[trackId];
    if (cues == null) return;

    final position = value.position;
    AVSubtitleCue? active;
    for (final cue in cues) {
      if (position >= cue.startTime && position < cue.endTime) {
        active = cue;
        break;
      }
      if (cue.startTime > position) break; // cues are sorted
    }

    if (active != value.currentSubtitleCue) {
      if (active != null) {
        value = value.copyWith(currentSubtitleCue: active);
      } else {
        value = value.copyWith(clearSubtitleCue: true);
      }
    }
  }

  @override
  void dispose() {
    _subtitleSyncTimer?.cancel();
    _eventSubscription?.cancel();
    final id = _playerId;
    if (id != null) {
      _platform.dispose(id);
    }
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

/// Displays video from an [AVPlayerController] with optional controls and gestures.
///
/// By default, renders just the native [Texture]. Set [showControls] to `true`
/// to add an animated overlay with play/pause, seek slider, skip buttons, and more.
///
/// ```dart
/// // Simple — just the video
/// AVVideoPlayer(controller)
///
/// // With built-in controls and gestures
/// AVVideoPlayer(
///   controller,
///   showControls: true,
///   gestureConfig: const AVGestureConfig(),
/// )
/// ```
class AVVideoPlayer extends StatefulWidget {
  const AVVideoPlayer(
    this.controller, {
    super.key,
    this.showControls = false,
    this.showSubtitles,
    this.controlsConfig,
    this.controlsBuilder,
    this.gestureConfig,
    this.title,
    this.onFullscreen,
    this.onNext,
    this.onPrevious,
  });

  /// Full video player preset — all controls, gestures, and PIP enabled.
  ///
  /// ```dart
  /// AVVideoPlayer.video(controller, title: 'My Video')
  /// ```
  const AVVideoPlayer.video(
    this.controller, {
    super.key,
    this.title,
    this.showSubtitles,
    this.onFullscreen,
    this.onNext,
    this.onPrevious,
    this.controlsBuilder,
    AVControlsConfig? controlsConfig,
    AVGestureConfig? gestureConfig,
  })  : showControls = true,
        controlsConfig = controlsConfig ??
            const AVControlsConfig(
              showSkipButtons: true,
              showPipButton: true,
              showSpeedButton: true,
              showFullscreenButton: true,
              showLoopButton: true,
            ),
        gestureConfig = gestureConfig ??
            const AVGestureConfig(
              doubleTapToSeek: true,
              longPressSpeed: true,
              swipeToVolume: true,
              swipeToBrightness: true,
            );

  /// Music player preset — simple controls, no video gestures.
  ///
  /// Shows play/pause, skip, speed, and loop. Disables PIP and fullscreen
  /// since the video surface is typically used for album art or visualizer.
  ///
  /// ```dart
  /// AVVideoPlayer.music(controller, title: 'Song Name')
  /// ```
  const AVVideoPlayer.music(
    this.controller, {
    super.key,
    this.title,
    this.showSubtitles,
    this.onNext,
    this.onPrevious,
    this.controlsBuilder,
    AVControlsConfig? controlsConfig,
  })  : showControls = true,
        controlsConfig = controlsConfig ??
            const AVControlsConfig(
              showSkipButtons: true,
              showPipButton: false,
              showSpeedButton: true,
              showFullscreenButton: false,
              showLoopButton: true,
            ),
        gestureConfig = null,
        onFullscreen = null;

  /// Live stream preset — no seek bar, no skip, live indicator style.
  ///
  /// Disables all seek-related controls and gestures since live streams
  /// cannot be seeked.
  ///
  /// ```dart
  /// AVVideoPlayer.live(controller, title: 'Live Stream')
  /// ```
  const AVVideoPlayer.live(
    this.controller, {
    super.key,
    this.title,
    this.showSubtitles,
    this.onFullscreen,
    this.controlsBuilder,
    AVControlsConfig? controlsConfig,
  })  : showControls = true,
        controlsConfig = controlsConfig ??
            const AVControlsConfig(
              showSkipButtons: false,
              showPipButton: true,
              showSpeedButton: false,
              showFullscreenButton: true,
              showLoopButton: false,
            ),
        gestureConfig = null,
        onNext = null,
        onPrevious = null;

  /// Short-form content preset — minimal controls, auto-loop friendly.
  ///
  /// Shows only play/pause with no surrounding chrome. Designed for
  /// vertical short-form content (TikTok/Reels/Shorts style).
  ///
  /// ```dart
  /// AVVideoPlayer.short(controller)
  /// ```
  const AVVideoPlayer.short(
    this.controller, {
    super.key,
    this.title,
    this.showSubtitles,
    this.onNext,
    this.onPrevious,
    this.controlsBuilder,
  })  : showControls = true,
        controlsConfig = const AVControlsConfig(
          showSkipButtons: false,
          showPipButton: false,
          showSpeedButton: false,
          showFullscreenButton: false,
          showLoopButton: false,
        ),
        gestureConfig = const AVGestureConfig(
          doubleTapToSeek: true,
          longPressSpeed: true,
          swipeToVolume: true,
          swipeToBrightness: false,
          horizontalSwipeToSeek: false,
        ),
        onFullscreen = null;

  /// The player controller to render.
  final AVPlayerController controller;

  /// Whether to show the built-in controls overlay. Defaults to `false`.
  final bool showControls;

  /// Whether to show subtitles. When null, falls back to [AVPlayerState.subtitlesEnabled].
  final bool? showSubtitles;

  /// Configuration for the built-in controls. Only used when [showControls] is true.
  final AVControlsConfig? controlsConfig;

  /// A custom controls builder that replaces the built-in [AVControls].
  /// When provided, [controlsConfig] is ignored.
  final Widget Function(BuildContext context, AVPlayerController controller)?
      controlsBuilder;

  /// Configuration for gesture detection. When non-null, a gesture layer is added.
  final AVGestureConfig? gestureConfig;

  /// Optional title shown in the controls top bar.
  final String? title;

  /// Called when the fullscreen button is pressed.
  final VoidCallback? onFullscreen;

  /// Called when the next track button is pressed.
  final VoidCallback? onNext;

  /// Called when the previous track button is pressed.
  final VoidCallback? onPrevious;

  @override
  State<AVVideoPlayer> createState() => _AVVideoPlayerState();
}

class _AVVideoPlayerState extends State<AVVideoPlayer>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only pause/resume if PIP is not active
    if (!widget.controller.value.isInPipMode) {
      if (state == AppLifecycleState.paused) {
        widget.controller.pause();
      } else if (state == AppLifecycleState.resumed) {
        if (widget.controller.value.isPlaying) {
          widget.controller.play();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AVPlayerState>(
      valueListenable: widget.controller,
      builder: (context, state, child) {
        final videoLayer = _buildVideoLayer(state);

        // Simple mode: just the video
        if (!widget.showControls &&
            widget.controlsBuilder == null &&
            widget.gestureConfig == null) {
          return videoLayer;
        }

        // Enhanced mode: video + subtitles + gestures + controls in a stack
        final showSubs = widget.showSubtitles ?? state.subtitlesEnabled;
        return Stack(
          fit: StackFit.expand,
          children: [
            videoLayer,
            if (showSubs)
              AVSubtitleOverlay(
                currentCue: state.currentSubtitleCue,
                bottomPadding: widget.showControls ? 80 : 16,
              ),
            if (widget.gestureConfig != null)
              AVGestures(
                controller: widget.controller,
                config: widget.gestureConfig!,
              ),
            if (widget.controlsBuilder != null)
              widget.controlsBuilder!(context, widget.controller)
            else if (widget.showControls)
              AVControls(
                controller: widget.controller,
                config: widget.controlsConfig ?? const AVControlsConfig(),
                title: widget.title,
                onFullscreen: widget.onFullscreen,
                onNext: widget.onNext,
                onPrevious: widget.onPrevious,
              ),
          ],
        );
      },
    );
  }

  Widget _buildVideoLayer(AVPlayerState state) {
    if (state.hasError) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  state.errorDescription ?? 'Unknown error',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!state.isInitialized) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final textureId = widget.controller.textureId;
    if (textureId != null) {
      if (kIsWeb) {
        return HtmlElementView(
          viewType: '$_kWebViewTypePrefix$textureId',
        );
      }
      return Texture(textureId: textureId);
    }

    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Icon(Icons.videocam, color: Colors.white54, size: 48),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
