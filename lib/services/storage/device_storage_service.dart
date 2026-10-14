import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/device_model.dart';

class DeviceStorageService {
  static const String _keyDevices = 'user_devices_v1';
  static const String _keyClearedDummy = 'has_cleared_dummy_devices';
  static const String _keySmartThingsToken = 'smartthings_pat_token';
  static const String _keyLgThinqToken = 'lg_thinq_token';
  static const String _keyWiproKey = 'wipro_tuya_key';

  SharedPreferences? _prefs;
  final Map<String, Object> _memoryStore = {};

  bool _failedToInitPrefs = false;

  Future<SharedPreferences?> _getPrefs() async {
    if (_failedToInitPrefs) return null;
    if (_prefs != null) return _prefs;
    try {
      _prefs = await SharedPreferences.getInstance();
      return _prefs;
    } catch (_) {
      _failedToInitPrefs = true;
      return null;
    }
  }

  /// Load devices from persistent storage with in-memory fallback
  Future<List<SmartDevice>> loadDevices() async {
    try {
      final prefs = await _getPrefs();
      final rawJson = prefs != null
          ? prefs.getString(_keyDevices)
          : (_memoryStore[_keyDevices] as String?);

      if (rawJson == null || rawJson.isEmpty) {
        return [];
      }

      final list = jsonDecode(rawJson) as List<dynamic>;
      return list
          .map((item) => SmartDevice.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Save list of devices
  Future<void> saveDevices(List<SmartDevice> devices) async {
    try {
      final prefs = await _getPrefs();
      final rawList = devices.map((d) => d.toJson()).toList();
      final encoded = jsonEncode(rawList);
      if (prefs != null) {
        await prefs.setString(_keyDevices, encoded);
      } else {
        _memoryStore[_keyDevices] = encoded;
      }
    } catch (_) {}
  }

  /// Track if user explicitly cleared preloaded dummy devices
  Future<bool> getHasClearedDummy() async {
    try {
      final prefs = await _getPrefs();
      if (prefs != null) {
        return prefs.getBool(_keyClearedDummy) ?? false;
      }
      return (_memoryStore[_keyClearedDummy] as bool?) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setHasClearedDummy(bool cleared) async {
    try {
      final prefs = await _getPrefs();
      if (prefs != null) {
        await prefs.setBool(_keyClearedDummy, cleared);
      } else {
        _memoryStore[_keyClearedDummy] = cleared;
      }
    } catch (_) {}
  }

  /// Credential storage helpers
  Future<void> saveSmartThingsToken(String token) async {
    try {
      final prefs = await _getPrefs();
      if (prefs != null) {
        await prefs.setString(_keySmartThingsToken, token);
      } else {
        _memoryStore[_keySmartThingsToken] = token;
      }
    } catch (_) {}
  }

  Future<String?> getSmartThingsToken() async {
    try {
      final prefs = await _getPrefs();
      if (prefs != null) {
        return prefs.getString(_keySmartThingsToken);
      }
      return _memoryStore[_keySmartThingsToken] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLgThinqToken(String token) async {
    try {
      final prefs = await _getPrefs();
      if (prefs != null) {
        await prefs.setString(_keyLgThinqToken, token);
      } else {
        _memoryStore[_keyLgThinqToken] = token;
      }
    } catch (_) {}
  }

  Future<String?> getLgThinqToken() async {
    try {
      final prefs = await _getPrefs();
      if (prefs != null) {
        return prefs.getString(_keyLgThinqToken);
      }
      return _memoryStore[_keyLgThinqToken] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveWiproKey(String key) async {
    try {
      final prefs = await _getPrefs();
      if (prefs != null) {
        await prefs.setString(_keyWiproKey, key);
      } else {
        _memoryStore[_keyWiproKey] = key;
      }
    } catch (_) {}
  }

  Future<String?> getWiproKey() async {
    try {
      final prefs = await _getPrefs();
      if (prefs != null) {
        return prefs.getString(_keyWiproKey);
      }
      return _memoryStore[_keyWiproKey] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearAll() async {
    try {
      final prefs = await _getPrefs();
      if (prefs != null) {
        await prefs.clear();
      }
      _memoryStore.clear();
    } catch (_) {}
  }
}
