import 'pigeon_av_player.dart';

/// Default fallback implementation of [AvPlayerPlatform] that uses
/// the Pigeon-generated [AvPlayerHostApi] under the hood.
///
/// Platform-specific packages (Android, iOS, etc.) register their own
/// implementations that override this.
class MethodChannelAvPlayer extends PigeonAvPlayer {
  MethodChannelAvPlayer() : super(eventChannelPrefix: 'av_player');
}
