import 'package:av_player/src/platform/av_player_windows.dart';
import 'package:av_player/src/platform/av_player_platform.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AvPlayerWindows', () {
    late AvPlayerWindows platform;
    final log = <MethodCall>[];

    setUp(() {
      platform = AvPlayerWindows();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        platform.methodChannel,
        (methodCall) async {
          log.add(methodCall);
          switch (methodCall.method) {
            case 'getPlatformName':
              return 'Windows';
            default:
              return null;
          }
        },
      );
    });

    tearDown(() {
      log.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(platform.methodChannel, null);
    });

    // -------------------------------------------------------------------------
    // Registration
    // -------------------------------------------------------------------------

    test('registerWith() sets platform instance', () {
      AvPlayerWindows.registerWith();
      expect(
        AvPlayerPlatform.instance,
        isA<AvPlayerWindows>(),
      );
    });

    test('uses correct method channel name', () {
      expect(
        platform.methodChannel.name,
        'av_player_windows',
      );
    });
  });
}
