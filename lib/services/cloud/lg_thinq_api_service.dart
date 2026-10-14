import 'dart:async';
import '../real_iot_controller.dart';
import '../master/zero_touch_onboarding_service.dart';

class LgThinqApiService {
  final ZeroTouchOnboardingService _zeroTouch = ZeroTouchOnboardingService();
  final RealIotController _controller = RealIotController();
  String? _accessToken;

  void setSessionToken(String token) {
    _accessToken = token.trim();
  }

  String? get accessToken => _accessToken;
  bool get isAuthenticated => _accessToken != null && _accessToken!.isNotEmpty;

  Future<bool> validateToken() async {
    if (!isAuthenticated) return false;
    try {
      final devices = await _zeroTouch.discoverLgThinqDevices(patToken: _accessToken!);
      return devices.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<List<RealSmartDevice>> listDevices() async {
    if (!isAuthenticated) return [];
    try {
      return await _zeroTouch.discoverLgThinqDevices(patToken: _accessToken!);
    } catch (_) {
      return [];
    }
  }

  Future<bool> sendControlCommand({
    required RealSmartDevice device,
    required bool power,
    double? temperature,
  }) async {
    await _controller.setPower(device, power);
    if (temperature != null) {
      await _controller.setPrimaryLevel(device, temperature);
    }
    return true;
  }
}
