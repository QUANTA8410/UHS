// test/wipro_tuya_udp_and_localkey_test.dart
//
// Bug 26: discoverLocalWiproBulbs Assigns a 17-Character Dummy Key ('auto_detected_lan')
// & UDP 6667 Beacon AES-128 Decryption
//
// Verifies:
// 1. Tuya UDP beacon decryption on port 6667/6666 for Tuya 3.1 (plaintext) and Tuya 3.3/3.4 (AES-128-ECB with md5('yGAdlopoPVldABfn')).
// 2. Elimination of 17-char 'auto_detected_lan' dummy key across discoverLocalWiproBulbs and active IP probes.
// 3. Proper resolution of 16-char localKey from known keys or existing devices, and seamless fallback to tuyaCloudDirect.
// 4. Safe handling in setPower and setPrimaryLevel without throwing ArgumentError: Invalid key length (17 bytes).
// 5. Preservation of cloud-harvested localKey and accessToken in scanAndLinkWiproLanBulbs.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_home/providers/real_home_provider.dart';
import 'package:unified_home/services/real_iot_controller.dart';

class FakeSocket implements Socket {
  final List<Uint8List> writtenBytes = [];
  bool isClosed = false;
  bool isDestroyed = false;

  @override
  void add(List<int> data) {
    writtenBytes.add(Uint8List.fromList(data));
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {
    isClosed = true;
  }

  @override
  void destroy() {
    isDestroyed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Bug 26: Tuya UDP Beacon Decryption Tests', () {
    test('1. Plaintext Tuya 3.1 UDP beacon decodes correctly', () {
      final jsonPayload = jsonEncode({
        'ip': '192.168.1.105',
        'gwId': 'bf_plain_gw_01',
        'version': '3.1',
        'productKey': 'wipro_white_cct',
      });
      final rawData = Uint8List.fromList(utf8.encode(jsonPayload));

      final parsed = RealIotController.decodeTuyaUdpPacket(rawData, '192.168.1.105');
      expect(parsed, isNotNull);
      expect(parsed!['devId'], equals('bf_plain_gw_01'));
      expect(parsed['ip'], equals('192.168.1.105'));
      expect(parsed['version'], equals('3.1'));
      expect(parsed['productKey'], equals('wipro_white_cct'));
    });

    test('2. Encrypted Tuya 3.3 UDP 6667 beacon decodes and extracts authentic gwId', () {
      final jsonPayload = jsonEncode({
        'ip': '192.168.1.120',
        'gwId': 'bf0123456789abcdef01',
        'version': '3.3',
        'productKey': 'wipro_rgb_9w',
      });

      // Encrypt with fixed Tuya UDP broadcast key: MD5('yGAdlopoPVldABfn')
      final udpKeyBytes = Uint8List.fromList(
        md5.convert(utf8.encode('yGAdlopoPVldABfn')).bytes,
      );
      final key = enc.Key(udpKeyBytes);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.ecb, padding: 'PKCS7'));
      final encryptedPayload = encrypter.encrypt(jsonPayload).bytes;

      // Construct standard 0x000055AA Tuya UDP frame
      // 16-byte header: prefix (4), seq (4), cmd 0x13 (4), length (4)
      final header = ByteData(16)
        ..setUint32(0, 0x000055AA, Endian.big)
        ..setUint32(4, 0, Endian.big)
        ..setUint32(8, 0x00000013, Endian.big) // UDP_NEW
        ..setUint32(12, encryptedPayload.length + 8, Endian.big);

      final footer = ByteData(8)
        ..setUint32(0, 0x12345678, Endian.big) // CRC32 placeholder
        ..setUint32(4, 0x0000AA55, Endian.big);

      final frame = BytesBuilder()
        ..add(header.buffer.asUint8List())
        ..add(encryptedPayload)
        ..add(footer.buffer.asUint8List());

      final parsed = RealIotController.decodeTuyaUdpPacket(frame.toBytes(), '192.168.1.120');
      expect(parsed, isNotNull);
      expect(parsed!['devId'], equals('bf0123456789abcdef01'));
      expect(parsed['ip'], equals('192.168.1.120'));
      expect(parsed['version'], equals('3.3'));
      expect(parsed['productKey'], equals('wipro_rgb_9w'));
    });

    test('3. Raw AES-128 block UDP beacon without 0x000055AA framing decodes cleanly', () {
      final jsonPayload = jsonEncode({
        'ip': '192.168.1.130',
        'gwId': 'bf_raw_block_02',
        'version': '3.4',
      });

      final udpKeyBytes = Uint8List.fromList(
        md5.convert(utf8.encode('yGAdlopoPVldABfn')).bytes,
      );
      final key = enc.Key(udpKeyBytes);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.ecb, padding: 'PKCS7'));
      final encryptedBytes = encrypter.encrypt(jsonPayload).bytes;

      final parsed = RealIotController.decodeTuyaUdpPacket(encryptedBytes, '192.168.1.130');
      expect(parsed, isNotNull);
      expect(parsed!['devId'], equals('bf_raw_block_02'));
      expect(parsed['ip'], equals('192.168.1.130'));
      expect(parsed['version'], equals('3.4'));
    });

    test('4. Malformed or non-Tuya UDP packets return null without throwing', () {
      final randomJunk = Uint8List.fromList(List.generate(32, (i) => (i * 7) & 0xFF));
      final parsed = RealIotController.decodeTuyaUdpPacket(randomJunk, '192.168.1.200');
      expect(parsed, isNull);
    });
  });

  group('Bug 26: Elimination of 17-Char auto_detected_lan Dummy Key', () {
    test('1. Discovered bulb without known key never assigns auto_detected_lan', () async {
      final controller = RealIotController(
        socketConnector: (host, port, {timeout}) async => FakeSocket(),
      );

      final found = await controller.discoverLocalWiproBulbs(
        subnet: '192.168.1.',
      );

      for (final device in found) {
        expect(device.credentials['localKey'], isNot(equals('auto_detected_lan')),
            reason: "'auto_detected_lan' is an invalid 17-byte dummy key and must never be assigned");
        if (device.credentials['localKey']?.isEmpty == true) {
          expect(device.credentials['isPendingKey'], equals('true'));
        }
      }
    });

    test('2. Discovered bulb with known 16-char key assigns authentic localKey', () async {
      final controller = RealIotController(
        socketConnector: (host, port, {timeout}) async => FakeSocket(),
      );

      final found = await controller.discoverLocalWiproBulbs(
        subnet: '192.168.1.',
        knownDeviceKeys: {
          '192.168.1.100': '0123456789abcdef',
        },
      );

      expect(found, isNotEmpty);
      final bulb100 = found.firstWhere((d) => d.credentials['ip'] == '192.168.1.100');
      expect(bulb100.credentials['localKey'], equals('0123456789abcdef'));
      expect(bulb100.credentials['localKey']!.length, equals(16));
      expect(bulb100.protocol, equals(ConnectionProtocol.tuyaLocalLan));
      expect(bulb100.hasRealHardwareCredentials, isTrue);
    });

    test('3. Bulb with isPendingKey behaves as dummy so setPower and setPrimaryLevel do not crash', () async {
      final controller = RealIotController();
      final pendingBulb = RealSmartDevice(
        id: 'wipro_pending_01',
        name: 'Wipro Auto-Discovered',
        room: 'Living Room',
        category: 'light',
        protocol: ConnectionProtocol.tuyaLocalLan,
        credentials: {
          'ip': '192.168.1.110',
          'port': '6668',
          'devId': 'wipro_pending_01',
          'localKey': '',
          'isPendingKey': 'true',
        },
        isOn: false,
        primaryValue: 20.0,
      );

      expect(pendingBulb.isPendingKey, isTrue);
      expect(pendingBulb.hasRealHardwareCredentials, isFalse);
      expect(pendingBulb.isDummy, isTrue);

      // setPower must toggle in memory without throwing
      await controller.setPower(pendingBulb, true);
      expect(pendingBulb.isOn, isTrue);

      // setPrimaryLevel must update level in memory without throwing ArgumentError: Invalid key length
      await controller.setPrimaryLevel(pendingBulb, 75.0);
      expect(pendingBulb.primaryValue, equals(75.0));
    });
  });

  group('Bug 26: Cloud Fallback & Local Command Execution', () {
    test('1. Bulb missing 16-char localKey but with accessToken seamlessly routes setPower to Tuya Cloud', () async {
      late http.Request recordedReq;
      final mockClient = MockClient((request) async {
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
      final hybridBulb = RealSmartDevice(
        id: 'wipro_hybrid_01',
        name: 'Wipro Hybrid Bulb',
        room: 'Living Room',
        category: 'light',
        protocol: ConnectionProtocol.tuyaLocalLan,
        credentials: {
          'ip': '192.168.1.115',
          'port': '6668',
          'devId': 'wipro_hybrid_01',
          'localKey': '', // No local key
          'accessToken': 'valid_cloud_token_abc123',
        },
        isOn: false,
      );

      await controller.setPower(hybridBulb, true);
      expect(hybridBulb.isOn, isTrue);
      expect(recordedReq.url.toString(), equals('https://px1.tuyain.com/homeassistant/skill'));

      final sentBody = jsonDecode(recordedReq.body) as Map<String, dynamic>;
      expect(sentBody['header']['name'], equals('turnOnOff'));
      expect(sentBody['payload']['accessToken'], equals('valid_cloud_token_abc123'));
      expect(sentBody['payload']['devId'], equals('wipro_hybrid_01'));
      expect(sentBody['payload']['value'], equals(1));
    });

    test('2. Bulb missing 16-char localKey but with accessToken seamlessly routes setPrimaryLevel to Tuya Cloud', () async {
      late http.Request recordedReq;
      final mockClient = MockClient((request) async {
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
      final hybridBulb = RealSmartDevice(
        id: 'wipro_hybrid_02',
        name: 'Wipro Hybrid Bulb',
        room: 'Living Room',
        category: 'light',
        protocol: ConnectionProtocol.tuyaLocalLan,
        credentials: {
          'ip': '192.168.1.115',
          'port': '6668',
          'devId': 'wipro_hybrid_02',
          'localKey': '',
          'accessToken': 'valid_cloud_token_abc123',
        },
        primaryValue: 20.0,
      );

      await controller.setPrimaryLevel(hybridBulb, 85.0);
      expect(hybridBulb.primaryValue, equals(85.0));

      final sentBody = jsonDecode(recordedReq.body) as Map<String, dynamic>;
      expect(sentBody['header']['name'], equals('brightnessSet'));
      expect(sentBody['payload']['value'], equals(85));
    });

    test('3. Real 16-char localKey sends local encrypted frame over port 6668', () async {
      final fakeSocket = FakeSocket();
      final controller = RealIotController(
        socketConnector: (host, port, {timeout}) async => fakeSocket,
      );

      final localBulb = RealSmartDevice(
        id: 'wipro_real_lan_01',
        name: 'Wipro LAN Bulb',
        room: 'Study',
        category: 'light',
        protocol: ConnectionProtocol.tuyaLocalLan,
        credentials: {
          'ip': '192.168.1.150',
          'port': '6668',
          'devId': 'wipro_real_lan_01',
          'localKey': '16bytekey1234567',
        },
        isOn: false,
      );

      await controller.setPower(localBulb, true);
      expect(localBulb.isOn, isTrue);
      expect(fakeSocket.writtenBytes, isNotEmpty);
      expect(fakeSocket.isClosed, isTrue);
    });
  });

  group('Bug 26: RealHomeProvider scanAndLinkWiproLanBulbs Key Preservation', () {
    test('1. Preserves existing 16-character localKey when scanning LAN', () async {
      final controller = RealIotController(
        socketConnector: (host, port, {timeout}) async => FakeSocket(),
      );
      final provider = RealHomeProvider(controller: controller);

      // Pre-populate with a bulb that has an authenticated 16-char key
      final existingBulb = RealSmartDevice(
        id: 'wipro_192_168_1_100',
        name: 'Existing Living Room Bulb',
        room: 'Living Room',
        category: 'light',
        protocol: ConnectionProtocol.tuyaLocalLan,
        credentials: {
          'ip': '192.168.1.100',
          'port': '6668',
          'devId': 'wipro_192_168_1_100',
          'localKey': 'auth_16_byte_key', // exactly 16 bytes
        },
        isOn: false,
      );
      provider.addDeviceDirect(existingBulb);

      final count = await provider.scanAndLinkWiproLanBulbs(subnet: '192.168.1.');
      expect(count, greaterThan(0));

      final updatedBulb = provider.devices.firstWhere((d) => d.id == 'wipro_192_168_1_100');
      expect(updatedBulb.credentials['localKey'], equals('auth_16_byte_key'),
          reason: 'Existing valid 16-char localKey must be preserved across LAN re-scans');
      expect(updatedBulb.protocol, equals(ConnectionProtocol.tuyaLocalLan));
      expect(updatedBulb.hasRealHardwareCredentials, isTrue);
    });
  });
}
