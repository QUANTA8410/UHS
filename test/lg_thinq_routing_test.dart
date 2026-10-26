import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_home/providers/real_home_provider.dart';
import 'package:unified_home/services/real_iot_controller.dart';

class _FakeHttpOverrides extends HttpOverrides {
  final Future<void> Function(String method, Uri uri, String body)? onIntercept;
  _FakeHttpOverrides({this.onIntercept});

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _FakeHttpClient(onIntercept);
  }
}

class _FakeHttpClient implements HttpClient {
  final Future<void> Function(String method, Uri uri, String body)? onIntercept;
  _FakeHttpClient(this.onIntercept);

  @override
  void close({bool force = false}) {}

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return _FakeHttpClientRequest(method, url, onIntercept);
  }

  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);
  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);
  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);
  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => openUrl('DELETE', url);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  @override
  final String method;
  @override
  final Uri uri;
  final Future<void> Function(String method, Uri uri, String body)? onIntercept;
  final List<int> _bodyBytes = [];

  _FakeHttpClientRequest(this.method, this.uri, this.onIntercept);

  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  int contentLength = -1;

  @override
  bool persistentConnection = false;

  @override
  bool bufferOutput = true;

  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  void add(List<int> data) {
    _bodyBytes.addAll(data);
  }

  @override
  Future<dynamic> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      _bodyBytes.addAll(chunk);
    }
  }

  @override
  void write(Object? obj) {
    if (obj != null) _bodyBytes.addAll(utf8.encode(obj.toString()));
  }

  @override
  Future<HttpClientResponse> close() async {
    final bodyStr = utf8.decode(_bodyBytes, allowMalformed: true);
    if (onIntercept != null) {
      await onIntercept!(method, uri, bodyStr);
    }
    return _FakeHttpClientResponse();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _headers = {};

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers.putIfAbsent(name.toLowerCase(), () => []).add(value.toString());
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers[name.toLowerCase()] = [value.toString()];
  }

  @override
  List<String>? operator [](String name) => _headers[name.toLowerCase()];

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _headers.forEach(action);
  }

  @override
  String? value(String name) {
    final list = _headers[name.toLowerCase()];
    if (list == null || list.isEmpty) return null;
    return list.first;
  }

  @override
  int get contentLength {
    final val = value(HttpHeaders.contentLengthHeader);
    return val != null ? (int.tryParse(val) ?? -1) : -1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  @override
  int get statusCode => 200;

  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  int get contentLength => -1;

  @override
  bool get isRedirect => false;

  @override
  bool get persistentConnection => false;

  @override
  String get reasonPhrase => 'OK';

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([
      utf8.encode('{"resultCode":"0000","result":{}}')
    ]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LG ThinQ Routing & Normalized Category Tests', () {
    test('RealSmartDevice.isLgThinq evaluates true for lgThinqCloud and customHttpWebhook with LG vendor', () {
      final cloudDevice = RealSmartDevice(
        id: 'lg_ac_1',
        name: 'LG Dual Inverter AC',
        room: 'Bedroom',
        category: 'ac',
        protocol: ConnectionProtocol.lgThinqCloud,
        credentials: {'token': 'valid_token_12345678'},
      );
      expect(cloudDevice.isLgThinq, isTrue);

      final webhookThinq = RealSmartDevice(
        id: 'lg_washtower_1',
        name: 'LG WashTower',
        room: 'Laundry',
        category: 'washer',
        protocol: ConnectionProtocol.customHttpWebhook,
        credentials: {'vendor': 'lg_thinq', 'token': 'valid_token_12345678'},
      );
      expect(webhookThinq.isLgThinq, isTrue);

      final webhookLg = RealSmartDevice(
        id: 'lg_fridge_1',
        name: 'LG InstaView Fridge',
        room: 'Kitchen',
        category: 'fridge',
        protocol: ConnectionProtocol.customHttpWebhook,
        credentials: {'vendor': 'lg', 'token': 'valid_token_12345678'},
      );
      expect(webhookLg.isLgThinq, isTrue);

      final webhookThinqOnly = RealSmartDevice(
        id: 'lg_aerotower_1',
        name: 'LG AeroTower',
        room: 'Living Room',
        category: 'air_purifier',
        protocol: ConnectionProtocol.customHttpWebhook,
        credentials: {'vendor': 'thinq', 'token': 'valid_token_12345678'},
      );
      expect(webhookThinqOnly.isLgThinq, isTrue);

      final nonLgDevice = RealSmartDevice(
        id: 'custom_relay_1',
        name: 'Custom Relay',
        room: 'Hall',
        category: 'switch',
        protocol: ConnectionProtocol.customHttpWebhook,
        credentials: {'vendor': 'custom_esp32', 'onUrl': 'http://192.168.1.50/on'},
      );
      expect(nonLgDevice.isLgThinq, isFalse);

      final tuyaDevice = RealSmartDevice(
        id: 'tuya_bulb_1',
        name: 'Smart Bulb',
        room: 'Bedroom',
        category: 'light',
        protocol: ConnectionProtocol.tuyaLocalLan,
        credentials: {'vendor': 'tuya', 'ip': '192.168.1.60', 'localKey': '1234567890123456'},
      );
      expect(tuyaDevice.isLgThinq, isFalse);
    });

    test('RealSmartDevice.normalizedCategory accurately normalizes appliance categories', () {
      expect(RealSmartDevice(id: '1', name: '', room: '', category: 'ac', protocol: ConnectionProtocol.lgThinqCloud, credentials: {}).normalizedCategory, 'ac');
      expect(RealSmartDevice(id: '2', name: '', room: '', category: 'Air_Conditioner', protocol: ConnectionProtocol.lgThinqCloud, credentials: {}).normalizedCategory, 'ac');
      expect(RealSmartDevice(id: '3', name: '', room: '', category: 'airconditioner', protocol: ConnectionProtocol.lgThinqCloud, credentials: {}).normalizedCategory, 'ac');
      expect(RealSmartDevice(id: '4', name: '', room: '', category: 'HVAC', protocol: ConnectionProtocol.lgThinqCloud, credentials: {}).normalizedCategory, 'ac');
      expect(RealSmartDevice(id: '5', name: '', room: '', category: 'climate', protocol: ConnectionProtocol.lgThinqCloud, credentials: {}).normalizedCategory, 'ac');

      expect(RealSmartDevice(id: '6', name: '', room: '', category: 'washer', protocol: ConnectionProtocol.lgThinqCloud, credentials: {}).normalizedCategory, 'washer');
      expect(RealSmartDevice(id: '7', name: '', room: '', category: 'washtower', protocol: ConnectionProtocol.lgThinqCloud, credentials: {}).normalizedCategory, 'washer');
      expect(RealSmartDevice(id: '8', name: '', room: '', category: 'washing_machine', protocol: ConnectionProtocol.lgThinqCloud, credentials: {}).normalizedCategory, 'washer');

      expect(RealSmartDevice(id: '9', name: '', room: '', category: 'dryer', protocol: ConnectionProtocol.lgThinqCloud, credentials: {}).normalizedCategory, 'dryer');

      expect(RealSmartDevice(id: '10', name: '', room: '', category: 'fridge', protocol: ConnectionProtocol.lgThinqCloud, credentials: {}).normalizedCategory, 'fridge');
      expect(RealSmartDevice(id: '11', name: '', room: '', category: 'refrigerator', protocol: ConnectionProtocol.lgThinqCloud, credentials: {}).normalizedCategory, 'fridge');

      expect(RealSmartDevice(id: '12', name: '', room: '', category: 'air_purifier', protocol: ConnectionProtocol.lgThinqCloud, credentials: {}).normalizedCategory, 'air_purifier');
      expect(RealSmartDevice(id: '13', name: '', room: '', category: 'aerotower', protocol: ConnectionProtocol.lgThinqCloud, credentials: {}).normalizedCategory, 'air_purifier');
      expect(RealSmartDevice(id: '14', name: '', room: '', category: 'purifier', protocol: ConnectionProtocol.lgThinqCloud, credentials: {}).normalizedCategory, 'air_purifier');

      expect(RealSmartDevice(id: '15', name: '', room: '', category: 'styler', protocol: ConnectionProtocol.lgThinqCloud, credentials: {}).normalizedCategory, 'styler');
      expect(RealSmartDevice(id: '16', name: '', room: '', category: 'steam_closet', protocol: ConnectionProtocol.lgThinqCloud, credentials: {}).normalizedCategory, 'styler');

      expect(RealSmartDevice(id: '17', name: '', room: '', category: 'dishwasher', protocol: ConnectionProtocol.lgThinqCloud, credentials: {}).normalizedCategory, 'dishwasher');

      expect(RealSmartDevice(id: '18', name: '', room: '', category: 'tv', protocol: ConnectionProtocol.lgThinqCloud, credentials: {}).normalizedCategory, 'tv');
      expect(RealSmartDevice(id: '19', name: '', room: '', category: 'television', protocol: ConnectionProtocol.lgThinqCloud, credentials: {}).normalizedCategory, 'tv');
    });

    test('RealSmartDevice.fromJson auto-migrates legacy customHttpWebhook LG devices to lgThinqCloud', () {
      final legacyJson = {
        'id': 'lg_legacy_1',
        'name': 'Legacy LG Washer',
        'room': 'Laundry',
        'category': 'washer',
        'protocol': 'customHttpWebhook',
        'credentials': {
          'vendor': 'lg_thinq',
          'token': 'secret_token_12345678',
        },
      };

      final migrated = RealSmartDevice.fromJson(legacyJson);
      expect(migrated.protocol, ConnectionProtocol.lgThinqCloud);
      expect(migrated.isLgThinq, isTrue);

      final directLgJson = {
        'id': 'lg_direct_1',
        'name': 'Direct LG AC',
        'room': 'Living Room',
        'category': 'ac',
        'protocol': 'lgThinqCloud',
        'credentials': {
          'token': 'secret_token_12345678',
        },
      };

      final direct = RealSmartDevice.fromJson(directLgJson);
      expect(direct.protocol, ConnectionProtocol.lgThinqCloud);

      final nonLgWebhookJson = {
        'id': 'webhook_generic',
        'name': 'Custom Switch',
        'room': 'Hall',
        'category': 'switch',
        'protocol': 'customHttpWebhook',
        'credentials': {
          'controlUrl': 'http://192.168.1.99/toggle',
        },
      };

      final nonLg = RealSmartDevice.fromJson(nonLgWebhookJson);
      expect(nonLg.protocol, ConnectionProtocol.customHttpWebhook);
    });

    test('hasRealHardwareCredentials validates lgThinqCloud credentials correctly', () {
      final validCloud = RealSmartDevice(
        id: 'lg_valid',
        name: 'LG Device',
        room: 'Living Room',
        category: 'ac',
        protocol: ConnectionProtocol.lgThinqCloud,
        credentials: {'token': 'valid_lg_thinq_pat_secret'},
      );
      expect(validCloud.hasRealHardwareCredentials, isTrue);
      expect(validCloud.isDummy, isFalse);

      final demoCloud = RealSmartDevice(
        id: 'lg_demo',
        name: 'LG Demo Device',
        room: 'Living Room',
        category: 'ac',
        protocol: ConnectionProtocol.lgThinqCloud,
        credentials: {'token': 'demo_token_123'},
      );
      expect(demoCloud.hasRealHardwareCredentials, isFalse);
      expect(demoCloud.isDummy, isTrue);

      final emptyToken = RealSmartDevice(
        id: 'lg_empty',
        name: 'LG Empty Token',
        room: 'Living Room',
        category: 'ac',
        protocol: ConnectionProtocol.lgThinqCloud,
        credentials: {'token': 'short'},
      );
      expect(emptyToken.hasRealHardwareCredentials, isFalse);

      final demoVendorDevice = RealSmartDevice(
        id: 'lg_demo_vendor',
        name: 'LG Demo Vendor',
        room: 'Living Room',
        category: 'ac',
        protocol: ConnectionProtocol.lgThinqCloud,
        credentials: {'vendor': 'demo'},
      );
      expect(demoVendorDevice.isDummy, isTrue);
    });
  });

  group('RealIotController LG ThinQ Power & Primary Level Routing', () {
    test('Dummy LG appliances toggle power and set level without network calls or onUrl errors', () async {
      final controller = RealIotController();

      final dummyWashTower = RealSmartDevice(
        id: 'dummy_washtower',
        name: 'Dummy WashTower',
        room: 'Laundry',
        category: 'washer',
        protocol: ConnectionProtocol.lgThinqCloud,
        credentials: {'vendor': 'demo'},
        isOn: false,
      );

      await controller.setPower(dummyWashTower, true);
      expect(dummyWashTower.isOn, isTrue);
      expect(dummyWashTower.isOnline, isTrue);

      await controller.setPrimaryLevel(dummyWashTower, 1200);
      expect(dummyWashTower.primaryValue, 1200);

      // Legacy protocol with LG vendor and demo credentials
      final legacyDummyFridge = RealSmartDevice(
        id: 'legacy_dummy_fridge',
        name: 'Dummy Fridge',
        room: 'Kitchen',
        category: 'fridge',
        protocol: ConnectionProtocol.customHttpWebhook,
        credentials: {'vendor': 'lg_thinq', 'isDemo': 'true'},
        isOn: false,
      );

      await controller.setPower(legacyDummyFridge, true);
      expect(legacyDummyFridge.isOn, isTrue);

      await controller.setPrimaryLevel(legacyDummyFridge, 3.0);
      expect(legacyDummyFridge.primaryValue, 3.0);
    });

    test('Real LG WashTower, Fridge, AeroTower, Styler, Dishwasher, TV, and AC dispatch to respective handlers without crashing on onUrl', () async {
      final interceptedCalls = <Map<String, dynamic>>[];

      final fakeOverrides = _FakeHttpOverrides(
        onIntercept: (method, uri, body) async {
          interceptedCalls.add({
            'method': method,
            'uri': uri.toString(),
            'body': body.isNotEmpty ? jsonDecode(body) : {},
          });
        },
      );

      await HttpOverrides.runWithHttpOverrides(() async {
        final controller = RealIotController();

        // 1. LG WashTower (category: washer)
        final washTower = RealSmartDevice(
          id: 'lg_washtower_real',
          name: 'LG WashTower AI DD',
          room: 'Laundry',
          category: 'washer',
          protocol: ConnectionProtocol.customHttpWebhook, // Verifying customHttpWebhook doesn't crash on onUrl!
          credentials: {
            'vendor': 'lg_thinq',
            'token': 'real_hardware_pat_token_secret_123',
            'gatewayUrl': 'https://api-kic.lgthinq.com',
          },
        );

        await controller.setPower(washTower, true);
        expect(washTower.isOn, isTrue);
        expect(interceptedCalls.last['uri'], contains('/devices/lg_washtower_real/control'));
        final washerPayload = interceptedCalls.last['body'] as Map<String, dynamic>;
        expect(washerPayload['washer']?['operation']?['stage'], 'wash');

        await controller.setPower(washTower, false);
        expect(washTower.isOn, isFalse);
        final washerOffPayload = interceptedCalls.last['body'] as Map<String, dynamic>;
        expect(washerOffPayload['washer']?['operation']?['stage'], 'idle');

        // 2. LG InstaView Refrigerator (category: fridge)
        final fridge = RealSmartDevice(
          id: 'lg_fridge_real',
          name: 'LG InstaView Refrigerator',
          room: 'Kitchen',
          category: 'fridge',
          protocol: ConnectionProtocol.lgThinqCloud,
          credentials: {
            'token': 'real_hardware_pat_token_secret_123',
            'gatewayUrl': 'https://api-kic.lgthinq.com',
          },
        );

        await controller.setPower(fridge, true);
        expect(fridge.isOn, isTrue);
        expect(interceptedCalls.last['uri'], contains('/devices/lg_fridge_real/control'));
        final fridgePayload = interceptedCalls.last['body'] as Map<String, dynamic>;
        expect(fridgePayload['specialFeature']?['expressCool'], isTrue);
        expect(fridgePayload['specialFeature']?['expressFreeze'], isTrue);

        // 3. LG PuriCare AeroTower (category: air_purifier)
        final aeroTower = RealSmartDevice(
          id: 'lg_aerotower_real',
          name: 'LG PuriCare AeroTower',
          room: 'Living Room',
          category: 'air_purifier',
          protocol: ConnectionProtocol.lgThinqCloud,
          credentials: {
            'token': 'real_hardware_pat_token_secret_123',
            'gatewayUrl': 'https://api-kic.lgthinq.com',
          },
        );

        await controller.setPower(aeroTower, true);
        expect(aeroTower.isOn, isTrue);
        final aeroPayload = interceptedCalls.last['body'] as Map<String, dynamic>;
        expect(aeroPayload['airPurifier']?['airflowMode'], 'Auto');
        expect(aeroPayload['airPurifier']?['uvNano'], isTrue);

        // 4. LG Styler Steam Closet (category: styler)
        final styler = RealSmartDevice(
          id: 'lg_styler_real',
          name: 'LG Styler Steam Closet',
          room: 'Master Bedroom',
          category: 'styler',
          protocol: ConnectionProtocol.customHttpWebhook,
          credentials: {
            'vendor': 'lg_thinq',
            'token': 'real_hardware_pat_token_secret_123',
            'gatewayUrl': 'https://api-kic.lgthinq.com',
          },
        );

        await controller.setPower(styler, true);
        expect(styler.isOn, isTrue);
        final stylerPayload = interceptedCalls.last['body'] as Map<String, dynamic>;
        expect(stylerPayload['styler']?['gentleDry'], isTrue);
        expect(stylerPayload['styler']?['trueSteam'], isTrue);

        // 5. LG QuadWash Dishwasher (category: dishwasher)
        final dishwasher = RealSmartDevice(
          id: 'lg_dishwasher_real',
          name: 'LG QuadWash Dishwasher',
          room: 'Kitchen',
          category: 'dishwasher',
          protocol: ConnectionProtocol.lgThinqCloud,
          credentials: {
            'token': 'real_hardware_pat_token_secret_123',
            'gatewayUrl': 'https://api-kic.lgthinq.com',
          },
        );

        await controller.setPower(dishwasher, true);
        expect(dishwasher.isOn, isTrue);
        final dishPayload = interceptedCalls.last['body'] as Map<String, dynamic>;
        expect(dishPayload['dishwasher']?['trueSteamDishwash'], isTrue);

        // 6. LG OLED TV (category: tv)
        final tv = RealSmartDevice(
          id: 'lg_oled_tv_real',
          name: 'LG OLED TV C3',
          room: 'Living Room',
          category: 'tv',
          protocol: ConnectionProtocol.lgThinqCloud,
          credentials: {
            'token': 'real_hardware_pat_token_secret_123',
            'gatewayUrl': 'https://api-kic.lgthinq.com',
          },
        );

        await controller.setPower(tv, true);
        expect(tv.isOn, isTrue);
        final tvPayload = interceptedCalls.last['body'] as Map<String, dynamic>;
        expect(tvPayload['operation']?['tvOperationMode'], 'POWER_ON');

        await controller.setPower(tv, false);
        expect(tv.isOn, isFalse);
        final tvOffPayload = interceptedCalls.last['body'] as Map<String, dynamic>;
        expect(tvOffPayload['operation']?['tvOperationMode'], 'POWER_OFF');

        // 7. LG DUAL Inverter AC (category: ac)
        final ac = RealSmartDevice(
          id: 'lg_dual_inverter_ac_real',
          name: 'LG DUAL Inverter AC',
          room: 'Bedroom',
          category: 'ac',
          protocol: ConnectionProtocol.customHttpWebhook,
          credentials: {
            'vendor': 'lg_thinq',
            'token': 'real_hardware_pat_token_secret_123',
            'gatewayUrl': 'https://api-kic.lgthinq.com',
          },
        );

        await controller.setPower(ac, true);
        expect(ac.isOn, isTrue);
        final acPayload = interceptedCalls.last['body'] as Map<String, dynamic>;
        expect(acPayload['operation']?['airConOperationMode'], 'POWER_ON');

        await controller.setPower(ac, false);
        expect(ac.isOn, isFalse);
        final acOffPayload = interceptedCalls.last['body'] as Map<String, dynamic>;
        expect(acOffPayload['operation']?['airConOperationMode'], 'POWER_OFF');
      }, fakeOverrides);
    });

    test('RealIotController.setPrimaryLevel dispatches correctly according to normalizedCategory', () async {
      final interceptedCalls = <Map<String, dynamic>>[];

      final fakeOverrides = _FakeHttpOverrides(
        onIntercept: (method, uri, body) async {
          interceptedCalls.add({
            'method': method,
            'uri': uri.toString(),
            'body': body.isNotEmpty ? jsonDecode(body) : {},
          });
        },
      );

      await HttpOverrides.runWithHttpOverrides(() async {
        final controller = RealIotController();

        // 1. AC: target temperature clamped 16 - 30
        final ac = RealSmartDevice(
          id: 'lg_ac_level',
          name: 'LG AC',
          room: 'Bedroom',
          category: 'ac',
          protocol: ConnectionProtocol.lgThinqCloud,
          credentials: {
            'token': 'real_hardware_pat_token_secret_123',
            'gatewayUrl': 'https://api-kic.lgthinq.com',
          },
        );

        await controller.setPrimaryLevel(ac, 14.0); // should clamp to 16
        expect(ac.primaryValue, 16.0);
        expect(interceptedCalls.last['body']?['temperature']?['targetTemperature'], 16);

        await controller.setPrimaryLevel(ac, 35.0); // should clamp to 30
        expect(ac.primaryValue, 30.0);
        expect(interceptedCalls.last['body']?['temperature']?['targetTemperature'], 30);

        // 2. Fridge: temperature clamped 1 - 7
        final fridge = RealSmartDevice(
          id: 'lg_fridge_level',
          name: 'LG Fridge',
          room: 'Kitchen',
          category: 'fridge',
          protocol: ConnectionProtocol.customHttpWebhook,
          credentials: {
            'vendor': 'lg_thinq',
            'token': 'real_hardware_pat_token_secret_123',
            'gatewayUrl': 'https://api-kic.lgthinq.com',
          },
        );

        await controller.setPrimaryLevel(fridge, 0.0); // should clamp to 1
        expect(fridge.primaryValue, 1.0);
        expect(interceptedCalls.last['body']?['temperature']?['targetFridgeTemperature'], 1);

        await controller.setPrimaryLevel(fridge, 10.0); // should clamp to 7
        expect(fridge.primaryValue, 7.0);
        expect(interceptedCalls.last['body']?['temperature']?['targetFridgeTemperature'], 7);

        // 3. AeroTower: cleanBoosterTilt clamped 0 - 90
        final aeroTower = RealSmartDevice(
          id: 'lg_aero_level',
          name: 'LG AeroTower',
          room: 'Living Room',
          category: 'air_purifier',
          protocol: ConnectionProtocol.lgThinqCloud,
          credentials: {
            'token': 'real_hardware_pat_token_secret_123',
            'gatewayUrl': 'https://api-kic.lgthinq.com',
          },
        );

        await controller.setPrimaryLevel(aeroTower, 60.0);
        expect(aeroTower.primaryValue, 60.0);
        expect(interceptedCalls.last['body']?['airPurifier']?['cleanBoosterTilt'], 60);

        // 4. Styler: movingHangerRpm clamped 100 - 220
        final styler = RealSmartDevice(
          id: 'lg_styler_level',
          name: 'LG Styler',
          room: 'Bedroom',
          category: 'styler',
          protocol: ConnectionProtocol.lgThinqCloud,
          credentials: {
            'token': 'real_hardware_pat_token_secret_123',
            'gatewayUrl': 'https://api-kic.lgthinq.com',
          },
        );

        await controller.setPrimaryLevel(styler, 190.0);
        expect(styler.primaryValue, 190.0);
        expect(interceptedCalls.last['body']?['styler']?['movingHangerRpm'], 190);

        // 5. Washer: spinSpeed
        final washer = RealSmartDevice(
          id: 'lg_washer_level',
          name: 'LG Washer',
          room: 'Laundry',
          category: 'washer',
          protocol: ConnectionProtocol.customHttpWebhook,
          credentials: {
            'vendor': 'lg_thinq',
            'token': 'real_hardware_pat_token_secret_123',
            'gatewayUrl': 'https://api-kic.lgthinq.com',
          },
        );

        await controller.setPrimaryLevel(washer, 1400.0);
        expect(washer.primaryValue, 1400.0);
        expect(interceptedCalls.last['body']?['washer']?['operation']?['spinSpeed'], 1400);

        // 6. TV: volume clamped 0 - 100
        final tv = RealSmartDevice(
          id: 'lg_tv_level',
          name: 'LG TV',
          room: 'Living Room',
          category: 'tv',
          protocol: ConnectionProtocol.lgThinqCloud,
          credentials: {
            'token': 'real_hardware_pat_token_secret_123',
            'gatewayUrl': 'https://api-kic.lgthinq.com',
          },
        );

        await controller.setPrimaryLevel(tv, 25.0);
        expect(tv.primaryValue, 25.0);
        expect(interceptedCalls.last['body']?['tv']?['volume'], 25);
      }, fakeOverrides);
    });

    test('RealIotController.executeDeviceCommand supports lgThinqCloud and isLgThinq', () async {
      final interceptedCalls = <Map<String, dynamic>>[];

      final fakeOverrides = _FakeHttpOverrides(
        onIntercept: (method, uri, body) async {
          interceptedCalls.add({
            'method': method,
            'uri': uri.toString(),
            'body': body.isNotEmpty ? jsonDecode(body) : {},
          });
        },
      );

      await HttpOverrides.runWithHttpOverrides(() async {
        final controller = RealIotController();

        final lgDev = RealSmartDevice(
          id: 'lg_command_dev',
          name: 'LG Appliance',
          room: 'Living Room',
          category: 'washer',
          protocol: ConnectionProtocol.lgThinqCloud,
          credentials: {
            'token': 'real_hardware_pat_token_secret_123',
            'gatewayUrl': 'https://api-kic.lgthinq.com',
          },
        );

        await controller.executeDeviceCommand(
          lgDev,
          'washerOperation',
          'setCourse',
          ['TurboWash360'],
        );

        expect(interceptedCalls.isNotEmpty, isTrue);
        expect(interceptedCalls.last['body'], {
          'washerOperation': {'setCourse': 'TurboWash360'}
        });
      }, fakeOverrides);
    });
  });

  group('RealHomeProvider Delegation Refactoring Tests', () {
    test('toggleDevicePower delegates to _controller.setPower without hardcoded AC-only branch', () async {
      final interceptedCalls = <Map<String, dynamic>>[];

      final fakeOverrides = _FakeHttpOverrides(
        onIntercept: (method, uri, body) async {
          interceptedCalls.add({
            'method': method,
            'uri': uri.toString(),
            'body': body.isNotEmpty ? jsonDecode(body) : {},
          });
        },
      );

      await HttpOverrides.runWithHttpOverrides(() async {
        final provider = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);

        // Toggling an LG WashTower must send WashTower payload, NOT airConOperationMode!
        final lgWasher = RealSmartDevice(
          id: 'provider_lg_washer',
          name: 'LG Laundry Tower',
          room: 'Laundry',
          category: 'washer',
          protocol: ConnectionProtocol.lgThinqCloud,
          credentials: {
            'vendor': 'lg_thinq',
            'token': 'real_hardware_pat_token_secret_123',
            'gatewayUrl': 'https://api-kic.lgthinq.com',
          },
          isOn: false,
        );

        await provider.addDirectLanDevice(lgWasher);
        await provider.toggleDevicePower(lgWasher);

        expect(lgWasher.isOn, isTrue);
        expect(interceptedCalls.isNotEmpty, isTrue);
        final lastPayload = interceptedCalls.last['body'] as Map<String, dynamic>;
        expect(lastPayload.containsKey('washer'), isTrue);
        expect(lastPayload['washer']?['operation']?['stage'], 'wash');
        // Crucial verification: must NOT contain airConOperationMode
        expect(lastPayload.containsKey('operation') && lastPayload['operation'].containsKey('airConOperationMode'), isFalse);

        // Toggling an LG AC works seamlessly as well
        final lgAc = RealSmartDevice(
          id: 'provider_lg_ac',
          name: 'LG DualCool AC',
          room: 'Bedroom',
          category: 'ac',
          protocol: ConnectionProtocol.lgThinqCloud,
          credentials: {
            'vendor': 'lg_thinq',
            'token': 'real_hardware_pat_token_secret_123',
            'gatewayUrl': 'https://api-kic.lgthinq.com',
          },
          isOn: false,
        );

        await provider.addDirectLanDevice(lgAc);
        await provider.toggleDevicePower(lgAc);

        expect(lgAc.isOn, isTrue);
        final acPayload = interceptedCalls.last['body'] as Map<String, dynamic>;
        expect(acPayload['operation']?['airConOperationMode'], 'POWER_ON');
      }, fakeOverrides);
    });

    test('setDeviceLevel delegates cleanly to _controller.setPrimaryLevel without AC-only restriction', () async {
      final interceptedCalls = <Map<String, dynamic>>[];

      final fakeOverrides = _FakeHttpOverrides(
        onIntercept: (method, uri, body) async {
          interceptedCalls.add({
            'method': method,
            'uri': uri.toString(),
            'body': body.isNotEmpty ? jsonDecode(body) : {},
          });
        },
      );

      await HttpOverrides.runWithHttpOverrides(() async {
        final provider = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);

        // LG AeroTower tilt level adjustment via setDeviceLevel
        final lgAero = RealSmartDevice(
          id: 'provider_lg_aero',
          name: 'LG AeroTower PuriCare',
          room: 'Living Room',
          category: 'air_purifier',
          protocol: ConnectionProtocol.lgThinqCloud,
          credentials: {
            'vendor': 'lg_thinq',
            'token': 'real_hardware_pat_token_secret_123',
            'gatewayUrl': 'https://api-kic.lgthinq.com',
          },
          primaryValue: 30.0,
        );

        await provider.addDirectLanDevice(lgAero);
        await provider.setDeviceLevel(lgAero, 75.0);

        // Wait for 250ms debouncer
        await Future.delayed(const Duration(milliseconds: 350));

        expect(lgAero.primaryValue, 75.0);
        expect(interceptedCalls.isNotEmpty, isTrue);
        final aeroPayload = interceptedCalls.last['body'] as Map<String, dynamic>;
        expect(aeroPayload['airPurifier']?['cleanBoosterTilt'], 75);

        // LG AC target temperature via setDeviceLevel
        final lgAc = RealSmartDevice(
          id: 'provider_lg_ac_level',
          name: 'LG DualCool AC',
          room: 'Bedroom',
          category: 'ac',
          protocol: ConnectionProtocol.lgThinqCloud,
          credentials: {
            'vendor': 'lg_thinq',
            'token': 'real_hardware_pat_token_secret_123',
            'gatewayUrl': 'https://api-kic.lgthinq.com',
          },
          primaryValue: 24.0,
        );

        await provider.addDirectLanDevice(lgAc);
        await provider.setDeviceLevel(lgAc, 21.0);

        await Future.delayed(const Duration(milliseconds: 350));

        expect(lgAc.primaryValue, 21.0);
        final acPayload = interceptedCalls.last['body'] as Map<String, dynamic>;
        expect(acPayload['temperature']?['targetTemperature'], 21);
      }, fakeOverrides);
    });
  });
}
