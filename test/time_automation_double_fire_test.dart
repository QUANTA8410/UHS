// test/time_automation_double_fire_test.dart
//
// Bug 16: Time-Based Automations Fire Twice Within the Same Minute (45s vs 60s)
//
// Verifies that once a time-based automation fires at HH:mm, it cannot fire
// again during the same calendar minute even if _pollingTimer calls
// _evaluateTimeAutomations() multiple times within that minute.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_home/providers/real_home_provider.dart';
import 'package:unified_home/services/real_iot_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Bug 16 – Time automation same-minute cooldown', () {
    late RealHomeProvider provider;

    setUp(() {
      provider = RealHomeProvider(
        autoInitStorage: false,
        autoStartPolling: false,
      );
    });

    tearDown(() => provider.dispose());

    RealSmartDevice demoLight({required String id, bool isOn = false}) {
      return RealSmartDevice(
        id: id,
        name: 'Light $id',
        room: 'Living Room',
        category: 'light',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {'vendor': 'demo', 'token': 'demo_$id'},
        isOn: isOn,
      );
    }

    test('automation fires at matching HH:mm', () async {
      final light = demoLight(id: 'light1', isOn: true);
      provider.addDeviceDirect(light);

      final now = DateTime.now();
      final hm =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      await provider.addAutomation(SmartAutomationRule(
        id: 'rule_bug16_a',
        name: 'Night mode',
        triggerType: 'time',
        triggerValue: hm,
        targetDeviceId: 'light1',
        targetPowerState: false, // turn off
      ));

      await provider.evaluateTimeAutomationsForTesting();

      final rule = provider.automations.first;
      expect(rule.lastTriggeredAt, isNotNull,
          reason: 'Rule must record lastTriggeredAt after firing');
      expect(rule.lastTriggeredAt!.minute, equals(now.minute));
    });

    test('automation does NOT fire a second time within the same clock minute',
        () async {
      final light = demoLight(id: 'light2', isOn: true);
      provider.addDeviceDirect(light);

      final now = DateTime.now();
      final hm =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      await provider.addAutomation(SmartAutomationRule(
        id: 'rule_bug16_b',
        name: 'Night mode 2',
        triggerType: 'time',
        triggerValue: hm,
        targetDeviceId: 'light2',
        targetPowerState: false,
      ));

      // First tick fires the automation (light2 goes off).
      await provider.evaluateTimeAutomationsForTesting();
      expect(
          provider.devices.firstWhere((d) => d.id == 'light2').isOn, isFalse,
          reason: 'Light must be turned off on first tick');

      // Manually turn the light back on to detect a spurious second trigger.
      provider.devices.firstWhere((d) => d.id == 'light2').isOn = true;

      // Second tick within the same minute — automation must NOT re-fire.
      await provider.evaluateTimeAutomationsForTesting();

      expect(provider.devices.firstWhere((d) => d.id == 'light2').isOn, isTrue,
          reason:
              'A second firing within the same minute must be blocked by the same-minute cooldown guard');
    });

    test('automation at a different HH:mm does not fire on current tick',
        () async {
      final light = demoLight(id: 'light3');
      provider.addDeviceDirect(light);

      await provider.addAutomation(SmartAutomationRule(
        id: 'rule_bug16_c',
        name: 'Far future',
        triggerType: 'time',
        triggerValue: '03:47', // guaranteed to differ from current minute
        targetDeviceId: 'light3',
        targetPowerState: true,
      ));

      await provider.evaluateTimeAutomationsForTesting();

      expect(
          provider.devices.firstWhere((d) => d.id == 'light3').isOn, isFalse,
          reason: 'Automation for a different time must not fire now');
      expect(provider.automations.first.lastTriggeredAt, isNull,
          reason: 'lastTriggeredAt must remain null when rule did not fire');
    });

    test('disabled automation is never executed', () async {
      final light = demoLight(id: 'light4');
      provider.addDeviceDirect(light);

      final now = DateTime.now();
      final hm =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      await provider.addAutomation(SmartAutomationRule(
        id: 'rule_bug16_d',
        name: 'Disabled rule',
        triggerType: 'time',
        triggerValue: hm,
        targetDeviceId: 'light4',
        targetPowerState: true,
        isEnabled: false,
      ));

      await provider.evaluateTimeAutomationsForTesting();

      expect(
          provider.automations.first.lastTriggeredAt, isNull,
          reason: 'Disabled automation must never fire');
    });
  });
}
