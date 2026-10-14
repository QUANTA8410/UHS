import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:unified_home/providers/real_home_provider.dart';
import 'package:unified_home/services/auth/brand_oauth_catalog.dart';
import 'package:unified_home/services/real_iot_controller.dart';
import 'package:unified_home/ui/widgets/dialogs/brand_oauth_webview_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 8: Brand OAuth Catalog & In-App Login Tests', () {
    test('BrandOAuthCatalog defines all 6 major brand providers with valid URIs', () {
      final providers = BrandOAuthCatalog.providers;
      expect(providers.length, greaterThanOrEqualTo(6));

      final providerIds = providers.map((p) => p.id).toSet();
      expect(providerIds.contains('samsung_smartthings'), isTrue);
      expect(providerIds.contains('lg_thinq'), isTrue);
      expect(providerIds.contains('wipro_smart_next'), isTrue);
      expect(providerIds.contains('philips_hue'), isTrue);
      expect(providerIds.contains('tplink_tapo'), isTrue);
      expect(providerIds.contains('home_assistant'), isTrue);

      for (final p in providers) {
        expect(p.brandName.isNotEmpty, isTrue);
        expect(p.subtitle.isNotEmpty, isTrue);
        expect(p.redirectUriPrefix.startsWith('unifiedhome://'), isTrue);
        final parsedUrl = Uri.tryParse(p.loginUrl);
        expect(parsedUrl, isNotNull);
        expect(parsedUrl!.hasScheme, isTrue);
        expect(p.brandColor.toARGB32(), isNonZero);
      }
    });

    test('Samsung SmartThings config matches official token endpoints', () {
      final samsung = BrandOAuthCatalog.providers.firstWhere((p) => p.id == 'samsung_smartthings');
      expect(samsung.vendorType, equals('smartthings'));
      expect(samsung.loginUrl, equals('https://account.smartthings.com/tokens'));
      expect(samsung.redirectUriPrefix, equals('unifiedhome://oauth/smartthings'));
    });

    test('LG ThinQ config matches official PAT portal', () {
      final lg = BrandOAuthCatalog.providers.firstWhere((p) => p.id == 'lg_thinq');
      expect(lg.vendorType, equals('lg_thinq'));
      expect(lg.loginUrl, equals('https://connect-pat.lgthinq.com/'));
      expect(lg.redirectUriPrefix, equals('unifiedhome://oauth/lgthinq'));
    });

    test('Home Assistant config supports local OAuth2 authorize flow', () {
      final ha = BrandOAuthCatalog.providers.firstWhere((p) => p.id == 'home_assistant');
      expect(ha.vendorType, equals('home_assistant'));
      expect(ha.redirectUriPrefix, equals('unifiedhome://oauth/ha'));
      final uri = Uri.parse(ha.loginUrl);
      expect(uri.queryParameters['response_type'], equals('code'));
    });

    test('Wipro Next / Smart Life config matches official Wipro portal endpoint', () {
      final wipro = BrandOAuthCatalog.providers.firstWhere((p) => p.id == 'wipro_smart_next');
      expect(wipro.vendorType, equals('wipro_tuya'));
      expect(wipro.loginUrl, equals('https://www.wiproconsumerlighting.com/login'));
    });

    test('ConnectionProtocol.tuyaCloudDirect serializes and deserializes in RealSmartDevice', () {
      final device = RealSmartDevice(
        id: 'wipro_bulb_test',
        name: 'Bedroom Bulb',
        room: 'Bedroom',
        category: 'light',
        protocol: ConnectionProtocol.tuyaCloudDirect,
        credentials: {
          'accessToken': 'test_token_123',
          'bizType': 'smart_life',
          'countryCode': '91',
        },
        isOn: true,
        primaryValue: 75.0,
      );
      final json = device.toJson();
      expect(json['protocol'], equals('tuyaCloudDirect'));

      final restored = RealSmartDevice.fromJson(json);
      expect(restored.protocol, equals(ConnectionProtocol.tuyaCloudDirect));
      expect(restored.credentials['accessToken'], equals('test_token_123'));
      expect(restored.isOn, isTrue);
      expect(restored.primaryValue, equals(75.0));
    });

    test('RealSmartDevice.fromJson handles non-string credential values without throwing', () {
      final json = <String, dynamic>{
        'id': 'test_dev_robust',
        'name': 'Robust Device',
        'room': 'Office',
        'category': 'camera',
        'protocol': 'rtspOnvifCamera',
        'credentials': {
          'port': 554, // int instead of String
          'active': true, // bool instead of String
          'ip': '192.168.1.100',
        },
        'liveAttributes': {
          'fps': 30,
          'bitrateKbps': 2048,
        },
        'isOn': true,
      };

      final device = RealSmartDevice.fromJson(json);
      expect(device.id, equals('test_dev_robust'));
      expect(device.credentials['port'], equals('554'));
      expect(device.credentials['active'], equals('true'));
      expect(device.credentials['ip'], equals('192.168.1.100'));
      expect(device.liveAttributes['fps'], equals(30));
    });

    test('BrandOAuthWebViewSheet widget instantiates properly', () {
      final provider = BrandOAuthCatalog.providers.first;
      final sheet = BrandOAuthWebViewSheet(brand: provider);
      expect(sheet.brand.id, equals(provider.id));
    });

    test('BrandOAuthCatalog contains Realme Smart Cam 360 provider', () {
      final realme = BrandOAuthCatalog.providers.firstWhere((p) => p.vendorType == 'realme_camera');
      expect(realme.id, equals('realme_camera'));
      expect(realme.brandName, equals('Realme Smart Cam 360'));
      expect(realme.icon, equals(Icons.videocam_rounded));
    });

    testWidgets('BrandOAuthWebViewSheet renders Realme Link handoff and setup UI', (tester) async {
      final realmeProvider = BrandOAuthCatalog.providers.firstWhere((p) => p.vendorType == 'realme_camera');
      final home = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<RealHomeProvider>.value(
            value: home,
            child: Scaffold(
              body: BrandOAuthWebViewSheet(brand: realmeProvider),
            ),
          ),
        ),
      );

      expect(find.text('Official Realme Link App Handoff'), findsOneWidget);
      expect(find.text('1. Open Official Realme Link App'), findsOneWidget);
      expect(find.text('Step-by-Step Instructions'), findsOneWidget);
      expect(find.text('PC View Username'), findsOneWidget);
      expect(find.text('PC View Password'), findsOneWidget);
      expect(find.text('Link Realme Device & Open Live Feed'), findsOneWidget);
    });

    test('BrandOAuthCatalog contains Philips Home Camera provider', () {
      final philips = BrandOAuthCatalog.providers.firstWhere((p) => p.vendorType == 'philips_camera');
      expect(philips.id, equals('philips_camera'));
      expect(philips.brandName, equals('Philips Home Camera'));
      expect(philips.icon, equals(Icons.security_rounded));
    });

    testWidgets('BrandOAuthWebViewSheet renders Philips Home Safety & Access handoff and setup UI', (tester) async {
      final philipsProvider = BrandOAuthCatalog.providers.firstWhere((p) => p.vendorType == 'philips_camera');
      final home = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<RealHomeProvider>.value(
            value: home,
            child: Scaffold(
              body: BrandOAuthWebViewSheet(brand: philipsProvider),
            ),
          ),
        ),
      );

      expect(find.text('Official Philips Home Safety Handoff'), findsOneWidget);
      expect(find.text('1. Open Philips Home Safety / Access App'), findsOneWidget);
      expect(find.text('Step-by-Step Instructions'), findsOneWidget);
      expect(find.text('Philips RTSP & Auto-Discovery'), findsOneWidget);
      expect(find.text('Scan Wi-Fi'), findsOneWidget);
      expect(find.text('RTSP / ONVIF Username'), findsOneWidget);
      expect(find.text('RTSP / ONVIF Password'), findsOneWidget);
      expect(find.text('Link Philips Camera & Open Live Feed'), findsOneWidget);
    });
  });
}


