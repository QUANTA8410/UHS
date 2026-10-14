import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/device_model.dart';

class LgThinqApiService {
  final String gatewayUrl;
  String? _accessToken;
  final http.Client _client;

  LgThinqApiService({
    this.gatewayUrl = 'https://eic-service.lgthinq.com:46030/api',
    http.Client? client,
  }) : _client = client ?? http.Client();

  void setSessionToken(String token) {
    _accessToken = token.trim();
  }

  String? get accessToken => _accessToken;

  bool get isAuthenticated => _accessToken != null && _accessToken!.isNotEmpty;

  Map<String, String> get _headers => {
        'x-thinq-token': _accessToken ?? '',
        'x-country-code': 'IN',
        'x-language-code': 'en-IN',
        'Content-Type': 'application/json',
      };

  /// Validate session token
  Future<bool> validateToken() async {
    if (!isAuthenticated) return false;
    try {
      final response = await _client.get(
        Uri.parse('$gatewayUrl/device/devices'),
        headers: _headers,
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// List LG ThinQ appliances
  Future<List<Map<String, dynamic>>> listDevices() async {
    if (!isAuthenticated) {
      return [];
    }

    try {
      final response = await _client.get(
        Uri.parse('$gatewayUrl/device/devices'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final items = data['item'] as List<dynamic>? ?? [];
        return items.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  /// Query appliance telemetry shadow (Wash cycles, fridge temperatures, AC target)
  Future<Map<String, dynamic>> getApplianceShadow(String deviceId) async {
    if (!isAuthenticated) {
      return {
        'deviceId': deviceId,
        'washer': {
          'cycle': 'TurboWash 39',
          'stage': 'WASH',
          'remainTime': 19,
          'waterTemp': 40,
          'spinSpeed': 'MAX',
          'steam': true,
          'turboWash': true,
        },
        'refrigerator': {
          'fridgeTemp': 3,
          'freezerTemp': -19,
          'craftIce': 'SIX_PER_DAY',
          'expressFreeze': false,
          'filterPercent': 86,
        },
      };
    }

    try {
      final response = await _client.get(
        Uri.parse('$gatewayUrl/device/devices/$deviceId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {};
  }

  /// Send LG appliance control command
  Future<bool> sendControlCommand({
    required String deviceId,
    required String commandType,
    required Map<String, dynamic> payload,
  }) async {
    if (!isAuthenticated) return true;

    try {
      final response = await _client.post(
        Uri.parse('$gatewayUrl/device/devices/$deviceId/control'),
        headers: _headers,
        body: jsonEncode({
          'command': commandType,
          'data': payload,
        }),
      );

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Convert LG raw device to our domain model
  SmartDevice? parseLgDevice(Map<String, dynamic> raw) {
    final deviceId = raw['deviceId'] as String? ?? '';
    final alias = raw['alias'] as String? ?? 'LG Appliance';
    final deviceType = raw['deviceType'] as int? ?? 401; // 401: AC, 201: Washer, 101: Refrigerator

    if (deviceType == 401 || alias.toLowerCase().contains('ac') || alias.toLowerCase().contains('air')) {
      return ThermostatDevice(
        id: 'lg_$deviceId',
        name: alias,
        room: 'Living Room',
        protocol: DeviceProtocol.lgThinQ,
        cloudDeviceId: deviceId,
        brand: 'LG DualCool',
        isDummy: false,
        jetCoolActive: false,
        airCleanActive: true,
      );
    } else if (deviceType == 201 || alias.toLowerCase().contains('washer')) {
      return WasherDevice(
        id: 'lg_$deviceId',
        name: alias,
        room: 'Laundry Room',
        protocol: DeviceProtocol.lgThinQ,
        cloudDeviceId: deviceId,
        brand: 'LG ThinQ',
        isDummy: false,
      );
    } else if (deviceType == 101 || alias.toLowerCase().contains('fridge') || alias.toLowerCase().contains('refrigerator')) {
      return RefrigeratorDevice(
        id: 'lg_$deviceId',
        name: alias,
        room: 'Kitchen',
        protocol: DeviceProtocol.lgThinQ,
        cloudDeviceId: deviceId,
        isDummy: false,
      );
    }

    return ThermostatDevice(
      id: 'lg_$deviceId',
      name: alias,
      room: 'Living Room',
      protocol: DeviceProtocol.lgThinQ,
      cloudDeviceId: deviceId,
      brand: 'LG ThinQ',
      isDummy: false,
    );
  }
}
