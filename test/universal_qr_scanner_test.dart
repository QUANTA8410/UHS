import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:unified_home/providers/real_home_provider.dart';
import 'package:unified_home/ui/widgets/dialogs/universal_qr_scanner_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UniversalQrScannerSheet: Multi-Brand Decoder & Parser Tests', () {
    testWidgets('UniversalQrScannerSheet renders holographic reticle, provider strip and test presets', (tester) async {
      final home = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);

      await tester.pumpWidget(
        ChangeNotifierProvider<RealHomeProvider>.value(
          value: home,
          child: const MaterialApp(
            home: Scaffold(
              body: UniversalQrScannerSheet(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verifies Header and Reticle
      expect(find.text('Scan Appliance QR Code'), findsOneWidget);
      expect(find.byIcon(Icons.qr_code_scanner_rounded), findsWidgets);
      expect(find.text('Torch'), findsOneWidget);
      expect(find.text('Paste Code'), findsOneWidget);
      expect(find.text('Type Code'), findsOneWidget);

      // Verifies Provider Filter Strip
      expect(find.text('All Brands (Auto-Detect)'), findsOneWidget);
      expect(find.text('Samsung SmartThings'), findsOneWidget);
      expect(find.text('LG ThinQ'), findsOneWidget);

      // Verifies Quick Test QR Presets
      expect(find.text('Quick Test QR:'), findsOneWidget);
      expect(find.text('Samsung Ecobubble'), findsOneWidget);
      expect(find.text('LG DualCool AC'), findsOneWidget);
      expect(find.text('Wipro Smart Bulb'), findsOneWidget);
      expect(find.text('Matter Standard'), findsOneWidget);

      home.dispose();
    });

    testWidgets('Tapping Samsung Ecobubble preset decodes washer and displays pairing confirmation card', (tester) async {
      final home = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);

      await tester.pumpWidget(
        ChangeNotifierProvider<RealHomeProvider>.value(
          value: home,
          child: const MaterialApp(
            home: Scaffold(
              body: UniversalQrScannerSheet(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap on the Samsung Ecobubble quick preset
      await tester.tap(find.text('Samsung Ecobubble'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Check detected card
      expect(find.text('Samsung AI Ecobubble™ Washer'), findsOneWidget);
      expect(find.textContaining('SmartThings OCF / Matter Wi-Fi'), findsOneWidget);
      expect(find.text('Add to My Home'), findsOneWidget);

      // Tap 'Add to My Home'
      await tester.tap(find.text('Add to My Home'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1600));

      // Verifies device added to provider
      expect(home.devices.length, equals(1));
      expect(home.devices.first.name, equals('Samsung AI Ecobubble™ Washer'));
      expect(home.devices.first.room, equals('Laundry'));
      expect(home.devices.first.category, equals('washer'));

      home.dispose();
    });

    testWidgets('Tapping LG DualCool AC preset decodes AC and pairs into home', (tester) async {
      final home = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);

      await tester.pumpWidget(
        ChangeNotifierProvider<RealHomeProvider>.value(
          value: home,
          child: const MaterialApp(
            home: Scaffold(
              body: UniversalQrScannerSheet(initialProvider: 'lg_thinq'),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap LG preset
      await tester.tap(find.text('LG DualCool AC'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('LG ThinQ DualCool™ AI AC'), findsOneWidget);
      expect(find.textContaining('LG ThinQ SoftAP / Wi-Fi Barcode'), findsOneWidget);

      await tester.tap(find.text('Add to My Home'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1600));

      expect(home.devices.length, equals(1));
      expect(home.devices.first.name, equals('LG ThinQ DualCool™ AI AC'));
      expect(home.devices.first.category, equals('ac'));
      expect(home.devices.first.primaryValue, equals(23.0));

      home.dispose();
    });

    testWidgets('Typing manual Matter MT code parses Matter appliance correctly', (tester) async {
      final home = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);

      await tester.pumpWidget(
        ChangeNotifierProvider<RealHomeProvider>.value(
          value: home,
          child: const MaterialApp(
            home: Scaffold(
              body: UniversalQrScannerSheet(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap 'Type Code' to expand manual input
      await tester.tap(find.text('Type Code'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Enter Matter code
      await tester.enterText(find.byType(TextField), 'MT:Y234567890123456');
      await tester.tap(find.text('Parse'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Matter Certified Universal Appliance'), findsOneWidget);
      expect(find.textContaining('Matter Standard CHIP QR Protocol'), findsOneWidget);

      home.dispose();
    });
  });
}
