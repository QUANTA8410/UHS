// test/device_level_power_state_test.dart
//
// Bug 7: setDeviceLevel Corrupts Power State on ACs and TVs
//
// Verifies that setDeviceLevel only infers isOn = newValue > 0 for lights,
// preserving the existing isOn power state for ACs (target temperature) and
// TVs (volume), preventing muted TVs from turning off and preset ACs from
// turning on prematurely.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_home/providers/real_home_provider.dart';
import 'package:unified_home/services/real_iot_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Bug 7: setDeviceLevel Power State Preservation Tests', () {
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
      required bool isOn,
      double primaryValue = 0.0,
      double ratedMaxWatts = 100.0,
    }) {
      return RealSmartDevice(
        id: id,
        name: '$category-$id',
        room: 'Living Room',
        category: category,
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {'vendor': 'demo', 'token': 'demo_$id'},
        isOn: isOn,
        primaryValue: primaryValue,
        ratedMaxWatts: ratedMaxWatts,
      );
    }

    test('1. AC: Setting target temperature when AC is OFF preserves isOn = false', () async {
      final ac = demoDevice(
        id: 'ac_living',
        category: 'ac',
        isOn: false,
        primaryValue: 24.0,
        ratedMaxWatts: 1480.0,
      );
      provider.addDeviceDirect(ac);

      await provider.setDeviceLevel(ac, 22.0);

      expect(ac.primaryValue, equals(22.0), reason: 'Target temperature should update to 22.0°C');
      expect(ac.isOn, isFalse, reason: 'AC must remain OFF when setting temperature preset');
      // When powered off, an online smart AC draws standby power (1.2 W standby)
      expect(ac.liveWatts, equals(1.2), reason: 'Powered-off AC in standby should draw 1.2 W');
    });

    test('2. AC: Setting target temperature when AC is ON preserves isOn = true', () async {
      final ac = demoDevice(
        id: 'ac_bedroom',
        category: 'ac',
        isOn: true,
        primaryValue: 26.0,
        ratedMaxWatts: 1480.0,
      );
      provider.addDeviceDirect(ac);

      await provider.setDeviceLevel(ac, 20.0);

      expect(ac.primaryValue, equals(20.0), reason: 'Target temperature should update to 20.0°C');
      expect(ac.isOn, isTrue, reason: 'Running AC must remain ON when temperature changes');
      expect(ac.liveWatts, greaterThanOrEqualTo(320.0), reason: 'Running AC should calculate active inverter wattage');
    });

    test('3. TV: Muting volume to 0 when TV is ON preserves isOn = true (does NOT turn TV off)', () async {
      final tv = demoDevice(
        id: 'tv_hall',
        category: 'tv',
        isOn: true,
        primaryValue: 25.0,
        ratedMaxWatts: 110.0,
      );
      provider.addDeviceDirect(tv);

      // User mutes the volume to 0
      await provider.setDeviceLevel(tv, 0.0);

      expect(tv.primaryValue, equals(0.0), reason: 'TV volume should be 0 (muted)');
      expect(tv.isOn, isTrue, reason: 'TV must remain ON when muted (volume 0 does not mean power off)');
      // A running TV even with volume 0 draws active panel power (75.0 W minimum)
      expect(tv.liveWatts, equals(75.0), reason: 'Active 4K panel draws 75.0 W base power when muted');
    });

    test('4. TV: Adjusting volume when TV is OFF preserves isOn = false', () async {
      final tv = demoDevice(
        id: 'tv_lounge',
        category: 'tv',
        isOn: false,
        primaryValue: 15.0,
        ratedMaxWatts: 110.0,
      );
      provider.addDeviceDirect(tv);

      await provider.setDeviceLevel(tv, 30.0);

      expect(tv.primaryValue, equals(30.0));
      expect(tv.isOn, isFalse, reason: 'TV must remain OFF when adjusting preset volume');
      expect(tv.liveWatts, equals(0.5), reason: 'Powered-off TV draws 0.5 W standby');
    });

    test('5. Light: Setting brightness > 0 turns light ON', () async {
      final light = demoDevice(
        id: 'light_ceiling',
        category: 'light',
        isOn: false,
        primaryValue: 0.0,
        ratedMaxWatts: 10.0,
      );
      provider.addDeviceDirect(light);

      await provider.setDeviceLevel(light, 75.0);

      expect(light.primaryValue, equals(75.0));
      expect(light.isOn, isTrue, reason: 'Light brightness > 0 must infer isOn = true');
      expect(light.liveWatts, greaterThan(0.4), reason: 'Active light should consume power proportional to brightness');
    });

    test('6. Light: Setting brightness to 0 turns light OFF', () async {
      final light = demoDevice(
        id: 'light_reading',
        category: 'light',
        isOn: true,
        primaryValue: 100.0,
        ratedMaxWatts: 10.0,
      );
      provider.addDeviceDirect(light);

      await provider.setDeviceLevel(light, 0.0);

      expect(light.primaryValue, equals(0.0));
      expect(light.isOn, isFalse, reason: 'Light brightness = 0 must infer isOn = false');
      expect(light.liveWatts, equals(0.4), reason: 'Turned off light draws 0.4 W standby');
    });

    test('7. setDevicePrimaryLevel alias operates identically', () async {
      final tv = demoDevice(
        id: 'tv_alias_test',
        category: 'tv',
        isOn: true,
        primaryValue: 20.0,
      );
      provider.addDeviceDirect(tv);

      await provider.setDevicePrimaryLevel(tv, 0.0);

      expect(tv.primaryValue, equals(0.0));
      expect(tv.isOn, isTrue, reason: 'setDevicePrimaryLevel alias must also preserve TV power state on mute');
    });
  });
}
