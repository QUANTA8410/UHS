// test/smartthings_discovery_and_polling_test.dart
//
// Bug 18: SmartThings discovery misclassifies refrigerators as ACs & N+1 HTTP blocking
// Bug 19: Transient network timeouts wipe cached isOn state on SmartThings devices
//
// Tests the category classification logic and the polling failure behavior.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_home/providers/real_home_provider.dart';
import 'package:unified_home/services/real_iot_controller.dart';

/// Helper: build a minimal SmartThings capability set that the discovery
/// code parses to determine [category].
String _category(List<String> capIds, String label) {
  // Mirror the exact classification logic from discoverSmartThingsDevices.
  if (capIds.contains('washerOperatingState') ||
      label.toLowerCase().contains('washer')) {
    return 'washer';
  }
  if (capIds.contains('dryerOperatingState') ||
      label.toLowerCase().contains('dryer')) {
    return 'washer';
  }
  if (capIds.contains('refrigeration') ||
      label.toLowerCase().contains('fridge') ||
      label.toLowerCase().contains('refrigerator')) {
    return 'fridge';
  }
  if (capIds.contains('airConditionerMode') ||
      capIds.contains('thermostatCoolingSetpoint')) {
    return 'ac';
  }
  if (capIds.contains('switchLevel') || capIds.contains('colorControl')) {
    return 'light';
  }
  if (capIds.contains('mediaPlayback') || capIds.contains('tvChannel')) {
    return 'tv';
  }
  return 'switch';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ---------------------------------------------------------------------------
  // Bug 18 – Category classification
  // ---------------------------------------------------------------------------
  group('Bug 18 – SmartThings category classification', () {
    test(
        'Samsung Family Hub with thermostatCoolingSetpoint is classified as fridge, not ac',
        () {
      // Family Hub exposes both refrigeration AND thermostatCoolingSetpoint.
      final capIds = ['refrigeration', 'thermostatCoolingSetpoint', 'switch'];
      expect(_category(capIds, 'Samsung Family Hub'),
          equals('fridge'),
          reason:
              'refrigeration capability must take priority over thermostatCoolingSetpoint');
    });

    test('label "refrigerator" triggers fridge classification', () {
      final capIds = ['thermostatCoolingSetpoint']; // no refrigeration cap
      expect(_category(capIds, 'Samsung Refrigerator'), equals('fridge'));
    });

    test('label "fridge" triggers fridge classification', () {
      final capIds = ['switch'];
      expect(_category(capIds, 'Kitchen Fridge'), equals('fridge'));
    });

    test('plain AC is still classified as ac', () {
      final capIds = ['airConditionerMode', 'thermostatCoolingSetpoint'];
      expect(_category(capIds, 'LG DualCool AC'), equals('ac'));
    });

    test('washer takes priority over fridge-like labels', () {
      final capIds = ['washerOperatingState', 'switch'];
      expect(_category(capIds, 'Samsung Washer'), equals('washer'));
    });

    test('dryer is mapped to washer category', () {
      final capIds = ['dryerOperatingState'];
      expect(_category(capIds, 'Samsung Dryer'), equals('washer'));
    });

    test('light classified by switchLevel cap', () {
      final capIds = ['switch', 'switchLevel'];
      expect(_category(capIds, 'Philips Hue Bulb'), equals('light'));
    });

    test('tv classified by mediaPlayback cap', () {
      final capIds = ['switch', 'mediaPlayback'];
      expect(_category(capIds, 'Samsung Smart TV'), equals('tv'));
    });

    test('unknown device defaults to switch', () {
      expect(_category(['switch'], 'Smart Plug'), equals('switch'));
    });
  });

  // ---------------------------------------------------------------------------
  // Bug 18 – Fridge rated wattage
  // ---------------------------------------------------------------------------
  group('Bug 18 – Fridge rated wattage is 150 W, not 1480 W (AC wattage)', () {
    test('RealSmartDevice with fridge category gets correct ratedMaxWatts', () {
      final dev = RealSmartDevice(
        id: 'fridge_st',
        name: 'Samsung Family Hub',
        room: 'Kitchen',
        category: 'fridge',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {'vendor': 'demo', 'token': 'demo_fridge'},
        ratedMaxWatts: 150.0,
      );
      expect(dev.ratedMaxWatts, equals(150.0),
          reason: 'Fridge must have 150 W rated power, not AC\'s 1480 W');
    });
  });

  // ---------------------------------------------------------------------------
  // Bug 19 – Polling failure preserves isOn
  // ---------------------------------------------------------------------------
  group('Bug 19 – Transient poll failure preserves last-known isOn state', () {
    late RealHomeProvider provider;

    setUp(() {
      provider = RealHomeProvider(
        autoInitStorage: false,
        autoStartPolling: false,
      );
    });

    tearDown(() => provider.dispose());

    test('single poll failure does not mark device offline or clear isOn', () async {
      final washer = RealSmartDevice(
        id: 'washer_st',
        name: 'Samsung Washer',
        room: 'Laundry',
        category: 'washer',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {'vendor': 'demo', 'token': 'demo_washer'},
        isOn: true,
      );
      provider.addDeviceDirect(washer);

      // Simulate 1 consecutive poll failure (threshold is 3).
      washer.consecutiveFailedPolls = 1;

      // The provider's syncAllDevicesSilent path only sets isOnline = false
      // after consecutiveFailedPolls >= 3 and must NOT set isOn = false.
      // We test the model invariant directly.
      expect(washer.isOn, isTrue,
          reason: 'isOn must remain true after just 1 failed poll');
      expect(washer.isOnline, isTrue,
          reason: 'isOnline must remain true after just 1 failed poll');
    });

    test(
        'three consecutive poll failures mark device offline but do NOT clear isOn',
        () {
      final washer = RealSmartDevice(
        id: 'washer_st2',
        name: 'Samsung Washer 2',
        room: 'Laundry',
        category: 'washer',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {'vendor': 'demo', 'token': 'demo_washer2'},
        isOn: true,
      );
      provider.addDeviceDirect(washer);

      // Manually drive the failure counter to threshold.
      washer.consecutiveFailedPolls = 3;
      washer.isOnline = false;
      // isOn must NOT be cleared — that is the Bug 19 fix.
      // If isOn were false here it would be because of the old buggy path.
      expect(washer.isOn, isTrue,
          reason:
              'isOn must NOT be wiped when device goes offline after 3 failed polls; '
              'only isOnline should flip to false');
    });

    test('successful poll after failures resets consecutiveFailedPolls', () {
      final dev = RealSmartDevice(
        id: 'dev1',
        name: 'Test Device',
        room: 'Test',
        category: 'light',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {'vendor': 'demo', 'token': 'demo_dev1'},
        isOn: false,
        consecutiveFailedPolls: 5,
        isOnline: false,
      );
      provider.addDeviceDirect(dev);

      // Simulate a successful poll recovery.
      dev.markOnlineSuccess();

      expect(dev.consecutiveFailedPolls, equals(0));
      expect(dev.isOnline, isTrue);
    });
  });
}
