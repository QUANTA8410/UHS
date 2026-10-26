import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_home/providers/real_home_provider.dart';
import 'package:unified_home/services/auth/brand_oauth_catalog.dart';
import 'package:unified_home/services/real_iot_controller.dart';
import 'package:unified_home/ui/widgets/dialogs/brand_oauth_webview_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Bug 32: OAuth Deep-Link Redirect URI & AndroidManifest.xml', () {
    test('AndroidManifest.xml registers universal scheme unifiedhome without restricting host to oauth-callback', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue);
      final content = manifestFile.readAsStringSync();

      // Verifies universal scheme registration
      expect(content, contains('<data android:scheme="unifiedhome" />'));
      // Verifies the restrictive host is eliminated
      expect(content, isNot(contains('<data android:scheme="unifiedhome" android:host="oauth-callback" />')));
    });

    test('RealHomeProvider.handleNfcOrDeepLink handles SmartThings OAuth callback', () async {
      final home = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);

      await home.handleNfcOrDeepLink('unifiedhome://oauth/smartthings?token=pat_st_token_callback_12345');

      expect(home.linkedSmartThingsPat, equals('pat_st_token_callback_12345'));
      home.dispose();
    });

    test('RealHomeProvider.handleNfcOrDeepLink handles LG ThinQ OAuth callback', () async {
      final home = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);

      await home.handleNfcOrDeepLink('unifiedhome://oauth/lgthinq?access_token=pat_lg_token_callback_67890');

      expect(home.linkedLgThinqPat, equals('pat_lg_token_callback_67890'));
      home.dispose();
    });

    test('RealHomeProvider.handleNfcOrDeepLink handles Home Assistant OAuth callback with custom hub URL', () async {
      final home = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);

      await home.handleNfcOrDeepLink('unifiedhome://oauth/ha?code=ha_auth_code_9999&hub_url=http://192.168.1.180:8123');

      expect(home.linkedHomeAssistantHubUrl, equals('http://192.168.1.180:8123'));
      home.dispose();
    });

    test('RealHomeProvider.handleNfcOrDeepLink preserves all_off and toggle quick actions', () async {
      final home = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);
      final dev = RealSmartDevice(
        id: 'plug_test_01',
        name: 'Smart Plug',
        room: 'Office',
        category: 'plug',
        protocol: ConnectionProtocol.homeAssistantBridge,
        credentials: {'vendor': 'demo'},
        isOn: true,
        isOnline: true,
        primaryValue: 1.0,
      );
      home.addDeviceDirect(dev);
      expect(dev.isOn, isTrue);

      // Deep link to toggle
      await home.handleNfcOrDeepLink('unifiedhome://toggle/plug_test_01');
      expect(dev.isOn, isFalse);

      // Deep link all_off
      dev.isOn = true;
      await home.handleNfcOrDeepLink('unifiedhome://all_off');
      expect(dev.isOn, isFalse);

      home.dispose();
    });
  });

  group('Bug 33: BrandOAuthWebViewSheet & BrandOAuthCatalog Corrections', () {
    test('BrandOAuthCatalog assigns vendorType tplink_tapo to Tapo provider instead of smartthings', () {
      final tapo = BrandOAuthCatalog.providers.firstWhere((p) => p.id == 'tplink_tapo');
      expect(tapo.vendorType, equals('tplink_tapo'));
      expect(tapo.vendorType, isNot(equals('smartthings')));
      expect(tapo.redirectUriPrefix, equals('unifiedhome://oauth/tapo'));
    });

    testWidgets('BrandOAuthWebViewSheet links LG ThinQ via home.linkLgThinqAccount and sets linkedLgThinqPat', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final home = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);
      final lgBrand = BrandOAuthCatalog.providers.firstWhere((p) => p.id == 'lg_thinq');

      await tester.pumpWidget(
        ChangeNotifierProvider<RealHomeProvider>.value(
          value: home,
          child: MaterialApp(
            home: Scaffold(
              body: BrandOAuthWebViewSheet(brand: lgBrand),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Enter LG ThinQ PAT token
      await tester.enterText(find.byType(TextField).first, 'pat_lg_thinq_live_token_77777');
      await tester.pump();

      // Tap link button
      final linkBtn = find.text('Link Account & Import Devices');
      await tester.ensureVisible(linkBtn);
      await tester.tap(linkBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Verify that home.linkedLgThinqPat was saved
      expect(home.linkedLgThinqPat, equals('pat_lg_thinq_live_token_77777'));

      home.dispose();
    });

    testWidgets('BrandOAuthWebViewSheet renders Home Assistant Hub URL input field and links custom hub', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final home = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);
      final haBrand = BrandOAuthCatalog.providers.firstWhere((p) => p.id == 'home_assistant');

      await tester.pumpWidget(
        ChangeNotifierProvider<RealHomeProvider>.value(
          value: home,
          child: MaterialApp(
            home: Scaffold(
              body: BrandOAuthWebViewSheet(brand: haBrand),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verifies custom Hub URL input is present
      expect(find.text('Home Assistant Hub URL / IP Address:'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));

      // Enter custom hub URL and token
      await tester.enterText(find.byType(TextField).first, 'http://192.168.1.222:8123');
      await tester.enterText(find.byType(TextField).last, 'ha_long_lived_access_token_8888');
      await tester.pump();

      final linkBtn = find.text('Link Account & Import Devices');
      await tester.ensureVisible(linkBtn);
      await tester.tap(linkBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Verifies linked Hub URL was updated to custom URL
      expect(home.linkedHomeAssistantHubUrl, equals('http://192.168.1.222:8123'));

      home.dispose();
    });
  });
}
