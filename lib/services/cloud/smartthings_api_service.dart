import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/device_model.dart';

class SmartThingsApiService {
  final String apiBaseUrl;
  String? _bearerToken;
  final http.Client _client;

  SmartThingsApiService({
    this.apiBaseUrl = 'https://api.smartthings.com/v1',
    http.Client? client,
  }) : _client = client ?? http.Client();

  void setAuthToken(String token) {
    _bearerToken = token.trim();
  }

  String? get authToken => _bearerToken;

  bool get isAuthenticated => _bearerToken != null && _bearerToken!.isNotEmpty;

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_bearerToken',
        'Content-Type': 'application/json',
        'Accept': 'application/vnd.smartthings+json;v=1',
      };

  /// Validate provided Personal Access Token against SmartThings Cloud
  Future<bool> validateToken() async {
    if (!isAuthenticated) return false;
    try {
      final response = await _client.get(
        Uri.parse('$apiBaseUrl/devices'),
        headers: _headers,
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Fetch devices from SmartThings Cloud
  Future<List<Map<String, dynamic>>> listDevices() async {
    if (!isAuthenticated) {
      return [
        {
          'deviceId': 'st_plug_01',
          'label': 'SmartThings Outlet',
          'deviceManufacturerCode': 'Samsung Electronics',
          'components': [
            {
              'id': 'main',
              'capabilities': [
                {'id': 'switch'},
                {'id': 'powerMeter'},
                {'id': 'energyMeter'},
              ],
            }
          ],
        },
      ];
    }

    final response = await _client.get(
      Uri.parse('$apiBaseUrl/devices'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>? ?? [];
      return items.cast<Map<String, dynamic>>();
    }
    throw Exception('SmartThings API error: ${response.statusCode} - ${response.body}');
  }

  /// Get live telemetry status of a device
  Future<Map<String, dynamic>> getDeviceStatus(String deviceId) async {
    if (!isAuthenticated) return {};

    try {
      final response = await _client.get(
        Uri.parse('$apiBaseUrl/devices/$deviceId/status'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {};
  }

  /// Execute standard capability command (e.g. switch on/off, level, etc.)
  Future<bool> executeCommand({
    required String deviceId,
    required String capability,
    required String command,
    List<dynamic> arguments = const [],
  }) async {
    if (!isAuthenticated) return true;

    try {
      final body = jsonEncode({
        'commands': [
          {
            'component': 'main',
            'capability': capability,
            'command': command,
            'arguments': arguments,
          }
        ]
      });

      final response = await _client.post(
        Uri.parse('$apiBaseUrl/devices/$deviceId/commands'),
        headers: _headers,
        body: body,
      );

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Dispatch Samsung Washer commands
  Future<bool> sendWasherCommand({
    required String deviceId,
    required String action,
    List<dynamic> args = const [],
  }) async {
    switch (action) {
      case 'start':
        return executeCommand(
          deviceId: deviceId,
          capability: 'washerOperatingState',
          command: 'setWasherJobState',
          arguments: ['wash'],
        );
      case 'pause':
        return executeCommand(
          deviceId: deviceId,
          capability: 'washerOperatingState',
          command: 'pause',
        );
      case 'setWaterTemp':
        return executeCommand(
          deviceId: deviceId,
          capability: 'custom.washerWaterTemperature',
          command: 'setWasherWaterTemperature',
          arguments: args,
        );
      case 'setSpinSpeed':
        return executeCommand(
          deviceId: deviceId,
          capability: 'custom.washerSpinSpeed',
          command: 'setWasherSpinSpeed',
          arguments: args,
        );
      case 'setCycle':
        return executeCommand(
          deviceId: deviceId,
          capability: 'samsungce.washerCycle',
          command: 'setWasherCycle',
          arguments: args,
        );
      default:
        return executeCommand(
          deviceId: deviceId,
          capability: 'switch',
          command: action,
          arguments: args,
        );
    }
  }

  /// Convert SmartThings Cloud JSON device to our SmartDevice domain model
  SmartDevice? parseSmartThingsDevice(Map<String, dynamic> raw) {
    final deviceId = raw['deviceId'] as String? ?? '';
    final label = (raw['label'] as String?)?.isNotEmpty == true
        ? raw['label'] as String
        : (raw['name'] as String? ?? 'Samsung Device');
    final roomName = raw['roomId'] != null ? 'Main Room' : 'Laundry Room';

    final components = raw['components'] as List<dynamic>? ?? [];
    final capabilities = <String>{};
    for (final comp in components) {
      final caps = (comp as Map<String, dynamic>)['capabilities'] as List<dynamic>? ?? [];
      for (final c in caps) {
        capabilities.add((c as Map<String, dynamic>)['id'] as String);
      }
    }

    if (capabilities.contains('washerOperatingState') ||
        capabilities.contains('washerCycle') ||
        label.toLowerCase().contains('washer') ||
        label.toLowerCase().contains('washing')) {
      return WasherDevice(
        id: 'st_$deviceId',
        name: label,
        room: 'Laundry Room',
        protocol: DeviceProtocol.smartThings,
        cloudDeviceId: deviceId,
        brand: 'Samsung SmartThings',
        isDummy: false,
        ecoBubbleEnabled: true,
        aiWashEnabled: true,
      );
    } else if (capabilities.contains('thermostatCoolingSetpoint') ||
        capabilities.contains('airConditionerMode') ||
        label.toLowerCase().contains('ac') ||
        label.toLowerCase().contains('air conditioner')) {
      return ThermostatDevice(
        id: 'st_$deviceId',
        name: label,
        room: roomName,
        protocol: DeviceProtocol.smartThings,
        cloudDeviceId: deviceId,
        brand: 'Samsung WindFree',
        isDummy: false,
      );
    } else if (capabilities.contains('switchLevel') ||
        capabilities.contains('colorControl') ||
        capabilities.contains('colorTemperature') ||
        label.toLowerCase().contains('light') ||
        label.toLowerCase().contains('bulb')) {
      return LightDevice(
        id: 'st_$deviceId',
        name: label,
        room: roomName,
        protocol: DeviceProtocol.smartThings,
        cloudDeviceId: deviceId,
        brand: 'SmartThings Light',
        isDummy: false,
      );
    } else if (capabilities.contains('tvChannel') ||
        capabilities.contains('mediaPlayback') ||
        label.toLowerCase().contains('tv')) {
      return TvDevice(
        id: 'st_$deviceId',
        name: label,
        room: 'Living Room',
        protocol: DeviceProtocol.smartThings,
        cloudDeviceId: deviceId,
        isDummy: false,
      );
    }

    return LightDevice(
      id: 'st_$deviceId',
      name: label,
      room: roomName,
      protocol: DeviceProtocol.smartThings,
      cloudDeviceId: deviceId,
      brand: 'SmartThings Outlet',
      isDummy: false,
    );
  }
}
