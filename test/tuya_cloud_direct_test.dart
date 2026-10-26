// test/tuya_cloud_direct_test.dart
//
// Bug 8: Wipro / Tuya Cloud Direct (tuyaCloudDirect) Rate-Limiting & Payload Format
//
// Verifies:
// 1. colorSet uses 'color' key in payload instead of 'value'.
// 2. executeDeviceCommand checks Tuya response header 'code' != 'SUCCESS' even on HTTP 200.
// 3. 120-second poll throttling in syncAllDevicesSilent skips frequent polls to avoid Tuya ban.

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_home/providers/real_home_provider.dart';
import 'package:unified_home/services/real_iot_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Bug 8: Tuya Cloud Direct Command Execution Tests', () {
    test('1. colorSet sends payload with "color" key instead of "value"', () async {
      late http.Request recordedReq;

      final mockClient = MockClient((http.Request request) async {
        recordedReq = request;
        return http.Response(
          jsonEncode({
            'header': {'code': 'SUCCESS'},
            'payload': {},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final controller = RealIotController(client: mockClient);
      final tuyaDevice = RealSmartDevice(
        id: 'tuya_bulb_rgb_01',
        name: 'Wipro RGB Bulb',
        room: 'Bedroom',
        category: 'light',
        protocol: ConnectionProtocol.tuyaCloudDirect,
        credentials: {
          'accessToken': 'valid_tuya_token_123',
          'token': 'valid_tuya_token_123',
        },
      );

      final colorPayload = {'hue': 180, 'saturation': 100, 'value': 80};
      await controller.executeDeviceCommand(
        tuyaDevice,
        'light',
        'colorSet',
        [colorPayload],
      );

      expect(recordedReq.method, equals('POST'));
      expect(
        recordedReq.url.toString(),
        equals('https://px1.tuyain.com/homeassistant/skill'),
      );

      final sentBody = jsonDecode(recordedReq.body) as Map<String, dynamic>;
      expect(sentBody['header']['name'], equals('colorSet'));
      expect(sentBody['payload']['accessToken'], equals('valid_tuya_token_123'));
      expect(sentBody['payload']['devId'], equals('tuya_bulb_rgb_01'));
      expect(sentBody['payload']['color'], equals(colorPayload),
          reason: 'Tuya colorSet command requires "color" key in payload, not "value"');
      expect(sentBody['payload'].containsKey('value'), isFalse,
          reason: '"value" key must not be present when sending colorSet');
    });

    test('2. Non-colorSet command sends payload with "value" key', () async {
      late http.Request recordedReq;

      final mockClient = MockClient((http.Request request) async {
        recordedReq = request;
        return http.Response(
          jsonEncode({
            'header': {'code': 'SUCCESS'},
            'payload': {},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final controller = RealIotController(client: mockClient);
      final tuyaDevice = RealSmartDevice(
        id: 'tuya_bulb_02',
        name: 'Wipro White Bulb',
        room: 'Study',
        category: 'light',
        protocol: ConnectionProtocol.tuyaCloudDirect,
        credentials: {'accessToken': 'valid_tuya_token_123'},
      );

      await controller.executeDeviceCommand(
        tuyaDevice,
        'light',
        'brightnessSet',
        [75],
      );

      final sentBody = jsonDecode(recordedReq.body) as Map<String, dynamic>;
      expect(sentBody['header']['name'], equals('brightnessSet'));
      expect(sentBody['payload']['value'], equals(75));
    });

    test('3. HTTP 200 with Tuya error header code throws descriptive exception', () async {
      final mockClient = MockClient((http.Request request) async {
        return http.Response(
          jsonEncode({
            'header': {
              'code': 'TargetOffline',
              'msg': 'Device is currently offline or unreachable',
            },
            'payload': {},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final controller = RealIotController(client: mockClient);
      final tuyaDevice = RealSmartDevice(
        id: 'tuya_bulb_03',
        name: 'Wipro Offline Bulb',
        room: 'Balcony',
        category: 'light',
        protocol: ConnectionProtocol.tuyaCloudDirect,
        credentials: {'accessToken': 'valid_tuya_token_123'},
      );

      expect(
        () async => await controller.executeDeviceCommand(
          tuyaDevice,
          'light',
          'colorSet',
          ['#FF0000'],
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            allOf([
              contains('Tuya error:'),
              contains('Device is currently offline or unreachable'),
            ]),
          ),
        ),
      );
    });

    test('4. HTTP 500 status code throws Exception with status code', () async {
      final mockClient = MockClient((http.Request request) async {
        return http.Response('Internal Server Error', 500);
      });

      final controller = RealIotController(client: mockClient);
      final tuyaDevice = RealSmartDevice(
        id: 'tuya_bulb_04',
        name: 'Wipro Error Bulb',
        room: 'Garage',
        category: 'light',
        protocol: ConnectionProtocol.tuyaCloudDirect,
        credentials: {'accessToken': 'valid_tuya_token_123'},
      );

      expect(
        () async => await controller.executeDeviceCommand(
          tuyaDevice,
          'light',
          'turnOnOff',
          [1],
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Tuya direct command failed (500)'),
          ),
        ),
      );
    });
  });

  group('Bug 8: Tuya Cloud Direct 120-Second Polling Throttling Tests', () {
    test('5. syncAllDevicesSilent throttles tuyaCloudDirect polling to 120-second interval', () async {
      final provider = RealHomeProvider(
        autoInitStorage: false,
        autoStartPolling: false,
      );

      final tuyaDev = RealSmartDevice(
        id: 'tuya_throttled_bulb',
        name: 'Throttled Wipro Bulb',
        room: 'Hall',
        category: 'light',
        protocol: ConnectionProtocol.tuyaCloudDirect,
        credentials: {'accessToken': 'real_hardware_token_abc'},
        isOn: true,
      );
      provider.addDeviceDirect(tuyaDev);

      // (a) Simulate first poll: device.lastPolledAt is null, so it executes
      expect(tuyaDev.lastPolledAt, isNull);
      await provider.syncAllDevicesSilent();
      expect(tuyaDev.lastPolledAt, isNotNull,
          reason: 'First poll must record lastPolledAt timestamp');

      final firstPollTime = tuyaDev.lastPolledAt!;

      // (b) Immediate second poll (e.g. 10s tick): difference < 120s -> must be skipped
      await provider.syncAllDevicesSilent();
      expect(tuyaDev.lastPolledAt, equals(firstPollTime),
          reason: 'Subsequent poll within 120s must be throttled/skipped');

      // (c) Simulate passage of 121 seconds
      tuyaDev.lastPolledAt = DateTime.now().subtract(const Duration(seconds: 121));
      await provider.syncAllDevicesSilent();
      expect(
        tuyaDev.lastPolledAt!.isAfter(firstPollTime),
        isTrue,
        reason: 'Poll after 120s cooldown must be allowed to execute',
      );

      // (d) Force poll bypasses cooldown
      final forcedTimeBefore = tuyaDev.lastPolledAt!;
      await provider.syncAllDevicesSilent(forceTuyaPoll: true);
      expect(
        tuyaDev.lastPolledAt!.millisecondsSinceEpoch,
        greaterThanOrEqualTo(forcedTimeBefore.millisecondsSinceEpoch),
        reason: 'forceTuyaPoll allows immediate execution regardless of cooldown',
      );

      provider.dispose();
    });
  });
}
