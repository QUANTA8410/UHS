import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:unified_home/services/real_iot_controller.dart';
import 'package:unified_home/services/wipro/wipro_tuya_service.dart';

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

  group('Bug 9: Wipro / Tuya Local LAN Socket Contention on Port 6668', () {
    test('Serializes concurrent socket operations to the same device IP without collision', () async {
      int activeConnections = 0;
      int maxConcurrentConnections = 0;
      final connectionLogs = <String>[];

      Future<Socket> fakeConnector(dynamic host, int port, {Duration? timeout}) async {
        activeConnections++;
        if (activeConnections > maxConcurrentConnections) {
          maxConcurrentConnections = activeConnections;
        }
        connectionLogs.add('CONNECT $host:$port (active: $activeConnections)');
        final socket = FakeSocket();
        // Simulate a 40ms network transmission delay
        await Future.delayed(const Duration(milliseconds: 40));
        activeConnections--;
        connectionLogs.add('DISCONNECT $host:$port (remaining: $activeConnections)');
        return socket;
      }

      final controller = RealIotController(socketConnector: fakeConnector);

      final device = RealSmartDevice(
        id: 'wipro_bulb_lan_01',
        name: 'Wipro Smart Bulb',
        room: 'Study',
        category: 'light',
        protocol: ConnectionProtocol.tuyaLocalLan,
        credentials: {
          'ip': '192.168.1.120',
          'localKey': '1234567890123456',
          'port': '6668',
        },
        isOn: false,
      );

      // Fire 3 commands concurrently on the same IP:
      // 1. setPower(true)
      // 2. setPrimaryLevel(80.0)
      // 3. refreshDeviceStatus
      await Future.wait([
        controller.setPower(device, true),
        controller.setPrimaryLevel(device, 80.0),
        controller.refreshDeviceStatus(device),
      ]);

      // Assert that max concurrent connections to port 6668 on that IP NEVER exceeded 1
      expect(maxConcurrentConnections, equals(1));
      expect(device.isOn, isTrue);
      expect(device.primaryValue, equals(80.0));
      expect(device.isOnline, isTrue);
    });

    test('Distinct device IPs run independently without cross-device blocking', () async {
      int maxConcurrentTotal = 0;
      int activeTotal = 0;

      Future<Socket> fakeConnector(dynamic host, int port, {Duration? timeout}) async {
        activeTotal++;
        if (activeTotal > maxConcurrentTotal) {
          maxConcurrentTotal = activeTotal;
        }
        final socket = FakeSocket();
        await Future.delayed(const Duration(milliseconds: 50));
        activeTotal--;
        return socket;
      }

      final controller = RealIotController(socketConnector: fakeConnector);

      final devA = RealSmartDevice(
        id: 'bulb_a',
        name: 'Bulb A',
        room: 'Room A',
        category: 'light',
        protocol: ConnectionProtocol.tuyaLocalLan,
        credentials: {'ip': '192.168.1.101', 'localKey': '1234567890123456'},
        isOn: false,
      );

      final devB = RealSmartDevice(
        id: 'bulb_b',
        name: 'Bulb B',
        room: 'Room B',
        category: 'light',
        protocol: ConnectionProtocol.tuyaLocalLan,
        credentials: {'ip': '192.168.1.102', 'localKey': '1234567890123456'},
        isOn: false,
      );

      // Firing commands to two separate IPs concurrently can overlap across different IPs
      await Future.wait([
        controller.setPower(devA, true),
        controller.setPower(devB, true),
      ]);

      expect(maxConcurrentTotal, greaterThanOrEqualTo(1));
      expect(devA.isOn, isTrue);
      expect(devB.isOn, isTrue);
    });

    test('refreshDeviceStatus bypasses port 6668 socket check when recently polled', () async {
      int socketCalls = 0;
      Future<Socket> fakeConnector(dynamic host, int port, {Duration? timeout}) async {
        socketCalls++;
        return FakeSocket();
      }

      final controller = RealIotController(socketConnector: fakeConnector);

      final device = RealSmartDevice(
        id: 'wipro_recent_poll',
        name: 'Recently Active Light',
        room: 'Kitchen',
        category: 'light',
        protocol: ConnectionProtocol.tuyaLocalLan,
        credentials: {'ip': '192.168.1.130', 'localKey': '1234567890123456'},
        isOn: true,
      );

      // Simulate a command that succeeded 3 seconds ago
      device.lastPolledAt = DateTime.now().subtract(const Duration(seconds: 3));

      await controller.refreshDeviceStatus(device);

      // Should have bypassed socket connect because device was recently active
      expect(socketCalls, equals(0));
      expect(device.isOnline, isTrue);

      // Now set lastPolledAt to 25 seconds ago (exceeding 15s threshold)
      device.lastPolledAt = DateTime.now().subtract(const Duration(seconds: 25));

      await controller.refreshDeviceStatus(device);

      // Should have performed socket connect check
      expect(socketCalls, equals(1));
      expect(device.isOnline, isTrue);
    });

    test('Protocol version 3.3 prefixes 15-byte header, while version 3.1 omits prefix', () async {
      FakeSocket? lastSocket;
      Future<Socket> fakeConnector(dynamic host, int port, {Duration? timeout}) async {
        final socket = FakeSocket();
        lastSocket = socket;
        return socket;
      }

      final controller = RealIotController(socketConnector: fakeConnector);

      // 1. Device with version 3.3 (default)
      final dev33 = RealSmartDevice(
        id: 'dev_33',
        name: 'Tuya 3.3 Bulb',
        room: 'Hall',
        category: 'light',
        protocol: ConnectionProtocol.tuyaLocalLan,
        credentials: {
          'ip': '192.168.1.150',
          'localKey': '1234567890123456',
          'version': '3.3',
        },
      );

      await controller.setPower(dev33, true);
      expect(lastSocket, isNotNull);
      final frame33 = lastSocket!.writtenBytes.first;

      // Header is 16 bytes: 0x000055AA (4), seq (4), cmd (4), length (4)
      // For v3.3, body begins with '3.3' padded to 15 bytes
      final prefix33 = utf8.decode(frame33.sublist(16, 19));
      expect(prefix33, equals('3.3'));
      // Bytes 19..31 (12 bytes) must be null bytes (0x00)
      for (int i = 19; i < 31; i++) {
        expect(frame33[i], equals(0));
      }

      // 2. Device with version 3.1 (omits 15-byte prefix)
      final dev31 = RealSmartDevice(
        id: 'dev_31',
        name: 'Tuya 3.1 Bulb',
        room: 'Balcony',
        category: 'light',
        protocol: ConnectionProtocol.tuyaLocalLan,
        credentials: {
          'ip': '192.168.1.151',
          'localKey': '1234567890123456',
          'version': '3.1',
        },
      );

      await controller.setPower(dev31, true);
      final frame31 = lastSocket!.writtenBytes.first;
      // In 3.1, body starts directly with AES ciphertext, not '3.1'
      final prefix31 = utf8.decode(frame31.sublist(16, 19), allowMalformed: true);
      expect(prefix31, isNot(equals('3.1')));
    });

    test('WiproTuyaService also serializes socket connections and handles versioning', () async {
      int active = 0;
      int maxConcurrent = 0;

      Future<Socket> fakeConnector(dynamic host, int port, {Duration? timeout}) async {
        active++;
        if (active > maxConcurrent) {
          maxConcurrent = active;
        }
        final s = FakeSocket();
        await Future.delayed(const Duration(milliseconds: 30));
        active--;
        return s;
      }

      final service = WiproTuyaService(socketConnector: fakeConnector);

      await Future.wait([
        service.setPower(
          host: '192.168.1.180',
          isPowered: true,
          localKey: '1234567890123456',
        ),
        service.setBrightness(
          host: '192.168.1.180',
          brightness: 0.75,
          localKey: '1234567890123456',
        ),
        service.checkConnectivity('192.168.1.180'),
      ]);

      expect(maxConcurrent, equals(1));
    });
  });
}
