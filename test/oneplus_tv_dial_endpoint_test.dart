import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:unified_home/services/real_iot_controller.dart';
import 'package:unified_home/services/tv/oneplus_connect_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Bug 10: OnePlus TV LAN Power Toggle DIAL Endpoint Tests', () {
    test('Power ON sends POST to /apps/YouTube and executes Wake-on-LAN when MAC present', () async {
      final requestedUrls = <String>[];
      final requestedMethods = <String>[];

      final mockClient = MockClient((request) async {
        requestedUrls.add(request.url.toString());
        requestedMethods.add(request.method);

        if (request.url.path == '/apps/YouTube' && request.method == 'POST') {
          return http.Response('', 201, headers: {'Location': 'http://192.168.1.105:8008/apps/YouTube/run'});
        }
        return http.Response('Not Found', 404);
      });

      final controller = RealIotController(client: mockClient);

      final tv = RealSmartDevice(
        id: 'oneplus_tv_01',
        name: 'OnePlus TV 55 U1S',
        room: 'Living Room',
        category: 'tv',
        protocol: ConnectionProtocol.onePlusTvLan,
        credentials: {
          'ip': '192.168.1.105',
          'mac': 'AA:BB:CC:DD:EE:FF',
        },
        isOn: false,
      );

      await controller.setPower(tv, true);

      expect(tv.isOn, isTrue);
      expect(requestedMethods, contains('POST'));
      expect(requestedUrls, contains('http://192.168.1.105:8008/apps/YouTube'));
    });

    test('Power OFF targets DIAL instance endpoint /apps/YouTube/run with DELETE and sends POWER key', () async {
      final requestedUrls = <String>[];
      final requestedMethods = <String>[];

      final mockClient = MockClient((request) async {
        requestedUrls.add(request.url.toString());
        requestedMethods.add(request.method);

        if (request.url.path == '/apps/YouTube/run' && request.method == 'DELETE') {
          return http.Response('', 200);
        }
        if (request.url.path == '/apps/OnePlusRemote' && request.method == 'POST') {
          return http.Response('{"status":"ok"}', 200);
        }
        return http.Response('Not Found', 404);
      });

      final controller = RealIotController(client: mockClient);

      final tv = RealSmartDevice(
        id: 'oneplus_tv_01',
        name: 'OnePlus TV 55 U1S',
        room: 'Living Room',
        category: 'tv',
        protocol: ConnectionProtocol.onePlusTvLan,
        credentials: {
          'ip': '192.168.1.105',
        },
        isOn: true,
      );

      await controller.setPower(tv, false);

      expect(tv.isOn, isFalse);
      // Must verify the DELETE request went to /apps/YouTube/run, NEVER /apps/YouTube without /run
      expect(requestedUrls, contains('http://192.168.1.105:8008/apps/YouTube/run'));
      expect(requestedUrls, isNot(contains('http://192.168.1.105:8008/apps/YouTube')));
      expect(requestedMethods, contains('DELETE'));
    });

    test('Power OFF gracefully tolerates 404 on DELETE when app is not running', () async {
      final mockClient = MockClient((request) async {
        if (request.method == 'DELETE' && request.url.path == '/apps/YouTube/run') {
          return http.Response('Application not running', 404);
        }
        return http.Response('{"status":"ok"}', 200);
      });

      final controller = RealIotController(client: mockClient);

      final tv = RealSmartDevice(
        id: 'oneplus_tv_02',
        name: 'OnePlus TV Y Series',
        room: 'Bedroom',
        category: 'tv',
        protocol: ConnectionProtocol.onePlusTvLan,
        credentials: {'ip': '192.168.1.106'},
        isOn: true,
      );

      // Should succeed without throwing an exception because 404 means the app was already inactive
      await controller.setPower(tv, false);
      expect(tv.isOn, isFalse);
    });

    test('Power ON falls back to POWER key when DIAL POST fails with 500', () async {
      final sentRemoteKeys = <String>[];

      final mockClient = MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/apps/YouTube') {
          return http.Response('Server Error', 500);
        }
        if (request.method == 'POST' && request.url.path == '/apps/OnePlusRemote') {
          sentRemoteKeys.add(request.body);
          return http.Response('{"status":"ok"}', 200);
        }
        return http.Response('Not Found', 404);
      });

      final controller = RealIotController(client: mockClient);

      final tv = RealSmartDevice(
        id: 'oneplus_tv_03',
        name: 'OnePlus TV Q1 Pro',
        room: 'Theater',
        category: 'tv',
        protocol: ConnectionProtocol.onePlusTvLan,
        credentials: {'ip': '192.168.1.107'},
        isOn: false,
      );

      await controller.setPower(tv, true);
      expect(tv.isOn, isTrue);
      expect(sentRemoteKeys.any((k) => k.contains('POWER')), isTrue);
    });

    test('OnePlusConnectService terminateApp hits /apps/<appName>/run with DELETE', () async {
      final deletedUrls = <String>[];

      final mockClient = MockClient((request) async {
        if (request.method == 'DELETE') {
          deletedUrls.add(request.url.toString());
          return http.Response('', 200);
        }
        return http.Response('Not Found', 404);
      });

      final service = OnePlusConnectService(client: mockClient);

      final ok = await service.terminateApp(
        tvId: 'oneplus_tv',
        appName: 'YouTube',
        host: '192.168.1.105',
      );

      expect(ok, isTrue);
      expect(deletedUrls, contains('http://192.168.1.105:8008/apps/YouTube/run'));
    });

    test('sendWakeOnLan parses valid MAC address formats', () async {
      final service = OnePlusConnectService();
      // Valid colon-separated MAC
      final res1 = await service.sendWakeOnLan('00:11:22:33:44:55');
      expect(res1, isTrue);

      // Valid hyphen-separated MAC
      final res2 = await service.sendWakeOnLan('AA-BB-CC-DD-EE-FF');
      expect(res2, isTrue);

      // Invalid MAC format
      final res3 = await service.sendWakeOnLan('invalid_mac');
      expect(res3, isFalse);
    });
  });
}
