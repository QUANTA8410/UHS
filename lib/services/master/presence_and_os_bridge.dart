import 'dart:async';
import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';

class PresenceAndOsBridge {
  static const MethodChannel _osChannel =
      MethodChannel('com.antigravity.home.unified_home/master_os');

  final NetworkInfo _networkInfo = NetworkInfo();
  String? homeRouterBssid;
  bool isUserAtHome = true;

  void initializeOsListeners({
    required void Function(String deepLinkUri) onNfcOrDeepLinkTriggered,
    required void Function() onIncomingPhoneCallDetected,
  }) {
    _osChannel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink') {
        final uri = call.arguments?.toString() ?? '';
        if (uri.isNotEmpty) onNfcOrDeepLinkTriggered(uri);
      } else if (call.method == 'onIncomingCall') {
        onIncomingPhoneCallDetected();
      }
    });
  }

  // ---------------------------------------------------------------------------
  // PILLAR 4: WI-FI BSSID ZERO-GPS HOME/AWAY GEOFENCING
  // ---------------------------------------------------------------------------
  Future<String?> getCurrentRouterBssid() async {
    try {
      return await _networkInfo.getWifiBSSID();
    } catch (_) {
      return null;
    }
  }

  Future<bool?> checkPresenceTransition() async {
    if (homeRouterBssid == null || homeRouterBssid!.isEmpty) return null;
    final currentBssid = await getCurrentRouterBssid();
    final nowHome =
        currentBssid != null && currentBssid.toLowerCase() == homeRouterBssid!.toLowerCase();

    if (nowHome != isUserAtHome) {
      isUserAtHome = nowHome;
      return nowHome; // true = Just Arrived Home, false = Just Left Home
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // PILLAR 5: LIVE SAMSUNG WASHER LOCK-SCREEN NOTIFICATION & QUICK TILES
  // ---------------------------------------------------------------------------
  Future<void> showLiveApplianceNotification({
    required String title,
    required String subtitle,
    required int progressPercent,
  }) async {
    try {
      await _osChannel.invokeMethod('updateLiveNotification', {
        'title': title,
        'subtitle': subtitle,
        'progress': progressPercent.clamp(0, 100),
      });
    } catch (_) {}
  }

  Future<void> dismissLiveApplianceNotification() async {
    try {
      await _osChannel.invokeMethod('dismissLiveNotification');
    } catch (_) {}
  }
}
