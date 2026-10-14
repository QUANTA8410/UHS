import 'dart:async';
import '../real_iot_controller.dart';

class SmartThingsApiService {
  final RealIotController _controller = RealIotController();
  String? _bearerToken;

  void setAuthToken(String token) {
    _bearerToken = token.trim();
  }

  String? get authToken => _bearerToken;
  bool get isAuthenticated => _bearerToken != null && _bearerToken!.isNotEmpty;

  Future<bool> validateToken() async {
    if (!isAuthenticated) return false;
    try {
      final devs = await _controller.discoverSmartThingsDevices(_bearerToken!);
      return devs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<List<RealSmartDevice>> listDevices() async {
    if (!isAuthenticated) return [];
    try {
      return await _controller.discoverSmartThingsDevices(_bearerToken!);
    } catch (_) {
      return [];
    }
  }

  Future<bool> executeCommand({
    required RealSmartDevice device,
    required bool power,
    double? primaryLevel,
  }) async {
    await _controller.setPower(device, power);
    if (primaryLevel != null) {
      await _controller.setPrimaryLevel(device, primaryLevel);
    }
    return true;
  }
}
