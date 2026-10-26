import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:unified_home/providers/real_home_provider.dart';
import 'package:unified_home/ui/widgets/dialogs/universal_qr_scanner_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Bug 31: Universal QR Scanner Real Credentials & MobileScanner Tests', () {
    testWidgets('Realme camera QR with RTSP URI extracts host, port, credentials and is NOT dummy', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final home = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);

      await tester.pumpWidget(
        ChangeNotifierProvider<RealHomeProvider>.value(
          value: home,
          child: const MaterialApp(
            home: Scaffold(
              body: UniversalQrScannerSheet(initialProvider: 'realme_camera'),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Open manual input
      await tester.tap(find.text('Type Code'));
      await tester.pump();

      // Enter RTSP QR code with credentials
      final rtspPayload = 'rtsp://camadmin:supersecret99@192.168.1.188:554/live/ch0';
      await tester.enterText(find.byType(TextField), rtspPayload);
      await tester.tap(find.text('Parse'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify detected device preview
      expect(find.text('Realme Smart Cam 360'), findsWidgets);
      expect(find.text('Add to My Home'), findsOneWidget);

      // Add to home
      await tester.tap(find.text('Add to My Home'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1600));

      expect(home.devices.length, equals(1));
      final dev = home.devices.first;
      expect(dev.category, equals('camera'));
      expect(dev.credentials['vendor'], equals('realme'));
      expect(dev.credentials['vendor'], isNot(equals('demo')));
      expect(dev.credentials['ip'], equals('192.168.1.188'));
      expect(dev.credentials['port'], equals('554'));
      expect(dev.credentials['username'], equals('camadmin'));
      expect(dev.credentials['password'], equals('supersecret99'));
      expect(dev.credentials['streamPath'], equals('/live/ch0'));
      expect(dev.credentials['rtspUrl'], equals(rtspPayload));
      expect(dev.isDummy, isFalse);

      home.dispose();
    });

    testWidgets('Philips camera QR with RTSP URI extracts credentials and is NOT dummy', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final home = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);

      await tester.pumpWidget(
        ChangeNotifierProvider<RealHomeProvider>.value(
          value: home,
          child: const MaterialApp(
            home: Scaffold(
              body: UniversalQrScannerSheet(initialProvider: 'philips_camera'),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('Type Code'));
      await tester.pump();

      final rtspPayload = 'rtsp://admin:philips2026@192.168.1.189:8554/ch0';
      await tester.enterText(find.byType(TextField), rtspPayload);
      await tester.tap(find.text('Parse'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Philips Home Camera'), findsWidgets);
      await tester.tap(find.text('Add to My Home'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1600));

      expect(home.devices.length, equals(1));
      final dev = home.devices.first;
      expect(dev.credentials['vendor'], equals('philips'));
      expect(dev.credentials['vendor'], isNot(equals('demo')));
      expect(dev.credentials['ip'], equals('192.168.1.189'));
      expect(dev.credentials['port'], equals('8554'));
      expect(dev.credentials['username'], equals('admin'));
      expect(dev.credentials['password'], equals('philips2026'));
      expect(dev.credentials['streamPath'], equals('/ch0'));
      expect(dev.isDummy, isFalse);

      home.dispose();
    });

    testWidgets('Samsung SmartThings inherits linked PAT and sets vendor samsung without demo flag', (tester) async {
      final home = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);
      home.linkedSmartThingsPat = 'pat_samsung_live_token_123456';

      await tester.pumpWidget(
        ChangeNotifierProvider<RealHomeProvider>.value(
          value: home,
          child: const MaterialApp(
            home: Scaffold(
              body: UniversalQrScannerSheet(initialProvider: 'samsung_smartthings'),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap preset
      await tester.tap(find.text('Samsung Ecobubble'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Add to My Home'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1600));

      expect(home.devices.length, equals(1));
      final dev = home.devices.first;
      expect(dev.credentials['vendor'], equals('samsung'));
      expect(dev.credentials['vendor'], isNot(equals('demo')));
      expect(dev.credentials['token'], equals('pat_samsung_live_token_123456'));
      expect(dev.hasRealHardwareCredentials, isTrue);
      expect(dev.isDummy, isFalse);

      home.dispose();
    });

    testWidgets('LG ThinQ inherits linked PAT and sets vendor lg_thinq without demo flag', (tester) async {
      final home = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);
      home.linkedLgThinqPat = 'pat_lg_thinq_live_token_abcdef';

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

      await tester.tap(find.text('LG DualCool AC'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Add to My Home'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1600));

      expect(home.devices.length, equals(1));
      final dev = home.devices.first;
      expect(dev.credentials['vendor'], equals('lg_thinq'));
      expect(dev.credentials['vendor'], isNot(equals('demo')));
      expect(dev.credentials['token'], equals('pat_lg_thinq_live_token_abcdef'));
      expect(dev.hasRealHardwareCredentials, isTrue);
      expect(dev.isDummy, isFalse);

      home.dispose();
    });

    testWidgets('Wipro bulb QR parser populates real IP, localKey and sets vendor wipro (not demo)', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final home = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);

      await tester.pumpWidget(
        ChangeNotifierProvider<RealHomeProvider>.value(
          value: home,
          child: const MaterialApp(
            home: Scaffold(
              body: UniversalQrScannerSheet(initialProvider: 'wipro_smart_next'),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('Type Code'));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'tuya://wipro?ip=192.168.1.150&key=abcdef0123456789&token=wipro_valid_token');
      await tester.tap(find.text('Parse'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Add to My Home'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1600));

      expect(home.devices.length, equals(1));
      final dev = home.devices.first;
      expect(dev.credentials['vendor'], equals('wipro'));
      expect(dev.credentials['vendor'], isNot(equals('demo')));
      expect(dev.credentials['ip'], equals('192.168.1.150'));
      expect(dev.credentials['localKey'], equals('abcdef0123456789'));
      expect(dev.credentials['token'], equals('wipro_valid_token'));
      expect(dev.isDummy, isFalse);

      home.dispose();
    });

    testWidgets('Viewfinder embeds MobileScanner with reticle and torch button works', (tester) async {
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

      // Verifies MobileScanner widget presence
      expect(find.byType(MobileScanner), findsOneWidget);

      // Verifies Torch toggle button
      final torchFinder = find.text('Torch');
      expect(torchFinder, findsOneWidget);
      await tester.tap(torchFinder);
      await tester.pump();

      // Check toggled state text
      expect(find.text('Torch On'), findsOneWidget);

      // Toggle off
      await tester.tap(find.text('Torch On'));
      await tester.pump();
      expect(find.text('Torch'), findsOneWidget);

      home.dispose();
    });
  });
}
