import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;

import 'av_player_platform.dart';

/// The view type prefix used when registering video platform views.
const _viewTypePrefix = 'com.flutterplaza.av_pip_video_';

/// JS interop type for the MediaSession `seekto` action details.
@JS()
extension type _SeekToActionDetails._(JSObject _) implements JSObject {
  external double? get seekTime;
}

/// The Web implementation of [AvPlayerPlatform].
///
/// Uses HTML5 `<video>` for playback, the Media Session API for
/// notification/lock screen controls, the Picture-in-Picture API for
/// native PIP, and the Screen Wake Lock API for wakelock.
class AvPlayerWeb extends AvPlayerPlatform {
  /// Registers this class as the default instance of
  /// [AvPlayerPlatform].
  static void registerWith([Object? registrar]) {
    AvPlayerPlatform.instance = AvPlayerWeb();
  }

  /// Auto-incrementing player ID.
  int _nextId = 0;

  /// Active player instances keyed by player ID.
  final Map<int, _WebPlayerInstance> _players = {};

  // ===========================================================================
  // Lifecycle
  // ===========================================================================

  @override
  Future<int> create(AVVideoSource source) async {
    final id = _nextId++;
    final player = _WebPlayerInstance(id, source);
    _players[id] = player;

    // Register the platform view so Flutter can embed the <video> element.
    ui_web.platformViewRegistry.registerViewFactory(
      '$_viewTypePrefix$id',
      (int viewId, {Object? params}) => player.videoElement,
    );

    return id;
  }

  @override
  Future<void> dispose(int playerId) async {
    final player = _players.remove(playerId);
    player?.dispose();
  }

  // ===========================================================================
  // Playback
  // ===========================================================================

  @override
  Future<void> play(int playerId) async {
    final player = _players[playerId];
    if (player == null) return;
    await player.videoElement.play().toDart;
  }

  @override
  Future<void> pause(int playerId) async {
    _players[playerId]?.videoElement.pause();
  }

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    final player = _players[playerId];
    if (player == null) return;
    player.videoElement.currentTime = position.inMilliseconds / 1000.0;
  }

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {
    _players[playerId]?.videoElement.playbackRate = speed;
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {
    _players[playerId]?.videoElement.loop = looping;
  }

  @override
  Future<void> setVolume(int playerId, double volume) async {
    _players[playerId]?.videoElement.volume = volume.clamp(0.0, 1.0);
  }

  // ===========================================================================
  // PIP
  // ===========================================================================

  @override
  Future<bool> isPipAvailable() async {
    return web.document.pictureInPictureEnabled;
  }

  @override
  Future<void> enterPip(int playerId, {double? aspectRatio}) async {
    final player = _players[playerId];
    if (player == null) return;
    await player.videoElement.requestPictureInPicture().toDart;
  }

  @override
  Future<void> exitPip(int playerId) async {
    if (web.document.pictureInPictureElement != null) {
      await web.document.exitPictureInPicture().toDart;
    }
  }

  // ===========================================================================
  // Media Session
  // ===========================================================================

  @override
  Future<void> setMediaMetadata(int playerId, AVMediaMetadata metadata) async {
    final session = web.window.navigator.mediaSession;

    final init = web.MediaMetadataInit(
      title: metadata.title ?? '',
      artist: metadata.artist ?? '',
      album: metadata.album ?? '',
    );

    // Add artwork if URL is provided.
    if (metadata.artworkUrl != null && metadata.artworkUrl!.isNotEmpty) {
      init.artwork = [
        web.MediaImage(src: metadata.artworkUrl!),
      ].toJS;
    }

    session.metadata = web.MediaMetadata(init);
  }

  @override
  Future<void> setNotificationEnabled(int playerId, bool enabled) async {
    final player = _players[playerId];
    if (player == null) return;

    if (enabled) {
      player.registerMediaSessionHandlers();
    } else {
      player.removeMediaSessionHandlers();
    }
  }

  // ===========================================================================
  // System Controls
  // ===========================================================================

  @override
  Future<void> setSystemVolume(double volume) async {
    // Web cannot control system volume — only per-element volume.
    // Apply to all active players as a best-effort.
    for (final player in _players.values) {
      player.videoElement.volume = volume.clamp(0.0, 1.0);
    }
  }

  @override
  Future<double> getSystemVolume() async {
    // Return volume of first active player, or 1.0 as default.
    if (_players.isNotEmpty) {
      return _players.values.first.videoElement.volume;
    }
    return 1.0;
  }

  @override
  Future<void> setScreenBrightness(double brightness) async {
    // Not possible in browsers. No-op.
  }

  @override
  Future<double> getScreenBrightness() async {
    // Not possible in browsers. Return nominal default.
    return 0.5;
  }

  @override
  Future<void> setWakelock(bool enabled) async {
    if (enabled) {
      await _acquireWakeLock();
    } else {
      await _releaseWakeLock();
    }
  }

  web.WakeLockSentinel? _wakeLockSentinel;

  Future<void> _acquireWakeLock() async {
    try {
      _wakeLockSentinel =
          await web.window.navigator.wakeLock.request('screen').toDart;
    } catch (_) {
      // Wake Lock API not supported or permission denied.
    }
  }

  Future<void> _releaseWakeLock() async {
    final sentinel = _wakeLockSentinel;
    if (sentinel != null && !sentinel.released) {
      await sentinel.release().toDart;
    }
    _wakeLockSentinel = null;
  }

  // ===========================================================================
  // Performance
  // ===========================================================================

  @override
  Future<void> setAbrConfig(int playerId, AVAbrConfig config) async {
    // Browser handles adaptive streaming internally — no-op.
  }

  @override
  Future<AVDecoderInfo> getDecoderInfo(int playerId) async {
    return AVDecoderInfo.unknown;
  }

  // ===========================================================================
  // Subtitles
  // ===========================================================================

  @override
  Future<List<AVSubtitleTrack>> getSubtitleTracks(int playerId) async {
    final player = _players[playerId];
    if (player == null) return [];

    final tracks = <AVSubtitleTrack>[];
    final textTracks = player.videoElement.textTracks;
    for (var i = 0; i < textTracks.length; i++) {
      final track = textTracks[i];
      tracks.add(AVSubtitleTrack(
        id: 'web_$i',
        label: track.label.isNotEmpty ? track.label : 'Track ${i + 1}',
        language: track.language.isNotEmpty ? track.language : null,
        isEmbedded: true,
      ));
    }
    return tracks;
  }

  @override
  Future<void> selectSubtitleTrack(int playerId, String? trackId) async {
    final player = _players[playerId];
    if (player == null) return;

    final textTracks = player.videoElement.textTracks;
    for (var i = 0; i < textTracks.length; i++) {
      final track = textTracks[i];
      track.mode = (trackId == 'web_$i') ? 'showing' : 'disabled';
    }
  }

  // ===========================================================================
  // Events
  // ===========================================================================

  @override
  Stream<AVPlayerEvent> playerEvents(int playerId) {
    final player = _players[playerId];
    if (player == null) {
      return const Stream.empty();
    }
    return player.eventController.stream;
  }

  /// Returns the view type string for embedding the video element of
  /// [playerId] in an [HtmlElementView].
  static String viewType(int playerId) => '$_viewTypePrefix$playerId';
}

// =============================================================================
// Internal player instance
// =============================================================================

/// Manages a single HTML5 `<video>` element and its associated event streams.
class _WebPlayerInstance {
  _WebPlayerInstance(this.id, AVVideoSource source) {
    _setupVideoElement(source);
    _attachEventListeners();
  }

  final int id;

  /// The underlying HTML5 video element.
  late final web.HTMLVideoElement videoElement;

  /// Dart-side event controller that feeds [AvPlayerWeb.playerEvents].
  final StreamController<AVPlayerEvent> eventController =
      StreamController<AVPlayerEvent>.broadcast();

  /// Position polling timer.
  Timer? _positionTimer;

  /// Tracks whether the media session handlers are currently registered.
  bool _mediaSessionActive = false;

  // ---------------------------------------------------------------------------
  // Setup
  // ---------------------------------------------------------------------------

  void _setupVideoElement(AVVideoSource source) {
    videoElement = web.HTMLVideoElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.setProperty('object-fit', 'contain')
      ..autoplay = false
      ..controls = false
      ..playsInline = true;

    switch (source) {
      case AVNetworkSource(:final url, :final headers):
        // Headers can't be set on <video> src directly.
        // For simple URLs, set src. For headers, use fetch + blob.
        if (headers.isEmpty) {
          videoElement.src = url;
        } else {
          _loadWithHeaders(url, headers);
        }
      case AVAssetSource(:final assetPath):
        // Flutter web assets are served from the assets directory.
        videoElement.src = 'assets/$assetPath';
      case AVFileSource(:final filePath):
        // On web, file paths are URLs (blob: or data: URIs).
        videoElement.src = filePath;
    }
  }

  /// Fetches a video URL with custom headers and loads it as a blob.
  void _loadWithHeaders(String url, Map<String, String> headers) {
    final jsHeaders = web.Headers();
    for (final entry in headers.entries) {
      jsHeaders.append(entry.key, entry.value);
    }
    final init = web.RequestInit(headers: jsHeaders);
    web.window
        .fetch(url.toJS, init)
        .toDart
        .then((response) => response.blob().toDart)
        .then((blob) {
      videoElement.src = web.URL.createObjectURL(blob);
    });
  }

  // ---------------------------------------------------------------------------
  // Event listeners
  // ---------------------------------------------------------------------------

  void _attachEventListeners() {
    videoElement.addEventListener('loadedmetadata', _onLoadedMetadata.toJS);
    videoElement.addEventListener('play', _onPlay.toJS);
    videoElement.addEventListener('pause', _onPause.toJS);
    videoElement.addEventListener('ended', _onEnded.toJS);
    videoElement.addEventListener('error', _onError.toJS);
    videoElement.addEventListener('waiting', _onWaiting.toJS);
    videoElement.addEventListener('playing', _onPlaying.toJS);
    videoElement.addEventListener('progress', _onProgress.toJS);
    videoElement.addEventListener(
      'enterpictureinpicture',
      _onEnterPip.toJS,
    );
    videoElement.addEventListener(
      'leavepictureinpicture',
      _onLeavePip.toJS,
    );
  }

  void _onLoadedMetadata(web.Event _) {
    final duration = Duration(
      milliseconds: (videoElement.duration * 1000).round(),
    );
    eventController.add(AVInitializedEvent(
      duration: duration,
      width: videoElement.videoWidth.toDouble(),
      height: videoElement.videoHeight.toDouble(),
      textureId: id,
    ));

    // Start position polling.
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => _reportPosition(),
    );
  }

  void _onPlay(web.Event _) {
    eventController.add(
      const AVPlaybackStateChangedEvent(state: AVPlaybackState.playing),
    );
  }

  void _onPause(web.Event _) {
    eventController.add(
      const AVPlaybackStateChangedEvent(state: AVPlaybackState.paused),
    );
  }

  void _onEnded(web.Event _) {
    eventController.add(const AVCompletedEvent());
  }

  void _onError(web.Event _) {
    final error = videoElement.error;
    eventController.add(AVErrorEvent(
      message: error?.message ?? 'Unknown error',
      code: error?.code.toString(),
    ));
  }

  void _onWaiting(web.Event _) {
    eventController.add(
      const AVPlaybackStateChangedEvent(state: AVPlaybackState.buffering),
    );
  }

  void _onPlaying(web.Event _) {
    eventController.add(
      const AVPlaybackStateChangedEvent(state: AVPlaybackState.playing),
    );
  }

  void _onProgress(web.Event _) {
    _reportBuffered();
  }

  void _onEnterPip(web.Event _) {
    eventController.add(const AVPipChangedEvent(isInPipMode: true));
  }

  void _onLeavePip(web.Event _) {
    eventController.add(const AVPipChangedEvent(isInPipMode: false));
  }

  void _reportPosition() {
    if (videoElement.readyState < 1) return;
    final ms = (videoElement.currentTime * 1000).round();
    eventController.add(
      AVPositionChangedEvent(position: Duration(milliseconds: ms)),
    );
  }

  void _reportBuffered() {
    final buffered = videoElement.buffered;
    if (buffered.length > 0) {
      final end = buffered.end(buffered.length - 1);
      eventController.add(
        AVBufferingUpdateEvent(
          buffered: Duration(milliseconds: (end * 1000).round()),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Media Session
  // ---------------------------------------------------------------------------

  void registerMediaSessionHandlers() {
    if (_mediaSessionActive) return;
    _mediaSessionActive = true;

    final session = web.window.navigator.mediaSession;

    session.setActionHandler(
      'play',
      ((JSAny? _) {
        videoElement.play();
        eventController.add(const AVMediaCommandEvent(
          command: AVMediaCommand.play,
        ));
      }).toJS,
    );

    session.setActionHandler(
      'pause',
      ((JSAny? _) {
        videoElement.pause();
        eventController.add(const AVMediaCommandEvent(
          command: AVMediaCommand.pause,
        ));
      }).toJS,
    );

    session.setActionHandler(
      'nexttrack',
      ((JSAny? _) {
        eventController.add(const AVMediaCommandEvent(
          command: AVMediaCommand.next,
        ));
      }).toJS,
    );

    session.setActionHandler(
      'previoustrack',
      ((JSAny? _) {
        eventController.add(const AVMediaCommandEvent(
          command: AVMediaCommand.previous,
        ));
      }).toJS,
    );

    session.setActionHandler(
      'seekto',
      ((JSAny? details) {
        if (details != null) {
          final seekDetails = details as _SeekToActionDetails;
          final seekTime = seekDetails.seekTime;
          if (seekTime != null) {
            videoElement.currentTime = seekTime;
            eventController.add(AVMediaCommandEvent(
              command: AVMediaCommand.seekTo,
              seekPosition: Duration(
                milliseconds: (seekTime * 1000).round(),
              ),
            ));
          }
        }
      }).toJS,
    );

    session.setActionHandler(
      'stop',
      ((JSAny? _) {
        videoElement.pause();
        videoElement.currentTime = 0;
        eventController.add(const AVMediaCommandEvent(
          command: AVMediaCommand.stop,
        ));
      }).toJS,
    );
  }

  void removeMediaSessionHandlers() {
    if (!_mediaSessionActive) return;
    _mediaSessionActive = false;

    final session = web.window.navigator.mediaSession;
    session.setActionHandler('play', null);
    session.setActionHandler('pause', null);
    session.setActionHandler('nexttrack', null);
    session.setActionHandler('previoustrack', null);
    session.setActionHandler('seekto', null);
    session.setActionHandler('stop', null);
    session.metadata = null;
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  void dispose() {
    _positionTimer?.cancel();
    removeMediaSessionHandlers();
    videoElement.pause();
    videoElement.src = '';
    videoElement.load(); // Forces release of media resources.
    eventController.close();
  }
}
