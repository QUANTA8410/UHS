import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unified_home/services/master/presence_and_os_bridge.dart';
import 'package:unified_home/services/notifications/appliance_notification_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Bug 11: Android Permissions & Runtime Requests Tests', () {
    test('AndroidManifest.xml declares all required hardware, location, and background permissions', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue, reason: 'AndroidManifest.xml must exist');

      final content = manifestFile.readAsStringSync();

      // Hardware wake lock for 24/7 NodeServer
      expect(content, contains('android.permission.WAKE_LOCK'),
          reason: 'WAKE_LOCK permission is required for CPU partial wake lock');

      // Location permissions for Wi-Fi BSSID / SSID home presence geofencing
      expect(content, contains('android.permission.ACCESS_FINE_LOCATION'),
          reason: 'ACCESS_FINE_LOCATION is required to read Wi-Fi BSSID on Android');
      expect(content, contains('android.permission.ACCESS_COARSE_LOCATION'),
          reason: 'ACCESS_COARSE_LOCATION is required for location resolution');
      expect(content, contains('android.permission.ACCESS_BACKGROUND_LOCATION'),
          reason: 'ACCESS_BACKGROUND_LOCATION is required for geofencing');

      // Android 14+ Foreground Service types
      expect(content, contains('android.permission.FOREGROUND_SERVICE'),
          reason: 'FOREGROUND_SERVICE is required');
      expect(content, contains('android.permission.FOREGROUND_SERVICE_CONNECTED_DEVICE'),
          reason: 'FOREGROUND_SERVICE_CONNECTED_DEVICE is required for smart home IoT node server');
      expect(content, contains('android.permission.FOREGROUND_SERVICE_DATA_SYNC'),
          reason: 'FOREGROUND_SERVICE_DATA_SYNC is required for telemetry sync');

      // NEARBY_WIFI_DEVICES should not assert neverForLocation because BSSID is used for physical location
      expect(content, contains('android.permission.NEARBY_WIFI_DEVICES'));
      expect(content, isNot(contains('NEARBY_WIFI_DEVICES" android:usesPermissionFlags="neverForLocation"')));
    });

    test('PresenceAndOsBridge invokes location permission channel methods', () async {
      final osChannel = const MethodChannel('com.antigravity.home.unified_home/master_os');
      final calls = <String>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        osChannel,
        (MethodCall call) async {
          calls.add(call.method);
          if (call.method == 'requestLocationPermission') {
            return true;
          }
          if (call.method == 'hasLocationPermission') {
            return true;
          }
          return null;
        },
      );

      final bridge = PresenceAndOsBridge();

      final hasPermission = await bridge.hasLocationPermission();
      expect(hasPermission, isTrue);
      expect(calls, contains('hasLocationPermission'));

      final requested = await bridge.requestLocationPermission();
      expect(requested, isTrue);
      expect(calls, contains('requestLocationPermission'));
    });

    test('ApplianceNotificationBridge invokes notification and location permission channel methods', () async {
      final notifChannel = const MethodChannel('com.antigravity.home/notifications');
      final calls = <String>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        notifChannel,
        (MethodCall call) async {
          calls.add(call.method);
          if (call.method == 'requestLocationPermission') {
            return true;
          }
          if (call.method == 'hasLocationPermission') {
            return true;
          }
          return true;
        },
      );

      final hasPerm = await ApplianceNotificationBridge.hasLocationPermission();
      expect(hasPerm, isTrue);
      expect(calls, contains('hasLocationPermission'));

      final reqPerm = await ApplianceNotificationBridge.requestLocationPermission();
      expect(reqPerm, isTrue);
      expect(calls, contains('requestLocationPermission'));
    });
  });
}
