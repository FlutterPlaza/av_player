import 'package:av_player_platform_interface/av_player_platform_interface.dart';
import 'package:av_player_windows/av_player_windows.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AvPlayerWindows', () {
    const kPlatformName = 'Windows';
    late AvPlayerWindows avPictureInPicture;
    late List<MethodCall> log;

    setUp(() async {
      avPictureInPicture = AvPlayerWindows();

      log = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(avPictureInPicture.methodChannel, (methodCall) async {
        log.add(methodCall);
        switch (methodCall.method) {
          case 'getPlatformName':
            return kPlatformName;
          default:
            return null;
        }
      });
    });

    test('can be registered', () {
      AvPlayerWindows.registerWith();
      expect(AvPlayerPlatform.instance, isA<AvPlayerWindows>());
    });

    test('getPlatformName returns correct name', () async {
      final name = await avPictureInPicture.getPlatformName();
      expect(
        log,
        <Matcher>[isMethodCall('getPlatformName', arguments: null)],
      );
      expect(name, equals(kPlatformName));
    });
  });
}
