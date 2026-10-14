import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:unified_home/models/device_model.dart';
import 'package:unified_home/providers/home_state.dart';
import 'package:unified_home/ui/widgets/dialogs/add_device_dialog.dart';
import 'package:unified_home/ui/views/devices_view.dart';

void main() {
  group('Real Device Management & Integration Tests', () {
    late HomeState state;

    setUp(() {
      state = HomeState();
    });

    test('Initial state detects preloaded dummy devices', () {
      expect(state.hasDummyDevices, true);
      expect(state.allDevices.any((d) => d.isDummy), true);
    });

    test('clearDummyDevices removes all preloaded demo hardware', () async {
      await state.clearDummyDevices();
      expect(state.hasDummyDevices, false);
      expect(state.allDevices.isEmpty, true);
    });

    test('restoreDemoFleet restores sample demo fleet when requested', () async {
      await state.clearDummyDevices();
      expect(state.allDevices.isEmpty, true);

      await state.restoreDemoFleet();
      expect(state.hasDummyDevices, true);
      expect(state.allDevices.length, greaterThanOrEqualTo(5));
    });

    test('addOnePlusTvDevice adds real TV with LAN IP and localLan protocol', () async {
      await state.clearDummyDevices();

      await state.addOnePlusTvDevice(
        name: 'My Living Room OnePlus TV',
        host: '192.168.1.105',
        room: 'Living Room',
      );

      expect(state.allDevices.length, 1);
      final tv = state.allDevices.first as TvDevice;
      expect(tv.name, 'My Living Room OnePlus TV');
      expect(tv.host, '192.168.1.105');
      expect(tv.protocol, DeviceProtocol.localLan);
      expect(tv.isDummy, false);
    });

    test('addWiproBulbDevice adds real Wipro bulb with IP and lighting category', () async {
      await state.clearDummyDevices();

      await state.addWiproBulbDevice(
        name: 'Bedroom Wipro Smart Bulb',
        host: '192.168.1.120',
        room: 'Master Bedroom',
      );

      expect(state.allDevices.length, 1);
      final bulb = state.allDevices.first as LightDevice;
      expect(bulb.name, 'Bedroom Wipro Smart Bulb');
      expect(bulb.host, '192.168.1.120');
      expect(bulb.brand, 'Wipro Smart Next');
      expect(bulb.isDummy, false);
    });

    test('SmartDevice serialization and deserialization preserves network host and dummy status', () {
      final originalTv = TvDevice(
        id: 'tv_test_1',
        name: 'Test OnePlus TV',
        room: 'Living Room',
        protocol: DeviceProtocol.localLan,
        host: '192.168.1.150',
        port: 5555,
        isDummy: false,
      );

      final json = originalTv.toJson();
      final restored = SmartDevice.fromJson(json) as TvDevice;

      expect(restored.id, 'tv_test_1');
      expect(restored.host, '192.168.1.150');
      expect(restored.port, 5555);
      expect(restored.isDummy, false);
    });
  });

  group('AddDeviceDialog & Fleet UI Tests', () {
    testWidgets('AddDeviceDialog renders Wi-Fi Scan, SmartThings, LG ThinQ, OnePlus TV, and Wipro tabs', (tester) async {
      final state = HomeState();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: state,
          child: const MaterialApp(
            home: Scaffold(
              body: AddDeviceDialog(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Add & Connect Real Devices'), findsOneWidget);
      expect(find.text('Wi-Fi Scan'), findsOneWidget);
      expect(find.text('SmartThings'), findsOneWidget);
      expect(find.text('LG ThinQ'), findsOneWidget);
      expect(find.text('OnePlus TV'), findsOneWidget);
      expect(find.text('Wipro Bulb'), findsOneWidget);
    });

    testWidgets('DevicesView displays sample banner with Clear All button when dummy devices are active', (tester) async {
      final state = HomeState();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: state,
          child: const MaterialApp(
            home: DevicesView(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Sample Demo Devices Active'), findsOneWidget);
      expect(find.text('Clear All'), findsOneWidget);
    });
  });
}
