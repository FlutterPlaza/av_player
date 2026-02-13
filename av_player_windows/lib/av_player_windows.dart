import 'package:av_player_platform_interface/av_player_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The Windows implementation of [AvPlayerPlatform].
class AvPlayerWindows extends AvPlayerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('av_player_windows');

  /// Registers this class as the default instance of [AvPlayerPlatform]
  static void registerWith() {
    AvPlayerPlatform.instance = AvPlayerWindows();
  }

  @override
  Future<String?> getPlatformName() {
    return methodChannel.invokeMethod<String>('getPlatformName');
  }
}
