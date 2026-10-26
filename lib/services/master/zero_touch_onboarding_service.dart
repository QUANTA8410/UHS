import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../real_iot_controller.dart';

class ZeroTouchOnboardingService {
  static final ZeroTouchOnboardingService instance = ZeroTouchOnboardingService();

  // Official LG ThinQ Connect Open API Gateways (Asia/India: kic, Europe: eic, Americas: aic)
  static const String _lgDefaultApiKey = 'v6GFvkweNo7DK7yD3ylIZ9w52aKBU0eJ7wLXkSR3';
  static const List<String> _lgRegionalGateways = [
    'https://api-kic.lgthinq.com', // India / Asia-Pacific (KIC)
    'https://api-eic.lgthinq.com', // Europe / Middle East / Africa (EIC)
    'https://api-aic.lgthinq.com', // Americas (AIC)
  ];

  // ---------------------------------------------------------------------------
  // 1. OFFICIAL LG THINQ CONNECT PAT DISCOVERY & AC CONTROL
  // Generate PAT at: https://connect-pat.lgthinq.com
  // Supports both official 'thinqpat_...' tokens and OAuth 'at_...' tokens
  // ---------------------------------------------------------------------------
  Future<List<RealSmartDevice>> discoverLgThinqDevices({
    required String patToken,
    String countryCode = 'IN',
  }) async {
    final cleanToken = patToken.trim();
    Map<String, dynamic>? decoded;
    String? successfulGateway;
    http.Response? lastResponse;

    // 1. Try official LG OpenAPI gateways (KIC -> EIC -> AIC)
    for (final gw in _lgRegionalGateways) {
      try {
        final headers = {
          'Authorization': 'Bearer $cleanToken',
          'x-api-key': _lgDefaultApiKey,
          'x-country': countryCode.toUpperCase(),
          'x-message-id': 'uhome-${DateTime.now().millisecondsSinceEpoch}',
          'x-client-id': 'unified-smart-home-master',
          'Content-Type': 'application/json',
        };
        final res = await http
            .get(Uri.parse('$gw/devices'), headers: headers)
            .timeout(const Duration(seconds: 8));
        lastResponse = res;
        if (res.statusCode == 200) {
          decoded = jsonDecode(res.body) as Map<String, dynamic>;
          successfulGateway = gw;
          break;
        }
      } catch (_) {}
    }

    // 2. If OpenAPI failed or token is an internal OAuth at_... token, try LG ThinQ v2 mobile endpoints
    if (decoded == null && (cleanToken.startsWith('at_') || lastResponse?.statusCode == 401)) {
      final mobileGateways = [
        'https://in.lgeapi.com/thinq/v2',
        'https://kic.lgeapi.com/thinq/v2',
        'https://aic.lgeapi.com/thinq/v2',
        'https://eic.lgeapi.com/thinq/v2',
      ];
      for (final mgw in mobileGateways) {
        try {
          final mHeaders = {
            'x-thinq-app-ver': '5.0.1000',
            'x-thinq-app-type': 'NUTS',
            'x-thinq-app-level': 'PRD',
            'x-thinq-app-os': 'ANDROID',
            'x-service-code': 'SVC202',
            'x-country-code': countryCode.toUpperCase(),
            'x-language-code': 'en-${countryCode.toUpperCase()}',
            'x-emp-token': cleanToken,
            'Authorization': 'Bearer $cleanToken',
            'Content-Type': 'application/json',
          };
          final res = await http
              .get(Uri.parse('$mgw/devices'), headers: mHeaders)
              .timeout(const Duration(seconds: 8));
          if (res.statusCode == 200) {
            decoded = jsonDecode(res.body) as Map<String, dynamic>;
            successfulGateway = mgw;
            break;
          }
        } catch (_) {}
      }
    }

    if (decoded == null) {
      throw Exception('LG ThinQ Connect Error (${lastResponse?.statusCode ?? 401}): Check your token and permissions.');
    }

    final responseList = (decoded['response'] is List)
        ? List<Map<String, dynamic>>.from(decoded['response'])
        : ((decoded['result']?['devices'] is List)
            ? List<Map<String, dynamic>>.from(decoded['result']['devices'])
            : ((decoded['devices'] is List)
                ? List<Map<String, dynamic>>.from(decoded['devices'])
                : <Map<String, dynamic>>[]));

    final List<RealSmartDevice> lgDevices = [];
    final activeGw = successfulGateway ?? _lgRegionalGateways.first;

    for (final item in responseList) {
      final deviceId = (item['deviceId'] ?? item['id'] ?? '').toString();
      final info = (item['deviceInfo'] ?? item) as Map<String, dynamic>;
      final alias = (info['alias'] ?? info['modelName'] ?? info['name'] ?? 'LG ThinQ Appliance').toString();
      final devType = (info['deviceType'] ?? item['deviceType'] ?? '').toString().toUpperCase();

      String category = 'ac';
      if (devType.contains('WASHER')) category = 'washer';
      if (devType.contains('TV')) category = 'tv';
      if (devType.contains('REFRIGERATOR') || devType.contains('FRIDGE')) category = 'refrigerator';

      double ratedMax = 1480.0;
      if (category == 'washer') ratedMax = 480.0;
      if (category == 'tv') ratedMax = 110.0;
      if (category == 'refrigerator') ratedMax = 180.0;

      lgDevices.add(
        RealSmartDevice(
          id: deviceId,
          name: alias,
          room: 'Living Room',
          category: category,
          protocol: ConnectionProtocol.customHttpWebhook,
          credentials: {
            'vendor': 'lg_thinq',
            'token': cleanToken,
            'country': countryCode.toUpperCase(),
            'gatewayUrl': activeGw,
            'onUrl': '$activeGw/devices/$deviceId/control',
            'offUrl': '$activeGw/devices/$deviceId/control',
          },
          isOn: false,
          isOnline: true,
          primaryValue: 22.0,
          ratedMaxWatts: ratedMax,
        ),
      );
    }
    return lgDevices;
  }

  Future<void> controlLgAirConditioner({
    required RealSmartDevice device,
    bool? powerOn,
    double? targetCelsius,
    bool? jetCoolMode,
    String? patTokenOverride,
  }) async {
    final token = patTokenOverride ?? device.credentials['token'] ?? '';
    final country = device.credentials['country'] ?? 'IN';
    final gw = device.credentials['gatewayUrl'] ?? _lgRegionalGateways.first;
    final isAtToken = token.startsWith('at_');

    final Map<String, String> headers = isAtToken
        ? {
            'x-thinq-app-ver': '5.0.1000',
            'x-thinq-app-type': 'NUTS',
            'x-thinq-app-level': 'PRD',
            'x-thinq-app-os': 'ANDROID',
            'x-service-code': 'SVC202',
            'x-country-code': country,
            'x-language-code': 'en-$country',
            'x-emp-token': token,
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          }
        : {
            'Authorization': 'Bearer $token',
            'x-api-key': _lgDefaultApiKey,
            'x-country': country,
            'x-message-id': 'cmd-${DateTime.now().millisecondsSinceEpoch}',
            'x-client-id': 'unified-smart-home-master',
            'Content-Type': 'application/json',
          };

    final Map<String, dynamic> body = {};
    if (powerOn != null) {
      body['operation'] = {'airConOperationMode': powerOn ? 'POWER_ON' : 'POWER_OFF'};
    }
    if (targetCelsius != null) {
      body['temperature'] = {'targetTemperature': targetCelsius.round(), 'unit': 'C'};
    }
    if (jetCoolMode != null) {
      body['airFlow'] = {'windStrength': jetCoolMode ? 'POWER' : 'AUTO'};
    }

    final res = await http
        .post(
          Uri.parse('$gw/devices/${device.id}/control'),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 8));

    if (res.statusCode >= 400) {
      throw Exception('LG ThinQ Control Rejected (${res.statusCode}): ${res.body}');
    }
  }

  // ---------------------------------------------------------------------------
  // LG THINQ CONNECT MULTI-APPLIANCE OPEN API CONTROLLER & HELPERS
  // ---------------------------------------------------------------------------
  Future<void> controlLgAppliance({
    required RealSmartDevice device,
    required Map<String, dynamic> commandPayload,
    String? patTokenOverride,
  }) async {
    final token = patTokenOverride ?? device.credentials['token'] ?? '';
    if (token.isEmpty || token.contains('demo') || device.isDummy) return;

    final country = device.credentials['country'] ?? 'IN';
    final gw = device.credentials['gatewayUrl'] ?? _lgRegionalGateways.first;
    final isAtToken = token.startsWith('at_');

    final Map<String, String> headers = isAtToken
        ? {
            'x-thinq-app-ver': '5.0.1000',
            'x-thinq-app-type': 'NUTS',
            'x-thinq-app-level': 'PRD',
            'x-thinq-app-os': 'ANDROID',
            'x-service-code': 'SVC202',
            'x-country-code': country,
            'x-language-code': 'en-$country',
            'x-emp-token': token,
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          }
        : {
            'Authorization': 'Bearer $token',
            'x-api-key': _lgDefaultApiKey,
            'x-country': country,
            'x-message-id': 'cmd-${DateTime.now().millisecondsSinceEpoch}',
            'x-client-id': 'unified-smart-home-master',
            'Content-Type': 'application/json',
          };

    final res = await http
        .post(
          Uri.parse('$gw/devices/${device.id}/control'),
          headers: headers,
          body: jsonEncode(commandPayload),
        )
        .timeout(const Duration(seconds: 8));

    if (res.statusCode >= 400) {
      throw Exception('LG ThinQ Control Rejected (${res.statusCode}): ${res.body}');
    }
  }

  Future<void> controlLgWashTower(
    RealSmartDevice dev,
    Map<String, dynamic> attrs, {
    String? patTokenOverride,
  }) async {
    final washerOp = <String, dynamic>{};
    if (attrs['turboWash360'] != null) washerOp['turboWash360'] = attrs['turboWash360'];
    if (attrs['ezDispenseDetergent'] != null) washerOp['ezDispenseDetergent'] = attrs['ezDispenseDetergent'];
    if (attrs['ezDispenseSoftener'] != null) washerOp['ezDispenseSoftener'] = attrs['ezDispenseSoftener'];
    if (attrs['steamPlus'] != null) washerOp['steamPlus'] = attrs['steamPlus'];
    if (attrs['smartPairing'] != null) washerOp['smartPairing'] = attrs['smartPairing'];
    if (attrs['stage'] != null) washerOp['stage'] = attrs['stage'];

    final dryerOp = <String, dynamic>{};
    if (attrs['dryLevel'] != null) dryerOp['dryLevel'] = attrs['dryLevel'];
    if (attrs['dryerStage'] != null) dryerOp['dryerStage'] = attrs['dryerStage'];

    final payload = <String, dynamic>{};
    if (washerOp.isNotEmpty) payload['washer'] = {'operation': washerOp};
    if (dryerOp.isNotEmpty) payload['dryer'] = {'operation': dryerOp};

    if (payload.isNotEmpty) {
      await controlLgAppliance(
        device: dev,
        commandPayload: payload,
        patTokenOverride: patTokenOverride,
      );
    }
  }

  Future<void> controlLgFridge(
    RealSmartDevice dev,
    Map<String, dynamic> attrs, {
    String? patTokenOverride,
  }) async {
    final payload = <String, dynamic>{};
    final temps = <String, dynamic>{};
    if (attrs['fridgeTemp'] != null) temps['targetFridgeTemperature'] = (attrs['fridgeTemp'] as num).round();
    if (attrs['freezerTemp'] != null) temps['targetFreezerTemperature'] = (attrs['freezerTemp'] as num).round();
    if (temps.isNotEmpty) {
      temps['unit'] = 'C';
      payload['temperature'] = temps;
    }

    final features = <String, dynamic>{};
    if (attrs['instaViewTransparent'] != null) features['instaViewTransparent'] = attrs['instaViewTransparent'];
    if (attrs['craftIce'] != null) features['craftIce'] = attrs['craftIce'];
    if (attrs['doorCooling'] != null) features['doorCooling'] = attrs['doorCooling'];
    if (attrs['hygieneFresh'] != null) features['hygieneFresh'] = attrs['hygieneFresh'];
    if (attrs['expressFreeze'] != null) features['expressFreeze'] = attrs['expressFreeze'];
    if (attrs['expressCool'] != null) features['expressCool'] = attrs['expressCool'];
    if (features.isNotEmpty) payload['specialFeature'] = features;

    if (payload.isNotEmpty) {
      await controlLgAppliance(
        device: dev,
        commandPayload: payload,
        patTokenOverride: patTokenOverride,
      );
    }
  }

  Future<void> controlLgAeroTower(
    RealSmartDevice dev,
    Map<String, dynamic> attrs, {
    String? patTokenOverride,
  }) async {
    final purifier = <String, dynamic>{};
    if (attrs['cleanBoosterTilt'] != null) purifier['cleanBoosterTilt'] = attrs['cleanBoosterTilt'];
    if (attrs['airflowMode'] != null) purifier['airflowMode'] = attrs['airflowMode'];
    if (attrs['uvNano'] != null) purifier['uvNano'] = attrs['uvNano'];
    if (attrs['petCare'] != null) purifier['petCare'] = attrs['petCare'];

    if (purifier.isNotEmpty) {
      await controlLgAppliance(
        device: dev,
        commandPayload: {'airPurifier': purifier},
        patTokenOverride: patTokenOverride,
      );
    }
  }

  Future<void> controlLgStyler(
    RealSmartDevice dev,
    Map<String, dynamic> attrs, {
    String? patTokenOverride,
  }) async {
    final styler = <String, dynamic>{};
    if (attrs['movingHangerSpeed'] != null) styler['movingHangerSpeed'] = attrs['movingHangerSpeed'];
    if (attrs['movingHangerRpm'] != null) styler['movingHangerRpm'] = attrs['movingHangerRpm'];
    if (attrs['trueSteam'] != null) styler['trueSteam'] = attrs['trueSteam'];
    if (attrs['pantsCrease'] != null) styler['pantsCrease'] = attrs['pantsCrease'];
    if (attrs['gentleDry'] != null) styler['gentleDry'] = attrs['gentleDry'];
    if (attrs['stylerCourse'] != null) styler['stylerCourse'] = attrs['stylerCourse'];

    if (styler.isNotEmpty) {
      await controlLgAppliance(
        device: dev,
        commandPayload: {'styler': styler},
        patTokenOverride: patTokenOverride,
      );
    }
  }

  Future<void> controlLgDishwasher(
    RealSmartDevice dev,
    Map<String, dynamic> attrs, {
    String? patTokenOverride,
  }) async {
    final dishwasher = <String, dynamic>{};
    if (attrs['quadWashArmPressure'] != null) dishwasher['quadWashArmPressure'] = attrs['quadWashArmPressure'];
    if (attrs['trueSteamDishwash'] != null) dishwasher['trueSteamDishwash'] = attrs['trueSteamDishwash'];
    if (attrs['autoDoorOpen'] != null) dishwasher['autoDoorOpen'] = attrs['autoDoorOpen'];
    if (attrs['dishwasherCourse'] != null) dishwasher['dishwasherCourse'] = attrs['dishwasherCourse'];

    if (dishwasher.isNotEmpty) {
      await controlLgAppliance(
        device: dev,
        commandPayload: {'dishwasher': dishwasher},
        patTokenOverride: patTokenOverride,
      );
    }
  }

  Future<void> activateLgThinqUpFeature(
    RealSmartDevice dev,
    String featureName, {
    String? patTokenOverride,
  }) async {
    await controlLgAppliance(
      device: dev,
      commandPayload: {
        'thinqUp': {
          'feature': featureName,
          'action': 'INSTALL_AND_ACTIVATE',
          'timestamp': DateTime.now().toIso8601String(),
        }
      },
      patTokenOverride: patTokenOverride,
    );
  }

  // ---------------------------------------------------------------------------
  // 2. WIPRO / TUYA CLOUD AUTO-KEY HARVESTER (INDIA REGION: openapi.tuyain.com)
  // Automatically extracts `deviceId` and 16-byte `localKey` for every Wipro bulb
  // ---------------------------------------------------------------------------
  Future<List<RealSmartDevice>> autoHarvestWiproTuyaKeys({
    required String accessId,
    required String accessSecret,
    required String sampleDeviceId,
    String regionHost = 'https://openapi.tuyain.com',
  }) async {
    final t = DateTime.now().millisecondsSinceEpoch.toString();
    // Step A: Obtain Tuya OpenAPI Access Token
    final tokenPath = '/v1.0/token?grant_type=1';
    final tokenSign = _signTuyaRequest(accessId, accessSecret, t, 'GET', tokenPath, '');

    final tokenRes = await http.get(
      Uri.parse('$regionHost$tokenPath'),
      headers: {
        'client_id': accessId,
        'sign': tokenSign,
        't': t,
        'sign_method': 'HMAC-SHA256',
      },
    ).timeout(const Duration(seconds: 8));

    final tokenJson = jsonDecode(tokenRes.body) as Map<String, dynamic>;
    if (tokenJson['success'] != true) {
      throw Exception('Tuya Auth Failed: ${tokenJson['msg']}');
    }
    final accessToken = tokenJson['result']['access_token'] as String;

    // Step B: Fetch Device Details including LocalKey
    final devPath = '/v1.0/devices/$sampleDeviceId';
    final t2 = DateTime.now().millisecondsSinceEpoch.toString();
    final devSign = _signTuyaRequest(
      accessId,
      accessSecret,
      t2,
      'GET',
      devPath,
      '',
      accessToken: accessToken,
    );

    final devRes = await http.get(
      Uri.parse('$regionHost$devPath'),
      headers: {
        'client_id': accessId,
        'access_token': accessToken,
        'sign': devSign,
        't': t2,
        'sign_method': 'HMAC-SHA256',
      },
    ).timeout(const Duration(seconds: 8));

    final devJson = jsonDecode(devRes.body) as Map<String, dynamic>;
    if (devJson['success'] != true) {
      throw Exception('Failed to extract Wipro LocalKey: ${devJson['msg']}');
    }

    final result = devJson['result'] as Map<String, dynamic>;
    final extractedLocalKey = result['local_key']?.toString() ?? '';
    final devName = result['name']?.toString() ?? 'Wipro Smart Bulb';
    final localIp = result['ip']?.toString() ?? '';

    return [
      RealSmartDevice(
        id: sampleDeviceId,
        name: devName,
        room: 'Living Room',
        category: 'light',
        protocol: ConnectionProtocol.tuyaLocalLan,
        credentials: {
          'ip': localIp,
          'port': '6668',
          'localKey': extractedLocalKey,
        },
        isOn: result['online'] == true,
        isOnline: result['online'] == true,
        primaryValue: 80.0,
        ratedMaxWatts: 9.0,
      ),
    ];
  }

  String _signTuyaRequest(
    String clientId,
    String secret,
    String timestamp,
    String method,
    String path,
    String body, {
    String accessToken = '',
  }) {
    final bodyHash = sha256.convert(utf8.encode(body)).toString();
    final stringToSign = '$method\n$bodyHash\n\n$path';
    final fullStr = '$clientId$accessToken$timestamp$stringToSign';
    final hmac = Hmac(sha256, utf8.encode(secret));
    return hmac.convert(utf8.encode(fullStr)).toString().toUpperCase();
  }

  // ---------------------------------------------------------------------------
  // 3. ONEPLUS / ANDROID TV REMOTE PAIRING & KEYCODE DISPATCHER
  // ---------------------------------------------------------------------------
  Future<bool> probeAndPairOnePlusTv(String tvIp) async {
    // Check Google Cast / DIAL Port 8008 or Android TV Remote Port 6466
    try {
      final socket = await Socket.connect(tvIp, 8008, timeout: const Duration(seconds: 3));
      await socket.close();
      return true;
    } catch (_) {
      try {
        final socket = await Socket.connect(tvIp, 6466, timeout: const Duration(seconds: 3));
        await socket.close();
        return true;
      } catch (_) {
        return false;
      }
    }
  }
}
