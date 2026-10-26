import 'package:flutter/services.dart';

/// Zero-dependency Native Android Notification & Audible Chime Alert Bridge
class ApplianceNotificationBridge {
  static const MethodChannel _channel = MethodChannel('com.antigravity.home/notifications');

  /// Requests POST_NOTIFICATIONS runtime permission on Android 13+ (API 33+)
  static Future<bool> requestPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('requestPermission');
      return res ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Requests ACCESS_FINE_LOCATION and ACCESS_COARSE_LOCATION permissions (Bug 11)
  static Future<bool> requestLocationPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('requestLocationPermission');
      return res ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Checks whether runtime location permission is granted
  static Future<bool> hasLocationPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('hasLocationPermission');
      return res ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Triggers a native heads-up notification with high importance, audible chime, and vibration
  static Future<void> triggerApplianceAlert({
    required String title,
    required String body,
    bool withChime = true,
    bool withVibration = true,
    int notificationId = 1002,
  }) async {
    try {
      await _channel.invokeMethod('triggerApplianceAlert', {
        'title': title,
        'body': body,
        'withChime': withChime,
        'withVibration': withVibration,
        'notificationId': notificationId,
      });
    } catch (_) {}
  }
}
