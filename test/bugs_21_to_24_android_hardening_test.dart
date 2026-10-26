import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unified_home/services/master/presence_and_os_bridge.dart';
import 'package:unified_home/services/notifications/appliance_notification_bridge.dart';
import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Bug 21: Cold-Start Deep Links Tests', () {
    const MethodChannel osChannel =
        MethodChannel('com.antigravity.home.unified_home/master_os');
    final List<MethodCall> methodCalls = [];
    String? mockInitialDeepLink = 'unifiedhome://oauth-callback?code=abc12345';

    setUp(() {
      methodCalls.clear();
      mockInitialDeepLink = 'unifiedhome://oauth-callback?code=abc12345';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(osChannel, (MethodCall call) async {
        methodCalls.add(call);
        if (call.method == 'getInitialDeepLink') {
          final link = mockInitialDeepLink;
          mockInitialDeepLink = null;
          return link;
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(osChannel, null);
    });

    test('getInitialDeepLink retrieves and consumes pending cold-start link',
        () async {
      final bridge = PresenceAndOsBridge();
      final link = await bridge.getInitialDeepLink();
      expect(link, equals('unifiedhome://oauth-callback?code=abc12345'));

      // Second retrieval should return null (single-consumption)
      final secondLink = await bridge.getInitialDeepLink();
      expect(secondLink, isNull);
    });

    test(
        'initializeOsListeners queries getInitialDeepLink and triggers callback on cold start',
        () async {
      final bridge = PresenceAndOsBridge();
      String? receivedUri;

      bridge.initializeOsListeners(
        onNfcOrDeepLinkTriggered: (uri) {
          receivedUri = uri;
        },
        onIncomingPhoneCallDetected: () {},
      );

      // Yield microtasks to allow .then() to execute
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(receivedUri, equals('unifiedhome://oauth-callback?code=abc12345'));
      expect(
        methodCalls.any((call) => call.method == 'getInitialDeepLink'),
        isTrue,
      );
    });

    test('warm-start deep link dispatches via method call handler', () async {
      final bridge = PresenceAndOsBridge();
      mockInitialDeepLink = null;
      String? warmUri;

      bridge.initializeOsListeners(
        onNfcOrDeepLinkTriggered: (uri) {
          warmUri = uri;
        },
        onIncomingPhoneCallDetected: () {},
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Simulate onNewIntent invoking onDeepLink
      final ByteData data = const StandardMethodCodec().encodeMethodCall(
        const MethodCall('onDeepLink', 'unifiedhome://open-room/kitchen'),
      );

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'com.antigravity.home.unified_home/master_os',
        data,
        (ByteData? reply) {},
      );

      expect(warmUri, equals('unifiedhome://open-room/kitchen'));
    });
  });

  group('Bug 22: Appliance Notification Bridge Alert Tests', () {
    const MethodChannel notificationChannel =
        MethodChannel('com.antigravity.home/notifications');
    final List<MethodCall> notificationCalls = [];

    setUp(() {
      notificationCalls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(notificationChannel,
              (MethodCall call) async {
        notificationCalls.add(call);
        return true;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(notificationChannel, null);
    });

    test('triggerApplianceAlert dispatches correctly with parameters',
        () async {
      await ApplianceNotificationBridge.triggerApplianceAlert(
        title: '🧺 Washer Done',
        body: 'Clean laundry ready to unload',
        withChime: true,
        withVibration: true,
        notificationId: 1002,
      );

      expect(notificationCalls.length, equals(1));
      final call = notificationCalls.first;
      expect(call.method, equals('triggerApplianceAlert'));
      expect(call.arguments['title'], equals('🧺 Washer Done'));
      expect(call.arguments['body'], equals('Clean laundry ready to unload'));
      expect(call.arguments['withChime'], isTrue);
      expect(call.arguments['withVibration'], isTrue);
      expect(call.arguments['notificationId'], equals(1002));
    });
  });

  group('Bug 23: 24/7 Node Server ForegroundService & WakeLock Config Tests',
      () {
    test('AndroidManifest contains NodeServerForegroundService registration',
        () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue);
      final content = manifestFile.readAsStringSync();
      expect(content.contains('.NodeServerForegroundService'), isTrue);
      expect(content.contains('foregroundServiceType="connectedDevice"'), isTrue);
      expect(content.contains('FOREGROUND_SERVICE_CONNECTED_DEVICE'), isTrue);
    });

    test('NodeServerForegroundService.kt exists and acquires indefinite WakeLock',
        () {
      final serviceFile = File(
          'android/app/src/main/kotlin/com/antigravity/home/unified_home/NodeServerForegroundService.kt');
      expect(serviceFile.existsSync(), isTrue);
      final content = serviceFile.readAsStringSync();
      expect(content.contains('class NodeServerForegroundService'), isTrue);
      expect(content.contains('startForeground'), isTrue);
      expect(content.contains('acquire()'), isTrue);
      // Ensure no 24-hour timeout (86400000)
      expect(content.contains('24 * 60 * 60 * 1000L'), isFalse);
    });

    test('MainActivity.kt starts NodeServerForegroundService on enableNodeKeepAlive',
        () {
      final activityFile = File(
          'android/app/src/main/kotlin/com/antigravity/home/unified_home/MainActivity.kt');
      expect(activityFile.existsSync(), isTrue);
      final content = activityFile.readAsStringSync();
      expect(content.contains('NodeServerForegroundService::class.java'), isTrue);
      expect(content.contains('startForegroundService(serviceIntent)'), isTrue);
      expect(content.contains('stopService(serviceIntent)'), isTrue);
      // Ensure no 24-hour timeout remaining in MainActivity
      expect(content.contains('acquire(24 * 60 * 60 * 1000L)'), isFalse);
    });
  });

  group('Bug 24: Release Keystore & ProGuard Rules Configuration Tests', () {
    test('build.gradle.kts configures release signing config and ProGuard',
        () {
      final gradleFile = File('android/app/build.gradle.kts');
      expect(gradleFile.existsSync(), isTrue);
      final content = gradleFile.readAsStringSync();
      expect(content.contains('keystorePropertiesFile'), isTrue);
      expect(content.contains('key.properties'), isTrue);
      expect(content.contains('signingConfigs {'), isTrue);
      expect(content.contains('create("release")'), isTrue);
      expect(content.contains('isMinifyEnabled = true'), isTrue);
      expect(content.contains('isShrinkResources = true'), isTrue);
      expect(content.contains('proguard-rules.pro'), isTrue);
    });

    test('proguard-rules.pro exists and preserves Flutter and media_kit bindings',
        () {
      final proguardFile = File('android/app/proguard-rules.pro');
      expect(proguardFile.existsSync(), isTrue);
      final content = proguardFile.readAsStringSync();
      expect(content.contains('io.flutter'), isTrue);
      expect(content.contains('com.alexmercerind.media_kit'), isTrue);
      expect(content.contains('JavascriptInterface'), isTrue);
    });

    test('key.properties.example exists for reference', () {
      final exampleFile = File('android/key.properties.example');
      expect(exampleFile.existsSync(), isTrue);
      final content = exampleFile.readAsStringSync();
      expect(content.contains('storePassword='), isTrue);
      expect(content.contains('keyAlias='), isTrue);
    });
  });
}
