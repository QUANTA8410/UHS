import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_home/providers/real_home_provider.dart';
import 'package:unified_home/services/real_iot_controller.dart';
import 'package:unified_home/ui/views/apple_glass_home_shell.dart';
import 'package:unified_home/ui/widgets/map3d/isometric_house_3d_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Bug 30: Apple Glass Sheet Light Kelvin, Color Swatches, and AC Modes & Fan Speeds', () {
    testWidgets('Tapping Kelvin chip dispatches colorTempKelvin update to bulb', (tester) async {
      final home = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);

      final wiproLight = RealSmartDevice(
        id: 'wipro_light_living',
        name: 'Living Room Smart Light',
        room: 'Living Room',
        category: 'light',
        protocol: ConnectionProtocol.tuyaLocalLan,
        credentials: {'ip': '192.168.1.101', 'devId': 'dev123', 'localKey': '0123456789abcdef'},
        isOn: true,
        isOnline: true,
        primaryValue: 80.0,
        liveAttributes: {'colorTempKelvin': 3000},
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<RealHomeProvider>.value(
          value: home,
          child: MaterialApp(
            home: Scaffold(
              body: AppleGlassDeviceControlSheet(initialDevice: wiproLight),
            ),
          ),
        ),
      );

      // Verify initial rendering
      expect(find.text('Color Temperature (Kelvin)'), findsOneWidget);
      expect(find.text('6500K Daylight'), findsOneWidget);

      // Tap 6500K Daylight chip
      await tester.tap(find.text('6500K Daylight'));
      await tester.pump();

      expect(wiproLight.liveAttributes['colorTempKelvin'], equals(6500));
    });

    testWidgets('Tapping Color Swatch dispatches RGB color update to bulb', (tester) async {
      final home = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);

      final wiproLight = RealSmartDevice(
        id: 'wipro_light_living',
        name: 'Living Room Smart Light',
        room: 'Living Room',
        category: 'light',
        protocol: ConnectionProtocol.tuyaLocalLan,
        credentials: {'ip': '192.168.1.101', 'devId': 'dev123', 'localKey': '0123456789abcdef'},
        isOn: true,
        isOnline: true,
        primaryValue: 80.0,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<RealHomeProvider>.value(
          value: home,
          child: MaterialApp(
            home: Scaffold(
              body: AppleGlassDeviceControlSheet(initialDevice: wiproLight),
            ),
          ),
        ),
      );

      expect(find.text('Color Preset'), findsOneWidget);

      // Find swatches by looking for GestureDetector descendants in the swatch list
      final targetColor = IsometricHouse3DWidget.kHouseControlSwatches[2]; // 3rd color in palette
      final swatchGesture = find.byWidgetPredicate(
        (w) => w is GestureDetector && w.child is Container && (w.child as Container).decoration is BoxDecoration &&
            ((w.child as Container).decoration as BoxDecoration).color == targetColor,
      );

      expect(swatchGesture, findsOneWidget);
      await tester.tap(swatchGesture);
      await tester.pump();

      expect(wiproLight.liveAttributes['color'], equals(targetColor.value.toRadixString(16)));
    });

    testWidgets('Tapping AC Climate Mode chips dispatches mode update', (tester) async {
      final home = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);

      final acDevice = RealSmartDevice(
        id: 'generic_living_ac',
        name: 'Living Room AC',
        room: 'Living Room',
        category: 'ac',
        protocol: ConnectionProtocol.customHttpWebhook,
        credentials: {'url': 'http://192.168.1.99/ac'},
        isOn: true,
        isOnline: true,
        primaryValue: 24.0,
        liveAttributes: {'mode': 'cool', 'fanSpeed': 'Auto'},
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<RealHomeProvider>.value(
          value: home,
          child: MaterialApp(
            home: Scaffold(
              body: AppleGlassDeviceControlSheet(initialDevice: acDevice),
            ),
          ),
        ),
      );

      expect(find.text('Climate Mode'), findsOneWidget);
      expect(find.text('Heat'), findsOneWidget);

      // Tap 'Heat' chip
      await tester.tap(find.text('Heat'));
      await tester.pump();

      expect(acDevice.liveAttributes['mode'], equals('heat'));

      // Tap 'Dry' chip
      await tester.tap(find.text('Dry'));
      await tester.pump();

      expect(acDevice.liveAttributes['mode'], equals('dry'));
    });

    testWidgets('Tapping AC Fan Speed chips dispatches fanSpeed update', (tester) async {
      final home = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);

      final acDevice = RealSmartDevice(
        id: 'generic_living_ac',
        name: 'Living Room AC',
        room: 'Living Room',
        category: 'ac',
        protocol: ConnectionProtocol.customHttpWebhook,
        credentials: {'url': 'http://192.168.1.99/ac'},
        isOn: true,
        isOnline: true,
        primaryValue: 24.0,
        liveAttributes: {'mode': 'cool', 'fanSpeed': 'Auto'},
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<RealHomeProvider>.value(
          value: home,
          child: MaterialApp(
            home: Scaffold(
              body: AppleGlassDeviceControlSheet(initialDevice: acDevice),
            ),
          ),
        ),
      );

      expect(find.text('Fan Speed'), findsOneWidget);
      expect(find.text('Turbo'), findsOneWidget);

      // Tap 'Turbo' chip
      await tester.tap(find.text('Turbo'));
      await tester.pump();

      expect(acDevice.liveAttributes['fanSpeed'], equals('Turbo'));

      // Tap 'Low' chip
      await tester.tap(find.text('Low'));
      await tester.pump();

      expect(acDevice.liveAttributes['fanSpeed'], equals('Low'));
    });

    testWidgets('Offline device disables all light and AC chips', (tester) async {
      final home = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);

      final offlineLight = RealSmartDevice(
        id: 'wipro_light_offline',
        name: 'Offline Bulb',
        room: 'Garage',
        category: 'light',
        protocol: ConnectionProtocol.tuyaLocalLan,
        credentials: {'ip': '192.168.1.200'},
        isOn: false,
        isOnline: false,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<RealHomeProvider>.value(
          value: home,
          child: MaterialApp(
            home: Scaffold(
              body: AppleGlassDeviceControlSheet(initialDevice: offlineLight),
            ),
          ),
        ),
      );

      // Kelvin chip should be disabled
      final kelvinChip = tester.widget<ChoiceChip>(
        find.ancestor(of: find.text('3000K Warm'), matching: find.byType(ChoiceChip)),
      );
      expect(kelvinChip.onSelected, isNull);

      // Swatch gesture should have null onTap
      final swatchGesture = tester.widget<GestureDetector>(
        find.byWidgetPredicate(
          (w) => w is GestureDetector && w.child is Container && (w.child as Container).decoration is BoxDecoration,
        ).first,
      );
      expect(swatchGesture.onTap, isNull);
    });
  });
}
