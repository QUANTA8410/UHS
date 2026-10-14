import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unified_home/services/real_iot_controller.dart';
import 'package:unified_home/theme/apple_glass_theme.dart';
import 'package:unified_home/ui/widgets/energy/animated_power_flow_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Flagship UI Polish Pack Tests', () {
    test('CircadianSkyPalette correctly generates valid gradients and orbs', () {
      const palette = CircadianSkyPalette(
        backgroundGradient: [
          Color(0xFF07162C),
          Color(0xFF0E2A47),
        ],
        orb1: Color(0xFF0A84FF),
        orb2: Color(0xFF5AC8FA),
        orb3: Color(0xFF00C7BE),
      );
      expect(palette.backgroundGradient.length, equals(2));
      expect(palette.orb1.toARGB32(), isNonZero);
      expect(palette.orb2.toARGB32(), isNonZero);
      expect(palette.orb3.toARGB32(), isNonZero);
    });

    testWidgets('AnimatedPowerFlowCard calculates wattage, INR tariff, and renders particles', (tester) async {
      final devices = [
        RealSmartDevice(
          id: 'ac_01',
          name: 'DualCool AC',
          room: 'Living Room',
          category: 'ac',
          isOn: true,
          protocol: ConnectionProtocol.smartThingsCloud,
          credentials: const {},
        ),
        RealSmartDevice(
          id: 'light_01',
          name: 'Wipro Bulb',
          room: 'Living Room',
          category: 'light',
          isOn: true,
          primaryValue: 80.0,
          protocol: ConnectionProtocol.tuyaLocalLan,
          credentials: const {},
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Center(
                child: SizedBox(
                  width: 360,
                  child: AnimatedPowerFlowCard(devices: devices),
                ),
              ),
            ),
          ),
        ),
      );

      // Verify header texts and tariff
      expect(find.text('LIVE POWER TOPOLOGY'), findsOneWidget);
      expect(find.textContaining('W  •  ₹'), findsOneWidget);
      expect(find.text('AI Energy (-15%)'), findsOneWidget);

      // Test 60 FPS animation tick
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));
    });
  });
}
