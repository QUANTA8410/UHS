import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_home/providers/real_home_provider.dart';
import 'package:unified_home/services/real_iot_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Bug 17: Cross-Brand Reflex Bus & LG ThinQ Routing Tests', () {
    test('RealIotController.setPower and setPrimaryLevel route LG ThinQ devices without requiring Webhook URL', () async {
      final controller = RealIotController();

      // Create an LG ThinQ device imported under customHttpWebhook without onUrl/offUrl
      final lgAc = RealSmartDevice(
        id: 'lg_ac_device_demo',
        name: 'LG DualCool AC',
        room: 'Living Room',
        category: 'ac',
        protocol: ConnectionProtocol.customHttpWebhook,
        credentials: {
          'vendor': 'lg_thinq',
          'token': 'demo_lg_token',
          'deviceId': 'lg_ac_device_demo',
        },
      );

      expect(lgAc.isLgThinq, isTrue);

      // setPower must route to LG logic and not throw FormatException/Missing onUrl
      await controller.setPower(lgAc, true);
      expect(lgAc.isOn, isTrue);
      expect(lgAc.liveWatts, greaterThan(0.0));

      // setPrimaryLevel must route to LG logic and update primaryValue
      await controller.setPrimaryLevel(lgAc, 21.0);
      expect(lgAc.primaryValue, 21.0);
    });

    test('executeAutomationRuleNow recomputes live wattage and notifies listeners', () async {
      final provider = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);

      final device = RealSmartDevice(
        id: 'wipro_bulb_test',
        name: 'Wipro Bulb',
        room: 'Living Room',
        category: 'light',
        protocol: ConnectionProtocol.customHttpWebhook,
        credentials: const {'vendor': 'demo'},
        isOn: false,
        primaryValue: 50.0,
      );
      provider.addDeviceDirect(device);

      final rule = SmartAutomationRule(
        id: 'rule_light_on',
        name: 'Turn Light On',
        triggerType: 'time',
        triggerValue: '20:00',
        targetDeviceId: device.id,
        targetPowerState: true,
        targetLevel: 80.0,
      );

      await provider.executeAutomationRuleNow(rule);

      expect(device.isOn, isTrue);
      expect(device.primaryValue, 80.0);
      expect(device.liveWatts, greaterThan(0.0));
      expect(rule.lastTriggeredAt, isNotNull);
    });
  });

  group('Bug 20: Philips Hue Dynamic Subnet Discovery Tests', () {
    test('discoverHueBridgeIps discovers bridge on dynamic DHCP host IP (192.168.1.37) using subnet scan', () async {
      final scannedIps = <String>[];
      Future<http.Response> mockHandler(http.Request req) async {
        final url = req.url.toString();
        scannedIps.add(url);

        // MeetHue endpoint returns empty to test subnet scan fallback
        if (url.contains('discovery.meethue.com')) {
          return http.Response('[]', 200);
        }

        // Bridge resides at 192.168.1.37 (dynamic host IP)
        if (url.contains('192.168.1.37')) {
          return http.Response(
            jsonEncode({
              'name': 'Philips Hue Bridge',
              'bridgeid': '001788FFFE123456',
              'modelid': 'BSB002',
            }),
            200,
          );
        }

        return http.Response('Not Found', 404);
      }

      final client = _MockClient(mockHandler);
      final controller = RealIotController(client: client);

      final foundIps = await controller.discoverHueBridgeIps(
        localIp: '192.168.1.15',
        subnetPrefix: '192.168.1.',
      );

      expect(foundIps, contains('192.168.1.37'));
    });
  });
}

class _MockClient extends http.BaseClient {
  final Future<http.Response> Function(http.Request) _handler;
  _MockClient(this._handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final httpRequest = request as http.Request;
    final res = await _handler(httpRequest);
    return http.StreamedResponse(
      Stream.value(utf8.encode(res.body)),
      res.statusCode,
      headers: res.headers,
    );
  }
}
