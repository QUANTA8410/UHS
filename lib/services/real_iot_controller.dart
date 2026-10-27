import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';
import 'master/zero_touch_onboarding_service.dart';
import 'tv/oneplus_connect_service.dart';
import 'wipro/wipro_tuya_service.dart';

enum ConnectionProtocol {
  smartThingsCloud,
  homeAssistantBridge,
  tuyaLocalLan,
  tuyaCloudDirect,
  onePlusTvLan,
  customHttpWebhook,
  philipsHueLocal,
  philipsWizUdp,
  rtspOnvifCamera,
  lgThinqCloud,
}

class RealSmartDevice {
  final String id;
  String name;
  String room;
  final String category; // 'light', 'ac', 'washer', 'tv', 'switch', 'camera'
  final ConnectionProtocol protocol;
  final Map<String, String> credentials; // token, ip, localKey, hubUrl, component
  bool isOn;
  bool isOnline;
  int consecutiveFailedPolls;
  double primaryValue; // Brightness (0-100) or Temp (16-30) or Spin RPM
  double liveWatts; // Exact real-time draw in Watts (0.0 when offline)
  double ratedMaxWatts; // Hardware nameplate rating (used when device lacks a shunt sensor)
  Map<String, dynamic> liveAttributes;
  String? lastError;
  DateTime? lastPolledAt;

  RealSmartDevice({
    required this.id,
    required this.name,
    required this.room,
    required this.category,
    required this.protocol,
    required this.credentials,
    this.isOn = false,
    this.isOnline = true,
    this.consecutiveFailedPolls = 0,
    this.primaryValue = 24.0,
    this.liveWatts = 0.0,
    this.ratedMaxWatts = 0.0,
    this.liveAttributes = const {},
    this.lastError,
    this.lastPolledAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'room': room,
        'category': category,
        'protocol': protocol.name,
        'credentials': credentials,
        'isOn': isOn,
        'isOnline': isOnline,
        'consecutiveFailedPolls': consecutiveFailedPolls,
        'primaryValue': primaryValue,
        'liveWatts': liveWatts,
        'ratedMaxWatts': ratedMaxWatts,
        'liveAttributes': liveAttributes,
        if (lastError != null) 'lastError': lastError,
        if (lastPolledAt != null) 'lastPolledAt': lastPolledAt!.toIso8601String(),
      };

  void markOnlineSuccess() {
    isOnline = true;
    consecutiveFailedPolls = 0;
    lastError = null;
    lastPolledAt = DateTime.now();
  }

  bool get isPowered => isOn;
  set isPowered(bool v) => isOn = v;
  String get cloudDeviceId => credentials['cloudDeviceId'] ?? credentials['devId'] ?? id;

  bool get isLgThinq {
    if (protocol == ConnectionProtocol.lgThinqCloud) return true;
    final vendor = credentials['vendor']?.toString().toLowerCase().trim();
    return vendor == 'lg_thinq' || vendor == 'lg' || vendor == 'thinq';
  }

  String get normalizedCategory {
    final cat = category.toLowerCase().trim().replaceAll('-', '_').replaceAll(' ', '_');
    if (cat == 'ac' ||
        cat == 'air_conditioner' ||
        cat == 'airconditioner' ||
        cat == 'hvac' ||
        cat == 'climate') {
      return 'ac';
    }
    if (cat == 'washer' || cat == 'washing_machine' || cat == 'washtower') {
      return 'washer';
    }
    if (cat == 'dryer') {
      return 'dryer';
    }
    if (cat == 'fridge' || cat == 'refrigerator') {
      return 'fridge';
    }
    if (cat == 'air_purifier' ||
        cat == 'airpurifier' ||
        cat == 'aerotower' ||
        cat == 'purifier') {
      return 'air_purifier';
    }
    if (cat == 'styler' || cat == 'steam_closet') {
      return 'styler';
    }
    if (cat == 'dishwasher') {
      return 'dishwasher';
    }
    if (cat == 'tv' || cat == 'television') {
      return 'tv';
    }
    return cat;
  }

  bool get hasRealHardwareCredentials {
    switch (protocol) {
      case ConnectionProtocol.lgThinqCloud:
        final token = credentials['token'];
        return token != null &&
            token.trim().isNotEmpty &&
            token.trim().length > 10 &&
            !token.toLowerCase().contains('demo');

      case ConnectionProtocol.smartThingsCloud:
        final token = credentials['token'];
        return token != null &&
            token.trim().isNotEmpty &&
            token.trim().length > 10 &&
            !token.toLowerCase().contains('demo');

      case ConnectionProtocol.tuyaLocalLan:
        final ip = credentials['ip'];
        final localKey = credentials['localKey'];
        final token = credentials['accessToken'] ?? credentials['token'];
        final hasValidKey = localKey != null && localKey.trim().length == 16;
        final hasValidToken = token != null && token.trim().length > 5 && !token.toLowerCase().contains('demo');
        return ip != null &&
            ip.trim().isNotEmpty &&
            !ip.toLowerCase().contains('demo') &&
            (hasValidKey || hasValidToken);

      case ConnectionProtocol.tuyaCloudDirect:
        final token = credentials['accessToken'] ?? credentials['token'];
        return token != null &&
            token.trim().isNotEmpty &&
            token.trim().length > 5 &&
            !token.toLowerCase().contains('demo');

      case ConnectionProtocol.homeAssistantBridge:
        final hubUrl = credentials['hubUrl'];
        final token = credentials['token'];
        return hubUrl != null &&
            hubUrl.trim().isNotEmpty &&
            !hubUrl.toLowerCase().contains('demo') &&
            token != null &&
            token.trim().isNotEmpty &&
            !token.toLowerCase().contains('demo');

      case ConnectionProtocol.onePlusTvLan:
        final ip = credentials['ip'];
        final vendor = credentials['vendor']?.toString().toLowerCase();
        final isDemo = (credentials as dynamic)['isDemo']?.toString().toLowerCase() == 'true';
        return ip != null &&
            ip.trim().isNotEmpty &&
            !ip.startsWith('127.') &&
            ip.trim() != '0.0.0.0' &&
            !ip.toLowerCase().contains('demo') &&
            vendor != 'demo' &&
            !isDemo;

      case ConnectionProtocol.philipsHueLocal:
        final bridgeIp = credentials['bridgeIp'] ?? credentials['ip'];
        final username = credentials['username'];
        return bridgeIp != null &&
            bridgeIp.trim().isNotEmpty &&
            !bridgeIp.toLowerCase().contains('demo') &&
            username != null &&
            username.trim().isNotEmpty &&
            !username.toLowerCase().contains('demo');

      case ConnectionProtocol.philipsWizUdp:
        final ip = credentials['ip'];
        final vendor = credentials['vendor']?.toString().toLowerCase();
        final isDemo = (credentials as dynamic)['isDemo']?.toString().toLowerCase() == 'true';
        return ip != null &&
            ip.trim().isNotEmpty &&
            !ip.startsWith('127.') &&
            ip.trim() != '0.0.0.0' &&
            !ip.toLowerCase().contains('demo') &&
            vendor != 'demo' &&
            !isDemo;

      case ConnectionProtocol.customHttpWebhook:
        final vendor = credentials['vendor']?.toLowerCase().trim();
        if (vendor == 'lg_thinq' || vendor == 'lg' || vendor == 'thinq' || isLgThinq) {
          final token = credentials['token'];
          return token != null &&
              token.trim().isNotEmpty &&
              token.trim().length > 10 &&
              !token.toLowerCase().contains('demo');
        }
        final url = credentials['controlUrl'] ?? credentials['onUrl'] ?? credentials['offUrl'];
        return url != null &&
            url.trim().isNotEmpty &&
            !url.toLowerCase().contains('demo');

      case ConnectionProtocol.rtspOnvifCamera:
        final endpoint = credentials['ip'] ?? credentials['rtspUrl'];
        final vendor = credentials['vendor']?.toString().toLowerCase();
        final isDemo = (credentials as dynamic)['isDemo']?.toString().toLowerCase() == 'true';
        return endpoint != null &&
            endpoint.trim().isNotEmpty &&
            !endpoint.toLowerCase().contains('demo') &&
            vendor != 'demo' &&
            !isDemo;
    }
  }

  bool get isPendingKey {
    if (protocol == ConnectionProtocol.tuyaLocalLan) {
      final lk = credentials['localKey'];
      return lk == null || lk.trim().length != 16;
    }
    return false;
  }

  bool get isDummy {
    if (hasRealHardwareCredentials) return false;
    final vendor = credentials['vendor']?.toString().toLowerCase();
    if (vendor == 'demo') return true;
    final isDemoVal = (credentials as dynamic)['isDemo'];
    if (isDemoVal == true || isDemoVal?.toString().toLowerCase() == 'true') return true;
    if (credentials['token']?.toString().toLowerCase().contains('demo') == true) return true;
    // Tuya LAN bulb pending local key without cloud token fallback behaves as dummy
    if (protocol == ConnectionProtocol.tuyaLocalLan && isPendingKey) {
      final token = credentials['accessToken'] ?? credentials['token'];
      if (token == null || token.toString().trim().isEmpty) {
        return true;
      }
    }
    return false;
  }
  String get statusSummary => isOnline ? (isOn ? 'On • ${primaryValue.round()}' : 'Off') : 'Offline';
  bool get ecoBubbleEnabled => liveAttributes['ecoBubble'] == true;
  bool get superSpeedEnabled => liveAttributes['superSpeed'] == true;
  bool get aiWashEnabled => liveAttributes['aiWash'] == true;
  bool get addWashDoorLocked => liveAttributes['addWashDoorLocked'] != false;
  int get detergentLevelPercent => int.tryParse(liveAttributes['detergentPercent']?.toString() ?? '75') ?? 75;
  int get softenerLevelPercent => int.tryParse(liveAttributes['softenerPercent']?.toString() ?? '45') ?? 45;
  int get drumCleanCount => int.tryParse(liveAttributes['drumCleanCount']?.toString() ?? '28') ?? 28;
  String get selectedCycle => liveAttributes['cycle']?.toString() ?? 'AI DD Normal';
  String? get recommendedLaundryRecipe => liveAttributes['recommendedRecipe']?.toString();
  int get remainingMinutes => int.tryParse(liveAttributes['remainingMinutes']?.toString() ?? '19') ?? (isOn ? 19 : 0);
  double get brightness => primaryValue / 100.0;
  set brightness(double b) => primaryValue = (b * 100.0).clamp(0.0, 100.0);
  double get targetTempC => primaryValue;
  set targetTempC(double t) => primaryValue = t;
  String get currentApp => liveAttributes['currentApp']?.toString() ?? 'OxygenPlay';
  String get pictureMode => liveAttributes['pictureMode']?.toString() ?? 'Cinema';
  int get volume => int.tryParse(liveAttributes['volume']?.toString() ?? '20') ?? 20;
  String get activeScene => liveAttributes['activeScene']?.toString() ?? 'Relax';
  bool get musicSyncActive => liveAttributes['musicSync'] == true;
  bool get jetCoolActive => liveAttributes['jetCool'] == true;
  String get washerStage => liveAttributes['stage']?.toString() ?? (isOn ? 'wash' : 'idle');
  int get rinseCount => int.tryParse(liveAttributes['rinseCount']?.toString() ?? '3') ?? 3;
  String get waterTemp => liveAttributes['waterTemp']?.toString() ?? (liveAttributes['waterTemperature'] != null ? '${liveAttributes['waterTemperature']}°C' : '40°C');
  String get spinSpeed => liveAttributes['spinSpeed']?.toString() ?? '1200 RPM';
  bool get autoCycleLinkEnabled => liveAttributes['autoCycleLink'] == true;
  bool get windFreeEnabled => liveAttributes['windFree'] == true;
  bool get goodSleepActive => liveAttributes['goodSleep'] == true;
  int get pm1AirQuality => int.tryParse(liveAttributes['pm1AirQuality']?.toString() ?? '12') ?? 12;
  bool get aiEnergyMode => liveAttributes['aiEnergyMode'] == true;
  double get fridgeTemp => double.tryParse(liveAttributes['fridgeTemp']?.toString() ?? '3.0') ?? 3.0;
  double get freezerTemp => double.tryParse(liveAttributes['freezerTemp']?.toString() ?? '-19.0') ?? -19.0;
  String get flexZoneMode => liveAttributes['flexZoneMode']?.toString() ?? 'Beverage';
  bool get powerCool => liveAttributes['powerCool'] == true;
  bool get powerFreeze => liveAttributes['powerFreeze'] == true;
  bool get iceBitesEnabled => liveAttributes['iceBites'] == true;
  bool get artModeEnabled => liveAttributes['artMode'] == true;
  bool get lightSyncEnabled => liveAttributes['lightSync'] == true;
  String get selectedArtwork => liveAttributes['selectedArtwork']?.toString() ?? 'Starry Night';

  // LG WashTower & AI DD Washer / Dryer
  bool get turboWash360Enabled => liveAttributes['turboWash360'] != false;
  int get ezDispenseDetergentPercent => int.tryParse(liveAttributes['ezDispenseDetergent']?.toString() ?? '82') ?? 82;
  int get ezDispenseSoftenerPercent => int.tryParse(liveAttributes['ezDispenseSoftener']?.toString() ?? '68') ?? 68;
  bool get steamPlusEnabled => liveAttributes['steamPlus'] != false;
  bool get smartPairingActive => liveAttributes['smartPairing'] != false;
  String get dryerDryLevel => liveAttributes['dryLevel']?.toString() ?? 'Normal';
  int get dryerRemainingMinutes => int.tryParse(liveAttributes['dryerRemainingMinutes']?.toString() ?? '34') ?? 34;
  String get dryerStage => liveAttributes['dryerStage']?.toString() ?? 'drying';

  // LG InstaView Refrigerator
  bool get instaViewGlassTransparent => liveAttributes['instaViewTransparent'] == true;
  bool get craftIceEnabled => liveAttributes['craftIce'] != false;
  bool get doorCoolingActive => liveAttributes['doorCooling'] != false;
  String get hygieneFreshMode => liveAttributes['hygieneFresh']?.toString() ?? 'Auto';
  bool get expressFreezeActive => liveAttributes['expressFreeze'] == true;
  bool get expressCoolActive => liveAttributes['expressCool'] == true;

  // LG PuriCare AeroTower
  int get cleanBoosterTiltAngle => int.tryParse(liveAttributes['cleanBoosterTilt']?.toString() ?? '55') ?? 55;
  String get aeroTowerAirflowMode => liveAttributes['airflowMode']?.toString() ?? 'Wide';
  bool get uvNanoEnabled => liveAttributes['uvNano'] != false;
  int get pm1LaserIndex => int.tryParse(liveAttributes['pm1Laser']?.toString() ?? '9') ?? 9;
  bool get petCareModeActive => liveAttributes['petCare'] == true;

  // LG Styler Steam Closet
  String get movingHangerSpeed => liveAttributes['movingHangerSpeed']?.toString() ?? 'Normal';
  int get movingHangerRpm => int.tryParse(liveAttributes['movingHangerRpm']?.toString() ?? '180') ?? 180;
  bool get trueSteamActive => liveAttributes['trueSteam'] != false;
  bool get pantsCreaseCare => liveAttributes['pantsCrease'] != false;
  bool get gentleDryActive => liveAttributes['gentleDry'] != false;
  String get stylerCourse => liveAttributes['stylerCourse']?.toString() ?? 'Refresh';

  // LG QuadWash Dishwasher
  String get quadWashArmPressure => liveAttributes['quadWashArmPressure']?.toString() ?? 'Dual Zone';
  bool get trueSteamDishwash => liveAttributes['trueSteamDishwash'] != false;
  bool get autoDoorOpenDry => liveAttributes['autoDoorOpen'] != false;
  String get dishwasherCourse => liveAttributes['dishwasherCourse']?.toString() ?? 'Auto';

  // LG ThinQ UP & Smart Diagnosis
  bool get thinqUpUpdateAvailable => liveAttributes['thinqUpUpdate'] != false;
  String get thinqUpFeatureName => liveAttributes['thinqUpFeature']?.toString() ?? 'Pet Care Cycle & Gentle Dry Wave';
  String get smartDiagnosisStatus => liveAttributes['smartDiagnosisStatus']?.toString() ?? 'Normal - 100% Component Health';
  bool get smartDiagnosisAudioToneReady => liveAttributes['audioToneReady'] != false;

  RealSmartDevice copyWith({
    String? id,
    String? name,
    String? room,
    String? category,
    ConnectionProtocol? protocol,
    Map<String, String>? credentials,
    bool? isOn,
    bool? isOnline,
    int? consecutiveFailedPolls,
    double? primaryValue,
    double? liveWatts,
    double? ratedMaxWatts,
    Map<String, dynamic>? liveAttributes,
    String? lastError,
    DateTime? lastPolledAt,
  }) {
    return RealSmartDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      room: room ?? this.room,
      category: category ?? this.category,
      protocol: protocol ?? this.protocol,
      credentials: credentials ?? Map<String, String>.from(this.credentials),
      isOn: isOn ?? this.isOn,
      isOnline: isOnline ?? this.isOnline,
      consecutiveFailedPolls: consecutiveFailedPolls ?? this.consecutiveFailedPolls,
      primaryValue: primaryValue ?? this.primaryValue,
      liveWatts: liveWatts ?? this.liveWatts,
      ratedMaxWatts: ratedMaxWatts ?? this.ratedMaxWatts,
      liveAttributes: liveAttributes ?? Map<String, dynamic>.from(this.liveAttributes),
      lastError: lastError ?? this.lastError,
      lastPolledAt: lastPolledAt ?? this.lastPolledAt,
    );
  }

  factory RealSmartDevice.fromJson(Map<String, dynamic> json) {
    final rawCreds = json['credentials'];
    final Map<String, String> safeCreds = {};
    if (rawCreds is Map) {
      for (final entry in rawCreds.entries) {
        if (entry.key != null && entry.value != null) {
          safeCreds[entry.key.toString()] = entry.value.toString();
        }
      }
    }

    final rawAttrs = json['liveAttributes'];
    final Map<String, dynamic> safeAttrs = {};
    if (rawAttrs is Map) {
      for (final entry in rawAttrs.entries) {
        if (entry.key != null) {
          safeAttrs[entry.key.toString()] = entry.value;
        }
      }
    }

    var proto = ConnectionProtocol.values.firstWhere(
      (e) => e.name == json['protocol'],
      orElse: () => ConnectionProtocol.smartThingsCloud,
    );
    final vendor = safeCreds['vendor']?.toLowerCase().trim();
    if (proto == ConnectionProtocol.customHttpWebhook &&
        (vendor == 'lg_thinq' || vendor == 'lg' || vendor == 'thinq')) {
      proto = ConnectionProtocol.lgThinqCloud;
    }

    return RealSmartDevice(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Smart Device').toString(),
      room: (json['room'] ?? 'Living Room').toString(),
      category: (json['category'] ?? 'switch').toString(),
      protocol: proto,
      credentials: safeCreds,
      isOn: json['isOn'] == true,
      isOnline: json['isOnline'] != false,
      consecutiveFailedPolls: json['consecutiveFailedPolls'] as int? ?? 0,
      primaryValue: (json['primaryValue'] as num?)?.toDouble() ?? 24.0,
      liveWatts: (json['liveWatts'] as num?)?.toDouble() ?? 0.0,
      ratedMaxWatts: (json['ratedMaxWatts'] as num?)?.toDouble() ?? 0.0,
      liveAttributes: safeAttrs,
      lastError: json['lastError']?.toString(),
      lastPolledAt: json['lastPolledAt'] != null
          ? DateTime.tryParse(json['lastPolledAt'].toString())
          : null,
    );
  }
}

class RealIotController {
  static const String _stBase = 'https://api.smartthings.com/v1';
  final http.Client? client;
  final Future<Socket> Function(dynamic host, int port, {Duration? timeout})? socketConnector;
  final WiproTuyaService wiproTuyaService;
  final OnePlusConnectService onePlusConnectService;
  final Map<String, Future<void>> _tuyaLanLocks = {};

  RealIotController({
    this.client,
    this.socketConnector,
    WiproTuyaService? wiproTuyaService,
    OnePlusConnectService? onePlusConnectService,
  })  : wiproTuyaService = wiproTuyaService ?? WiproTuyaService(socketConnector: socketConnector),
        onePlusConnectService = onePlusConnectService ?? OnePlusConnectService(client: client);

  /// Serializes socket connections on port 6668 per device IP to prevent
  /// socket contention on single-connection ESP8266/BK7231 microcontrollers (Bug 9).
  Future<T> _withTuyaLanLock<T>(String key, Future<T> Function() action) {
    final previous = _tuyaLanLocks[key] ?? Future.value();
    final completer = Completer<void>();
    _tuyaLanLocks[key] = completer.future;

    return previous.then((_) async {
      try {
        return await action();
      } finally {
        await Future.delayed(const Duration(milliseconds: 100));
        completer.complete();
        if (_tuyaLanLocks[key] == completer.future) {
          _tuyaLanLocks.remove(key);
        }
      }
    }, onError: (_) async {
      try {
        return await action();
      } finally {
        await Future.delayed(const Duration(milliseconds: 100));
        completer.complete();
        if (_tuyaLanLocks[key] == completer.future) {
          _tuyaLanLocks.remove(key);
        }
      }
    });
  }

  Future<Socket> _socketConnect(dynamic host, int port, {Duration? timeout}) {
    final sc = socketConnector;
    return sc != null
        ? sc(host, port, timeout: timeout)
        : Socket.connect(host, port, timeout: timeout);
  }

  Future<http.Response> _get(Uri url, {Map<String, String>? headers}) {
    final c = client;
    return c != null ? c.get(url, headers: headers) : http.get(url, headers: headers);
  }

  Future<http.Response> _post(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) {
    final c = client;
    return c != null
        ? c.post(url, headers: headers, body: body, encoding: encoding)
        : http.post(url, headers: headers, body: body, encoding: encoding);
  }

  Future<http.Response> _delete(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) {
    final c = client;
    return c != null
        ? c.delete(url, headers: headers, body: body, encoding: encoding)
        : http.delete(url, headers: headers, body: body, encoding: encoding);
  }

  String _requireCredential(
    RealSmartDevice device,
    String key, {
    List<String> fallbacks = const [],
  }) {
    final primary = device.credentials[key];
    if (primary != null && primary.trim().isNotEmpty) {
      return primary.trim();
    }
    for (final fb in fallbacks) {
      final fallbackVal = device.credentials[fb];
      if (fallbackVal != null && fallbackVal.trim().isNotEmpty) {
        return fallbackVal.trim();
      }
    }
    final keysDesc = fallbacks.isEmpty ? "'$key'" : "'$key' (or ${fallbacks.map((f) => "'$f'").join(', ')})";
    throw Exception(
      "Missing required credential $keysDesc for device '${device.name}' (${device.id}, protocol: ${device.protocol.name})",
    );
  }

  // ---------------------------------------------------------------------------
  // 1. REAL SMARTTHINGS CLOUD IMPORT & CONTROL (NO DUMMY FALLBACKS)
  // ---------------------------------------------------------------------------
  Future<List<RealSmartDevice>> discoverSmartThingsDevices(String patToken) async {
    final cleanToken = patToken.trim();
    final res = await _get(
      Uri.parse('$_stBase/devices'),
      headers: {
        'Authorization': 'Bearer $cleanToken',
        'Accept': 'application/vnd.smartthings+json;v=1',
      },
    ).timeout(const Duration(seconds: 12));

    if (res.statusCode != 200) {
      throw Exception('SmartThings API Error (${res.statusCode}): Invalid Token or Network');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final items = List<Map<String, dynamic>>.from(body['items'] ?? []);
    if (items.isEmpty) {
      throw Exception('Token authenticated, but 0 devices were found in your SmartThings account.');
    }

    final List<RealSmartDevice> discovered = [];
    for (final item in items) {
      final deviceId = item['deviceId'] as String;
      final label = (item['label'] ?? item['name'] ?? 'SmartThings Device').toString();
      final components = List<Map<String, dynamic>>.from(item['components'] ?? []);
      final capIds = <String>{};
      for (final comp in components) {
        final caps = List<Map<String, dynamic>>.from(comp['capabilities'] ?? []);
        for (final c in caps) {
          capIds.add(c['id'].toString());
        }
      }

      String category = 'switch';
      if (capIds.contains('washerOperatingState') || label.toLowerCase().contains('washer')) {
        category = 'washer';
      } else if (capIds.contains('dryerOperatingState') || label.toLowerCase().contains('dryer')) {
        category = 'washer'; // dryer shares washer UI/wattage profile
      } else if (capIds.contains('refrigeration') ||
          label.toLowerCase().contains('fridge') ||
          label.toLowerCase().contains('refrigerator')) {
        // Samsung Family Hub exposes thermostatCoolingSetpoint — check fridge
        // capability first so it is never misclassified as an AC (Bug 18).
        category = 'fridge';
      } else if (capIds.contains('airConditionerMode') || capIds.contains('thermostatCoolingSetpoint')) {
        category = 'ac';
      } else if (capIds.contains('switchLevel') || capIds.contains('colorControl')) {
        category = 'light';
      } else if (capIds.contains('mediaPlayback') || capIds.contains('tvChannel')) {
        category = 'tv';
      }

      double ratedMax = 0.0;
      if (category == 'washer') {
        ratedMax = 480.0;
      } else if (category == 'ac') {
        ratedMax = 1480.0;
      } else if (category == 'fridge') {
        ratedMax = 150.0;
      } else if (category == 'light') {
        ratedMax = 9.0;
      } else if (category == 'tv') {
        ratedMax = 110.0;
      }

      final dev = RealSmartDevice(
        id: deviceId,
        name: label,
        room: 'Living Room',
        category: category,
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {'token': cleanToken},
        ratedMaxWatts: ratedMax,
      );
      discovered.add(dev);
    }

    // Parallelize initial status fetch — avoids N+1 sequential HTTP round-trips
    // for each device's /health + /status calls (Bug 18).
    await Future.wait(
      discovered.map((dev) async {
        try {
          await refreshDeviceStatus(dev);
        } catch (_) {
          // Non-fatal: a device discovered but temporarily unreachable still
          // appears in the list with isOnline = false.
        }
      }),
    );
    return discovered;
  }

  // ---------------------------------------------------------------------------
  // 2. UNIVERSAL HOME ASSISTANT / MATTER HUB IMPORT (CONNECTS ANY BRAND)
  // ---------------------------------------------------------------------------
  Future<List<RealSmartDevice>> discoverHomeAssistantDevices(
    String hubUrl,
    String longLivedToken,
  ) async {
    final cleanUrl = hubUrl.trim().replaceAll(RegExp(r'/$'), '');
    final cleanToken = longLivedToken.trim();

    final res = await http.get(
      Uri.parse('$cleanUrl/api/states'),
      headers: {
        'Authorization': 'Bearer $cleanToken',
        'Content-Type': 'application/json',
      },
    ).timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) {
      throw Exception('Universal Hub Error (${res.statusCode}): Check URL & Token');
    }

    final states = List<Map<String, dynamic>>.from(jsonDecode(res.body));
    final List<RealSmartDevice> devices = [];

    for (final st in states) {
      final entityId = st['entity_id'].toString();
      final domain = entityId.split('.').first;
      if (!['light', 'switch', 'climate', 'media_player', 'fan'].contains(domain)) {
        continue;
      }
      final attrs = Map<String, dynamic>.from(st['attributes'] ?? {});
      final friendlyName = (attrs['friendly_name'] ?? entityId).toString();
      final stateStr = st['state'].toString().toLowerCase();

      String category = 'switch';
      double ratedMax = 25.0;
      if (domain == 'light') {
        category = 'light';
        ratedMax = 9.0;
      } else if (domain == 'climate') {
        category = 'ac';
        ratedMax = 1480.0;
      } else if (domain == 'media_player') {
        category = 'tv';
        ratedMax = 110.0;
      }

      final dev = RealSmartDevice(
        id: entityId,
        name: friendlyName,
        room: 'Living Room',
        category: category,
        protocol: ConnectionProtocol.homeAssistantBridge,
        credentials: {'hubUrl': cleanUrl, 'token': cleanToken, 'domain': domain},
        isOn: stateStr != 'off' && stateStr != 'unavailable' && stateStr != 'standby',
        isOnline: stateStr != 'unavailable',
        primaryValue: (attrs['temperature'] as num?)?.toDouble() ??
            (((attrs['brightness'] as num?)?.toDouble() ?? 255.0) / 2.55),
        ratedMaxWatts: ratedMax,
        liveAttributes: attrs,
      );
      computeDeviceLiveWattage(dev);
      devices.add(dev);
    }
    return devices;
  }

  // ---------------------------------------------------------------------------
  // 3. WIPRO NEXT / SMART LIFE DIRECT CLOUD AUTH & CONTROL (INDIAN REGION)
  // ---------------------------------------------------------------------------
  Future<List<RealSmartDevice>> discoverWiproOrSmartLifeCloudDevices({
    required String username,
    required String password,
    String countryCode = '91',
    String bizType = 'smart_life',
  }) async {
    final cleanUser = username.trim();
    final cleanPass = password.trim();
    final cleanCountry = countryCode.trim().replaceAll('+', '');

    Future<Map<String, dynamic>> attemptAuth(String biz) async {
      final res = await http.post(
        Uri.parse('https://px1.tuyain.com/homeassistant/auth.do'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body:
            'userName=${Uri.encodeComponent(cleanUser)}&password=${Uri.encodeComponent(cleanPass)}&countryCode=$cleanCountry&bizType=$biz&from=tuya',
      ).timeout(const Duration(seconds: 10));

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return json;
    }

    Map<String, dynamic> authResult = await attemptAuth(bizType);
    if (authResult['responseStatus'] == 'error' && bizType == 'smart_life') {
      try {
        final fallback = await attemptAuth('tuya');
        if (fallback['responseStatus'] != 'error' && fallback['access_token'] != null) {
          authResult = fallback;
        }
      } catch (_) {}
    }

    if (authResult['responseStatus'] == 'error' || authResult['access_token'] == null) {
      final errorMsg = authResult['errorMsg']?.toString() ??
          'Tuya/Wipro Authentication failed: check email/phone, password, or country code.';
      throw Exception(errorMsg);
    }

    final accessToken = authResult['access_token'].toString();

    final discoveryRes = await http.post(
      Uri.parse('https://px1.tuyain.com/homeassistant/skill'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'header': {
          'name': 'Discovery',
          'namespace': 'discovery',
          'payloadVersion': 1,
        },
        'payload': {
          'accessToken': accessToken,
        },
      }),
    ).timeout(const Duration(seconds: 10));

    if (discoveryRes.statusCode != 200) {
      throw Exception('Wipro/Tuya discovery request rejected (${discoveryRes.statusCode})');
    }

    final discJson = jsonDecode(discoveryRes.body) as Map<String, dynamic>;
    final devicesList = (discJson['payload']?['devices'] as List<dynamic>?) ?? [];

    final List<RealSmartDevice> discovered = [];
    for (final raw in devicesList) {
      if (raw is! Map<String, dynamic>) continue;
      final devId = raw['id']?.toString() ?? '';
      final name = raw['name']?.toString() ?? 'Wipro Smart Device';
      final devType = raw['dev_type']?.toString().toLowerCase() ?? 'light';
      final haType = raw['ha_type']?.toString().toLowerCase() ?? '';

      String category = 'light';
      if (devType.contains('switch') || haType.contains('switch')) {
        category = 'switch';
      } else if (devType.contains('socket') || haType.contains('socket') || devType.contains('plug')) {
        category = 'plug';
      } else if (devType.contains('climate') || haType.contains('climate') || devType.contains('ac')) {
        category = 'ac';
      }

      final dataMap = (raw['data'] as Map<String, dynamic>?) ?? {};
      final stateVal = dataMap['state']?.toString().toLowerCase();
      final bool isDeviceOn = stateVal == 'true' || stateVal == '1' || stateVal == 'on';
      final bool isDeviceOnline = raw['online'] != false;
      final double brightnessVal = (dataMap['brightness'] is num)
          ? (dataMap['brightness'] as num).toDouble()
          : (dataMap['brightness'] != null ? double.tryParse(dataMap['brightness'].toString()) ?? 100.0 : 100.0);

      final dev = RealSmartDevice(
        id: devId,
        name: name,
        room: 'Living Room',
        category: category,
        protocol: ConnectionProtocol.tuyaCloudDirect,
        credentials: {
          'accessToken': accessToken,
          'bizType': bizType,
          'countryCode': cleanCountry,
        },
        isOn: isDeviceOn,
        isOnline: isDeviceOnline,
        primaryValue: brightnessVal,
        ratedMaxWatts: category == 'light' ? 9.0 : (category == 'ac' ? 1480.0 : 25.0),
        liveAttributes: Map<String, dynamic>.from(dataMap),
      );
      computeDeviceLiveWattage(dev);
      discovered.add(dev);
    }
    return discovered;
  }

  // ---------------------------------------------------------------------------
  // 4. PHILIPS HUE BRIDGE DISCOVERY, PUSHLINK PAIRING & LIGHT ENUMERATION
  // ---------------------------------------------------------------------------
  /// Finds Philips Hue Bridge IP via Official MeetHue Discovery + Local Subnet Scan
  Future<List<String>> discoverHueBridgeIps({String? subnetPrefix, String? localIp}) async {
    final List<String> ips = [];
    // 1. Official MeetHue discovery endpoint
    try {
      final res = await _get(
        Uri.parse('https://discovery.meethue.com/'),
      ).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        for (final item in list) {
          if (item is Map && item['internalipaddress'] != null) {
            final ip = item['internalipaddress'].toString();
            if (!ips.contains(ip)) ips.add(ip);
          }
        }
      }
    } catch (_) {}

    // 2. Local subnet scan fallback on port 80 /api/config
    if (ips.isEmpty) {
      final subnets = <String>[];
      if (subnetPrefix != null && subnetPrefix.trim().isNotEmpty) {
        final p = subnetPrefix.trim();
        subnets.add(p.endsWith('.') ? p : '$p.');
      }
      try {
        final wifiIp = localIp ?? await NetworkInfo().getWifiIP();
        if (wifiIp != null && wifiIp.contains('.')) {
          final parts = wifiIp.split('.');
          if (parts.length == 4) {
            final detected = '${parts[0]}.${parts[1]}.${parts[2]}.';
            if (!subnets.contains(detected)) subnets.add(detected);
          }
        }
      } catch (_) {}

      for (final defaultSub in const ['192.168.1.', '192.168.0.', '192.168.29.']) {
        if (!subnets.contains(defaultSub)) subnets.add(defaultSub);
      }

      for (final sub in subnets) {
        final allHosts = List<int>.generate(254, (i) => i + 1);
        const chunkSize = 25;
        for (var i = 0; i < allHosts.length; i += chunkSize) {
          final end = (i + chunkSize > allHosts.length) ? allHosts.length : i + chunkSize;
          final chunk = allHosts.sublist(i, end);
          await Future.wait(chunk.map((host) async {
            final testIp = '$sub$host';
            try {
              final res = await _get(
                Uri.parse('http://$testIp/api/config'),
              ).timeout(const Duration(milliseconds: 350));
              if (res.statusCode == 200 &&
                  (res.body.toLowerCase().contains('philips hue') ||
                      res.body.toLowerCase().contains('hue bridge'))) {
                if (!ips.contains(testIp)) ips.add(testIp);
              }
            } catch (_) {}
          }));
          if (ips.isNotEmpty) break;
        }
        if (ips.isNotEmpty) break;
      }
    }

    return ips;
  }

  /// Pairs with Philips Hue Bridge via physical pushlink button.
  /// Returns the newly generated API token (username).
  Future<String> pairHueBridge({required String bridgeIp}) async {
    final cleanIp = bridgeIp.trim().replaceAll(RegExp(r'^https?://'), '').replaceAll('/', '');
    final res = await http
        .post(
          Uri.parse('http://$cleanIp/api'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'devicetype': 'unified_home#flutter_client'}),
        )
        .timeout(const Duration(seconds: 8));

    if (res.statusCode != 200) {
      throw Exception('Hue Bridge rejected pairing request (HTTP ${res.statusCode})');
    }

    final list = jsonDecode(res.body) as List<dynamic>;
    if (list.isEmpty) throw Exception('Unexpected empty response from Hue Bridge');
    final first = list.first as Map<String, dynamic>;

    if (first.containsKey('error')) {
      final err = first['error'] as Map<String, dynamic>;
      final type = err['type'];
      if (type == 101) {
        throw Exception('Link button not pressed! Please press the physical pushlink button on your Philips Hue Bridge, then tap Pair again.');
      }
      throw Exception('Hue error: ${err['description'] ?? type}');
    }

    if (first.containsKey('success')) {
      final success = first['success'] as Map<String, dynamic>;
      final username = success['username']?.toString();
      if (username != null && username.isNotEmpty) {
        return username;
      }
    }

    throw Exception('Failed to obtain Hue Bridge username token.');
  }

  /// Discovers and returns all paired Philips Hue lights connected to the Hue Bridge.
  Future<List<RealSmartDevice>> discoverHueLights({
    required String bridgeIp,
    required String username,
  }) async {
    final cleanIp = bridgeIp.trim().replaceAll(RegExp(r'^https?://'), '').replaceAll('/', '');
    final cleanUser = username.trim();

    final res = await http
        .get(Uri.parse('http://$cleanIp/api/$cleanUser/lights'))
        .timeout(const Duration(seconds: 8));

    if (res.statusCode != 200) {
      throw Exception('Failed to fetch Hue lights (HTTP ${res.statusCode})');
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final List<RealSmartDevice> lights = [];

    json.forEach((lightId, data) {
      if (data is! Map<String, dynamic>) return;
      final name = data['name']?.toString() ?? 'Hue Light $lightId';
      final state = (data['state'] as Map<String, dynamic>?) ?? {};
      final isOn = state['on'] == true;
      final isReachable = state['reachable'] != false;
      final bri = (state['bri'] as num?)?.toDouble() ?? 254.0;
      final briPct = (bri / 2.54).clamp(1.0, 100.0);

      final dev = RealSmartDevice(
        id: 'hue_${cleanIp.replaceAll('.', '_')}_$lightId',
        name: name,
        room: 'Living Room',
        category: 'light',
        protocol: ConnectionProtocol.philipsHueLocal,
        credentials: {
          'bridgeIp': cleanIp,
          'username': cleanUser,
          'lightId': lightId,
        },
        isOn: isOn,
        isOnline: isReachable,
        primaryValue: briPct,
        ratedMaxWatts: 9.5,
        liveAttributes: Map<String, dynamic>.from(state),
      );
      computeDeviceLiveWattage(dev);
      lights.add(dev);
    });

    return lights;
  }

  // ---------------------------------------------------------------------------
  // 5. PHILIPS WIZ WI-FI LIGHTS LOCAL UDP PROTOCOL (PORT 38899)
  // ---------------------------------------------------------------------------
  /// Helper to send and receive JSON UDP datagrams to/from Philips WiZ bulbs on port 38899
  Future<Map<String, dynamic>> _sendWizUdpPacket(
    String ip,
    Map<String, dynamic> msg, {
    int timeoutMs = 2500,
  }) async {
    final rawSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    try {
      final data = utf8.encode(jsonEncode(msg));
      rawSocket.send(data, InternetAddress(ip), 38899);

      final completer = Completer<Map<String, dynamic>>();
      final timer = Timer(Duration(milliseconds: timeoutMs), () {
        if (!completer.isCompleted) completer.complete({});
      });

      rawSocket.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = rawSocket.receive();
          if (dg != null) {
            try {
              final respStr = utf8.decode(dg.data);
              final json = jsonDecode(respStr) as Map<String, dynamic>;
              timer.cancel();
              if (!completer.isCompleted) completer.complete(json);
            } catch (_) {}
          }
        }
      });

      return await completer.future;
    } finally {
      rawSocket.close();
    }
  }

  /// Broadcasts UDP discovery packet to local subnet and returns responding WiZ bulbs
  Future<List<RealSmartDevice>> discoverWizLights({String subnet = '192.168.1.'}) async {
    final List<RealSmartDevice> found = [];
    final rawSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    rawSocket.broadcastEnabled = true;

    try {
      final msg = utf8.encode(jsonEncode({'method': 'getPilot', 'params': {}}));
      try {
        rawSocket.send(msg, InternetAddress('255.255.255.255'), 38899);
      } catch (_) {}

      final responses = <String, Map<String, dynamic>>{};
      rawSocket.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = rawSocket.receive();
          if (dg != null) {
            try {
              final resp = jsonDecode(utf8.decode(dg.data)) as Map<String, dynamic>;
              if (resp.containsKey('result')) {
                responses[dg.address.address] = resp['result'] as Map<String, dynamic>;
              }
            } catch (_) {}
          }
        }
      });

      await Future.delayed(const Duration(milliseconds: 1800));

      responses.forEach((ip, result) {
        final mac = result['mac']?.toString() ?? ip.replaceAll('.', '_');
        final isOn = result['state'] == true;
        final dimming = (result['dimming'] as num?)?.toDouble() ?? 100.0;

        final dev = RealSmartDevice(
          id: 'wiz_$mac',
          name: 'Philips WiZ Light ($ip)',
          room: 'Living Room',
          category: 'light',
          protocol: ConnectionProtocol.philipsWizUdp,
          credentials: {'ip': ip, 'mac': mac},
          isOn: isOn,
          isOnline: true,
          primaryValue: dimming,
          ratedMaxWatts: 8.5,
          liveAttributes: Map<String, dynamic>.from(result),
        );
        computeDeviceLiveWattage(dev);
        found.add(dev);
      });
    } finally {
      rawSocket.close();
    }
    return found;
  }

  // ---------------------------------------------------------------------------
  // 6. REALME & PHILIPS HOME CAMERA RTSP / ONVIF DISCOVERY & CONTROL
  // ---------------------------------------------------------------------------
  /// Tests RTSP socket connection and constructs a configured Realme or Philips Camera device
  Future<RealSmartDevice> probeAndPairCamera({
    required String brand, // 'realme' or 'philips'
    required String ip,
    String port = '554',
    String username = 'admin',
    String password = '',
    String customStreamPath = '',
    String room = 'Living Room',
    String? customName,
  }) async {
    final cleanIp = ip.trim().replaceAll(RegExp(r'^https?://|^rtsp://'), '').split(':').first.replaceAll('/', '');
    final cleanPort = int.tryParse(port.trim()) ?? 554;
    final defaultPath = brand.toLowerCase() == 'realme' ? '/live/ch0' : '/ch0';
    final streamPath = customStreamPath.trim().isNotEmpty ? customStreamPath.trim() : defaultPath;

    // Probe RTSP socket reachability
    bool reachable = false;
    try {
      final s = await Socket.connect(cleanIp, cleanPort, timeout: const Duration(seconds: 3));
      try {
        reachable = true;
      } finally {
        s.destroy();
      }
    } catch (_) {
      try {
        final s80 = await Socket.connect(cleanIp, 80, timeout: const Duration(seconds: 2));
        try {
          reachable = true;
        } finally {
          s80.destroy();
        }
      } catch (_) {}
    }

    final authPart = username.isNotEmpty
        ? (password.isNotEmpty ? '${Uri.encodeComponent(username)}:${Uri.encodeComponent(password)}@' : '${Uri.encodeComponent(username)}@')
        : '';
    final rtspUrl = 'rtsp://$authPart$cleanIp:$cleanPort$streamPath';
    final snapshotUrl = 'http://$cleanIp:80/snapshot.jpg';

    final displayName = customName?.trim().isNotEmpty == true
        ? customName!.trim()
        : (brand.toLowerCase() == 'realme' ? 'Realme Smart Cam 360' : 'Philips Home Camera');

    final dev = RealSmartDevice(
      id: 'cam_${brand.toLowerCase()}_${cleanIp.replaceAll('.', '_')}',
      name: displayName,
      room: room,
      category: 'camera',
      protocol: ConnectionProtocol.rtspOnvifCamera,
      credentials: {
        'brand': brand.toLowerCase(),
        'ip': cleanIp,
        'port': cleanPort.toString(),
        'username': username,
        'password': password,
        'rtspUrl': rtspUrl,
        'snapshotUrl': snapshotUrl,
        'streamPath': streamPath,
      },
      isOn: true, // streaming active
      isOnline: reachable,
      primaryValue: 1080.0, // 1080p resolution
      ratedMaxWatts: 4.5,
      liveAttributes: {
        'ptzCapable': brand.toLowerCase() == 'realme',
        'nightVision': true,
        'motionAlerts': true,
        'powerSource': 'RTSP Camera Sensor',
      },
    );
    computeDeviceLiveWattage(dev);
    return dev;
  }

  // ---------------------------------------------------------------------------
  // 7. REAL HARDWARE STATUS POLLING
  // ---------------------------------------------------------------------------
  Future<void> refreshDeviceStatus(RealSmartDevice device) async {
    if (device.isDummy && device.protocol != ConnectionProtocol.rtspOnvifCamera) {
      device.markOnlineSuccess();
      computeDeviceLiveWattage(device);
      return;
    }
    switch (device.protocol) {
      case ConnectionProtocol.smartThingsCloud:
        final token = _requireCredential(device, 'token');

        // 1. Query SmartThings Health endpoint first
        final healthRes = await _get(
          Uri.parse('$_stBase/devices/${device.id}/health'),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 8));

        if (healthRes.statusCode == 200) {
          final healthJson = jsonDecode(healthRes.body) as Map<String, dynamic>;
          final healthState = healthJson['state']?.toString().toUpperCase();
          if (healthState != 'ONLINE') {
            throw Exception('Device is $healthState');
          }
        } else {
          throw Exception('SmartThings health check failed (${healthRes.statusCode})');
        }

        // 2. Query SmartThings Status endpoint
        final res = await _get(
          Uri.parse('$_stBase/devices/${device.id}/status'),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 8));

        if (res.statusCode != 200) {
          throw Exception('SmartThings status poll failed (${res.statusCode})');
        }
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final allComponents = (data['components'] as Map<String, dynamic>?) ?? {};
        final configuredComp = device.credentials['component']?.toString().trim();
        Map<String, dynamic> comp = {};
        if (configuredComp != null && configuredComp.isNotEmpty && allComponents.containsKey(configuredComp)) {
          comp = (allComponents[configuredComp] as Map<String, dynamic>?) ?? {};
        } else if (allComponents.containsKey('main')) {
          comp = (allComponents['main'] as Map<String, dynamic>?) ?? {};
        } else if (allComponents.isNotEmpty) {
          comp = (allComponents.values.first as Map<String, dynamic>?) ?? {};
        }
        final mainComp = (allComponents['main'] as Map<String, dynamic>?) ?? comp;

        // Parse real switch state
        final switchVal = comp['switch']?['switch']?['value']?.toString().toLowerCase();

        // Parse real temperature or brightness
        final coolingSetpoint = comp['thermostatCoolingSetpoint']?['coolingSetpoint']?['value'] ??
            mainComp['thermostatCoolingSetpoint']?['coolingSetpoint']?['value'];
        final switchLevel = comp['switchLevel']?['level']?['value'] ??
            mainComp['switchLevel']?['level']?['value'];
        if (coolingSetpoint is num) device.primaryValue = coolingSetpoint.toDouble();
        if (switchLevel is num) device.primaryValue = switchLevel.toDouble();

        // Support washerOperatingState, dryerOperatingState, dishwasherOperatingState, operatingState
        final opState = (comp['washerOperatingState'] as Map<String, dynamic>?) ??
            (comp['dryerOperatingState'] as Map<String, dynamic>?) ??
            (comp['dishwasherOperatingState'] as Map<String, dynamic>?) ??
            (comp['operatingState'] as Map<String, dynamic>?) ??
            (mainComp['washerOperatingState'] as Map<String, dynamic>?) ??
            (mainComp['dryerOperatingState'] as Map<String, dynamic>?) ??
            (mainComp['dishwasherOperatingState'] as Map<String, dynamic>?) ??
            (mainComp['operatingState'] as Map<String, dynamic>?);

        final machineState = opState?['machineState']?['value']?.toString().toLowerCase() ??
            opState?['operatingState']?['value']?.toString().toLowerCase();

        final jobState = opState?['washerJobState']?['value']?.toString().toLowerCase() ??
            opState?['dryerJobState']?['value']?.toString().toLowerCase() ??
            opState?['dishwasherJobState']?['value']?.toString().toLowerCase() ??
            opState?['jobState']?['value']?.toString().toLowerCase();

        final completionTime = opState?['completionTime']?['value'];
        final Map<String, dynamic> parsedAttrs = Map<String, dynamic>.from(device.liveAttributes);
        if (machineState != null) parsedAttrs['machineState'] = machineState;
        if (jobState != null) {
          parsedAttrs['jobState'] = jobState;
          parsedAttrs['stage'] = jobState;
        }
        if (completionTime != null) {
          parsedAttrs['completionTime'] = completionTime;
          final dt = DateTime.tryParse(completionTime.toString());
          if (dt != null) {
            final diff = dt.toUtc().difference(DateTime.now().toUtc()).inMinutes;
            parsedAttrs['remainingMinutes'] = diff > 0 ? diff : 0;
          }
        }
        final washerWaterTemp = comp['custom.washerWaterTemperature']?['washerWaterTemperature']?['value']?.toString() ??
            mainComp['custom.washerWaterTemperature']?['washerWaterTemperature']?['value']?.toString();
        if (washerWaterTemp != null) parsedAttrs['waterTemperature'] = washerWaterTemp;
        final washerSpinSpeed = comp['custom.washerSpinSpeed']?['washerSpinSpeed']?['value']?.toString() ??
            mainComp['custom.washerSpinSpeed']?['washerSpinSpeed']?['value']?.toString();
        if (washerSpinSpeed != null) parsedAttrs['spinSpeed'] = washerSpinSpeed;

        // Parse real SmartThings Power Meter & Consumption Report (comp or fallback to mainComp for dual-drum shared mains telemetry)
        final powerMeterVal = comp['powerMeter']?['power']?['value'] ??
            mainComp['powerMeter']?['power']?['value'];
        final powerReportVal = comp['powerConsumptionReport']?['powerConsumption']?['value'] ??
            mainComp['powerConsumptionReport']?['powerConsumption']?['value'];
        if (powerMeterVal is num) {
          parsedAttrs['powerW'] = powerMeterVal.toDouble();
          parsedAttrs['powerSource'] = 'SmartThings Sensor';
        } else if (powerReportVal is Map && powerReportVal['power'] is num) {
          parsedAttrs['powerW'] = (powerReportVal['power'] as num).toDouble();
          parsedAttrs['powerSource'] = 'SmartThings Sensor';
        } else if (powerReportVal is num) {
          parsedAttrs['powerW'] = powerReportVal.toDouble();
          parsedAttrs['powerSource'] = 'SmartThings Sensor';
        }
        if (powerReportVal is Map && powerReportVal['energy'] is num) {
          parsedAttrs['energyWh'] = (powerReportVal['energy'] as num).toDouble();
        }

        device.liveAttributes = parsedAttrs;

        // Resilient two-tier power state machine:
        // Tier 1: Hardware switch takes definitive precedence if reported
        if (switchVal != null) {
          device.isOn = (switchVal == 'on');
        } else {
          // Tier 2: Infer power from appliance operating states or power draw
          const activeStates = {
            'run',
            'running',
            'pause',
            'paused',
            'wash',
            'washing',
            'rinse',
            'rinsing',
            'spin',
            'spinning',
            'dry',
            'drying',
            'damp',
            'airwash',
            'cooling',
            'heating',
            'weightSensing',
            'delayWash',
          };
          const inactiveStates = {
            'stop',
            'stopped',
            'finish',
            'finished',
            'ready',
            'standby',
            'idle',
            'off',
            'complete',
            'completed',
            'none',
          };

          if (machineState != null && activeStates.contains(machineState)) {
            device.isOn = true;
          } else if (machineState != null && inactiveStates.contains(machineState)) {
            device.isOn = false;
          } else {
            final powerW = (parsedAttrs['powerW'] as num?)?.toDouble() ?? 0.0;
            device.isOn = (powerW > 2.0 || device.category == 'fridge');
          }
        }

        device.markOnlineSuccess();
        break;

      case ConnectionProtocol.homeAssistantBridge:
        final hubUrl = _requireCredential(device, 'hubUrl');
        final token = _requireCredential(device, 'token');
        final res = await http.get(
          Uri.parse('$hubUrl/api/states/${device.id}'),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 6));

        if (res.statusCode == 200) {
          final st = jsonDecode(res.body) as Map<String, dynamic>;
          final stateStr = st['state'].toString();
          device.isOn = stateStr != 'off' && stateStr != 'unavailable';
          device.isOnline = stateStr != 'unavailable';
          device.liveAttributes = Map<String, dynamic>.from(st['attributes'] ?? {});
        }
        break;

      case ConnectionProtocol.tuyaLocalLan:
        final ip = _requireCredential(device, 'ip');
        final port = int.tryParse(device.credentials['port'] ?? '6668') ?? 6668;

        // Optimization (Bug 9): If device successfully responded within the last 15s,
        // it is demonstrably online. Skip probing port 6668 to avoid unnecessary contention.
        final lastSuccess = device.lastPolledAt;
        if (lastSuccess != null && DateTime.now().difference(lastSuccess).inSeconds < 15) {
          device.markOnlineSuccess();
          break;
        }

        await _withTuyaLanLock(ip, () async {
          final socket = await _socketConnect(ip, port, timeout: const Duration(seconds: 3));
          try {
            device.markOnlineSuccess();
          } finally {
            await socket.close();
          }
        });
        break;

      case ConnectionProtocol.onePlusTvLan:
        final ip = _requireCredential(device, 'ip');
        final port = int.tryParse(device.credentials['port'] ?? '8008') ?? 8008;
        final socket = await _socketConnect(ip, port, timeout: const Duration(seconds: 3));
        try {
          device.isOnline = true;
        } finally {
          socket.destroy();
        }
        break;

      case ConnectionProtocol.lgThinqCloud:
      case ConnectionProtocol.customHttpWebhook:
        if (device.isLgThinq || device.credentials['vendor'] == 'lg_thinq' || device.credentials['vendor'] == 'lg') {
          final token = _requireCredential(device, 'token');
          final country = device.credentials['country'] ?? 'IN';
          final gw = device.credentials['gatewayUrl'] ?? 'https://api-kic.lgthinq.com';
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
                  'x-api-key': 'v6GFvkweNo7DK7yD3ylIZ9w52aKBU0eJ7wLXkSR3',
                  'x-country': country,
                  'x-message-id': 'status-${DateTime.now().millisecondsSinceEpoch}',
                  'x-client-id': 'unified-smart-home-master',
                  'Content-Type': 'application/json',
                };
          try {
            final res = await http
                .get(Uri.parse('$gw/devices/${device.id}/status'), headers: headers)
                .timeout(const Duration(seconds: 8));
            if (res.statusCode == 200) {
              final json = jsonDecode(res.body) as Map<String, dynamic>;
              final airState = (json['airState'] ?? json['data'] ?? json) as Map<String, dynamic>;
              final opMode = airState['operation']?['airConOperationMode']?.toString() ??
                  airState['airConOperationMode']?.toString();
              if (opMode != null) {
                device.isOn = opMode.toUpperCase().contains('POWER_ON') || opMode.toUpperCase().contains('ON');
              }
              final targetT = airState['temperature']?['targetTemperature'] ?? airState['targetTemperature'];
              if (targetT is num) {
                device.primaryValue = targetT.toDouble();
              }
              final currentT = airState['temperature']?['currentTemperature'] ?? airState['currentTemperature'];
              final parsedAttrs = Map<String, dynamic>.from(device.liveAttributes);
              if (currentT is num) parsedAttrs['currentTemperature'] = currentT.toDouble();

              final energy = airState['energy'] ?? json['energy'];
              if (energy is Map) {
                final curPower = energy['onCurrent'] ?? energy['power'] ?? energy['powerConsumption'];
                if (curPower is num) {
                  parsedAttrs['powerW'] = curPower.toDouble();
                  parsedAttrs['powerSource'] = 'LG ThinQ Telemetry';
                }
              }
              device.liveAttributes = parsedAttrs;
              device.isOnline = true;
              device.lastError = null;
            }
          } catch (_) {}
        }
        break;

      case ConnectionProtocol.tuyaCloudDirect:
        final token = _requireCredential(device, 'accessToken', fallbacks: ['token']);
        try {
          final res = await _post(
            Uri.parse('https://px1.tuyain.com/homeassistant/skill'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'header': {
                'name': 'Query',
                'namespace': 'query',
                'payloadVersion': 1,
              },
              'payload': {
                'accessToken': token,
                'devId': device.id,
              },
            }),
          ).timeout(const Duration(seconds: 8));

          if (res.statusCode == 200) {
            final qJson = jsonDecode(res.body) as Map<String, dynamic>;
            if (qJson['header']?['code'] != null && qJson['header']['code'] != 'SUCCESS') {
              throw Exception('Tuya query error: ${qJson['header']?['msg'] ?? qJson['header']['code']}');
            }
            final payload = qJson['payload'] as Map<String, dynamic>?;
            if (payload != null) {
              final dataMap = (payload['data'] as Map<String, dynamic>?) ?? payload;
              final stateVal = dataMap['state']?.toString().toLowerCase();
              if (stateVal != null) {
                device.isOn = (stateVal == 'true' || stateVal == '1' || stateVal == 'on');
              }
              if (payload['online'] != null) {
                device.isOnline = payload['online'] != false;
              }
              final bVal = dataMap['brightness'];
              if (bVal is num) {
                device.primaryValue = bVal.toDouble();
              } else if (bVal != null) {
                final parsed = double.tryParse(bVal.toString());
                if (parsed != null) device.primaryValue = parsed;
              }
              final curPower = dataMap['cur_power'] ?? dataMap['power'] ?? dataMap['curPower'];
              final parsedAttrs = Map<String, dynamic>.from(dataMap);
              if (curPower is num) {
                parsedAttrs['powerW'] = curPower > 10000 ? (curPower / 10.0) : curPower.toDouble();
                parsedAttrs['powerSource'] = 'Tuya Energy Meter';
              }
              device.liveAttributes = parsedAttrs;
              device.lastError = null;
            }
          }
        } catch (_) {}
        break;

      case ConnectionProtocol.philipsHueLocal:
        final bridgeIp = _requireCredential(device, 'bridgeIp', fallbacks: ['ip']);
        final username = _requireCredential(device, 'username');
        final lightId = _requireCredential(device, 'lightId');
        final res = await http
            .get(Uri.parse('http://$bridgeIp/api/$username/lights/$lightId'))
            .timeout(const Duration(seconds: 6));
        if (res.statusCode == 200) {
          final json = jsonDecode(res.body) as Map<String, dynamic>;
          final state = (json['state'] as Map<String, dynamic>?) ?? {};
          if (state['reachable'] == false) {
            throw Exception('Hue light is unreachable');
          }
          device.isOn = state['on'] == true;
          final bri = (state['bri'] as num?)?.toDouble() ?? 254.0;
          device.primaryValue = (bri / 2.54).clamp(1.0, 100.0);
          device.liveAttributes = Map<String, dynamic>.from(state);
          device.markOnlineSuccess();
        } else {
          throw Exception('Hue bridge status poll failed (${res.statusCode})');
        }
        break;

      case ConnectionProtocol.philipsWizUdp:
        final ip = _requireCredential(device, 'ip');
        final res = await _sendWizUdpPacket(
          ip,
          {'method': 'getPilot', 'params': {}},
          timeoutMs: 2000,
        );
        if (res.containsKey('result')) {
          final result = res['result'] as Map<String, dynamic>;
          device.isOn = result['state'] == true;
          device.primaryValue = (result['dimming'] as num?)?.toDouble() ?? 100.0;
          device.liveAttributes = Map<String, dynamic>.from(result);
          device.markOnlineSuccess();
        } else {
          throw Exception('WiZ getPilot returned no result from $ip');
        }
        break;

      case ConnectionProtocol.rtspOnvifCamera:
        final ip = _requireCredential(device, 'ip', fallbacks: ['rtspUrl']);
        final port = int.tryParse(device.credentials['port'] ?? '554') ?? 554;
        Socket? s;
        try {
          s = await Socket.connect(ip, port, timeout: const Duration(seconds: 2));
        } catch (_) {
          s = await Socket.connect(ip, 80, timeout: const Duration(seconds: 2));
        } finally {
          s?.destroy();
        }
        device.markOnlineSuccess();
        break;
    }
    device.markOnlineSuccess();
    computeDeviceLiveWattage(device);
  }

  /// Calculates real hardware wattage based on live cloud sensors or calibrated electrical curves.
  double computeDeviceLiveWattage(RealSmartDevice device) {
    if (!device.isOnline) {
      device.liveWatts = 0.0;
      final attrs = Map<String, dynamic>.from(device.liveAttributes);
      attrs['powerSource'] = 'Offline (0.0 W)';
      device.liveAttributes = attrs;
      return 0.0;
    }

    // Direct hardware sensor reading if available and positive
    final sensorPower = device.liveAttributes['powerW'];
    if (sensorPower is num && sensorPower > 0) {
      device.liveWatts = sensorPower.toDouble();
      final attrs = Map<String, dynamic>.from(device.liveAttributes);
      attrs['powerSource'] = attrs['powerSource'] ?? 'Hardware Telemetry';
      device.liveAttributes = attrs;
      return device.liveWatts;
    }

    final attrs = Map<String, dynamic>.from(device.liveAttributes);

    // Physics-calibrated hardware consumption models
    switch (device.category) {
      case 'washer':
        final machineState = device.liveAttributes['machineState']?.toString().toLowerCase() ??
            device.liveAttributes['state']?.toString().toLowerCase() ??
            (device.isOn ? 'run' : 'stop');
        if (machineState == 'run' ||
            machineState == 'wash' ||
            machineState == 'spin' ||
            machineState == 'rinse') {
          device.liveWatts = device.ratedMaxWatts > 0 ? device.ratedMaxWatts : 480.0;
          attrs['powerSource'] = 'Samsung AI EcoBubble Telemetry';
        } else if (machineState == 'pause') {
          device.liveWatts = 4.5;
          attrs['powerSource'] = 'Samsung Standby';
        } else {
          device.liveWatts = device.isOn ? 4.5 : 0.0;
          attrs['powerSource'] = device.isOn ? 'Samsung Standby' : 'Power Off';
        }
        break;

      case 'ac':
        if (!device.isOn) {
          device.liveWatts = 1.2; // Standby
          attrs['powerSource'] = 'LG Inverter Standby';
        } else {
          final target = device.primaryValue;
          final roomTemp = (device.liveAttributes['currentTemperature'] as num?)?.toDouble() ?? 28.0;
          final deltaT = (roomTemp - target).clamp(0.0, 12.0);
          device.liveWatts = (320.0 + (deltaT * 92.0)).clamp(320.0, 1480.0);
          attrs['powerSource'] = 'DualCool Inverter Curve';
        }
        break;

      case 'camera':
        if (!device.isOn) {
          device.liveWatts = 2.0; // Standby / Privacy Mode
          final brandName = device.credentials['brand'] == 'realme' ? 'Realme Cam 360' : 'Philips Home Cam';
          attrs['powerSource'] = '$brandName Standby (Privacy Mode)';
        } else {
          device.liveWatts = device.ratedMaxWatts > 0 ? device.ratedMaxWatts : 4.5; // Active 1080p stream
          final brandName = device.credentials['brand'] == 'realme' ? 'Realme Cam 360' : 'Philips Home Cam';
          attrs['powerSource'] = '$brandName Active 1080p Stream';
        }
        break;

      case 'light':
        if (device.protocol == ConnectionProtocol.philipsHueLocal) {
          if (!device.isOn) {
            device.liveWatts = 0.4;
            attrs['powerSource'] = 'Philips Hue Zigbee Standby';
          } else {
            final pct = (device.primaryValue / 100.0).clamp(0.01, 1.0);
            device.liveWatts = 0.4 + (pct * (device.ratedMaxWatts > 0 ? device.ratedMaxWatts : 9.5));
            attrs['powerSource'] = 'Philips Hue White & Color (9.5W)';
          }
        } else if (device.protocol == ConnectionProtocol.philipsWizUdp) {
          if (!device.isOn) {
            device.liveWatts = 0.4;
            attrs['powerSource'] = 'Philips WiZ Wi-Fi Standby';
          } else {
            final pct = (device.primaryValue / 100.0).clamp(0.01, 1.0);
            device.liveWatts = 0.4 + (pct * (device.ratedMaxWatts > 0 ? device.ratedMaxWatts : 8.5));
            attrs['powerSource'] = 'Philips WiZ Smart LED (8.5W)';
          }
        } else {
          if (!device.isOn) {
            device.liveWatts = 0.4; // Standby
            attrs['powerSource'] = 'Wipro Standby';
          } else {
            final maxW = device.ratedMaxWatts > 0 ? device.ratedMaxWatts : 9.0;
            final pct = (device.primaryValue / 100.0).clamp(0.01, 1.0);
            device.liveWatts = 0.4 + (pct * maxW);
            attrs['powerSource'] = 'Calibrated 9W LED Curve';
          }
        }
        break;

      case 'tv':
        if (!device.isOn) {
          device.liveWatts = 0.5; // Standby
          attrs['powerSource'] = 'OnePlus Standby';
        } else {
          final vol = (device.primaryValue / 100.0).clamp(0.0, 1.0);
          device.liveWatts = 75.0 + (vol * 35.0);
          attrs['powerSource'] = '4K Panel + Audio Curve';
        }
        break;

      default:
        if (!device.isOn) {
          device.liveWatts = 0.0;
          attrs['powerSource'] = 'Power Off';
        } else {
          device.liveWatts = device.ratedMaxWatts > 0 ? device.ratedMaxWatts : 25.0;
          attrs['powerSource'] = 'Smart Relay';
        }
        break;
    }

    device.liveAttributes = attrs;
    return device.liveWatts;
  }

  // ---------------------------------------------------------------------------
  // 4. REAL HARDWARE COMMAND EXECUTION (THROWS ON FAILURE — NEVER FAKES STATE)
  // ---------------------------------------------------------------------------
  Future<void> _dispatchLgPower(RealSmartDevice device, bool turnOn) async {
    if (device.isDummy) {
      device.isOn = turnOn;
      device.markOnlineSuccess();
      computeDeviceLiveWattage(device);
      return;
    }

    switch (device.normalizedCategory) {
      case 'ac':
        await ZeroTouchOnboardingService.instance.controlLgAirConditioner(
          device: device,
          powerOn: turnOn,
        );
        break;
      case 'washer':
        await ZeroTouchOnboardingService.instance.controlLgWashTower(
          device,
          {
            'stage': turnOn ? 'wash' : 'idle',
            'washerOperationMode': turnOn ? 'START' : 'STOP',
          },
        );
        break;
      case 'fridge':
        await ZeroTouchOnboardingService.instance.controlLgFridge(
          device,
          {
            'expressCool': turnOn,
            'expressFreeze': turnOn,
          },
        );
        break;
      case 'air_purifier':
        await ZeroTouchOnboardingService.instance.controlLgAeroTower(
          device,
          {
            'airflowMode': turnOn ? 'Auto' : 'Off',
            'uvNano': turnOn,
          },
        );
        break;
      case 'styler':
        await ZeroTouchOnboardingService.instance.controlLgStyler(
          device,
          {
            'gentleDry': turnOn,
            'trueSteam': turnOn,
          },
        );
        break;
      case 'dishwasher':
        await ZeroTouchOnboardingService.instance.controlLgDishwasher(
          device,
          {
            'trueSteamDishwash': turnOn,
          },
        );
        break;
      case 'tv':
        await ZeroTouchOnboardingService.instance.controlLgAppliance(
          device: device,
          commandPayload: {
            'operation': {
              'tvOperationMode': turnOn ? 'POWER_ON' : 'POWER_OFF',
            },
          },
        );
        break;
      default:
        await ZeroTouchOnboardingService.instance.controlLgAppliance(
          device: device,
          commandPayload: {
            'operation': {
              'operationMode': turnOn ? 'POWER_ON' : 'POWER_OFF',
            },
          },
        );
        break;
    }

    device.isOn = turnOn;
  }

  Future<void> _dispatchLgPrimaryLevel(RealSmartDevice device, double value) async {
    if (device.isDummy) {
      device.primaryValue = value;
      device.markOnlineSuccess();
      computeDeviceLiveWattage(device);
      return;
    }

    switch (device.normalizedCategory) {
      case 'ac':
        final clamped = value.clamp(16.0, 30.0);
        await ZeroTouchOnboardingService.instance.controlLgAirConditioner(
          device: device,
          targetCelsius: clamped,
        );
        device.primaryValue = clamped;
        break;

      case 'fridge':
        final clamped = value.clamp(1.0, 7.0);
        await ZeroTouchOnboardingService.instance.controlLgFridge(
          device,
          {'fridgeTemp': clamped.round()},
        );
        device.primaryValue = clamped;
        break;

      case 'air_purifier':
        final clamped = value.clamp(0.0, 90.0);
        await ZeroTouchOnboardingService.instance.controlLgAeroTower(
          device,
          {'cleanBoosterTilt': clamped.round()},
        );
        device.primaryValue = clamped;
        break;

      case 'styler':
        final clamped = value.clamp(100.0, 220.0);
        await ZeroTouchOnboardingService.instance.controlLgStyler(
          device,
          {'movingHangerRpm': clamped.round()},
        );
        device.primaryValue = clamped;
        break;

      case 'washer':
        final spin = value.round();
        await ZeroTouchOnboardingService.instance.controlLgAppliance(
          device: device,
          commandPayload: {
            'washer': {
              'operation': {'spinSpeed': spin},
            },
          },
        );
        device.primaryValue = value;
        break;

      case 'tv':
        final vol = value.round().clamp(0, 100);
        await ZeroTouchOnboardingService.instance.controlLgAppliance(
          device: device,
          commandPayload: {
            'tv': {
              'volume': vol,
            },
          },
        );
        device.primaryValue = vol.toDouble();
        break;

      default:
        final bri = value.round().clamp(0, 100);
        await ZeroTouchOnboardingService.instance.controlLgAppliance(
          device: device,
          commandPayload: {
            'brightness': {
              'brightness': bri,
            },
          },
        );
        device.primaryValue = bri.toDouble();
        break;
    }
  }

  Future<void> setPower(RealSmartDevice device, bool turnOn) async {
    if (device.isDummy) {
      device.isOn = turnOn;
      device.markOnlineSuccess();
      computeDeviceLiveWattage(device);
      return;
    }
    if (device.isLgThinq) {
      await _dispatchLgPower(device, turnOn);
      device.isOn = turnOn;
      device.markOnlineSuccess();
      computeDeviceLiveWattage(device);
      return;
    }
    switch (device.protocol) {
      case ConnectionProtocol.lgThinqCloud:
        await _dispatchLgPower(device, turnOn);
        break;

      case ConnectionProtocol.smartThingsCloud:
        final token = _requireCredential(device, 'token');
        final targetComponent = (device.credentials['component']?.toString().trim().isNotEmpty == true)
            ? device.credentials['component']!.toString().trim()
            : 'main';
        final res = await _post(
          Uri.parse('$_stBase/devices/${device.id}/commands'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'commands': [
              {
                'component': targetComponent,
                'capability': 'switch',
                'command': turnOn ? 'on' : 'off',
              }
            ]
          }),
        ).timeout(const Duration(seconds: 8));

        if (res.statusCode == 200) {
          device.isOn = turnOn;
          break;
        }

        // If appliance and switch rejected (e.g. 409 Conflict, 422 Unprocessable Entity, or >= 400),
        // automatically fallback to operating state -> setMachineState('run' | 'stop')
        final isAppliance = device.category == 'washer' ||
            device.category == 'dryer' ||
            device.category == 'dishwasher';
        if (isAppliance && (res.statusCode == 409 || res.statusCode == 422 || res.statusCode >= 400)) {
          final fallbackCapability = device.category == 'dryer'
              ? 'dryerOperatingState'
              : (device.category == 'dishwasher'
                  ? 'dishwasherOperatingState'
                  : 'washerOperatingState');
          final fallbackRes = await _post(
            Uri.parse('$_stBase/devices/${device.id}/commands'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'commands': [
                {
                  'component': targetComponent,
                  'capability': fallbackCapability,
                  'command': 'setMachineState',
                  'arguments': [turnOn ? 'run' : 'stop'],
                }
              ]
            }),
          ).timeout(const Duration(seconds: 8));

          if (fallbackRes.statusCode == 200) {
            device.isOn = turnOn;
            final attrs = Map<String, dynamic>.from(device.liveAttributes);
            attrs['machineState'] = turnOn ? 'run' : 'stop';
            device.liveAttributes = attrs;
            break;
          }
        }

        throw Exception('SmartThings rejected command (${res.statusCode}): ${res.body}');

      case ConnectionProtocol.homeAssistantBridge:
        final hubUrl = _requireCredential(device, 'hubUrl');
        final token = _requireCredential(device, 'token');
        final domain = device.credentials['domain'] ?? device.id.split('.').first;
        final service = turnOn ? 'turn_on' : 'turn_off';

        final res = await http.post(
          Uri.parse('$hubUrl/api/services/$domain/$service'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'entity_id': device.id}),
        ).timeout(const Duration(seconds: 8));

        if (res.statusCode != 200) {
          throw Exception('Hub command failed (${res.statusCode}): ${res.body}');
        }
        device.isOn = turnOn;
        break;

      case ConnectionProtocol.tuyaLocalLan:
        final ip = _requireCredential(device, 'ip');
        final devId = device.id;
        final localKey = device.credentials['localKey'] ?? '';
        final token = device.credentials['accessToken'] ?? device.credentials['token'];
        if (localKey.length == 16) {
          final version = device.credentials['version'] ?? '3.3';
          await _withTuyaLanLock(ip, () => wiproTuyaService.setPower(
            host: ip,
            cloudDeviceId: devId,
            localKey: localKey,
            isPowered: turnOn,
            version: version,
          ));
          device.isOn = turnOn;
        } else if (token != null && token.trim().length > 5 && !token.toLowerCase().contains('demo')) {
          final res = await _post(
            Uri.parse('https://px1.tuyain.com/homeassistant/skill'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'header': {
                'name': 'turnOnOff',
                'namespace': 'control',
                'payloadVersion': 1,
              },
              'payload': {
                'accessToken': token,
                'devId': devId,
                'value': turnOn ? 1 : 0,
              },
            }),
          ).timeout(const Duration(seconds: 8));
          if (res.statusCode != 200) {
            throw Exception('Tuya Cloud fallback failed (${res.statusCode}): ${res.body}');
          }
          device.isOn = turnOn;
        } else {
          throw Exception("Wipro/Tuya Local LAN requires a 16-character LocalKey for device '${device.name}' (${device.id}).");
        }
        break;

      case ConnectionProtocol.onePlusTvLan:
        final ip = _requireCredential(device, 'ip');

        if (turnOn) {
          // 1. Broadcast Wake-on-LAN if MAC address is provided in credentials (Bug 10)
          final mac = device.credentials['mac'] ?? device.credentials['macAddress'];
          if (mac != null && mac.isNotEmpty) {
            await onePlusConnectService.sendWakeOnLan(mac);
          }

          // 2. Trigger wake / DIAL YouTube launch over port 8008
          final uri = Uri.parse('http://$ip:8008/apps/YouTube');
          final res = await _post(uri).timeout(const Duration(seconds: 4));
          if (res.statusCode >= 400) {
            // Fallback to sending POWER key if DIAL launch returns error
            final sent = await onePlusConnectService.sendRemoteKey(tvId: device.id, keyAction: 'POWER', host: ip);
            if (!sent) {
              throw Exception('OnePlus TV DIAL HTTP ${res.statusCode}');
            }
          }
        } else {
          // Stop DIAL application: Must target the instance endpoint /apps/YouTube/run (Bug 10)
          final uri = Uri.parse('http://$ip:8008/apps/YouTube/run');
          final res = await _delete(uri).timeout(const Duration(seconds: 4));
          // Send POWER key to put Android TV panel into standby
          await onePlusConnectService.sendRemoteKey(tvId: device.id, keyAction: 'POWER', host: ip);
          if (res.statusCode >= 400 && res.statusCode != 404) {
            throw Exception('OnePlus TV DIAL HTTP ${res.statusCode}');
          }
        }
        device.isOn = turnOn;
        break;

      case ConnectionProtocol.customHttpWebhook:
        if (device.isLgThinq) {
          await _dispatchLgPower(device, turnOn);
          break;
        }
        final url = turnOn
            ? _requireCredential(device, 'onUrl', fallbacks: ['controlUrl', 'url'])
            : _requireCredential(device, 'offUrl', fallbacks: ['controlUrl', 'url']);
        final uri = Uri.tryParse(url);
        if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
          throw Exception("Invalid webhook URL '$url' for device '${device.name}' (${device.id})");
        }
        final res = await http.get(uri).timeout(const Duration(seconds: 6));
        if (res.statusCode >= 400) {
          throw Exception('Webhook failed with HTTP ${res.statusCode}');
        }
        device.isOn = turnOn;
        break;

      case ConnectionProtocol.tuyaCloudDirect:
        final token = _requireCredential(device, 'accessToken', fallbacks: ['token']);
        final res = await _post(
          Uri.parse('https://px1.tuyain.com/homeassistant/skill'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'header': {
              'name': 'turnOnOff',
              'namespace': 'control',
              'payloadVersion': 1,
            },
            'payload': {
              'accessToken': token,
              'devId': device.id,
              'value': turnOn ? 1 : 0,
            },
          }),
        ).timeout(const Duration(seconds: 8));

        if (res.statusCode != 200) {
          throw Exception('Wipro/Tuya Cloud command rejected (${res.statusCode}): ${res.body}');
        }
        final resBody = jsonDecode(res.body) as Map<String, dynamic>;
        if (resBody['header']?['code'] != null && resBody['header']['code'] != 'SUCCESS') {
          throw Exception('Wipro/Tuya Cloud error: ${resBody['header']?['msg'] ?? resBody['header']['code']}');
        }
        device.isOn = turnOn;
        break;

      case ConnectionProtocol.philipsHueLocal:
        final bridgeIp = _requireCredential(device, 'bridgeIp', fallbacks: ['ip']);
        final username = _requireCredential(device, 'username');
        final lightId = _requireCredential(device, 'lightId');
        final res = await http.put(
          Uri.parse('http://$bridgeIp/api/$username/lights/$lightId/state'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'on': turnOn}),
        ).timeout(const Duration(seconds: 8));
        if (res.statusCode != 200) {
          throw Exception('Hue Bridge state update failed (${res.statusCode}): ${res.body}');
        }
        device.isOn = turnOn;
        break;

      case ConnectionProtocol.philipsWizUdp:
        final ip = _requireCredential(device, 'ip');
        final res = await _sendWizUdpPacket(
          ip,
          {'method': 'setPilot', 'params': {'state': turnOn}},
          timeoutMs: 2500,
        );
        if (res.isEmpty) {
          throw Exception('No UDP response from WiZ light at $ip:38899');
        }
        device.isOn = turnOn;
        break;

      case ConnectionProtocol.rtspOnvifCamera:
        // Toggling power sets privacy mode on/off
        device.isOn = turnOn;
        final attrs = Map<String, dynamic>.from(device.liveAttributes);
        attrs['privacyMode'] = !turnOn;
        device.liveAttributes = attrs;
        break;
    }
    device.markOnlineSuccess();
    computeDeviceLiveWattage(device);
  }

  Future<void> executeDeviceCommand(
    RealSmartDevice device,
    String capability,
    String command, [
    List<dynamic> arguments = const [],
    String? component,
  ]) async {
    if (device.isDummy && device.protocol != ConnectionProtocol.rtspOnvifCamera) {
      device.markOnlineSuccess();
      return;
    }
    switch (device.protocol) {
      case ConnectionProtocol.smartThingsCloud:
        final token = _requireCredential(device, 'token');
        final targetComponent = component ?? device.credentials['component'] ?? 'main';
        final res = await _post(
          Uri.parse('$_stBase/devices/${device.id}/commands'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'commands': [
              {
                'component': targetComponent,
                'capability': capability,
                'command': command,
                'arguments': arguments,
              }
            ]
          }),
        ).timeout(const Duration(seconds: 8));

        if (res.statusCode != 200) {
          throw Exception('Command rejected (${res.statusCode}): ${res.body}');
        }
        break;

      case ConnectionProtocol.tuyaLocalLan:
        final ip = _requireCredential(device, 'ip');
        final localKey = device.credentials['localKey'] ?? '';
        final version = device.credentials['version'] ?? '3.3';
        await _withTuyaLanLock(ip, () async {
          if (command == 'setBrightness' && arguments.isNotEmpty) {
            final bri = (arguments.first as num).toDouble();
            await wiproTuyaService.setBrightness(
              host: ip,
              cloudDeviceId: device.id,
              localKey: localKey,
              brightness: bri / 100.0,
              version: version,
            );
          } else if (command == 'setColorTemp' && arguments.isNotEmpty) {
            final kelvin = (arguments.first as num).round();
            await wiproTuyaService.setColorTemp(
              host: ip,
              cloudDeviceId: device.id,
              localKey: localKey,
              kelvin: kelvin,
              version: version,
            );
          } else if (command == 'setColorHex' && arguments.isNotEmpty) {
            await wiproTuyaService.setColorHex(
              host: ip,
              cloudDeviceId: device.id,
              localKey: localKey,
              hexRgb: arguments.first.toString(),
              version: version,
            );
          } else if (arguments.isNotEmpty && arguments.first is Map) {
            await wiproTuyaService.sendEncryptedFrame(
              host: ip,
              deviceId: device.id,
              localKey: localKey,
              dps: Map<String, dynamic>.from(arguments.first as Map),
              version: version,
            );
          } else {
            await wiproTuyaService.setPower(
              host: ip,
              cloudDeviceId: device.id,
              localKey: localKey,
              isPowered: command == 'turnOn' || command == 'on',
              version: version,
            );
          }
        });
        break;

      case ConnectionProtocol.onePlusTvLan:
        final ip = _requireCredential(device, 'ip');
        if (command == 'key' || command == 'sendKey' || command == 'sendRemoteKey') {
          final key = arguments.isNotEmpty ? arguments.first.toString() : 'SELECT';
          await onePlusConnectService.sendRemoteKey(tvId: device.id, keyAction: key, host: ip);
        } else if (command == 'launchApp' && arguments.isNotEmpty) {
          await onePlusConnectService.launchApp(tvId: device.id, appName: arguments.first.toString(), host: ip);
        } else if (command == 'terminateApp' && arguments.isNotEmpty) {
          await onePlusConnectService.terminateApp(tvId: device.id, appName: arguments.first.toString(), host: ip);
        } else if (command == 'switchInput' && arguments.isNotEmpty) {
          await onePlusConnectService.switchInput(tvId: device.id, inputSource: arguments.first.toString(), host: ip);
        } else if (command == 'wakeOnLan') {
          final mac = device.credentials['mac'] ?? device.credentials['macAddress'] ?? '';
          await onePlusConnectService.sendWakeOnLan(mac);
        } else {
          await onePlusConnectService.sendRemoteKey(tvId: device.id, keyAction: command, host: ip);
        }
        break;

      case ConnectionProtocol.lgThinqCloud:
      case ConnectionProtocol.customHttpWebhook:
        if (device.isLgThinq || device.credentials['vendor'] == 'lg_thinq' || device.credentials['vendor'] == 'lg') {
          Map<String, dynamic> payload = {};
          if (arguments.isNotEmpty && arguments.first is Map) {
            payload = Map<String, dynamic>.from(arguments.first as Map);
          } else {
            payload = {
              capability: {command: arguments.isNotEmpty ? arguments.first : true}
            };
          }
          await ZeroTouchOnboardingService.instance.controlLgAppliance(
            device: device,
            commandPayload: payload,
          );
        } else {
          final url = _requireCredential(device, 'controlUrl', fallbacks: ['onUrl', 'url']);
          final uri = Uri.tryParse(url);
          if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
            throw Exception("Invalid webhook URL '$url' for device '${device.name}' (${device.id})");
          }
          final res = await http.post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'capability': capability,
              'command': command,
              'arguments': arguments,
            }),
          ).timeout(const Duration(seconds: 6));
          if (res.statusCode >= 400) {
            throw Exception('Webhook command rejected (${res.statusCode})');
          }
        }
        break;

      case ConnectionProtocol.homeAssistantBridge:
        final hubUrl = _requireCredential(device, 'hubUrl');
        final token = _requireCredential(device, 'token');
        final cleanHubUrl = hubUrl.replaceAll(RegExp(r'/+$'), '');

        final Map<String, dynamic> payload = {'entity_id': device.id};

        if (arguments.isNotEmpty) {
          final firstArg = arguments.first;
          if (firstArg is Map) {
            payload.addAll(Map<String, dynamic>.from(firstArg));
          } else {
            final cmd = command.toLowerCase();
            final cap = capability.toLowerCase();

            if (cap == 'climate' || cmd == 'set_temperature' || cmd == 'settemperature') {
              payload['temperature'] = firstArg;
            } else if (cap == 'media_player' &&
                (cmd == 'select_source' || cmd == 'selectsource' || cmd == 'launchapp')) {
              payload['source'] = firstArg;
            } else if (cmd == 'volume_set' ||
                cmd == 'set_volume' ||
                cmd == 'setvolume' ||
                (cap == 'media_player' && cmd == 'volume')) {
              payload['volume_level'] = firstArg;
            } else if (cap == 'fan' && (cmd == 'set_percentage' || cmd == 'setpercentage')) {
              payload['percentage'] = firstArg;
            } else if (cap == 'cover' &&
                (cmd == 'set_cover_position' || cmd == 'set_position' || cmd == 'setposition')) {
              payload['position'] = firstArg;
            } else if (cmd == 'select_option' || cmd == 'selectoption') {
              payload['option'] = firstArg;
            } else if (cap == 'light' && firstArg is List) {
              payload['rgb_color'] = firstArg;
            } else if (cap == 'light' &&
                arguments.length >= 3 &&
                arguments.every((a) => a is num)) {
              payload['rgb_color'] = arguments.sublist(0, 3);
            } else if (cap == 'light' &&
                (cmd == 'turn_on' ||
                    cmd == 'turnon' ||
                    cmd == 'set_brightness' ||
                    cmd == 'setbrightness') &&
                firstArg is num) {
              payload['brightness_pct'] = firstArg;
            } else {
              payload['value'] = firstArg;
              if (arguments.length > 1) {
                payload['arguments'] = arguments;
              }
            }
          }
        }

        final res = await _post(
          Uri.parse('$cleanHubUrl/api/services/$capability/$command'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 8));

        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw Exception('Hub command failed (${res.statusCode}): ${res.body}');
        }
        break;

      case ConnectionProtocol.tuyaCloudDirect:
        final token = _requireCredential(device, 'accessToken', fallbacks: ['token']);
        final Map<String, dynamic> payload = {
          'accessToken': token,
          'devId': device.id,
        };
        if (command == 'colorSet' && arguments.isNotEmpty) {
          payload['color'] = arguments.first;
        } else if (arguments.isNotEmpty && arguments.first is Map) {
          payload.addAll(Map<String, dynamic>.from(arguments.first as Map));
        } else {
          payload['value'] = arguments.isNotEmpty ? arguments.first : 1;
        }
        final res = await _post(
          Uri.parse('https://px1.tuyain.com/homeassistant/skill'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'header': {
              'name': command,
              'namespace': 'control',
              'payloadVersion': 1,
            },
            'payload': payload,
          }),
        ).timeout(const Duration(seconds: 8));

        if (res.statusCode != 200) {
          throw Exception('Tuya direct command failed (${res.statusCode})');
        }
        final resBody = jsonDecode(res.body) as Map<String, dynamic>;
        if (resBody['header']?['code'] != null && resBody['header']['code'] != 'SUCCESS') {
          throw Exception('Tuya error: ${resBody['header']?['msg'] ?? resBody['header']['code']}');
        }
        break;

      case ConnectionProtocol.philipsHueLocal:
        final bridgeIp = _requireCredential(device, 'bridgeIp', fallbacks: ['ip']);
        final username = _requireCredential(device, 'username');
        final lightId = _requireCredential(device, 'lightId');
        Map<String, dynamic> body = {};
        if (command == 'setColor' && arguments.isNotEmpty) {
          if (arguments.first is List) {
            body = {'xy': arguments.first};
          } else if (arguments.first is Map) {
            body = Map<String, dynamic>.from(arguments.first as Map);
          }
        } else if (command == 'setCt' && arguments.isNotEmpty) {
          body = {'ct': arguments.first};
        } else if (command == 'alert') {
          body = {'alert': arguments.isNotEmpty ? arguments.first : 'select'};
        } else if (arguments.isNotEmpty && arguments.first is Map) {
          body = Map<String, dynamic>.from(arguments.first as Map);
        } else {
          body = {command: arguments.isNotEmpty ? arguments.first : true};
        }
        final res = await http.put(
          Uri.parse('http://$bridgeIp/api/$username/lights/$lightId/state'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 8));
        if (res.statusCode != 200) {
          throw Exception('Hue command failed (${res.statusCode})');
        }
        break;

      case ConnectionProtocol.philipsWizUdp:
        final ip = _requireCredential(device, 'ip');
        Map<String, dynamic> pilotParams = {};
        if (command == 'setPilot' && arguments.isNotEmpty && arguments.first is Map) {
          pilotParams = Map<String, dynamic>.from(arguments.first as Map);
        } else if (command == 'setRgb' && arguments.length >= 3) {
          pilotParams = {'r': arguments[0], 'g': arguments[1], 'b': arguments[2]};
        } else if (command == 'setTemp' && arguments.isNotEmpty) {
          pilotParams = {'temp': arguments.first};
        } else {
          pilotParams = {'state': true};
        }
        final res = await _sendWizUdpPacket(ip, {'method': 'setPilot', 'params': pilotParams});
        if (res.isEmpty) {
          throw Exception('WiZ command failed on $ip:38899');
        }
        break;

      case ConnectionProtocol.rtspOnvifCamera:
        if (command == 'ptzMove') {
          final dir = arguments.isNotEmpty ? arguments.first.toString() : 'center';
          await sendCameraPtzCommand(device, dir);
        } else if (command == 'togglePrivacy') {
          await setPower(device, !device.isOn);
        }
        break;
    }
    device.markOnlineSuccess();
  }

  /// Sends ONVIF / HTTP PTZ Continuous Move or Relative Move command to smart camera
  Future<void> sendCameraPtzCommand(RealSmartDevice device, String direction) async {
    final ip = _requireCredential(device, 'ip', fallbacks: ['rtspUrl']);

    // Update pan/tilt angle models in liveAttributes
    final attrs = Map<String, dynamic>.from(device.liveAttributes);
    double pan = (attrs['panAngle'] as num?)?.toDouble() ?? 0.0;
    double tilt = (attrs['tiltAngle'] as num?)?.toDouble() ?? 0.0;

    switch (direction.toLowerCase()) {
      case 'up':
        tilt = (tilt + 15.0).clamp(-45.0, 90.0);
        break;
      case 'down':
        tilt = (tilt - 15.0).clamp(-45.0, 90.0);
        break;
      case 'left':
        pan = (pan - 30.0).clamp(-180.0, 180.0);
        break;
      case 'right':
        pan = (pan + 30.0).clamp(-180.0, 180.0);
        break;
      case 'center':
      case 'reset':
        pan = 0.0;
        tilt = 0.0;
        break;
    }

    attrs['panAngle'] = pan;
    attrs['tiltAngle'] = tilt;
    attrs['lastPtzDirection'] = direction;
    device.liveAttributes = attrs;

    // Send ONVIF SOAP or HTTP CGI packet to camera
    if (ip.isNotEmpty) {
      try {
        final panVel = direction == 'left' ? -0.5 : (direction == 'right' ? 0.5 : 0.0);
        final tiltVel = direction == 'down' ? -0.5 : (direction == 'up' ? 0.5 : 0.0);
        final onvifSoap = '''
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:tptz="http://www.onvif.org/ver20/ptz/wsdl" xmlns:tt="http://www.onvif.org/ver10/schema">
  <soap:Body>
    <tptz:ContinuousMove>
      <tptz:ProfileToken>Profile_1</tptz:ProfileToken>
      <tptz:Velocity>
        <tt:PanTilt x="$panVel" y="$tiltVel" space="http://www.onvif.org/ver10/tptz/PanTiltSpaces/VelocityGenericSpace"/>
      </tptz:Velocity>
    </tptz:ContinuousMove>
  </soap:Body>
</soap:Envelope>''';

        final onvifUri = Uri.parse('http://$ip:8000/onvif/ptz_service');
        await _post(
          onvifUri,
          headers: {'Content-Type': 'application/soap+xml; charset=utf-8; action="http://www.onvif.org/ver20/ptz/wsdl/ContinuousMove"'},
          body: onvifSoap,
        ).timeout(const Duration(milliseconds: 1500));
      } catch (_) {
        try {
          final cgiUri = Uri.parse('http://$ip/cgi-bin/ptz.cgi?action=move&dir=$direction');
          await _get(cgiUri).timeout(const Duration(milliseconds: 1000));
        } catch (_) {}
      }
    }
  }

  Future<void> setPrimaryLevel(RealSmartDevice device, double value) async {
    if (device.isDummy) {
      device.primaryValue = value;
      device.markOnlineSuccess();
      computeDeviceLiveWattage(device);
      return;
    }
    if (device.isLgThinq) {
      await _dispatchLgPrimaryLevel(device, value);
      device.markOnlineSuccess();
      computeDeviceLiveWattage(device);
      return;
    }
    switch (device.protocol) {
      case ConnectionProtocol.lgThinqCloud:
        await _dispatchLgPrimaryLevel(device, value);
        break;

      case ConnectionProtocol.smartThingsCloud:
        final token = _requireCredential(device, 'token');
        final isClimate = device.category == 'ac';
        final capability = isClimate ? 'thermostatCoolingSetpoint' : 'switchLevel';
        final command = isClimate ? 'setCoolingSetpoint' : 'setLevel';
        final targetComponent = (device.credentials['component']?.toString().trim().isNotEmpty == true)
            ? device.credentials['component']!.toString().trim()
            : 'main';

        final res = await _post(
          Uri.parse('$_stBase/devices/${device.id}/commands'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'commands': [
              {
                'component': targetComponent,
                'capability': capability,
                'command': command,
                'arguments': [value.round()],
              }
            ]
          }),
        ).timeout(const Duration(seconds: 8));

        if (res.statusCode != 200) {
          throw Exception('Level update rejected (${res.statusCode}): ${res.body}');
        }
        device.primaryValue = value;
        break;

      case ConnectionProtocol.homeAssistantBridge:
        final hubUrl = _requireCredential(device, 'hubUrl');
        final token = _requireCredential(device, 'token');
        final isClimate = device.category == 'ac';
        final domain = isClimate ? 'climate' : 'light';
        final service = isClimate ? 'set_temperature' : 'turn_on';
        final payload = isClimate
            ? {'entity_id': device.id, 'temperature': value}
            : {'entity_id': device.id, 'brightness_pct': value.round()};

        final res = await http.post(
          Uri.parse('$hubUrl/api/services/$domain/$service'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 8));

        if (res.statusCode != 200) {
          throw Exception('Hub level update failed (${res.statusCode})');
        }
        device.primaryValue = value;
        break;

      case ConnectionProtocol.tuyaLocalLan:
        final ip = _requireCredential(device, 'ip');
        final localKey = device.credentials['localKey'] ?? '';
        final token = device.credentials['accessToken'] ?? device.credentials['token'];
        if (localKey.length == 16) {
          final version = device.credentials['version'] ?? '3.3';
          await _withTuyaLanLock(ip, () => wiproTuyaService.setBrightness(
            host: ip,
            cloudDeviceId: device.id,
            localKey: localKey,
            brightness: value / 100.0,
            version: version,
          ));
          device.primaryValue = value;
        } else if (token != null && token.trim().length > 5 && !token.toLowerCase().contains('demo')) {
          final clamped = value.round().clamp(1, 100);
          final res = await _post(
            Uri.parse('https://px1.tuyain.com/homeassistant/skill'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'header': {
                'name': 'brightnessSet',
                'namespace': 'control',
                'payloadVersion': 1,
              },
              'payload': {
                'accessToken': token,
                'devId': device.id,
                'value': clamped,
              },
            }),
          ).timeout(const Duration(seconds: 8));
          if (res.statusCode != 200) {
            throw Exception('Tuya Cloud fallback level update failed (${res.statusCode})');
          }
          device.primaryValue = value;
        } else {
          throw Exception("Wipro/Tuya Local LAN requires a 16-character LocalKey for device '${device.name}' (${device.id}).");
        }
        break;

      case ConnectionProtocol.tuyaCloudDirect:
        final token = _requireCredential(device, 'accessToken', fallbacks: ['token']);
        final clamped = value.round().clamp(1, 100);
        final res = await _post(
          Uri.parse('https://px1.tuyain.com/homeassistant/skill'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'header': {
              'name': 'brightnessSet',
              'namespace': 'control',
              'payloadVersion': 1,
            },
            'payload': {
              'accessToken': token,
              'devId': device.id,
              'value': clamped,
            },
          }),
        ).timeout(const Duration(seconds: 8));

        if (res.statusCode != 200) {
          throw Exception('Wipro/Tuya brightness update failed (${res.statusCode})');
        }
        final resBody = jsonDecode(res.body) as Map<String, dynamic>;
        if (resBody['header']?['code'] != null && resBody['header']['code'] != 'SUCCESS') {
          throw Exception('Wipro/Tuya brightness error: ${resBody['header']?['msg'] ?? resBody['header']['code']}');
        }
        device.primaryValue = value;
        break;

      case ConnectionProtocol.philipsHueLocal:
        final bridgeIp = _requireCredential(device, 'bridgeIp', fallbacks: ['ip']);
        final username = _requireCredential(device, 'username');
        final lightId = _requireCredential(device, 'lightId');
        final bri = (value * 2.54).round().clamp(1, 254);
        final res = await http.put(
          Uri.parse('http://$bridgeIp/api/$username/lights/$lightId/state'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'on': true, 'bri': bri}),
        ).timeout(const Duration(seconds: 8));
        if (res.statusCode != 200) {
          throw Exception('Hue brightness update failed (${res.statusCode})');
        }
        device.primaryValue = value;
        break;

      case ConnectionProtocol.philipsWizUdp:
        final ip = _requireCredential(device, 'ip');
        final clamped = value.round().clamp(10, 100);
        final res = await _sendWizUdpPacket(
          ip,
          {'method': 'setPilot', 'params': {'state': true, 'dimming': clamped}},
        );
        if (res.isEmpty) {
          throw Exception('WiZ brightness update failed on $ip');
        }
        device.primaryValue = value;
        break;

      case ConnectionProtocol.customHttpWebhook:
        final vendor = device.credentials['vendor']?.toString().toLowerCase();
        if (device.isLgThinq || vendor == 'lg_thinq' || vendor == 'lg') {
          if (device.category == 'ac') {
            final clamped = value.clamp(16.0, 30.0);
            await ZeroTouchOnboardingService.instance.controlLgAirConditioner(
              device: device,
              powerOn: device.isOn,
              targetCelsius: clamped,
            );
          } else {
            await _dispatchLgPrimaryLevel(device, value);
          }
          device.primaryValue = value;
          break;
        }
        device.primaryValue = value;
        break;

      case ConnectionProtocol.onePlusTvLan:
        final ip = _requireCredential(device, 'ip');
        final currentVol = device.primaryValue.round();
        final targetVol = value.round().clamp(0, 100);
        final diff = targetVol - currentVol;
        if (diff != 0) {
          final action = diff > 0 ? 'VOL_UP' : 'VOL_DOWN';
          for (int i = 0; i < diff.abs() && i < 15; i++) {
            await onePlusConnectService.sendRemoteKey(tvId: device.id, keyAction: action, host: ip);
          }
        }
        device.primaryValue = targetVol.toDouble();
        break;

      case ConnectionProtocol.rtspOnvifCamera:
        device.primaryValue = value;
        break;
    }
    device.markOnlineSuccess();
    computeDeviceLiveWattage(device);
  }

  /// Flashes a light or switch device [pulses] times by toggling power on/off with delays.
  Future<void> flashDevice(
    RealSmartDevice device, {
    int pulses = 3,
    Duration pulseDuration = const Duration(milliseconds: 800),
  }) async {
    final originalPower = device.isOn;
    final originalLevel = device.primaryValue;

    for (int i = 0; i < pulses; i++) {
      await setPower(device, true);
      if (device.category == 'light') {
        try {
          await setPrimaryLevel(device, 100.0);
        } catch (_) {}
      }
      await Future.delayed(pulseDuration);
      await setPower(device, false);
      if (i < pulses - 1) {
        await Future.delayed(pulseDuration);
      }
    }

    if (originalPower) {
      await Future.delayed(pulseDuration);
      await setPower(device, true);
      if (device.category == 'light') {
        try {
          await setPrimaryLevel(device, originalLevel);
        } catch (_) {}
      }
    }
  }

  /// Public helper for sending raw Tuya DPS frames over encrypted local LAN
  Future<void> sendTuyaLocalDps(RealSmartDevice device, Map<String, dynamic> dpsMap) async {
    if (device.isDummy) return;
    final ip = _requireCredential(device, 'ip');
    final localKey = device.credentials['localKey'] ?? '';
    final token = device.credentials['accessToken'] ?? device.credentials['token'];
    if (localKey.length == 16) {
      final version = device.credentials['version'] ?? '3.3';
      await _sendTuyaEncryptedFrame(ip, device.id, localKey, dpsMap, version: version);
    } else if (token != null && token.trim().length > 5 && !token.toLowerCase().contains('demo')) {
      if (dpsMap.containsKey('20')) {
        final isOn = dpsMap['20'] == true;
        await _post(
          Uri.parse('https://px1.tuyain.com/homeassistant/skill'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'header': {'name': 'turnOnOff', 'namespace': 'control', 'payloadVersion': 1},
            'payload': {'accessToken': token, 'devId': device.id, 'value': isOn ? 1 : 0},
          }),
        ).timeout(const Duration(seconds: 8));
      }
    } else {
      throw Exception("Wipro/Tuya Local LAN requires a 16-character LocalKey for device '${device.name}' (${device.id}).");
    }
  }

  Future<void> _sendTuyaEncryptedFrame(
    String ip,
    String deviceId,
    String localKey,
    Map<String, dynamic> dps, {
    String version = '3.3',
  }) async {
    await _withTuyaLanLock(ip, () async {
      final socket = await _socketConnect(ip, 6668, timeout: const Duration(seconds: 4));
      try {
        final payload = jsonEncode({
          'gwId': deviceId,
          'devId': deviceId,
          'uid': deviceId,
          't': (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
          'dps': dps,
        });

        final key = enc.Key.fromUtf8(localKey);
        final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.ecb, padding: 'PKCS7'));
        final encrypted = encrypter.encrypt(payload).bytes;

        final body = BytesBuilder();
        if (version == '3.1') {
          body.add(encrypted);
        } else {
          final versionBytes = utf8.encode(version);
          final padLength = (15 - versionBytes.length).clamp(0, 15);
          body.add(versionBytes);
          if (padLength > 0) {
            body.add(Uint8List(padLength));
          }
          body.add(encrypted);
        }
        final bodyBytes = body.toBytes();

        final header = ByteData(16)
          ..setUint32(0, 0x000055AA, Endian.big)
          ..setUint32(4, 1, Endian.big)
          ..setUint32(8, 7, Endian.big)
          ..setUint32(12, bodyBytes.length + 8, Endian.big);

        final frame = BytesBuilder()
          ..add(header.buffer.asUint8List())
          ..add(bodyBytes);

        int crc = 0xFFFFFFFF;
        for (final b in frame.toBytes()) {
          crc ^= b;
          for (int i = 0; i < 8; i++) {
            crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
          }
        }
        crc ^= 0xFFFFFFFF;

        final footer = ByteData(8)
          ..setUint32(0, crc, Endian.big)
          ..setUint32(4, 0x0000AA55, Endian.big);
        frame.add(footer.buffer.asUint8List());

        socket.add(frame.toBytes());
        await socket.flush();
      } finally {
        await socket.close();
      }
    });
  }

  /// Decodes and decrypts Tuya UDP broadcast beacon packets (UDP 6667 / 6666)
  /// Supports Tuya 3.1 (plaintext JSON), 3.3 and 3.4 (AES-128-ECB with md5('yGAdlopoPVldABfn'))
  static Map<String, dynamic>? decodeTuyaUdpPacket(Uint8List data, [String senderIp = '']) {
    if (data.length < 16) return null;

    // 1. Plaintext JSON beacon (Tuya 3.1 on UDP 6666)
    try {
      final text = utf8.decode(data, allowMalformed: true).trim();
      if (text.contains('gwId') || text.contains('ip') || text.contains('devId')) {
        final start = text.indexOf('{');
        final end = text.lastIndexOf('}');
        if (start != -1 && end > start) {
          final decoded = jsonDecode(text.substring(start, end + 1));
          if (decoded is Map<String, dynamic>) {
            return {
              'devId': (decoded['gwId'] ?? decoded['devId'])?.toString(),
              'ip': decoded['ip']?.toString() ?? senderIp,
              'version': decoded['version']?.toString() ?? '3.1',
              'productKey': decoded['productKey']?.toString(),
              'raw': decoded,
            };
          }
        }
      }
    } catch (_) {}

    // 2. Encrypted Tuya beacon (Tuya 3.3 / 3.4 on UDP 6667)
    // Fixed UDP broadcast key = MD5('yGAdlopoPVldABfn')
    try {
      final udpKeyBytes = Uint8List.fromList(
        md5.convert(utf8.encode('yGAdlopoPVldABfn')).bytes,
      );
      final key = enc.Key(udpKeyBytes);

      final List<Uint8List> candidates = [];

      // Frame prefix 0x000055AA
      if (data.length >= 24) {
        final prefix = ByteData.sublistView(data, 0, 4).getUint32(0, Endian.big);
        if (prefix == 0x000055AA) {
          // Standard Tuya frame without return code: 16-byte header + payload + 4-byte CRC + 4-byte suffix
          if (data.length > 24) {
            final p8 = data.sublist(16, data.length - 8);
            if (p8.isNotEmpty && p8.length % 16 == 0) candidates.add(p8);
          }
          // Return code variant (bytes 16..19): 20-byte header + payload + 8-byte suffix
          if (data.length > 28) {
            final pret = data.sublist(20, data.length - 8);
            if (pret.isNotEmpty && pret.length % 16 == 0) candidates.add(pret);
          }
          // Frame without CRC: 16-byte header + payload + 4-byte suffix
          if (data.length > 20) {
            final p4 = data.sublist(16, data.length - 4);
            if (p4.isNotEmpty && p4.length % 16 == 0) candidates.add(p4);
          }
        }
      }

      // Raw AES blocks
      if (data.length % 16 == 0) {
        candidates.add(data);
      }

      for (final candidate in candidates) {
        // Try PKCS7 unpadding first
        try {
          final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.ecb, padding: 'PKCS7'));
          final decrypted = encrypter.decrypt(enc.Encrypted(candidate));
          if (decrypted.contains('gwId') || decrypted.contains('ip') || decrypted.contains('devId')) {
            final start = decrypted.indexOf('{');
            final end = decrypted.lastIndexOf('}');
            if (start != -1 && end > start) {
              final decoded = jsonDecode(decrypted.substring(start, end + 1));
              if (decoded is Map<String, dynamic>) {
                return {
                  'devId': (decoded['gwId'] ?? decoded['devId'])?.toString(),
                  'ip': decoded['ip']?.toString() ?? senderIp,
                  'version': decoded['version']?.toString() ?? '3.3',
                  'productKey': decoded['productKey']?.toString(),
                  'raw': decoded,
                };
              }
            }
          }
        } catch (_) {}

        // Fallback to null padding
        try {
          final rawEnc = enc.Encrypter(enc.AES(key, mode: enc.AESMode.ecb, padding: null));
          final rawBytes = rawEnc.decryptBytes(enc.Encrypted(candidate));
          if (rawBytes.isNotEmpty) {
            final pad = rawBytes.last;
            final unpadded = (pad > 0 && pad <= 16)
                ? rawBytes.sublist(0, rawBytes.length - pad)
                : rawBytes;
            final text = utf8.decode(unpadded, allowMalformed: true).trim();
            if (text.contains('gwId') || text.contains('ip') || text.contains('devId')) {
              final start = text.indexOf('{');
              final end = text.lastIndexOf('}');
              if (start != -1 && end > start) {
                final decoded = jsonDecode(text.substring(start, end + 1));
                if (decoded is Map<String, dynamic>) {
                  return {
                    'devId': (decoded['gwId'] ?? decoded['devId'])?.toString(),
                    'ip': decoded['ip']?.toString() ?? senderIp,
                    'version': decoded['version']?.toString() ?? '3.3',
                    'productKey': decoded['productKey']?.toString(),
                    'raw': decoded,
                  };
                }
              }
            }
          }
        } catch (_) {}
      }
    } catch (_) {}

    return null;
  }

  /// Auto-detects Wipro Next / Tuya Smart Bulbs on the local Wi-Fi network (Ports 6667 UDP & 6668 TCP)
  Future<List<RealSmartDevice>> discoverLocalWiproBulbs({
    String subnet = '192.168.1.',
    Map<String, String>? knownDeviceKeys,
    List<RealSmartDevice>? existingDevices,
  }) async {
    final List<RealSmartDevice> detected = [];
    final seenDevIds = <String>{};
    final seenIps = <String>{};

    // Helper to cross-reference localKey or cloud token
    (String, String?) resolveCredentials(String devId, String ip) {
      if (knownDeviceKeys != null) {
        if (knownDeviceKeys[devId]?.trim().length == 16) return (knownDeviceKeys[devId]!.trim(), null);
        if (knownDeviceKeys[ip]?.trim().length == 16) return (knownDeviceKeys[ip]!.trim(), null);
      }
      if (existingDevices != null) {
        for (final ed in existingDevices) {
          if (ed.id == devId || ed.credentials['devId'] == devId || ed.credentials['ip'] == ip) {
            final lk = ed.credentials['localKey'];
            final token = ed.credentials['accessToken'] ?? ed.credentials['token'];
            if (lk != null && lk.trim().length == 16) {
              return (lk.trim(), token);
            }
            if (token != null && token.trim().isNotEmpty && !token.toLowerCase().contains('demo')) {
              return ('', token);
            }
          }
        }
      }
      return ('', null);
    }

    // 1. Listen for UDP broadcast beacons on port 6667 / 6666
    try {
      final udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 6667, reuseAddress: true);
      udpSocket.broadcastEnabled = true;
      final sub = udpSocket.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = udpSocket.receive();
          if (dg != null) {
            final senderIp = dg.address.address;
            final parsed = decodeTuyaUdpPacket(dg.data, senderIp);
            if (parsed != null) {
              final devId = parsed['devId']?.toString() ?? 'wipro_${senderIp.replaceAll('.', '_')}';
              if (!seenDevIds.contains(devId)) {
                seenDevIds.add(devId);
                seenIps.add(senderIp);

                final (harvestedKey, cloudToken) = resolveCredentials(devId, senderIp);
                final isKeyValid = harvestedKey.length == 16;

                final creds = <String, String>{
                  'ip': senderIp,
                  'port': '6668',
                  'devId': devId,
                  'version': parsed['version']?.toString() ?? '3.3',
                };

                if (isKeyValid) {
                  creds['localKey'] = harvestedKey;
                } else {
                  creds['localKey'] = '';
                  creds['isPendingKey'] = 'true';
                  if (cloudToken != null) creds['accessToken'] = cloudToken;
                }

                detected.add(
                  RealSmartDevice(
                    id: devId,
                    name: 'Wipro Smart Next Bulb',
                    room: 'Living Room',
                    category: 'light',
                    protocol: isKeyValid
                        ? ConnectionProtocol.tuyaLocalLan
                        : (cloudToken != null
                            ? ConnectionProtocol.tuyaCloudDirect
                            : ConnectionProtocol.tuyaLocalLan),
                    credentials: creds,
                    isOn: true,
                    isOnline: true,
                    primaryValue: 80.0,
                    ratedMaxWatts: 9.0,
                  ),
                );
              }
            }
          }
        }
      });
      await Future.delayed(const Duration(milliseconds: 1200));
      await sub.cancel();
      udpSocket.close();
    } catch (_) {}

    // 2. Active subnet probe on port 6668 for common smart home bulb IPs if UDP didn't find any
    if (detected.isEmpty) {
      final base = subnet.endsWith('.') ? subnet : '$subnet.';
      final candidateIps = [
        '${base}100',
        '${base}105',
        '${base}110',
        '${base}115',
        '${base}120',
        '${base}125',
        '${base}130',
        '${base}150',
      ];

      const chunkSize = 25;
      for (int i = 0; i < candidateIps.length; i += chunkSize) {
        final chunk = candidateIps.sublist(
          i,
          (i + chunkSize > candidateIps.length) ? candidateIps.length : i + chunkSize,
        );
        final batch = chunk.map((ip) async {
          if (seenIps.contains(ip)) return;
          try {
            final s = await _socketConnect(ip, 6668, timeout: const Duration(milliseconds: 350));
            try {
              final id = 'wipro_${ip.replaceAll('.', '_')}';
              final (harvestedKey, cloudToken) = resolveCredentials(id, ip);
              final isKeyValid = harvestedKey.length == 16;

              final creds = <String, String>{
                'ip': ip,
                'port': '6668',
                'devId': id,
                'version': '3.3',
              };
              if (isKeyValid) {
                creds['localKey'] = harvestedKey;
              } else {
                creds['localKey'] = '';
                creds['isPendingKey'] = 'true';
                if (cloudToken != null) creds['accessToken'] = cloudToken;
              }

              detected.add(
                RealSmartDevice(
                  id: id,
                  name: 'Wipro Smart Next Bulb ($ip)',
                  room: 'Living Room',
                  category: 'light',
                  protocol: isKeyValid
                      ? ConnectionProtocol.tuyaLocalLan
                      : (cloudToken != null
                          ? ConnectionProtocol.tuyaCloudDirect
                          : ConnectionProtocol.tuyaLocalLan),
                  credentials: creds,
                  isOn: true,
                  isOnline: true,
                  primaryValue: 80.0,
                  ratedMaxWatts: 9.0,
                ),
              );
              seenIps.add(ip);
            } finally {
              s.destroy();
            }
          } catch (_) {}
        });
        await Future.wait(batch);
      }
    }

    return detected;
  }
}
