import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_home/providers/real_home_provider.dart';
import 'package:unified_home/services/real_iot_controller.dart';
import 'package:unified_home/ui/widgets/energy/animated_power_flow_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Live Power Telemetry & Hardware Curves Tests', () {
    final controller = RealIotController();

    test('Strict Offline = 0.0 W Rule', () {
      final offlineDev = RealSmartDevice(
        id: 'washer_offline',
        name: 'Samsung Washer',
        room: 'Utility',
        category: 'washer',
        isOn: true,
        isOnline: false,
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: const {},
      );

      final watts = controller.computeDeviceLiveWattage(offlineDev);
      expect(watts, equals(0.0));
      expect(offlineDev.liveWatts, equals(0.0));
      expect(offlineDev.liveAttributes['powerSource'], contains('Offline'));
    });

    test('Direct Hardware Sensor Telemetry takes precedence when present', () {
      final sensorDev = RealSmartDevice(
        id: 'plug_01',
        name: 'Tuya Smart Plug',
        room: 'Kitchen',
        category: 'plug',
        isOn: true,
        isOnline: true,
        protocol: ConnectionProtocol.tuyaCloudDirect,
        credentials: const {},
        liveAttributes: {'powerW': 1250.5, 'powerSource': 'Smart Meter'},
      );

      final watts = controller.computeDeviceLiveWattage(sensorDev);
      expect(watts, equals(1250.5));
      expect(sensorDev.liveWatts, equals(1250.5));
      expect(sensorDev.liveAttributes['powerSource'], equals('Smart Meter'));
    });

    test('Samsung Washer physics curve: run, pause, stop', () {
      final washer = RealSmartDevice(
        id: 'samsung_washer',
        name: 'AI Ecobubble',
        room: 'Utility',
        category: 'washer',
        isOn: true,
        isOnline: true,
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: const {},
        liveAttributes: {'machineState': 'run'},
      );

      // 1. Running state -> 480.0 W
      expect(controller.computeDeviceLiveWattage(washer), equals(480.0));
      expect(washer.liveAttributes['powerSource'], contains('Samsung AI EcoBubble'));

      // 2. Paused state -> 4.5 W
      washer.liveAttributes = {'machineState': 'pause'};
      expect(controller.computeDeviceLiveWattage(washer), equals(4.5));
      expect(washer.liveAttributes['powerSource'], contains('Standby'));

      // 3. Stopped state -> 0.0 W
      washer.liveAttributes = {'machineState': 'stop'};
      washer.isOn = false;
      expect(controller.computeDeviceLiveWattage(washer), equals(0.0));
    });

    test('LG DualCool Inverter AC temperature delta curve', () {
      final ac = RealSmartDevice(
        id: 'lg_ac',
        name: 'DualCool AC',
        room: 'Master Bedroom',
        category: 'ac',
        isOn: true,
        isOnline: true,
        primaryValue: 24.0, // target temp
        protocol: ConnectionProtocol.customHttpWebhook,
        credentials: const {'vendor': 'lg_thinq'},
        liveAttributes: {'currentTemperature': 30.0}, // delta = 6 C
      );

      // (320.0 + (6 * 92.0)) = 872.0 W
      final watts = controller.computeDeviceLiveWattage(ac);
      expect(watts, closeTo(872.0, 0.1));
      expect(ac.liveAttributes['powerSource'], contains('DualCool Inverter Curve'));

      // Standby draw when turned off -> 1.2 W
      ac.isOn = false;
      expect(controller.computeDeviceLiveWattage(ac), equals(1.2));
      expect(ac.liveAttributes['powerSource'], contains('LG Inverter Standby'));
    });

    test('Wipro 9W LED Bulb brightness-proportional curve', () {
      final bulb = RealSmartDevice(
        id: 'wipro_bulb',
        name: 'Wipro Smart Light',
        room: 'Living Room',
        category: 'light',
        isOn: true,
        isOnline: true,
        primaryValue: 100.0, // 100%
        ratedMaxWatts: 9.0,
        protocol: ConnectionProtocol.tuyaCloudDirect,
        credentials: const {},
      );

      // 100% brightness -> 0.4 + 9.0 = 9.4 W
      expect(controller.computeDeviceLiveWattage(bulb), closeTo(9.4, 0.1));

      // 50% brightness -> 0.4 + 4.5 = 4.9 W
      bulb.primaryValue = 50.0;
      expect(controller.computeDeviceLiveWattage(bulb), closeTo(4.9, 0.1));

      // Standby when OFF -> 0.4 W
      bulb.isOn = false;
      expect(controller.computeDeviceLiveWattage(bulb), equals(0.4));
      expect(bulb.liveAttributes['powerSource'], contains('Wipro Standby'));
    });

    test('OnePlus TV volume-proportional curve', () {
      final tv = RealSmartDevice(
        id: 'oneplus_tv',
        name: 'OnePlus TV U1S',
        room: 'Living Room',
        category: 'tv',
        isOn: true,
        isOnline: true,
        primaryValue: 40.0, // 40% volume
        protocol: ConnectionProtocol.onePlusTvLan,
        credentials: const {},
      );

      // 75.0 + (0.40 * 35.0) = 89.0 W
      expect(controller.computeDeviceLiveWattage(tv), closeTo(89.0, 0.1));

      // Standby when OFF -> 0.5 W
      tv.isOn = false;
      expect(controller.computeDeviceLiveWattage(tv), equals(0.5));
      expect(tv.liveAttributes['powerSource'], contains('OnePlus Standby'));
    });
  });

  group('RealHomeProvider Power Aggregation & Riemann Sum Energy Tests', () {
    test('Aggregates live watts and appliance categories accurately', () {
      final provider = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);

      final washer = RealSmartDevice(
        id: 'w1',
        name: 'Samsung Washer',
        room: 'Utility',
        category: 'washer',
        isOn: true,
        isOnline: true,
        liveWatts: 480.0,
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: const {},
      );

      final ac = RealSmartDevice(
        id: 'ac1',
        name: 'LG AC',
        room: 'Living Room',
        category: 'ac',
        isOn: true,
        isOnline: true,
        liveWatts: 850.0,
        protocol: ConnectionProtocol.customHttpWebhook,
        credentials: const {'vendor': 'lg_thinq'},
      );

      final light = RealSmartDevice(
        id: 'l1',
        name: 'Wipro Bulb',
        room: 'Bedroom',
        category: 'light',
        isOn: true,
        isOnline: true,
        liveWatts: 7.6,
        protocol: ConnectionProtocol.tuyaCloudDirect,
        credentials: const {},
      );

      final offlineDev = RealSmartDevice(
        id: 'tv1',
        name: 'TV',
        room: 'Living Room',
        category: 'tv',
        isOn: true,
        isOnline: false,
        liveWatts: 0.0,
        protocol: ConnectionProtocol.onePlusTvLan,
        credentials: const {},
      );

      provider.addDeviceDirect(washer);
      provider.addDeviceDirect(ac);
      provider.addDeviceDirect(light);
      provider.addDeviceDirect(offlineDev);
      provider.todayAccumulatedKwh = 4.5;

      expect(provider.devices.length, equals(4));
      expect(provider.totalLiveWatts, equals(1337.6));
      expect(provider.hvacAndLaundryWatts, equals(1330.0));
      expect(provider.lightingAndMediaWatts, closeTo(7.6, 0.1));
      expect(provider.activeDrawingDevicesCount, equals(3));
      expect(provider.todayAccumulatedKwh, equals(4.5));
      expect(provider.estimatedTodayCostInr, closeTo(4.5 * 7.50, 0.01));
    });
  });

  group('AnimatedPowerFlowCard Widget Tests', () {
    testWidgets('Renders empty state when 0 devices connected', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 360,
                child: AnimatedPowerFlowCard(devices: []),
              ),
            ),
          ),
        ),
      );

      expect(find.text('LIVE POWER TOPOLOGY'), findsOneWidget);
      expect(find.textContaining('0 W  •  ₹0.00/hr'), findsOneWidget);
      expect(find.textContaining('No appliances paired'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Renders live telemetry list and topology for active fleet', (tester) async {
      final devices = [
        RealSmartDevice(
          id: 'washer_01',
          name: 'Samsung AI Ecobubble',
          room: 'Utility Room',
          category: 'washer',
          isOn: true,
          isOnline: true,
          protocol: ConnectionProtocol.smartThingsCloud,
          credentials: const {},
          liveAttributes: {'machineState': 'run'},
        ),
        RealSmartDevice(
          id: 'bulb_01',
          name: 'Wipro 9W Smart LED',
          room: 'Living Room',
          category: 'light',
          isOn: true,
          isOnline: true,
          primaryValue: 80.0,
          protocol: ConnectionProtocol.tuyaCloudDirect,
          credentials: const {},
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 360,
                child: AnimatedPowerFlowCard(devices: devices),
              ),
            ),
          ),
        ),
      );

      expect(find.text('LIVE POWER TOPOLOGY'), findsOneWidget);
      expect(find.text('Samsung AI Ecobubble'), findsOneWidget);
      expect(find.text('Wipro 9W Smart LED'), findsOneWidget);
      expect(find.text('AI Energy (-15%)'), findsOneWidget);

      // Verify animation frames execute smoothly
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 200));
    });
  });
}
