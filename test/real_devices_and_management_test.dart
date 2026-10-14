import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_home/providers/real_home_provider.dart';
import 'package:unified_home/services/real_iot_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Real Device Management & Integration Tests', () {
    late RealHomeProvider provider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      provider = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);
    });

    tearDown(() {
      provider.dispose();
    });

    test('Provider starts empty when initialized without cache', () {
      expect(provider.devices.isEmpty, true);
    });

    test('addDirectLanDevice adds real hardware and updates list', () {
      final tv = RealSmartDevice(
        id: 'tv_oneplus_test',
        name: 'My Living Room OnePlus TV',
        room: 'Living Room',
        category: 'tv',
        protocol: ConnectionProtocol.onePlusTvLan,
        credentials: {'ip': '192.168.1.105'},
      );

      provider.addDeviceDirect(tv);

      expect(provider.devices.length, 1);
      final storedTv = provider.devices.first;
      expect(storedTv.name, 'My Living Room OnePlus TV');
      expect(storedTv.credentials['ip'], '192.168.1.105');
      expect(storedTv.protocol, ConnectionProtocol.onePlusTvLan);
    });

    test('addWiproBulbDevice adds real Wipro bulb with IP and lighting category', () {
      final bulb = RealSmartDevice(
        id: 'wipro_bulb_test',
        name: 'Bedroom Wipro Smart Bulb',
        room: 'Master Bedroom',
        category: 'light',
        protocol: ConnectionProtocol.tuyaLocalLan,
        credentials: {'ip': '192.168.1.120'},
      );

      provider.addDeviceDirect(bulb);

      expect(provider.devices.length, 1);
      final storedBulb = provider.devices.first;
      expect(storedBulb.name, 'Bedroom Wipro Smart Bulb');
      expect(storedBulb.category, 'light');
    });

    test('clearAllDevices removes all paired hardware and empties list', () async {
      final dev = RealSmartDevice(
        id: 'dev_test',
        name: 'Test Device',
        room: 'Living Room',
        category: 'switch',
        protocol: ConnectionProtocol.homeAssistantBridge,
        credentials: {},
      );
      provider.addDeviceDirect(dev);
      expect(provider.devices.isNotEmpty, true);

      await provider.clearAllDevices();
      expect(provider.devices.isEmpty, true);
    });

    test('removeDevice removes targeted hardware by id', () async {
      final d1 = RealSmartDevice(id: 'd1', name: 'D1', room: 'R', category: 'light', protocol: ConnectionProtocol.homeAssistantBridge, credentials: {});
      final d2 = RealSmartDevice(id: 'd2', name: 'D2', room: 'R', category: 'light', protocol: ConnectionProtocol.homeAssistantBridge, credentials: {});
      provider.addDeviceDirect(d1);
      provider.addDeviceDirect(d2);

      expect(provider.devices.length, 2);
      await provider.removeDevice('d1');
      expect(provider.devices.length, 1);
      expect(provider.devices.first.id, 'd2');
    });
  });
}
