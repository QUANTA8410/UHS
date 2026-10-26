import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:http/http.dart' as http;

/// Credentials for the Tuya Cloud OpenAPI ("Smart Home" project linked to Smart Life).
class TuyaCredentials {
  final String accessId;
  final String accessSecret;
  final String region; // 'in', 'eu', 'eu-w', 'us', 'us-e', 'cn', 'sg'

  const TuyaCredentials({
    required this.accessId,
    required this.accessSecret,
    this.region = 'in', // Default to Indian region for Wipro Smart Next
  });

  bool get isConfigured =>
      accessId.trim().isNotEmpty &&
      accessSecret.trim().isNotEmpty &&
      TuyaService.hosts.containsKey(region);

  Map<String, dynamic> toJson() => {
        'accessId': accessId,
        'accessSecret': accessSecret,
        'region': region,
      };

  factory TuyaCredentials.fromJson(Map<String, dynamic> json) {
    return TuyaCredentials(
      accessId: json['accessId'] as String? ?? '',
      accessSecret: json['accessSecret'] as String? ?? '',
      region: json['region'] as String? ?? 'in',
    );
  }
}

/// Minimal client for the Tuya Cloud OpenAPI matching House Control's TuyaService.swift.
/// Covers device listing, live status reading, and command execution with HMAC-SHA256 signing.
class TuyaService {
  static const Map<String, String> hosts = {
    'in': 'openapi.tuyain.com', // India (Wipro Next primary region)
    'eu': 'openapi.tuyaeu.com', // Central Europe
    'eu-w': 'openapi-weaz.tuyaeu.com', // Western Europe
    'us': 'openapi.tuyaus.com', // Western America
    'us-e': 'openapi-ueaz.tuyaus.com', // Eastern America
    'cn': 'openapi.tuyacn.com', // China
    'sg': 'openapi-sg.iotbing.com', // Singapore
  };

  TuyaCredentials? credentials;
  String? _token;
  DateTime _tokenExpiry = DateTime.fromMillisecondsSinceEpoch(0);

  final Map<String, Set<String>> knownCodes = {};
  final Map<String, Map<String, List<double>>> knownRanges = {};

  TuyaService({this.credentials});

  bool get isConfigured => credentials?.isConfigured ?? false;

  Map<String, dynamic> get publicInfo => {
        'configured': isConfigured,
        'accessId': credentials?.accessId ?? '',
        'region': credentials?.region ?? 'in',
        'hasSecret': credentials?.accessSecret.isNotEmpty ?? false,
      };

  // MARK: - OpenAPI Calls

  /// Every device of the linked account, with the DP codes it supports.
  Future<List<Map<String, dynamic>>> listDevices() async {
    final List<Map<String, dynamic>> devices = [];
    String? lastKey;

    do {
      final query = <String, String>{'size': '50'};
      if (lastKey != null) query['last_row_key'] = lastKey;

      final result = await request('GET', '/v1.0/iot-01/associated-users/devices', query: query);
      if (result is! Map<String, dynamic>) break;

      final devList = result['devices'] as List? ?? [];
      for (final d in devList) {
        if (d is! Map<String, dynamic>) continue;
        final id = d['id'] as String?;
        if (id == null) continue;

        final status = d['status'] as List? ?? [];
        final codes = <String>{};
        for (final item in status) {
          if (item is Map && item['code'] != null) {
            codes.add(item['code'].toString());
          }
        }
        knownCodes[id] = codes;

        devices.add({
          'id': id,
          'name': d['name'] ?? id,
          'category': d['category'] ?? '',
          'product': d['product_name'] ?? '',
          'online': d['online'] ?? false,
          'codes': codes.toList(),
        });
      }

      final hasMore = result['has_more'] as bool? ?? false;
      lastKey = hasMore ? result['last_row_key'] as String? : null;
    } while (lastKey != null);

    return devices;
  }

  /// Current data points for the given devices, keyed by device id.
  Future<Map<String, List<Map<String, dynamic>>>> status(List<String> ids) async {
    final Map<String, List<Map<String, dynamic>>> out = {};

    for (var i = 0; i < ids.countChunks(20); i++) {
      final chunk = ids.skip(i * 20).take(20).toList();
      final result = await request(
        'GET',
        '/v1.0/iot-03/devices/status',
        query: {'device_ids': chunk.join(',')},
      );

      if (result is List) {
        for (final entry in result) {
          if (entry is! Map<String, dynamic>) continue;
          final id = entry['id'] as String?;
          final statusList = (entry['status'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
          if (id != null) {
            out[id] = statusList;
            knownCodes[id] = statusList.map((e) => e['code'].toString()).toSet();
          }
        }
      }
    }

    return out;
  }

  /// Sends standard instruction commands to a device via Tuya OpenAPI.
  Future<void> send(List<Map<String, dynamic>> commands, {required String toDeviceId}) async {
    if (commands.isEmpty) return;
    final body = jsonEncode({'commands': commands});
    await request('POST', '/v1.0/iot-03/devices/$toDeviceId/commands', body: utf8.encode(body));
  }

  // MARK: - HMAC-SHA256 Token & Request Signing

  Future<String> accessToken() async {
    if (_token != null && _tokenExpiry.isAfter(DateTime.now().add(const Duration(seconds: 60)))) {
      return _token!;
    }

    final result = await request('GET', '/v1.0/token', query: {'grant_type': '1'}, authorized: false);
    if (result is! Map<String, dynamic> || result['access_token'] == null) {
      throw Exception('Tuya did not return an access token: $result');
    }

    _token = result['access_token'].toString();
    final expireSec = (result['expire_time'] as num?)?.toInt() ?? 3600;
    _tokenExpiry = DateTime.now().add(Duration(seconds: expireSec));
    return _token!;
  }

  Future<dynamic> request(
    String method,
    String path, {
    Map<String, String> query = const {},
    List<int>? body,
    bool authorized = true,
    bool retry = true,
  }) async {
    final creds = credentials;
    if (creds == null || !creds.isConfigured) {
      throw Exception('Tuya credentials are not configured or region is invalid');
    }
    final host = hosts[creds.region];
    if (host == null) throw Exception('Unknown region: ${creds.region}');

    // Sort query alphabetically
    final sortedKeys = query.keys.toList()..sort();
    final queryString = sortedKeys.map((k) => '$k=${query[k]}').join('&');
    final signedUrl = queryString.isEmpty ? path : '$path?$queryString';
    final fullUri = Uri.parse('https://$host$signedUrl');

    final bodyBytes = body ?? [];
    final bodyHash = sha256.convert(bodyBytes).toString().toLowerCase();
    final t = '${DateTime.now().millisecondsSinceEpoch}';
    final token = authorized ? await accessToken() : '';

    // Authentic Tuya HMAC-SHA256 signature payload
    final payload = '${creds.accessId}$token$t$method\n$bodyHash\n\n$signedUrl';
    final mac = Hmac(sha256, utf8.encode(creds.accessSecret));
    final sign = mac.convert(utf8.encode(payload)).toString().toUpperCase();

    final headers = <String, String>{
      'client_id': creds.accessId,
      'sign': sign,
      't': t,
      'sign_method': 'HMAC-SHA256',
    };
    if (authorized) headers['access_token'] = token;
    if (body != null) headers['Content-Type'] = 'application/json';

    final http.Response res;
    if (method == 'GET') {
      res = await http.get(fullUri, headers: headers).timeout(const Duration(seconds: 12));
    } else if (method == 'POST') {
      res = await http.post(fullUri, headers: headers, body: body).timeout(const Duration(seconds: 12));
    } else if (method == 'PUT') {
      res = await http.put(fullUri, headers: headers, body: body).timeout(const Duration(seconds: 12));
    } else if (method == 'DELETE') {
      res = await http.delete(fullUri, headers: headers, body: body).timeout(const Duration(seconds: 12));
    } else {
      throw Exception('Unsupported HTTP method: $method');
    }

    final dynamic parsed;
    try {
      parsed = jsonDecode(res.body);
    } catch (_) {
      throw Exception('Unexpected response format from Tuya (${res.statusCode})');
    }

    if (parsed is Map<String, dynamic>) {
      if (parsed['success'] == true) return parsed['result'];
      final code = (parsed['code'] as num?)?.toInt() ?? 0;

      // 1010 / 1011: token expired or invalid. Re-authenticate once
      if (authorized && retry && (code == 1010 || code == 1011)) {
        _token = null;
        return request(method, path, query: query, body: body, authorized: true, retry: false);
      }
      throw Exception('${parsed['msg'] ?? 'Tuya request failed'} (code $code)');
    }
    return parsed;
  }
}

/// Translates between the app's device state and Tuya's standard instruction set.
/// Matches House Control's TuyaMapper.swift with full support for lights, ACs, and IR remotes.
class TuyaMapper {
  static const Map<String, String> acModes = {
    'cool': 'cold',
    'heat': 'hot',
    'dry': 'wet',
    'fan': 'wind',
    'auto': 'auto',
  };

  static const Map<String, String> acFans = {
    'auto': 'auto',
    'low': 'low',
    'medium': 'mid',
    'high': 'high',
    'turbo': 'strong',
  };

  static const Map<String, int> irModes = {
    'cool': 0,
    'heat': 1,
    'auto': 2,
    'fan': 3,
    'dry': 4,
  };

  static const Map<String, int> irFans = {
    'auto': 0,
    'low': 1,
    'medium': 2,
    'high': 3,
    'turbo': 3,
  };

  static String? pick(List<String> candidates, Set<String> codes, [String? override]) {
    if (override != null && override.isNotEmpty) return override;
    for (final c in candidates) {
      if (codes.contains(c)) return c;
    }
    return null;
  }

  static (double, double) range(String code, Map<String, List<double>> ranges, {double floor = 0}) {
    final r = ranges[code];
    if (r != null && r.length == 2 && r[1] > r[0]) {
      return (r[0], r[1]);
    }
    return code.endsWith('_v2') ? (floor > 0 ? 10.0 : 0.0, 1000.0) : (floor, 255.0);
  }

  /// Converts RGB hex e.g. '#FF5733' to HSV (h: 0..360, s: 0..1, v: 0..1)
  static (double, double, double)? hexToHsv(String hex) {
    var clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) {
      final r = int.parse(clean.substring(0, 2), radix: 16) / 255.0;
      final g = int.parse(clean.substring(2, 4), radix: 16) / 255.0;
      final b = int.parse(clean.substring(4, 6), radix: 16) / 255.0;

      final maxC = [r, g, b].reduce((curr, next) => curr > next ? curr : next);
      final minC = [r, g, b].reduce((curr, next) => curr < next ? curr : next);
      final delta = maxC - minC;

      double h = 0;
      if (delta > 0) {
        if (maxC == r) {
          h = ((g - b) / delta) % 6;
        } else if (maxC == g) {
          h = ((b - r) / delta) + 2;
        } else {
          h = ((r - g) / delta) + 4;
        }
        h *= 60;
        if (h < 0) h += 360;
      }
      final s = maxC == 0 ? 0.0 : delta / maxC;
      final v = maxC;
      return (h, s, v);
    }
    return null;
  }

  /// Commands to set light state (on/off, brightness, color temp Kelvin, RGB)
  static List<Map<String, dynamic>> lightCommands({
    required Map<String, dynamic> patch,
    Map<String, dynamic> state = const {},
    Map<String, dynamic> link = const {},
    required Set<String> codes,
    Map<String, List<double>> ranges = const {},
  }) {
    final custom = link['codes'] as Map<String, dynamic>? ?? {};
    final List<Map<String, dynamic>> out = [];

    if (patch.containsKey('on')) {
      final code = pick(['switch_led', 'switch_1', 'switch'], codes, custom['switch'] as String?) ?? 'switch_led';
      out.add({'code': code, 'value': patch['on'] == true});
    }

    if (patch.containsKey('brightness')) {
      final b = (patch['brightness'] as num).toDouble();
      final code = pick(['bright_value_v2', 'bright_value'], codes);
      if (code != null) {
        final (lo, hi) = range(code, ranges, floor: 25);
        out.add({'code': code, 'value': (lo + b * (hi - lo)).round()});
      }
    }

    if (patch.containsKey('temp')) {
      final k = (patch['temp'] as num).toDouble();
      final code = pick(['temp_value_v2', 'temp_value'], codes);
      if (code != null) {
        final t = ((k - 2200) / (6500 - 2200)).clamp(0.0, 1.0);
        final (lo, hi) = range(code, ranges);
        if (codes.contains('work_mode')) {
          out.add({'code': 'work_mode', 'value': 'white'});
        }
        out.add({'code': code, 'value': (lo + t * (hi - lo)).round()});
      }
    }

    if (patch.containsKey('color')) {
      final hex = patch['color'] as String;
      final hsv = hexToHsv(hex);
      final code = pick(['colour_data_v2', 'colour_data'], codes);
      if (hsv != null && code != null) {
        final scale = range(code == 'colour_data_v2' ? 'bright_value_v2' : 'bright_value', ranges).$2 > 255 ? 1000.0 : 255.0;
        final v = ((state['brightness'] as num?)?.toDouble() ?? 1.0).clamp(0.01, 1.0);
        if (codes.contains('work_mode')) {
          out.add({'code': 'work_mode', 'value': 'colour'});
        }
        out.add({
          'code': code,
          'value': jsonEncode({
            'h': hsv.$1.round(),
            's': (hsv.$2 * scale).round(),
            'v': (v * scale).round(),
          }),
        });
      }
    }

    return out;
  }

  /// Parses device status list into uniform light state
  static Map<String, dynamic> lightState(List<Map<String, dynamic>> status, {Map<String, List<double>> ranges = const {}}) {
    final Map<String, dynamic> out = {};
    for (final dp in status) {
      final code = dp['code'] as String?;
      final value = dp['value'];
      if (code == null || value == null) continue;

      switch (code) {
        case 'switch_led':
        case 'switch_1':
        case 'switch':
          if (!out.containsKey('on') && value is bool) out['on'] = value;
          break;
        case 'bright_value_v2':
        case 'bright_value':
          if (value is num) {
            final (lo, hi) = range(code, ranges, floor: 25);
            out['brightness'] = ((value - lo) / (hi - lo)).clamp(0.05, 1.0);
          }
          break;
        case 'temp_value_v2':
        case 'temp_value':
          if (value is num) {
            final (lo, hi) = range(code, ranges);
            out['temp'] = 2200 + ((value - lo) / (hi - lo)).clamp(0.0, 1.0) * 4300;
          }
          break;
      }
    }
    return out;
  }

  /// True for an AC that is controlled via infrared blaster
  static bool isInfraredAC(Set<String> codes) => codes.contains('PowerOn') || codes.contains('PowerOff');

  /// Key presses for infrared remote
  static List<Map<String, dynamic>> infraredKeys(Map<String, dynamic> patch) {
    final List<Map<String, dynamic>> out = [];
    if (patch.containsKey('on')) {
      final key = patch['on'] == true ? 'PowerOn' : 'PowerOff';
      out.add({'code': key, 'value': key});
    }
    if (patch.containsKey('mode') && irModes.containsKey(patch['mode'])) {
      out.add({'code': 'M', 'value': irModes[patch['mode']]});
    }
    if (patch.containsKey('target')) {
      out.add({'code': 'T', 'value': (patch['target'] as num).round()});
    }
    if (patch.containsKey('fan') && irFans.containsKey(patch['fan'])) {
      out.add({'code': 'F', 'value': irFans[patch['fan']]});
    }
    return out;
  }

  /// AC unit commands
  static List<Map<String, dynamic>> acCommands({
    required Map<String, dynamic> patch,
    Map<String, dynamic> link = const {},
    required Set<String> codes,
  }) {
    if (isInfraredAC(codes)) return infraredKeys(patch);

    final custom = link['codes'] as Map<String, dynamic>? ?? {};
    final List<Map<String, dynamic>> out = [];

    if (patch.containsKey('on')) {
      final code = pick(['switch', 'power', 'switch_1'], codes, custom['switch'] as String?) ?? 'switch';
      out.add({'code': code, 'value': patch['on'] == true});
    }
    if (patch.containsKey('target')) {
      final code = pick(['temp_set'], codes, custom['target'] as String?) ?? 'temp_set';
      out.add({'code': code, 'value': (patch['target'] as num).round()});
    }
    if (patch.containsKey('mode') && acModes.containsKey(patch['mode'])) {
      final code = pick(['mode'], codes, custom['mode'] as String?) ?? 'mode';
      out.add({'code': code, 'value': acModes[patch['mode']]});
    }
    if (patch.containsKey('fan') && acFans.containsKey(patch['fan'])) {
      final code = pick(['fan_speed_enum', 'windspeed'], codes, custom['fan'] as String?);
      if (code != null) out.add({'code': code, 'value': acFans[patch['fan']]});
    }
    if (patch.containsKey('sleep') && codes.contains('sleep')) {
      out.add({'code': 'sleep', 'value': patch['sleep'] == true});
    }
    if (patch.containsKey('eco') && codes.contains('eco')) {
      out.add({'code': 'eco', 'value': patch['eco'] == true});
    }
    return out;
  }

  /// Parses status list into uniform AC state
  static Map<String, dynamic> acState(List<Map<String, dynamic>> status) {
    final Map<String, dynamic> out = {};
    for (final dp in status) {
      final code = dp['code'] as String?;
      final value = dp['value'];
      if (code == null || value == null) continue;

      switch (code) {
        case 'switch':
        case 'power':
          if (value is bool) out['on'] = value;
          break;
        case 'temp_set':
          if (value is num) out['target'] = value.toDouble();
          break;
        case 'temp_current':
          if (value is num) out['roomTemp'] = value.toDouble();
          break;
        case 'mode':
          if (value is String) {
            for (final entry in acModes.entries) {
              if (entry.value == value) out['mode'] = entry.key;
            }
          }
          break;
        case 'fan_speed_enum':
        case 'windspeed':
          if (value is String) {
            for (final entry in acFans.entries) {
              if (entry.value == value) out['fan'] = entry.key;
            }
          }
          break;
      }
    }
    return out;
  }
}

/// Helper extension for paging
extension _ListChunk<T> on List<T> {
  int countChunks(int chunkSize) => (length / chunkSize).ceil();
}

/// Hybrid Wipro / Tuya Direct Local Encrypted Frame & Cloud Service.
class WiproTuyaService {
  final TuyaService cloud = TuyaService();

  /// Test whether Wipro bulb is reachable at the given LAN IP address
  Future<bool> checkConnectivity(String host, {Duration timeout = const Duration(seconds: 2)}) async {
    if (host.isEmpty) return false;
    try {
      final socket = await Socket.connect(host, 6668, timeout: timeout);
      socket.destroy();
      return true;
    } catch (_) {
      try {
        final socket = await Socket.connect(host, 80, timeout: timeout);
        socket.destroy();
        return true;
      } catch (_) {}
    }
    return false;
  }

  /// Sends raw Tuya 3.3 / 3.4 LAN DPS payload to the Wipro bulb over TCP port 6668
  Future<bool> sendLocalCommand({
    required String host,
    required Map<String, dynamic> dps,
    String? localKey,
    String? deviceId,
  }) async {
    if (host.isEmpty) return true;

    // If a 16-character localKey is available, send authentic AES-128 encrypted frame
    if (localKey != null && localKey.length == 16) {
      return sendEncryptedFrame(
        host: host,
        deviceId: deviceId ?? 'wipro_bulb',
        localKey: localKey,
        dps: dps,
      );
    }

    try {
      final socket = await Socket.connect(host, 6668, timeout: const Duration(seconds: 1));
      final payload = jsonEncode({
        'gwId': deviceId ?? 'wipro_bulb',
        'devId': deviceId ?? 'wipro_bulb',
        'uid': 'wipro_user',
        't': '${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
        'dps': dps,
      });

      socket.write(payload);
      await socket.flush();
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Direct Tuya / Smart Life local encrypted frame transmission (v3.3 AES-128-ECB PKCS7 + CRC32)
  Future<bool> sendEncryptedFrame({
    required String host,
    required String deviceId,
    required String localKey,
    required Map<String, dynamic> dps,
  }) async {
    if (host.isEmpty || localKey.length != 16) return false;

    try {
      final socket = await Socket.connect(host, 6668, timeout: const Duration(seconds: 3));
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

        final body = BytesBuilder()
          ..add(utf8.encode('3.3\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'))
          ..add(encrypted);
        final bodyBytes = body.toBytes();

        final header = ByteData(16)
          ..setUint32(0, 0x000055AA, Endian.big)
          ..setUint32(4, 1, Endian.big)
          ..setUint32(8, 7, Endian.big) // 7 = CONTROL
          ..setUint32(12, bodyBytes.length + 8, Endian.big);

        final frame = BytesBuilder()
          ..add(header.buffer.asUint8List())
          ..add(bodyBytes);

        // IEEE 802.3 CRC32
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
        return true;
      } finally {
        await socket.close();
      }
    } catch (_) {
      return false;
    }
  }

  /// Power toggle (DPS 20: boolean)
  Future<bool> setPower({
    required String host,
    required bool isPowered,
    String? cloudDeviceId,
    String? localKey,
  }) async {
    return sendLocalCommand(
      host: host,
      dps: {'20': isPowered},
      localKey: localKey,
      deviceId: cloudDeviceId,
    );
  }

  /// Brightness: 0.0 - 1.0 mapped to Tuya DPS 22 (10 - 1000)
  Future<bool> setBrightness({
    required String host,
    required double brightness,
    String? cloudDeviceId,
    String? localKey,
  }) async {
    final tuyaVal = (brightness * 1000).clamp(10, 1000).round();
    return sendLocalCommand(
      host: host,
      dps: {'22': tuyaVal},
      localKey: localKey,
      deviceId: cloudDeviceId,
    );
  }

  /// Color Temperature: 2700K - 6500K mapped to Tuya DPS 23 (0 - 1000)
  Future<bool> setColorTemp({
    required String host,
    required int kelvin,
    String? cloudDeviceId,
    String? localKey,
  }) async {
    final percent = ((kelvin - 2700) / (6500 - 2700)).clamp(0.0, 1.0);
    final tuyaVal = (percent * 1000).round();
    return sendLocalCommand(
      host: host,
      dps: {'23': tuyaVal},
      localKey: localKey,
      deviceId: cloudDeviceId,
    );
  }

  /// RGB Color: mapped to Tuya DPS 24 (HSV hex string)
  Future<bool> setColorHex({
    required String host,
    required String hexRgb,
    String? cloudDeviceId,
    String? localKey,
  }) async {
    return sendLocalCommand(
      host: host,
      dps: {'24': hexRgb, '21': 'colour'},
      localKey: localKey,
      deviceId: cloudDeviceId,
    );
  }

  /// Listens on UDP port 6667 for Tuya / Smart Life local LAN broadcast beacons
  Future<List<Map<String, dynamic>>> discoverLocalTuyaDevices({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final List<Map<String, dynamic>> discovered = [];
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        6667,
        reuseAddress: true,
        reusePort: false,
      );
      socket.broadcastEnabled = true;

      final completer = Completer<List<Map<String, dynamic>>>();
      final sub = socket.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket?.receive();
          if (datagram != null) {
            try {
              final text = utf8.decode(datagram.data, allowMalformed: true);
              if (text.contains('gwId') || text.contains('ip')) {
                discovered.add({
                  'ip': datagram.address.address,
                  'port': datagram.port,
                  'raw': text,
                  'discoveredAt': DateTime.now().toIso8601String(),
                });
              }
            } catch (_) {}
          }
        }
      });

      Timer(timeout, () {
        sub.cancel();
        socket?.close();
        if (!completer.isCompleted) completer.complete(discovered);
      });

      return await completer.future;
    } catch (_) {
      socket?.close();
      return discovered;
    }
  }
}

