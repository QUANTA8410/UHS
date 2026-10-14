import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_home/providers/real_home_provider.dart';
import 'package:unified_home/services/real_iot_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RealHomeProvider Model & Capability Tests', () {
    late RealHomeProvider provider;

    setUp(() {
      provider = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);
    });

    tearDown(() {
      provider.dispose();
    });

    test('Initializes with clean state and adds direct devices', () async {
      expect(provider.allDevices.isEmpty, true);

      final washer = RealSmartDevice(
        id: 'samsung_washer',
        name: 'Samsung Ecobubble™ AI DD Washer',
        room: 'Laundry Room',
        category: 'washer',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {'cloudDeviceId': 'st_washer_01'},
        isOn: false,
        liveWatts: 0.0,
      );

      final ac = RealSmartDevice(
        id: 'lg_dualcool_ac',
        name: 'LG DualCool AI Inverter AC',
        room: 'Living Room',
        category: 'ac',
        protocol: ConnectionProtocol.customHttpWebhook,
        credentials: {'cloudDeviceId': 'lg_ac_01'},
        isOn: false,
        liveWatts: 0.0,
      );

      provider.addDeviceDirect(washer);
      provider.addDeviceDirect(ac);

      expect(provider.allDevices.length, 2);
      expect(provider.rooms.length, 2);
      expect(provider.devicesInRoom('Laundry Room').length, 1);
    });

    test('Toggle device power flips state and updates active appliances count', () async {
      final dev = RealSmartDevice(
        id: 'bulb_1',
        name: 'Living Room Bulb',
        room: 'Living Room',
        category: 'light',
        protocol: ConnectionProtocol.tuyaLocalLan,
        credentials: {'vendor': 'demo'},
        isOn: false,
      );
      provider.addDeviceDirect(dev);

      expect(provider.activeLightsCount, 0);
      await provider.toggleDevicePower(dev);
      expect(dev.isOn, true);
      expect(provider.activeLightsCount, 1);
    });

    test('Samsung Washer updates cycle, water temperature, and EcoBubble', () {
      final washer = RealSmartDevice(
        id: 'washer_1',
        name: 'Samsung Washer',
        room: 'Laundry',
        category: 'washer',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {},
      );
      provider.addDeviceDirect(washer);

      provider.updateSamsungWasher(
        'washer_1',
        cycle: 'Steam Refresh',
        waterTemp: 60,
        spinSpeed: 'Max',
        ecoBubble: true,
        recommendedRecipe: 'Sanitizing Steam Care',
      );

      final updated = provider.allDevices.firstWhere((d) => d.id == 'washer_1');
      expect(updated.selectedCycle, 'Steam Refresh');
      expect(updated.liveAttributes['waterTemperature'], 60);
      expect(updated.liveAttributes['spinSpeed'], 'Max');
      expect(updated.ecoBubbleEnabled, true);
      expect(updated.recommendedLaundryRecipe, 'Sanitizing Steam Care');
    });

    test('LG AC updates target temperature and Jet Cool mode', () {
      final ac = RealSmartDevice(
        id: 'ac_1',
        name: 'LG DualCool AC',
        room: 'Living Room',
        category: 'ac',
        protocol: ConnectionProtocol.customHttpWebhook,
        credentials: {},
      );
      provider.addDeviceDirect(ac);

      provider.updateLgAc('ac_1', targetTemp: 19.5, fanSpeed: 'high', jetCool: true);

      final updated = provider.allDevices.firstWhere((d) => d.id == 'ac_1');
      expect(updated.primaryValue, 19.5);
      expect(updated.targetTempC, 19.5);
      expect(updated.jetCoolActive, true);
    });

    test('Live power topology telemetry sums wattage accurately', () {
      final d1 = RealSmartDevice(
        id: 'dev_1',
        name: 'Washer',
        room: 'Laundry',
        category: 'washer',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {},
        liveWatts: 450.0,
      );
      final d2 = RealSmartDevice(
        id: 'dev_2',
        name: 'AC',
        room: 'Living Room',
        category: 'ac',
        protocol: ConnectionProtocol.customHttpWebhook,
        credentials: {},
        liveWatts: 1200.0,
      );
      final d3 = RealSmartDevice(
        id: 'dev_3',
        name: 'Bulb',
        room: 'Bedroom',
        category: 'light',
        protocol: ConnectionProtocol.tuyaLocalLan,
        credentials: {},
        liveWatts: 12.0,
      );

      provider.addDeviceDirect(d1);
      provider.addDeviceDirect(d2);
      provider.addDeviceDirect(d3);

      expect(provider.totalLiveWatts, 1662.0);
      expect(provider.hvacAndLaundryWatts, 1650.0);
      expect(provider.lightingAndMediaWatts, 12.0);
    });
  });
}
