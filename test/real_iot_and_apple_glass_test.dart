import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_home/providers/real_home_provider.dart';
import 'package:unified_home/services/real_iot_controller.dart';
import 'package:unified_home/theme/apple_glass_theme.dart';
import 'package:unified_home/ui/views/apple_glass_home_shell.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RealSmartDevice and RealIotController Unit Tests', () {
    test('RealSmartDevice serialization and deserialization preserves credentials', () {
      final device = RealSmartDevice(
        id: 'real_st_washer_uuid_1234',
        name: 'Samsung AI Ecobubble Washer',
        room: 'Laundry Room',
        category: 'washer',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {'token': 'test_bearer_pat_token'},
        isOn: false,
        isOnline: true,
        primaryValue: 1200.0,
        liveAttributes: {'machineState': 'run', 'completionTime': '2026-10-14T01:00:00Z'},
      );

      final json = device.toJson();
      expect(json['id'], 'real_st_washer_uuid_1234');
      expect(json['credentials']['token'], 'test_bearer_pat_token');
      expect(json['category'], 'washer');

      final deserialized = RealSmartDevice.fromJson(json);
      expect(deserialized.id, device.id);
      expect(deserialized.name, device.name);
      expect(deserialized.protocol, ConnectionProtocol.smartThingsCloud);
      expect(deserialized.credentials['token'], 'test_bearer_pat_token');
      expect(deserialized.liveAttributes['machineState'], 'run');
    });

    test('SmartAutomationRule model serialization and deserialization', () {
      final rule = SmartAutomationRule(
        id: 'auto_rule_1',
        name: 'Night Laundry Finish',
        triggerType: 'time',
        triggerValue: '23:30',
        targetDeviceId: 'real_st_washer_uuid_1234',
        targetPowerState: false,
        targetLevel: null,
      );

      final json = rule.toJson();
      expect(json['triggerValue'], '23:30');
      expect(json['targetPowerState'], false);

      final parsed = SmartAutomationRule.fromJson(json);
      expect(parsed.id, 'auto_rule_1');
      expect(parsed.name, 'Night Laundry Finish');
      expect(parsed.isEnabled, true);
    });
  });

  group('RealHomeProvider Tests', () {
    test('Starts with empty device list when no devices are paired', () async {
      final provider = RealHomeProvider(autoStartPolling: false);
      expect(provider.devices.isEmpty, isTrue);
      expect(provider.automations.isEmpty, isTrue);
      provider.dispose();
    });

    test('Add, toggle, and remove automation rules', () async {
      final provider = RealHomeProvider(autoStartPolling: false);
      final rule = SmartAutomationRule(
        id: 'rule_100',
        name: 'Turn off living room AC at night',
        triggerType: 'time',
        triggerValue: '23:00',
        targetDeviceId: 'dev_ac_1',
        targetPowerState: false,
      );

      await provider.addAutomation(rule);
      expect(provider.automations.length, 1);
      expect(provider.automations.first.isEnabled, isTrue);

      await provider.toggleAutomationEnabled('rule_100');
      expect(provider.automations.first.isEnabled, isFalse);

      await provider.deleteAutomation('rule_100');
      expect(provider.automations.isEmpty, isTrue);
      provider.dispose();
    });
  });

  group('Apple Glass UI Shell Widget Tests', () {
    testWidgets('Renders Apple visionOS / iOS 26 Liquid Glass Shell and Empty State', (WidgetTester tester) async {
      final provider = RealHomeProvider(autoStartPolling: false);

      await tester.pumpWidget(
        ChangeNotifierProvider<RealHomeProvider>.value(
          value: provider,
          child: MaterialApp(
            theme: AppleGlassTheme.themeData,
            home: const AppleGlassHomeShell(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Check title and dock pills
      expect(find.text('My Home'), findsOneWidget);
      expect(find.text('Pair Device'), findsOneWidget);
      expect(find.text('No Dummy Devices Loaded'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.byIcon(Icons.view_in_ar_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);

      provider.dispose();
    });

    testWidgets('Switch to 3D Spatial Twin and Automations tabs in Apple Glass Dock', (WidgetTester tester) async {
      final provider = RealHomeProvider(autoStartPolling: false);

      await tester.pumpWidget(
        ChangeNotifierProvider<RealHomeProvider>.value(
          value: provider,
          child: MaterialApp(
            theme: AppleGlassTheme.themeData,
            home: const AppleGlassHomeShell(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Tap 3D Map icon in dock
      await tester.tap(find.byIcon(Icons.view_in_ar_rounded));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('3D Spatial Twin'), findsOneWidget);
      expect(find.text('Isometric 3D'), findsOneWidget);
      expect(find.text('Top Blueprint'), findsOneWidget);

      // Tap Automations icon in dock
      await tester.tap(find.byIcon(Icons.bolt_rounded));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Automations'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Automation Rule'), findsAtLeastNWidgets(1));

      provider.dispose();
    });
  });
}
