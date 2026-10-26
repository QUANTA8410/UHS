// test/presence_automation_exemption_test.dart
//
// Bug 15: Leaving Home Presence Automation Turns Off Refrigerators and Security Cameras
//
// Verifies that the leaving-home power-off logic correctly exempts fridge,
// camera, and washer categories so that refrigerators, security cameras, and
// active laundry machines are never powered off when the user walks out.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_home/providers/real_home_provider.dart';
import 'package:unified_home/services/real_iot_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Bug 15 – Presence automation exempts critical appliances', () {
    late RealHomeProvider provider;

    setUp(() {
      provider = RealHomeProvider(
        autoInitStorage: false,
        autoStartPolling: false,
      );
    });

    tearDown(() => provider.dispose());

    RealSmartDevice demoDevice({
      required String id,
      required String category,
      bool isOn = true,
    }) {
      return RealSmartDevice(
        id: id,
        name: '$category-$id',
        room: 'Home',
        category: category,
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {'vendor': 'demo', 'token': 'demo_$id'},
        isOn: isOn,
      );
    }

    test('fridge stays on when user leaves home', () async {
      final fridge = demoDevice(id: 'fridge1', category: 'fridge');
      final light = demoDevice(id: 'light1', category: 'light');
      provider.addDeviceDirect(fridge);
      provider.addDeviceDirect(light);

      await provider.simulatePresenceDeparture();

      expect(provider.devices.firstWhere((d) => d.id == 'fridge1').isOn, isTrue,
          reason: 'Fridge must never be powered off by leaving-home automation');
      expect(provider.devices.firstWhere((d) => d.id == 'light1').isOn, isFalse,
          reason: 'Non-exempt light should be turned off');
    });

    test('security camera stays on when user leaves home', () async {
      final cam = demoDevice(id: 'cam1', category: 'camera');
      final fan = demoDevice(id: 'fan1', category: 'fan');
      provider.addDeviceDirect(cam);
      provider.addDeviceDirect(fan);

      await provider.simulatePresenceDeparture();

      expect(provider.devices.firstWhere((d) => d.id == 'cam1').isOn, isTrue,
          reason: 'Camera must stay on for security when user leaves');
      expect(provider.devices.firstWhere((d) => d.id == 'fan1').isOn, isFalse);
    });

    test('active washer stays on when user leaves home', () async {
      final washer = demoDevice(id: 'washer1', category: 'washer');
      final tv = demoDevice(id: 'tv1', category: 'tv');
      provider.addDeviceDirect(washer);
      provider.addDeviceDirect(tv);

      await provider.simulatePresenceDeparture();

      expect(provider.devices.firstWhere((d) => d.id == 'washer1').isOn, isTrue,
          reason: 'Active washer cycle must not be aborted by leaving-home automation');
      expect(provider.devices.firstWhere((d) => d.id == 'tv1').isOn, isFalse);
    });

    test('all three exempt categories coexist with non-exempt devices', () async {
      final fridge = demoDevice(id: 'fridge1', category: 'fridge');
      final cam = demoDevice(id: 'cam1', category: 'camera');
      final washer = demoDevice(id: 'washer1', category: 'washer');
      final light = demoDevice(id: 'light1', category: 'light');
      final ac = demoDevice(id: 'ac1', category: 'ac');

      for (final d in [fridge, cam, washer, light, ac]) {
        provider.addDeviceDirect(d);
      }

      await provider.simulatePresenceDeparture();

      expect(provider.devices.firstWhere((d) => d.id == 'fridge1').isOn, isTrue);
      expect(provider.devices.firstWhere((d) => d.id == 'cam1').isOn, isTrue);
      expect(provider.devices.firstWhere((d) => d.id == 'washer1').isOn, isTrue);
      expect(provider.devices.firstWhere((d) => d.id == 'light1').isOn, isFalse);
      expect(provider.devices.firstWhere((d) => d.id == 'ac1').isOn, isFalse);
    });

    test('already-off devices remain off regardless of category', () async {
      final fridge = demoDevice(id: 'fridge1', category: 'fridge', isOn: false);
      final light = demoDevice(id: 'light1', category: 'light', isOn: false);
      provider.addDeviceDirect(fridge);
      provider.addDeviceDirect(light);

      await provider.simulatePresenceDeparture();

      expect(provider.devices.firstWhere((d) => d.id == 'fridge1').isOn, isFalse);
      expect(provider.devices.firstWhere((d) => d.id == 'light1').isOn, isFalse);
    });
  });
}
