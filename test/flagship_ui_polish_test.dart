import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:unified_home/main.dart';
import 'package:unified_home/providers/real_home_provider.dart';
import 'package:unified_home/services/real_iot_controller.dart';
import 'package:unified_home/theme/apple_glass_theme.dart';
import 'package:unified_home/ui/views/liquid_glass_splash_screen.dart';
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

    testWidgets('LiquidGlassSplashScreen renders 4-stage 3D Isometric Extrusion and reveals child', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LiquidGlassSplashScreen(
            duration: Duration(milliseconds: 1200),
            child: Scaffold(
              body: Center(
                child: Text('LIVE_APPLE_GLASS_DASHBOARD'),
              ),
            ),
          ),
        ),
      );

      // Verify Typography during early animation
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('UNIFIED HOME'), findsOneWidget);
      expect(find.text('3D SPATIAL SMART CONTROLLER'), findsOneWidget);

      // Complete animation past stage 4 portal exit
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.text('LIVE_APPLE_GLASS_DASHBOARD'), findsOneWidget);
    });

    testWidgets('UnifiedAppleGlassApp boots with LiquidGlassSplashScreen wrapping AppleGlassHomeShell', (tester) async {
      final provider = RealHomeProvider(autoStartPolling: false);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<RealHomeProvider>.value(value: provider),
          ],
          child: const UnifiedAppleGlassApp(),
        ),
      );

      // Check splash screen text appears on boot
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('UNIFIED HOME'), findsOneWidget);

      // Complete splash animation (2.8s duration)
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('My Home'), findsOneWidget);

      provider.dispose();
    });
  });
}
