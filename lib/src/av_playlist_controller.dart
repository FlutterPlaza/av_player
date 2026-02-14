import 'dart:math';

import 'platform/av_player_platform.dart';
import 'package:flutter/foundation.dart';

/// Repeat modes for playlist playback.
enum AVRepeatMode {
  /// No repeat. Playback stops after the last track.
  none,

  /// Repeat the current track indefinitely.
  one,

  /// Repeat the entire playlist.
  all,
}

/// Immutable state of the playlist.
@immutable
class AVPlaylistState {
  const AVPlaylistState({
    this.queue = const [],
    this.currentIndex = -1,
    this.repeatMode = AVRepeatMode.none,
    this.isShuffled = false,
  });

  final List<AVVideoSource> queue;
  final int currentIndex;
  final AVRepeatMode repeatMode;
  final bool isShuffled;

  /// The currently playing source, or null if the queue is empty.
  AVVideoSource? get currentSource =>
      currentIndex >= 0 && currentIndex < queue.length
          ? queue[currentIndex]
          : null;

  /// Whether there is a next track available.
  bool get hasNext {
    if (queue.isEmpty) return false;
    if (repeatMode == AVRepeatMode.all) return true;
    return currentIndex < queue.length - 1;
  }

  /// Whether there is a previous track available.
  bool get hasPrevious {
    if (queue.isEmpty) return false;
    if (repeatMode == AVRepeatMode.all) return true;
    return currentIndex > 0;
  }

  AVPlaylistState copyWith({
    List<AVVideoSource>? queue,
    int? currentIndex,
    AVRepeatMode? repeatMode,
    bool? isShuffled,
  }) {
    return AVPlaylistState(
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      repeatMode: repeatMode ?? this.repeatMode,
      isShuffled: isShuffled ?? this.isShuffled,
    );
  }
}

/// Manages a queue of video sources with navigation, repeat, and shuffle.
///
/// When the current track completes, the controller automatically advances
/// to the next track (respecting repeat mode and shuffle).
///
/// ```dart
/// final playlist = AVPlaylistController(
///   sources: [
///     AVVideoSource.network('https://example.com/video1.mp4'),
///     AVVideoSource.network('https://example.com/video2.mp4'),
///   ],
///   onSourceChanged: (source) async {
///     await playerController.dispose();
///     playerController = AVPlayerController(source);
///     await playerController.initialize();
///     await playerController.play();
///   },
/// );
/// ```
class AVPlaylistController extends ValueNotifier<AVPlaylistState> {
  AVPlaylistController({
    List<AVVideoSource> sources = const [],
    this.onSourceChanged,
  }) : super(AVPlaylistState(
          queue: List.unmodifiable(sources),
          currentIndex: sources.isEmpty ? -1 : 0,
        ));

  /// Called when the current source changes (next/previous/jump).
  /// The caller should use this to reinitialize the player controller.
  final ValueChanged<AVVideoSource>? onSourceChanged;

  final Random _random = Random();

  // Stores the original order when shuffled
  List<AVVideoSource>? _originalOrder;

  /// Adds a source to the end of the queue.
  void add(AVVideoSource source) {
    final newQueue = [...value.queue, source];
    final newIndex = value.currentIndex < 0 ? 0 : value.currentIndex;
    value = value.copyWith(
      queue: List.unmodifiable(newQueue),
      currentIndex: newIndex,
    );
    if (newQueue.length == 1) {
      _notifySourceChanged();
    }
  }

  /// Adds multiple sources to the end of the queue.
  void addAll(List<AVVideoSource> sources) {
    if (sources.isEmpty) return;
    final newQueue = [...value.queue, ...sources];
    final newIndex = value.currentIndex < 0 ? 0 : value.currentIndex;
    value = value.copyWith(
      queue: List.unmodifiable(newQueue),
      currentIndex: newIndex,
    );
    if (value.queue.length == sources.length) {
      _notifySourceChanged();
    }
  }

  /// Removes the source at [index] from the queue.
  void removeAt(int index) {
    if (index < 0 || index >= value.queue.length) return;
    final newQueue = [...value.queue]..removeAt(index);
    var newIndex = value.currentIndex;
    if (index < newIndex) {
      newIndex--;
    } else if (index == newIndex) {
      // Current track was removed
      if (newIndex >= newQueue.length) {
        newIndex = newQueue.isEmpty ? -1 : newQueue.length - 1;
      }
      value = value.copyWith(
        queue: List.unmodifiable(newQueue),
        currentIndex: newIndex,
      );
      if (newIndex >= 0) _notifySourceChanged();
      return;
    }
    value = value.copyWith(
      queue: List.unmodifiable(newQueue),
      currentIndex: newIndex,
    );
  }

  /// Moves a source from [oldIndex] to [newIndex].
  void reorder(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    final queue = [...value.queue];
    if (oldIndex < 0 || oldIndex >= queue.length) return;
    if (newIndex < 0 || newIndex >= queue.length) return;

    final item = queue.removeAt(oldIndex);
    queue.insert(newIndex, item);

    var currentIndex = value.currentIndex;
    if (currentIndex == oldIndex) {
      currentIndex = newIndex;
    } else {
      if (oldIndex < currentIndex && newIndex >= currentIndex) {
        currentIndex--;
      } else if (oldIndex > currentIndex && newIndex <= currentIndex) {
        currentIndex++;
      }
    }

    value = value.copyWith(
      queue: List.unmodifiable(queue),
      currentIndex: currentIndex,
    );
  }

  /// Clears the entire queue.
  void clear() {
    _originalOrder = null;
    value = const AVPlaylistState();
  }

  /// Jumps to the source at [index].
  void jumpTo(int index) {
    if (index < 0 || index >= value.queue.length) return;
    if (index == value.currentIndex) return;
    value = value.copyWith(currentIndex: index);
    _notifySourceChanged();
  }

  /// Advances to the next track.
  ///
  /// Returns `true` if there was a next track to advance to.
  bool next() {
    if (value.queue.isEmpty) return false;

    if (value.repeatMode == AVRepeatMode.one) {
      // Restart current track
      _notifySourceChanged();
      return true;
    }

    var nextIndex = value.currentIndex + 1;
    if (nextIndex >= value.queue.length) {
      if (value.repeatMode == AVRepeatMode.all) {
        nextIndex = 0;
      } else {
        return false;
      }
    }

    value = value.copyWith(currentIndex: nextIndex);
    _notifySourceChanged();
    return true;
  }

  /// Goes back to the previous track.
  ///
  /// Returns `true` if there was a previous track to go to.
  bool previous() {
    if (value.queue.isEmpty) return false;

    if (value.repeatMode == AVRepeatMode.one) {
      _notifySourceChanged();
      return true;
    }

    var prevIndex = value.currentIndex - 1;
    if (prevIndex < 0) {
      if (value.repeatMode == AVRepeatMode.all) {
        prevIndex = value.queue.length - 1;
      } else {
        return false;
      }
    }

    value = value.copyWith(currentIndex: prevIndex);
    _notifySourceChanged();
    return true;
  }

  /// Sets the repeat mode.
  void setRepeatMode(AVRepeatMode mode) {
    value = value.copyWith(repeatMode: mode);
  }

  /// Toggles shuffle on or off.
  void setShuffle(bool enabled) {
    if (enabled == value.isShuffled) return;

    if (enabled) {
      _originalOrder = List.of(value.queue);
      final currentSource = value.currentSource;
      final shuffled = [...value.queue]..shuffle(_random);

      // Keep current track at the front
      if (currentSource != null) {
        shuffled.remove(currentSource);
        shuffled.insert(0, currentSource);
      }

      value = value.copyWith(
        queue: List.unmodifiable(shuffled),
        currentIndex: 0,
        isShuffled: true,
      );
    } else {
      // Restore original order
      if (_originalOrder != null) {
        final currentSource = value.currentSource;
        final restoredIndex =
            currentSource != null ? _originalOrder!.indexOf(currentSource) : 0;
        value = value.copyWith(
          queue: List.unmodifiable(_originalOrder!),
          currentIndex: restoredIndex >= 0 ? restoredIndex : 0,
          isShuffled: false,
        );
        _originalOrder = null;
      } else {
        value = value.copyWith(isShuffled: false);
      }
    }
  }

  /// Called when the current track completes. Automatically advances
  /// to the next track based on repeat mode.
  ///
  /// Call this from the player controller's completion event handler.
  void onTrackCompleted() {
    next();
  }

  void _notifySourceChanged() {
    final source = value.currentSource;
    if (source != null) {
      onSourceChanged?.call(source);
    }
  }
}
