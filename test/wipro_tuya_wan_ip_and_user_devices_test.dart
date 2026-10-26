import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:unified_home/services/master/self_healing_network_engine.dart';
import 'package:unified_home/services/master/zero_touch_onboarding_service.dart';
import 'package:unified_home/services/real_iot_controller.dart';

class _FakeSocket implements Socket {
  final InternetAddress _addr;
  final int _port;

  _FakeSocket(this._addr, this._port);

  @override
  InternetAddress get address => _addr;

  @override
  int get port => _port;

  @override
  InternetAddress get remoteAddress => _addr;

  @override
  int get remotePort => _port;

  @override
  void destroy() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('RFC 1918 Private LAN IP Validation (Bug 27)', () {
    test('Correctly identifies RFC 1918 and loopback private LAN addresses', () {
      expect(isPrivateLanIp('192.168.1.1'), isTrue);
      expect(isPrivateLanIp('192.168.0.254'), isTrue);
      expect(isPrivateLanIp('10.0.0.1'), isTrue);
      expect(isPrivateLanIp('10.254.10.15'), isTrue);
      expect(isPrivateLanIp('172.16.0.1'), isTrue);
      expect(isPrivateLanIp('172.20.100.5'), isTrue);
      expect(isPrivateLanIp('172.31.255.254'), isTrue);
      expect(isPrivateLanIp('127.0.0.1'), isTrue);
      expect(isPrivateLanIp('169.254.1.1'), isTrue);
    });

    test('Rejects public WAN IPs, ISP router IPs, and invalid format strings', () {
      // Common ISP router WAN IPs returned by Tuya OpenAPI
      expect(isPrivateLanIp('122.161.45.89'), isFalse);
      expect(isPrivateLanIp('49.37.112.45'), isFalse);
      expect(isPrivateLanIp('8.8.8.8'), isFalse);
      expect(isPrivateLanIp('1.1.1.1'), isFalse);
      expect(isPrivateLanIp('172.15.0.1'), isFalse);
      expect(isPrivateLanIp('172.32.0.1'), isFalse);
      expect(isPrivateLanIp('11.0.0.1'), isFalse);

      // Malformed / Empty
      expect(isPrivateLanIp(null), isFalse);
      expect(isPrivateLanIp(''), isFalse);
      expect(isPrivateLanIp('   '), isFalse);
      expect(isPrivateLanIp('192.168.1'), isFalse);
      expect(isPrivateLanIp('192.168.1.256'), isFalse);
      expect(isPrivateLanIp('not_an_ip'), isFalse);
    });
  });

  group('SelfHealingNetworkEngine Safe Subnet Sweep (Bug 27)', () {
    test('Never sweeps a public WAN IP when device has router WAN IP', () async {
      final sweptIps = <String>[];

      final engine = SelfHealingNetworkEngine(
        socketConnect: (host, port, {timeout}) async {
          sweptIps.add(host.toString());
          if (host.toString() == '192.168.1.105') {
            return _FakeSocket(InternetAddress(host.toString()), port);
          }
          throw const SocketException('Connection refused');
        },
      );

      final device = RealSmartDevice(
        id: 'wipro_wan_dev',
        name: 'Wipro Bulb with WAN IP',
        room: 'Living Room',
        category: 'light',
        protocol: ConnectionProtocol.tuyaLocalLan,
        credentials: {
          'ip': '122.161.45.89', // Tuya Cloud router WAN IP
          'port': '6668',
          'localKey': '1234567890123456',
        },
        isOn: true,
        isOnline: true,
        primaryValue: 80.0,
        ratedMaxWatts: 9.0,
      );

      final healedIp = await engine.healDeviceIpAddress(device);

      // Asserts that no WAN IPs were swept
      expect(sweptIps.any((ip) => ip.startsWith('122.161.45.')), isFalse);
      // Asserts safe fallback subnet was used
      expect(sweptIps.any((ip) => ip.startsWith('192.168.1.')), isTrue);
      expect(healedIp, equals('192.168.1.105'));
      expect(device.credentials['ip'], equals('192.168.1.105'));
    });
  });

  group('ZeroTouchOnboardingService.autoHarvestWiproTuyaKeys (Bug 27)', () {
    test('Harvests ALL devices under uid and discards public WAN IPs', () async {
      final mockClient = MockClient((request) async {
        final path = request.url.path;

        if (path == '/v1.0/token') {
          return http.Response(
            jsonEncode({
              'success': true,
              'result': {
                'access_token': 'tuya_mock_token_abc123',
                'expire_time': 7200,
              },
            }),
            200,
          );
        }

        if (path == '/v1.0/devices/dev_sample_01') {
          return http.Response(
            jsonEncode({
              'success': true,
              'result': {
                'id': 'dev_sample_01',
                'uid': 'user_tuya_account_999',
                'name': 'Living Room Bulb',
                'local_key': '1111222233334444',
                'ip': '122.161.45.89', // Public WAN router IP
                'online': true,
                'category': 'dj',
              },
            }),
            200,
          );
        }

        if (path == '/v1.0/users/user_tuya_account_999/devices') {
          return http.Response(
            jsonEncode({
              'success': true,
              'result': [
                {
                  'id': 'dev_sample_01',
                  'name': 'Living Room Bulb',
                  'local_key': '1111222233334444',
                  'ip': '122.161.45.89',
                  'online': true,
                  'category': 'dj',
                },
                {
                  'id': 'dev_bulb_02',
                  'name': 'Kitchen Downlight',
                  'local_key': '9bf9****51d59', // Masked key!
                  'ip': '122.161.45.89',
                  'online': true,
                  'category': 'dj',
                },
                {
                  'id': 'dev_bulb_03',
                  'name': 'Balcony Lamp',
                  'local_key': '', // Omitted key!
                  'ip': '122.161.45.89',
                  'online': false,
                  'category': 'dj',
                },
              ],
            }),
            200,
          );
        }

        if (path == '/v1.0/devices/dev_bulb_02') {
          return http.Response(
            jsonEncode({
              'success': true,
              'result': {
                'id': 'dev_bulb_02',
                'name': 'Kitchen Downlight',
                'local_key': '5555666677778888', // Unmasked key!
                'ip': '122.161.45.89',
                'online': true,
                'category': 'dj',
              },
            }),
            200,
          );
        }

        if (path == '/v1.0/devices/dev_bulb_03') {
          return http.Response(
            jsonEncode({
              'success': true,
              'result': {
                'id': 'dev_bulb_03',
                'name': 'Balcony Lamp',
                'local_key': '9999000011112222', // Unmasked key!
                'ip': '122.161.45.89',
                'online': false,
                'category': 'dj',
              },
            }),
            200,
          );
        }

        return http.Response('{"success": false, "msg": "Not found"}', 404);
      });

      final zt = ZeroTouchOnboardingService();

      final devices = await zt.autoHarvestWiproTuyaKeys(
        accessId: 'test_client_id',
        accessSecret: 'test_client_secret',
        sampleDeviceId: 'dev_sample_01',
        httpClient: mockClient,
      );

      // 1. Should harvest all 3 user devices, not just the single sample device
      expect(devices.length, equals(3));

      final dev1 = devices.firstWhere((d) => d.id == 'dev_sample_01');
      final dev2 = devices.firstWhere((d) => d.id == 'dev_bulb_02');
      final dev3 = devices.firstWhere((d) => d.id == 'dev_bulb_03');

      // 2. WAN IP 122.161.45.89 must NOT be stored as the bulb's local IP!
      expect(dev1.credentials['ip'], isNot(equals('122.161.45.89')));
      expect(dev2.credentials['ip'], isNot(equals('122.161.45.89')));
      expect(dev3.credentials['ip'], isNot(equals('122.161.45.89')));

      // 3. Authentic unmasked 16-char localKeys must be harvested
      expect(dev1.credentials['localKey'], equals('1111222233334444'));
      expect(dev2.credentials['localKey'], equals('5555666677778888'));
      expect(dev3.credentials['localKey'], equals('9999000011112222'));

      // 4. AccessToken must be attached to credentials for cloud fallback
      expect(dev1.credentials['accessToken'], equals('tuya_mock_token_abc123'));
      expect(dev2.credentials['accessToken'], equals('tuya_mock_token_abc123'));
      expect(dev3.credentials['accessToken'], equals('tuya_mock_token_abc123'));
    });

    test('Gracefully falls back to sample device if user devices call fails', () async {
      final mockClient = MockClient((request) async {
        final path = request.url.path;

        if (path == '/v1.0/token') {
          return http.Response(
            jsonEncode({
              'success': true,
              'result': {
                'access_token': 'tuya_fallback_token',
              },
            }),
            200,
          );
        }

        if (path == '/v1.0/devices/dev_solo') {
          return http.Response(
            jsonEncode({
              'success': true,
              'result': {
                'id': 'dev_solo',
                'uid': '', // No uid available
                'name': 'Solo Bulb',
                'local_key': 'abcdef1234567890',
                'ip': '49.37.112.45', // WAN IP
                'online': true,
              },
            }),
            200,
          );
        }

        return http.Response('{"success": false}', 500);
      });

      final zt = ZeroTouchOnboardingService();

      final devices = await zt.autoHarvestWiproTuyaKeys(
        accessId: 'test_id',
        accessSecret: 'test_sec',
        sampleDeviceId: 'dev_solo',
        httpClient: mockClient,
      );

      expect(devices.length, equals(1));
      expect(devices.first.id, equals('dev_solo'));
      // WAN IP must NOT be stored
      expect(devices.first.credentials['ip'], isNot(equals('49.37.112.45')));
      expect(devices.first.credentials['localKey'], equals('abcdef1234567890'));
    });
  });
}
