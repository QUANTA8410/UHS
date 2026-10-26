import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:unified_home/providers/real_home_provider.dart';
import 'package:unified_home/services/real_iot_controller.dart';
import 'package:unified_home/ui/widgets/sheets/lg_thinq_ac_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LG ThinQ AC Control Sheet (LgThinqAcSheet) Tests', () {
    testWidgets('Renders Hero dial, steppers, ambient room readouts, and mode chips', (tester) async {
      final home = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);

      final acDevice = RealSmartDevice(
        id: 'lg_dual_inverter_living',
        name: 'Living Room AC',
        room: 'Living Room',
        category: 'climate',
        protocol: ConnectionProtocol.tuyaCloudDirect,
        credentials: {'vendor': 'lg_thinq'},
        isOn: true,
        isOnline: true,
        liveAttributes: {
          'targetTemp': 24.0,
          'currentTemp': 26.5,
          'humidity': 55,
          'mode': 'cool',
          'fan': 'auto',
          'swingVertical': true,
          'swingHorizontal': false,
          'indirectWind': false,
          'airClean': true,
          'pm25': 14,
          'energyStep': 1,
          'autoDry': true,
        },
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<RealHomeProvider>.value(
          value: home,
          child: MaterialApp(
            home: Scaffold(
              body: LgThinqAcSheet(device: acDevice),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify Header and Power Status
      expect(find.text('Living Room AC'), findsOneWidget);
      expect(find.text('Running · LG DUAL Inverter'), findsOneWidget);

      // 2. Verify Room Environment Telemetry
      expect(find.text('Room 26.5°C'), findsOneWidget);
      expect(find.text('Humidity 55%'), findsOneWidget);

      // 3. Verify Target Temp Setpoint
      expect(find.text('24°'), findsOneWidget);
      expect(find.text('Target Setpoint'), findsOneWidget);

      // 4. Verify Operation Modes
      expect(find.text('Cool'), findsOneWidget);
      expect(find.text('Dry'), findsOneWidget);
      expect(find.text('Fan'), findsOneWidget);
      expect(find.text('AI Smart'), findsOneWidget);
      expect(find.text('Heat'), findsOneWidget);
      expect(find.text('Jet Turbo'), findsOneWidget);

      // 5. Verify Wind Strength & Vanes
      expect(find.text('WIND STRENGTH'), findsOneWidget);
      expect(find.text('Vertical 3D'), findsOneWidget);
      expect(find.text('Horizontal 3D'), findsOneWidget);
      expect(find.text('Comfort Indirect'), findsOneWidget);

      // 6. Verify PuriCare & Energy
      expect(find.text('PURICARE AIR QUALITY'), findsOneWidget);
      expect(find.text('Clean / 좋음'), findsOneWidget);
      expect(find.text('ACTIVE ENERGY CONTROL'), findsOneWidget);
      expect(find.text('Auto-Dry (자동건조)'), findsOneWidget);

      home.dispose();
    });

    testWidgets('Stepping target temperature updates local dial optimistically', (tester) async {
      final home = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);

      final acDevice = RealSmartDevice(
        id: 'lg_dual_inverter_living',
        name: 'Living Room AC',
        room: 'Living Room',
        category: 'climate',
        protocol: ConnectionProtocol.tuyaCloudDirect,
        credentials: {'vendor': 'lg_thinq'},
        isOn: true,
        isOnline: true,
        liveAttributes: {
          'targetTemp': 24.0,
          'mode': 'cool',
          'fan': 'mid',
        },
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<RealHomeProvider>.value(
          value: home,
          child: MaterialApp(
            home: Scaffold(
              body: LgThinqAcSheet(device: acDevice),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('24°'), findsOneWidget);

      // Tap Plus Stepper (+)
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();

      expect(find.text('25°'), findsOneWidget);

      // Tap Minus Stepper (-) twice
      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pump();

      expect(find.text('23°'), findsOneWidget);

      home.dispose();
    });

    testWidgets('Switching to Jet mode forces 18°C setpoint and Turbo fan speed', (tester) async {
      final home = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);

      final acDevice = RealSmartDevice(
        id: 'lg_dual_inverter_living',
        name: 'Living Room AC',
        room: 'Living Room',
        category: 'climate',
        protocol: ConnectionProtocol.tuyaCloudDirect,
        credentials: {'vendor': 'lg_thinq'},
        isOn: true,
        isOnline: true,
        liveAttributes: {
          'targetTemp': 25.0,
          'mode': 'cool',
          'fan': 'low',
        },
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<RealHomeProvider>.value(
          value: home,
          child: MaterialApp(
            home: Scaffold(
              body: LgThinqAcSheet(device: acDevice),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Jet Turbo mode
      await tester.tap(find.text('Jet Turbo'));
      await tester.pump();

      expect(find.text('18°'), findsOneWidget);
      expect(find.text('TURBO'), findsOneWidget);

      home.dispose();
    });
  });
}
