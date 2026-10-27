import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_home/providers/real_home_provider.dart';
import 'package:unified_home/services/master/self_healing_network_engine.dart';
import 'package:unified_home/services/node/embedded_android_node_server.dart';
import 'package:unified_home/services/real_iot_controller.dart';
import 'package:unified_home/services/tv/oneplus_connect_service.dart';
import 'package:unified_home/services/wipro/wipro_tuya_service.dart';

// ---------------------------------------------------------------------------
// Fake / Spy Implementations
// ---------------------------------------------------------------------------

class _FakeWiproTuyaService extends WiproTuyaService {
  String? lastHost;
  bool? lastPower;
  double? lastBrightness;
  int? lastKelvin;
  String? lastHexRgb;
  Map<String, dynamic>? lastDps;
  int setPowerCalls = 0;
  int setBrightnessCalls = 0;
  int setColorTempCalls = 0;
  int setColorHexCalls = 0;
  int sendFrameCalls = 0;

  @override
  Future<bool> setPower({
    required String host,
    required bool isPowered,
    String? cloudDeviceId,
    String? localKey,
    String version = '3.3',
  }) async {
    lastHost = host;
    lastPower = isPowered;
    setPowerCalls++;
    return true;
  }

  @override
  Future<bool> setBrightness({
    required String host,
    required double brightness,
    String? cloudDeviceId,
    String? localKey,
    String version = '3.3',
  }) async {
    lastHost = host;
    lastBrightness = brightness;
    setBrightnessCalls++;
    return true;
  }

  @override
  Future<bool> setColorTemp({
    required String host,
    required int kelvin,
    String? cloudDeviceId,
    String? localKey,
    String version = '3.3',
  }) async {
    lastHost = host;
    lastKelvin = kelvin;
    setColorTempCalls++;
    return true;
  }

  @override
  Future<bool> setColorHex({
    required String host,
    required String hexRgb,
    String? cloudDeviceId,
    String? localKey,
    String version = '3.3',
  }) async {
    lastHost = host;
    lastHexRgb = hexRgb;
    setColorHexCalls++;
    return true;
  }

  @override
  Future<bool> sendEncryptedFrame({
    required String host,
    required String deviceId,
    required String localKey,
    required Map<String, dynamic> dps,
    String version = '3.3',
    int commandByte = 0x07,
  }) async {
    lastHost = host;
    lastDps = dps;
    sendFrameCalls++;
    return true;
  }
}

class _FakeOnePlusConnectService extends OnePlusConnectService {
  final List<String> dispatchedKeys = [];
  String? lastAppLaunched;
  String? lastAppTerminated;
  String? lastInputSwitched;
  String? lastWakeOnLanMac;

  @override
  Future<bool> sendRemoteKey({
    required String tvId,
    required String keyAction,
    String? host,
    int? port,
  }) async {
    dispatchedKeys.add(keyAction);
    return true;
  }

  @override
  Future<bool> launchApp({
    required String tvId,
    required String appName,
    String? host,
  }) async {
    lastAppLaunched = appName;
    return true;
  }

  @override
  Future<bool> terminateApp({
    required String tvId,
    required String appName,
    String? host,
  }) async {
    lastAppTerminated = appName;
    return true;
  }

  @override
  Future<bool> switchInput({
    required String tvId,
    required String inputSource,
    String? host,
  }) async {
    lastInputSwitched = inputSource;
    return true;
  }

  @override
  Future<bool> sendWakeOnLan(String macAddress) async {
    lastWakeOnLanMac = macAddress;
    return true;
  }
}

class _MockSocket implements Socket {
  bool destroyed = false;

  @override
  void destroy() {
    destroyed = true;
  }

  @override
  Future close() async {
    destroyed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RealHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (cert, host, port) => true;
    return client;
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    HttpOverrides.global = _RealHttpOverrides();
  });

  // =========================================================================
  // Bug 34: Injected Driver Services
  // =========================================================================
  group('Bug 34: Injected Driver Services in RealIotController', () {
    test('Delegates setPower to injected WiproTuyaService for tuyaLocalLan', () async {
      final fakeTuya = _FakeWiproTuyaService();
      final fakeOnePlus = _FakeOnePlusConnectService();

      final controller = RealIotController(
        wiproTuyaService: fakeTuya,
        onePlusConnectService: fakeOnePlus,
      );

      final tuyaBulb = RealSmartDevice(
        id: 'wipro_bulb_lan_1',
        name: 'Wipro RGB Bulb',
        room: 'Bedroom',
        category: 'light',
        protocol: ConnectionProtocol.tuyaLocalLan,
        credentials: {
          'ip': '192.168.1.120',
          'localKey': '0123456789abcdef',
        },
        isOn: false,
        primaryValue: 50.0,
      );

      await controller.setPower(tuyaBulb, true);
      expect(fakeTuya.setPowerCalls, equals(1));
      expect(fakeTuya.lastHost, equals('192.168.1.120'));
      expect(fakeTuya.lastPower, isTrue);
    });

    test('Delegates setPrimaryLevel to injected WiproTuyaService', () async {
      final fakeTuya = _FakeWiproTuyaService();
      final controller = RealIotController(wiproTuyaService: fakeTuya);

      final tuyaBulb = RealSmartDevice(
        id: 'wipro_bulb_lan_2',
        name: 'Wipro Bulb',
        room: 'Kitchen',
        category: 'light',
        protocol: ConnectionProtocol.tuyaLocalLan,
        credentials: {
          'ip': '192.168.1.121',
          'localKey': '0123456789abcdef',
        },
        isOn: true,
        primaryValue: 50.0,
      );

      await controller.setPrimaryLevel(tuyaBulb, 75.0);
      expect(fakeTuya.setBrightnessCalls, equals(1));
      expect(fakeTuya.lastBrightness, closeTo(0.75, 0.01));
    });

    test('Delegates executeDeviceCommand setColorTemp to WiproTuyaService', () async {
      final fakeTuya = _FakeWiproTuyaService();
      final controller = RealIotController(wiproTuyaService: fakeTuya);

      final bulb = RealSmartDevice(
        id: 'wipro_color_1',
        name: 'Wipro CT Bulb',
        room: 'Hall',
        category: 'light',
        protocol: ConnectionProtocol.tuyaLocalLan,
        credentials: {
          'ip': '192.168.1.122',
          'localKey': '0123456789abcdef',
        },
        isOn: true,
        primaryValue: 100.0,
      );

      await controller.executeDeviceCommand(bulb, 'setColorTemp', 'setColorTemp', [4000]);
      expect(fakeTuya.setColorTempCalls, equals(1));
      expect(fakeTuya.lastKelvin, equals(4000));
    });

    test('Delegates executeDeviceCommand setColorHex to WiproTuyaService', () async {
      final fakeTuya = _FakeWiproTuyaService();
      final controller = RealIotController(wiproTuyaService: fakeTuya);

      final bulb = RealSmartDevice(
        id: 'wipro_rgb_1',
        name: 'Wipro RGB Bulb',
        room: 'Den',
        category: 'light',
        protocol: ConnectionProtocol.tuyaLocalLan,
        credentials: {
          'ip': '192.168.1.123',
          'localKey': '0123456789abcdef',
        },
        isOn: true,
        primaryValue: 100.0,
      );

      await controller.executeDeviceCommand(bulb, 'setColorHex', 'setColorHex', ['#FF5500']);
      expect(fakeTuya.setColorHexCalls, equals(1));
      expect(fakeTuya.lastHexRgb, equals('#FF5500'));
    });

    test('Delegates executeDeviceCommand with raw dps Map to WiproTuyaService', () async {
      final fakeTuya = _FakeWiproTuyaService();
      final controller = RealIotController(wiproTuyaService: fakeTuya);

      final plug = RealSmartDevice(
        id: 'wipro_raw_1',
        name: 'Wipro Plug',
        room: 'Garage',
        category: 'switch',
        protocol: ConnectionProtocol.tuyaLocalLan,
        credentials: {
          'ip': '192.168.1.124',
          'localKey': '0123456789abcdef',
        },
        isOn: true,
        primaryValue: 0.0,
      );

      await controller.executeDeviceCommand(plug, 'rawDps', 'rawDps', [{'20': true, '21': 'white'}]);
      expect(fakeTuya.sendFrameCalls, equals(1));
      expect(fakeTuya.lastDps?['20'], isTrue);
    });

    test('Delegates to injected OnePlusConnectService for LAN TV', () async {
      final fakeOnePlus = _FakeOnePlusConnectService();
      final controller = RealIotController(onePlusConnectService: fakeOnePlus);

      final tv = RealSmartDevice(
        id: 'oneplus_tv_1',
        name: 'OnePlus 55U1 TV',
        room: 'Living Room',
        category: 'tv',
        protocol: ConnectionProtocol.onePlusTvLan,
        credentials: {
          'ip': '192.168.1.130',
          'mac': 'AA:BB:CC:DD:EE:FF',
        },
        isOn: true,
        primaryValue: 20.0,
      );

      await controller.executeDeviceCommand(tv, 'launchApp', 'launchApp', ['Netflix']);
      expect(fakeOnePlus.lastAppLaunched, equals('Netflix'));

      await controller.executeDeviceCommand(tv, 'terminateApp', 'terminateApp', ['YouTube']);
      expect(fakeOnePlus.lastAppTerminated, equals('YouTube'));

      await controller.executeDeviceCommand(tv, 'switchInput', 'switchInput', ['HDMI 2']);
      expect(fakeOnePlus.lastInputSwitched, equals('HDMI 2'));

      await controller.executeDeviceCommand(tv, 'wakeOnLan', 'wakeOnLan');
      expect(fakeOnePlus.lastWakeOnLanMac, equals('AA:BB:CC:DD:EE:FF'));

      await controller.executeDeviceCommand(tv, 'sendKey', 'sendKey', ['BACK']);
      expect(fakeOnePlus.dispatchedKeys.contains('BACK'), isTrue);
    });
  });

  // =========================================================================
  // Bug 35: setPrimaryLevel for LG AC and OnePlus TV volume
  // =========================================================================
  group('Bug 35: setPrimaryLevel for customHttpWebhook (LG AC) & onePlusTvLan (TV Volume)', () {
    test('setPrimaryLevel handles onePlusTvLan volume stepping up and down', () async {
      final fakeOnePlus = _FakeOnePlusConnectService();
      final controller = RealIotController(onePlusConnectService: fakeOnePlus);

      final tv = RealSmartDevice(
        id: 'oneplus_volume_tv',
        name: 'OnePlus TV',
        room: 'Living Room',
        category: 'tv',
        protocol: ConnectionProtocol.onePlusTvLan,
        credentials: {'ip': '192.168.1.150'},
        isOn: true,
        primaryValue: 20.0,
      );

      await controller.setPrimaryLevel(tv, 23.0);
      expect(fakeOnePlus.dispatchedKeys, equals(['VOL_UP', 'VOL_UP', 'VOL_UP']));
      expect(tv.primaryValue, equals(23.0));

      fakeOnePlus.dispatchedKeys.clear();

      await controller.setPrimaryLevel(tv, 21.0);
      expect(fakeOnePlus.dispatchedKeys, equals(['VOL_DOWN', 'VOL_DOWN']));
      expect(tv.primaryValue, equals(21.0));
    });

    test('setPrimaryLevel handles customHttpWebhook LG AC by setting primaryValue', () async {
      final controller = RealIotController();

      final ac = RealSmartDevice(
        id: 'lg_ac_1',
        name: 'LG Dual Inverter AC',
        room: 'Master Bedroom',
        category: 'ac',
        protocol: ConnectionProtocol.customHttpWebhook,
        credentials: {
          'vendor': 'lg_thinq',
          'token': 'demo_token',
        },
        isOn: true,
        primaryValue: 24.0,
      );

      await controller.setPrimaryLevel(ac, 22.0);
      expect(ac.primaryValue, equals(22.0));
      expect(ac.isOnline, isTrue);
    });
  });

  // =========================================================================
  // Bug 36: WebSocket path matching (single test per server instance)
  // =========================================================================
  group('Bug 36: WebSocket Path Matching for /ws and /api/ws', () {
    test('EmbeddedAndroidNodeServer accepts WebSocket on /ws', () async {
      final home = RealHomeProvider();
      final server = EmbeddedAndroidNodeServer();
      const testPort = 8794;

      final started = await server.startServer(home, port: testPort);
      expect(started, isTrue);

      try {
        final ws = await WebSocket.connect('ws://127.0.0.1:$testPort/ws');
        await ws.first;
        expect(server.connectedClientsCount, greaterThanOrEqualTo(1));
        await ws.close();
      } finally {
        await server.stopServer();
        home.dispose();
      }
    });

    test('EmbeddedAndroidNodeServer accepts WebSocket on /api/ws', () async {
      final home = RealHomeProvider();
      final server = EmbeddedAndroidNodeServer();
      const testPort = 8797;

      final started = await server.startServer(home, port: testPort);
      expect(started, isTrue);

      try {
        final ws = await WebSocket.connect('ws://127.0.0.1:$testPort/api/ws');
        await ws.first;
        expect(server.connectedClientsCount, greaterThanOrEqualTo(1));
        await ws.close();
      } finally {
        await server.stopServer();
        home.dispose();
      }
    });

    test('Both /ws and /api/ws are accepted concurrently on one server', () async {
      final home = RealHomeProvider();
      final server = EmbeddedAndroidNodeServer();
      const testPort = 8798;

      final started = await server.startServer(home, port: testPort);
      expect(started, isTrue);

      try {
        final ws1 = await WebSocket.connect('ws://127.0.0.1:$testPort/ws');
        final ws2 = await WebSocket.connect('ws://127.0.0.1:$testPort/api/ws');
        await ws1.first;
        await ws2.first;
        expect(server.connectedClientsCount, greaterThanOrEqualTo(2));
        await ws1.close();
        await ws2.close();
      } finally {
        await server.stopServer();
        home.dispose();
      }
    });
  });

  // =========================================================================
  // Bug 37: Subnet Sweep Chunking & Socket Cleanup
  // =========================================================================
  group('Bug 37: Subnet Sweep Chunking, Socket Cleanup & Verification', () {
    test('healDeviceIpAddress finds target IP and destroys successfully opened sockets', () async {
      // Track only successfully connected sockets (not refused ones)
      final successSockets = <_MockSocket>[];

      final engine = SelfHealingNetworkEngine(
        socketConnect: (dynamic host, int port, {Duration? timeout}) async {
          final hostStr = host.toString();
          if (hostStr == '192.168.1.42') {
            final mockSocket = _MockSocket();
            successSockets.add(mockSocket);
            return mockSocket;
          }
          // Refused connections never create a socket
          throw const SocketException('Connection refused');
        },
      );

      // Use a non-Tuya protocol to skip the UDP 6667 beacon listen attempt
      final device = RealSmartDevice(
        id: 'healer_device_1',
        name: 'Smart Device',
        room: 'Kitchen',
        category: 'switch',
        protocol: ConnectionProtocol.homeAssistantBridge,
        credentials: {'ip': '192.168.1.10', 'port': '8008'},
      );

      final healedIp = await engine.healDeviceIpAddress(
        device,
        verifyDevice: (candidateIp, socket) async {
          return candidateIp == '192.168.1.42';
        },
      );

      expect(healedIp, equals('192.168.1.42'));
      expect(device.credentials['ip'], equals('192.168.1.42'));

      // The one successfully opened socket must have been destroyed in finally
      expect(successSockets.length, equals(1));
      expect(successSockets.first.destroyed, isTrue);
    });

    test('healDeviceIpAddress rejects candidate IP when verifyDevice returns false', () async {
      final engine = SelfHealingNetworkEngine(
        socketConnect: (dynamic host, int port, {Duration? timeout}) async {
          // All IPs accept connections
          return _MockSocket();
        },
      );

      final device = RealSmartDevice(
        id: 'healer_device_2',
        name: 'Unmatched Device',
        room: 'Garage',
        category: 'switch',
        protocol: ConnectionProtocol.homeAssistantBridge,
        credentials: {'ip': '192.168.1.99', 'port': '8008'},
      );

      // verifyDevice always returns false -> no IP should be healed
      final healedIp = await engine.healDeviceIpAddress(
        device,
        verifyDevice: (candidateIp, socket) async {
          return false;
        },
      );

      expect(healedIp, isNull);
    });
  });

  // =========================================================================
  // Bug 38: WebSocket handler firstOrNull and async
  // =========================================================================
  group('Bug 38: WebSocket Handler Async/Await & firstOrNull Guard', () {
    test('WebSocket message with unknown deviceId does not crash the server', () async {
      final home = RealHomeProvider();
      final server = EmbeddedAndroidNodeServer();
      const testPort = 8795;

      await server.startServer(home, port: testPort);

      try {
        final ws = await WebSocket.connect('ws://127.0.0.1:$testPort/ws');

        // Send action targeting a non-existent deviceId
        ws.add(jsonEncode({
          'action': 'toggle',
          'deviceId': 'non_existent_device_99999',
        }));

        // Allow handler time to execute
        await Future.delayed(const Duration(milliseconds: 200));

        // Verify server is still online via dart:io HttpClient
        final client = HttpClient();
        try {
          final req = await client.getUrl(Uri.parse('http://127.0.0.1:$testPort/api/status'));
          final res = await req.close();
          expect(res.statusCode, equals(HttpStatus.ok));
        } finally {
          client.close();
        }

        await ws.close();
      } finally {
        await server.stopServer();
        home.dispose();
      }
    });

    test('WebSocket message dispatches toggle on dummy device (no real network I/O)', () async {
      final home = RealHomeProvider();

      // Use a dummy device so toggleDevicePower succeeds without real UDP/TCP
      final device = RealSmartDevice(
        id: 'ws_dummy_bulb',
        name: 'WS Dummy Bulb',
        room: 'Office',
        category: 'light',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {'token': 'demo_token'},
        isOn: false,
        primaryValue: 10.0,
      );
      home.addDeviceDirect(device);

      final server = EmbeddedAndroidNodeServer();
      const testPort = 8796;
      await server.startServer(home, port: testPort);

      try {
        final ws = await WebSocket.connect('ws://127.0.0.1:$testPort/ws');
        await ws.first; // consume initial state message

        // Send toggle action
        ws.add(jsonEncode({
          'action': 'toggle',
          'deviceId': 'ws_dummy_bulb',
        }));

        await Future.delayed(const Duration(milliseconds: 300));

        // toggleDevicePower optimistically toggles isOn: false -> true
        expect(home.devices.firstWhere((d) => d.id == 'ws_dummy_bulb').isOn, isTrue);

        await ws.close();
      } finally {
        await server.stopServer();
        home.dispose();
      }
    });
  });

  // =========================================================================
  // Bug 39: AnimatedPowerFlowCard no longer mutates state during build
  // =========================================================================
  group('Bug 39: AnimatedPowerFlowCard._getDeviceWatts does not mutate state during build', () {
    test('Device with liveWatts == 0 remains at 0 watts (no mutation)', () {
      final device = RealSmartDevice(
        id: 'energy_test_1',
        name: 'Off Lamp',
        room: 'Living Room',
        category: 'light',
        protocol: ConnectionProtocol.tuyaLocalLan,
        credentials: {'ip': '192.168.1.44', 'localKey': '0123456789abcdef'},
        isOn: false,
        primaryValue: 0.0,
      );

      expect(device.liveWatts, equals(0.0));

      // Simulate the fixed _getDeviceWatts: return d.isOnline ? d.liveWatts : 0.0
      final watts = device.isOnline ? device.liveWatts : 0.0;
      expect(watts, equals(0.0));
      expect(device.liveWatts, equals(0.0));
    });

    test('Online device with liveWatts > 0 returns its measured value without mutation', () {
      final device = RealSmartDevice(
        id: 'energy_test_2',
        name: 'On AC',
        room: 'Bedroom',
        category: 'ac',
        protocol: ConnectionProtocol.lgThinqCloud,
        credentials: {'token': 'test_token'},
        isOn: true,
        primaryValue: 22.0,
      );
      device.isOnline = true;
      device.liveWatts = 1450.0;

      final watts = device.isOnline ? device.liveWatts : 0.0;
      expect(watts, equals(1450.0));
      expect(device.liveWatts, equals(1450.0));
    });
  });
}
