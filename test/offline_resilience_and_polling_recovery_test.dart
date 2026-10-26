import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_home/providers/real_home_provider.dart';
import 'package:unified_home/services/real_iot_controller.dart';
import 'package:unified_home/theme/apple_glass_theme.dart';
import 'package:unified_home/ui/views/apple_glass_home_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Bug 2: Resilient Polling & Offline Lockout Recovery Tests', () {
    test('RealSmartDevice serialization and deserialization preserves consecutiveFailedPolls', () {
      final dev = RealSmartDevice(
        id: 'test_dev_polls_01',
        name: 'Poll Test Device',
        room: 'Living Room',
        category: 'light',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {'token': 'test_token'},
        isOn: true,
        isOnline: true,
        consecutiveFailedPolls: 2,
      );

      final json = dev.toJson();
      expect(json['consecutiveFailedPolls'], equals(2));

      final parsed = RealSmartDevice.fromJson(json);
      expect(parsed.consecutiveFailedPolls, equals(2));
      expect(parsed.isOnline, isTrue);

      // markOnlineSuccess resets consecutive failures and clears lastError
      parsed.lastError = 'Connection refused';
      parsed.markOnlineSuccess();
      expect(parsed.isOnline, isTrue);
      expect(parsed.consecutiveFailedPolls, equals(0));
      expect(parsed.lastError, isNull);
    });

    test('3 consecutive failed polls mark device offline, while 1 and 2 keep it online', () async {
      final provider = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);

      // Create a device with a non-reachable endpoint that will fail when polled
      final dev = RealSmartDevice(
        id: 'failing_dev_01',
        name: 'Unreachable SmartLight',
        room: 'Balcony',
        category: 'light',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {'token': 'invalid_poll_pat_token'},
        isOn: true,
        isOnline: true,
        ratedMaxWatts: 60.0,
      );
      provider.addDeviceDirect(dev);

      expect(dev.isOnline, isTrue);
      expect(dev.consecutiveFailedPolls, equals(0));
      expect(dev.isOn, isTrue);

      // --- Poll 1 (Failure 1) ---
      await provider.syncAllDevicesSilent();
      expect(dev.consecutiveFailedPolls, equals(1));
      expect(dev.isOnline, isTrue, reason: 'Device should remain online on first failure');
      expect(dev.isOn, isTrue);

      // --- Poll 2 (Failure 2) ---
      await provider.syncAllDevicesSilent();
      expect(dev.consecutiveFailedPolls, equals(2));
      expect(dev.isOnline, isTrue, reason: 'Device should remain online on second failure');
      expect(dev.isOn, isTrue);

      // --- Poll 3 (Failure 3: Threshold reached) ---
      await provider.syncAllDevicesSilent();
      expect(dev.consecutiveFailedPolls, equals(3));
      expect(dev.isOnline, isFalse, reason: 'Device must be marked offline after 3 consecutive failures');
      expect(dev.isOn, isTrue, reason: 'Preserve last known isOn state on poll failure per Bug 19');
      expect(dev.liveWatts, equals(0.0), reason: 'Live wattage must drop to 0.0 W when offline');

      // --- Clean recovery / markOnlineSuccess ---
      dev.markOnlineSuccess();
      expect(dev.isOnline, isTrue);
      expect(dev.consecutiveFailedPolls, equals(0));
      expect(dev.lastError, isNull);

      provider.dispose();
    });

    test('Resurrection: setPower resurrects offline device without lockout exception', () async {
      final controller = RealIotController();
      final offlineDev = RealSmartDevice(
        id: 'offline_bulb_demo',
        name: 'Demo Lamp',
        room: 'Study',
        category: 'light',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {'vendor': 'demo'},
        isOn: false,
        isOnline: false,
        consecutiveFailedPolls: 3,
        lastError: 'HTTP 500 Server Error',
      );

      expect(offlineDev.isOnline, isFalse);

      // Dispatching setPower must NOT throw offline lockout guard
      await controller.setPower(offlineDev, true);

      expect(offlineDev.isOn, isTrue);
      expect(offlineDev.isOnline, isTrue, reason: 'Device must be resurrected online on successful power dispatch');
      expect(offlineDev.consecutiveFailedPolls, equals(0));
      expect(offlineDev.lastError, isNull);
    });

    test('Resurrection: setPrimaryLevel resurrects offline device and updates watts', () async {
      final controller = RealIotController();
      final offlineDev = RealSmartDevice(
        id: 'offline_ac_demo',
        name: 'Living Room AC Demo',
        room: 'Living Room',
        category: 'ac',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {'vendor': 'demo'},
        isOn: false,
        isOnline: false,
        consecutiveFailedPolls: 4,
        primaryValue: 24.0,
      );

      expect(offlineDev.isOnline, isFalse);

      // Setting primary level must resurrect the device
      await controller.setPrimaryLevel(offlineDev, 21.0);

      expect(offlineDev.isOnline, isTrue);
      expect(offlineDev.consecutiveFailedPolls, equals(0));
      expect(offlineDev.primaryValue, equals(21.0));
    });

    test('Resurrection: executeDeviceCommand executes without offline lockout guard', () async {
      final controller = RealIotController();
      final offlineDev = RealSmartDevice(
        id: 'offline_cmd_demo',
        name: 'Appliance Demo',
        room: 'Kitchen',
        category: 'switch',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {'vendor': 'demo'},
        isOn: false,
        isOnline: false,
        consecutiveFailedPolls: 3,
      );

      // Should not throw offline lockout exception
      await controller.executeDeviceCommand(offlineDev, 'switch', 'on');
      expect(offlineDev.isOnline, isTrue);
      expect(offlineDev.consecutiveFailedPolls, equals(0));
    });

    test('toggleDevicePower in RealHomeProvider resurrects previously offline device', () async {
      final provider = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);
      final dev = RealSmartDevice(
        id: 'provider_resurrect_demo',
        name: 'Bedroom Lamp',
        room: 'Bedroom',
        category: 'light',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {'vendor': 'demo'},
        isOn: false,
        isOnline: false,
        consecutiveFailedPolls: 3,
        lastError: 'Network unreachable',
      );
      provider.addDeviceDirect(dev);

      expect(dev.isOnline, isFalse);
      expect(dev.isOn, isFalse);

      await provider.toggleDevicePower(dev);

      expect(dev.isOn, isTrue);
      expect(dev.isOnline, isTrue);
      expect(dev.consecutiveFailedPolls, equals(0));
      expect(dev.lastError, isNull);

      provider.dispose();
    });

    testWidgets('Device control sheet Power button is interactive when offline and resurrects device',
        (WidgetTester tester) async {
      final provider = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);
      final dev = RealSmartDevice(
        id: 'offline_sheet_device_demo',
        name: 'Living Room Smart Plug',
        room: 'Living Room',
        category: 'switch',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {'vendor': 'demo'},
        isOn: false,
        isOnline: false,
        consecutiveFailedPolls: 3,
        lastError: 'Socket timeout',
      );
      provider.addDeviceDirect(dev);

      await tester.pumpWidget(
        ChangeNotifierProvider<RealHomeProvider>.value(
          value: provider,
          child: MaterialApp(
            theme: AppleGlassTheme.themeData,
            home: Scaffold(
              body: AppleGlassDeviceControlSheet(initialDevice: dev),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Verify the device control sheet is rendered
      expect(find.text('STANDBY / OFF'), findsOneWidget);
      final turnOnButtonFinder = find.widgetWithText(ElevatedButton, 'Turn On');
      expect(turnOnButtonFinder, findsOneWidget);

      // Verify button is ENABLED (onPressed is not null even though isOnline is false)
      final elevatedButton = tester.widget<ElevatedButton>(turnOnButtonFinder);
      expect(elevatedButton.onPressed, isNotNull, reason: 'Power button must not be disabled when offline');

      // Tap the Turn On button to resurrect the device
      await tester.tap(turnOnButtonFinder);
      await tester.pump(const Duration(milliseconds: 300));

      // Device is now powered and back online
      expect(dev.isOn, isTrue);
      expect(dev.isOnline, isTrue);
      expect(dev.consecutiveFailedPolls, equals(0));

      // Reconnection SnackBar is shown
      expect(find.text('Reconnected to Living Room Smart Plug! Device is back online.'), findsOneWidget);

      provider.dispose();
    });
  });
}
