//
// Generated file. Do not edit.
// This file is generated from template in file `flutter_tools/lib/src/flutter_plugins.dart`.
//

// @dart = 3.4

import 'dart:io'; // flutter_ignore: dart_io_import.
import 'package:av_player/av_player.dart' as av_player;
import 'package:av_player/av_player.dart' as av_player;
import 'package:av_player/av_player.dart' as av_player;
import 'package:av_player/av_player.dart' as av_player;
import 'package:av_player/av_player.dart' as av_player;

@pragma('vm:entry-point')
class _PluginRegistrant {

  @pragma('vm:entry-point')
  static void register() {
    if (Platform.isAndroid) {
      try {
        av_player.AvPlayerAndroid.registerWith();
      } catch (err) {
        print(
          '`av_player` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

    } else if (Platform.isIOS) {
      try {
        av_player.AvPlayerIOS.registerWith();
      } catch (err) {
        print(
          '`av_player` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

    } else if (Platform.isLinux) {
      try {
        av_player.AvPlayerLinux.registerWith();
      } catch (err) {
        print(
          '`av_player` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

    } else if (Platform.isMacOS) {
      try {
        av_player.AvPlayerMacOS.registerWith();
      } catch (err) {
        print(
          '`av_player` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

    } else if (Platform.isWindows) {
      try {
        av_player.AvPlayerWindows.registerWith();
      } catch (err) {
        print(
          '`av_player` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

    }
  }
}
