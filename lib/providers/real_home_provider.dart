import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/master/cross_brand_reflex_bus.dart';
import '../services/master/presence_and_os_bridge.dart';
import '../services/master/self_healing_network_engine.dart';
import '../services/automation/smart_automation_engine.dart';
import '../services/master/zero_touch_onboarding_service.dart';
import '../services/node/embedded_android_node_server.dart';
import '../services/notifications/appliance_notification_bridge.dart';
import '../services/real_iot_controller.dart';
import '../services/smartthings/smartthings_laundry_service.dart';

class SmartAutomationRule {
  final String id;
  String name;
  bool isEnabled;
  String triggerType; // 'time' or 'device_state'
  String triggerValue; // '22:00' or 'deviceId:on'
  String targetDeviceId;
  bool targetPowerState;
  double? targetLevel;
  DateTime? lastTriggeredAt;

  DateTime? get lastExecutedAt => lastTriggeredAt;
  set lastExecutedAt(DateTime? dt) => lastTriggeredAt = dt;

  SmartAutomationRule({
    required this.id,
    required this.name,
    this.isEnabled = true,
    required this.triggerType,
    required this.triggerValue,
    required this.targetDeviceId,
    required this.targetPowerState,
    this.targetLevel,
    this.lastTriggeredAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isEnabled': isEnabled,
        'triggerType': triggerType,
        'triggerValue': triggerValue,
        'targetDeviceId': targetDeviceId,
        'targetPowerState': targetPowerState,
        'targetLevel': targetLevel,
      };

  factory SmartAutomationRule.fromJson(Map<String, dynamic> json) =>
      SmartAutomationRule(
        id: json['id'] as String,
        name: json['name'] as String,
        isEnabled: json['isEnabled'] as bool? ?? true,
        triggerType: json['triggerType'] as String,
        triggerValue: json['triggerValue'] as String,
        targetDeviceId: json['targetDeviceId'] as String,
        targetPowerState: json['targetPowerState'] as bool,
        targetLevel: (json['targetLevel'] as num?)?.toDouble(),
      );
}

class RealHomeProvider extends ChangeNotifier {
  final RealIotController _controller = RealIotController();
  RealIotController get iot => _controller;
  final SelfHealingNetworkEngine networkEngine = SelfHealingNetworkEngine();
  final ZeroTouchOnboardingService zeroTouch = ZeroTouchOnboardingService();
  final CrossBrandReflexBus reflexBus = CrossBrandReflexBus();
  final PresenceAndOsBridge osBridge = PresenceAndOsBridge();
  final EmbeddedAndroidNodeServer nodeServer = EmbeddedAndroidNodeServer();
  final List<String> reflexActivityLog = [];

  final List<RealSmartDevice> _devices = [];
  final List<SmartAutomationRule> _automations = [];
  final SmartAutomationEngine smartEngine = SmartAutomationEngine();
  final SmartThingsLaundryService laundryService = SmartThingsLaundryService();
  final List<MultiConditionAutomationRule> _multiConditionRules = [];
  final Map<String, String> _lastWasherMachineState = {};
  Timer? _pollingTimer;
  bool _isPollingInFlight = false;
  final Map<String, Timer> _levelDebounceTimers = {};
  final Map<String, Timer> _applianceDebounceTimers = {};
  bool isBusy = false;
  String? lastGlobalError;

  double todayAccumulatedKwh = 0.0;
  DateTime? _lastEnergySampleTime;

  List<RealSmartDevice> get devices => List.unmodifiable(_devices);
  List<RealSmartDevice> get allDevices => devices;
  List<String> get rooms => _devices.map((d) => d.room).toSet().toList();
  List<RealSmartDevice> devicesInRoom(String room) => _devices.where((d) => d.room == room).toList();
  int get activeLightsCount => _devices.where((d) => d.category == 'light' && d.isOn).length;
  int get activeAppliancesCount => _devices.where((d) => d.category != 'light' && d.isOn).length;
  List<SmartAutomationRule> get automations => List.unmodifiable(_automations);
  List<MultiConditionAutomationRule> get multiConditionRules =>
      List.unmodifiable(_multiConditionRules);
  List<AutomationExecutionLog> get executionLogs => smartEngine.executionLogs;
  Map<String, String> get lastWasherMachineState => Map.unmodifiable(_lastWasherMachineState);
  bool get isUserAtHome => osBridge.isUserAtHome;

  // Real Power Topology Telemetry Getters
  double get totalLiveWatts =>
      _devices.where((d) => d.isOnline).fold(0.0, (sum, d) => sum + d.liveWatts);

  double get hvacAndLaundryWatts => _devices
      .where((d) => d.isOnline && (d.category == 'ac' || d.category == 'washer'))
      .fold(0.0, (sum, d) => sum + d.liveWatts);

  double get lightingAndMediaWatts => _devices
      .where((d) => d.isOnline && d.category != 'ac' && d.category != 'washer')
      .fold(0.0, (sum, d) => sum + d.liveWatts);

  int get activeDrawingDevicesCount =>
      _devices.where((d) => d.isOnline && d.liveWatts > 1.5).length;

  double get estimatedTodayCostInr => todayAccumulatedKwh * 7.50;

  bool _isDisposed = false;

  RealHomeProvider({bool autoInitStorage = true, bool autoStartPolling = true}) {
    // Initialize OS Listeners for Deep Links & Incoming Calls
    osBridge.initializeOsListeners(
      onNfcOrDeepLinkTriggered: (uri) => handleNfcOrDeepLink(uri),
      onIncomingPhoneCallDetected: () {
        reflexBus.emitEvent(
          HardwareReflexEvent(
            sourceDeviceId: 'smartphone',
            sourceCategory: 'phone_call',
            eventType: 'incoming_call',
          ),
        );
      },
    );

    if (autoInitStorage) {
      _loadPersistedState();
    }
    if (autoStartPolling) {
      // Poll real device statuses and evaluate automations every 10 seconds
      _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
        await syncAllDevicesSilent();
        await _evaluateTimeAutomations();
        await _checkPresenceAutomations();
      });
    }
  }

  Future<bool> startNodeServer({int port = 8765}) async {
    final ok = await nodeServer.startServer(this, port: port);
    notifyListeners();
    return ok;
  }

  Future<void> stopNodeServer() async {
    await nodeServer.stopServer();
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _pollingTimer?.cancel();
    for (final timer in _levelDebounceTimers.values) {
      timer.cancel();
    }
    _levelDebounceTimers.clear();
    for (final timer in _applianceDebounceTimers.values) {
      timer.cancel();
    }
    _applianceDebounceTimers.clear();
    reflexBus.dispose();
    nodeServer.stopServer();
    nodeServer.dispose();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  Future<void> _checkPresenceAutomations() async {
    final transition = await osBridge.checkPresenceTransition();
    if (transition != null) {
      if (!transition) {
        // Left Home -> Auto turn off running devices, but never power off
        // always-on or safety-critical appliances such as refrigerators,
        // security cameras, or active laundry machines.
        const exemptCategories = {'fridge', 'camera', 'washer'};
        for (final d
            in _devices.where((d) => d.isOn && !exemptCategories.contains(d.category))) {
          try {
            await toggleDevicePower(d);
          } catch (_) {}
        }
      }

      // Multi-condition presence automations
      for (final rule in _multiConditionRules) {
        if (!rule.isEnabled) continue;
        final satisfiesGuards = smartEngine.evaluatePreconditions(
          rule,
          isUserAtHome: transition,
          devices: _devices,
        );
        if (!satisfiesGuards) continue;

        if (smartEngine.shouldTriggerPresence(rule, transition)) {
          await smartEngine.executeSequence(
            rule,
            _controller,
            _devices,
            onLog: (_) => _saveState(),
          );
          notifyListeners();
        }
      }
    }
  }

  String? linkedSmartThingsPat;
  String? linkedLgThinqPat;
  String? linkedHomeAssistantHubUrl;
  String? linkedHomeAssistantToken;
  String? linkedHueBridgeIp;
  String? linkedHueUsername;
  bool _hasExplicitlyClearedDevices = false;

  Future<void> _loadPersistedState() async {
    final prefs = await SharedPreferences.getInstance();
    if (_isDisposed) return;

    try {
      final devRaw = prefs.getString('unified_home_paired_devices_v4') ?? prefs.getString('real_devices_v2');
      if (devRaw != null && devRaw.isNotEmpty) {
        final decoded = jsonDecode(devRaw);
        if (decoded is List) {
          final loaded = <RealSmartDevice>[];
          for (final item in decoded) {
            try {
              if (item is Map) {
                final d = RealSmartDevice.fromJson(Map<String, dynamic>.from(item));
                _controller.computeDeviceLiveWattage(d);
                loaded.add(d);
              }
            } catch (e) {
              debugPrint('Error deserializing saved device: $e');
            }
          }
          if (loaded.isNotEmpty) {
            _devices
              ..clear()
              ..addAll(loaded);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading saved devices: $e');
    }

    final tokenJson = prefs.getString('unified_home_brand_tokens_v4');
    if (tokenJson != null && tokenJson.isNotEmpty) {
      try {
        final Map<String, dynamic> tokens = jsonDecode(tokenJson);
        linkedSmartThingsPat = tokens['st_pat']?.toString();
        linkedLgThinqPat = tokens['lg_pat']?.toString();
        linkedHomeAssistantHubUrl = tokens['ha_hub_url']?.toString();
        linkedHomeAssistantToken = tokens['ha_token']?.toString();
        linkedHueBridgeIp = tokens['hue_bridge_ip']?.toString();
        linkedHueUsername = tokens['hue_username']?.toString();
      } catch (_) {}
    }

    linkedSmartThingsPat ??= prefs.getString('linked_st_pat_token');
    linkedLgThinqPat ??= prefs.getString('linked_lg_pat_token');
    linkedHomeAssistantHubUrl ??= prefs.getString('linked_ha_hub_url');
    linkedHomeAssistantToken ??= prefs.getString('linked_ha_token');
    linkedHueBridgeIp ??= prefs.getString('linked_hue_bridge_ip');
    linkedHueUsername ??= prefs.getString('linked_hue_username');

    try {
      final autoRaw = prefs.getString('real_automations_v2');
      if (autoRaw != null) {
        final list = List<Map<String, dynamic>>.from(jsonDecode(autoRaw));
        _automations
          ..clear()
          ..addAll(list.map(SmartAutomationRule.fromJson));
      }
    } catch (_) {}

    try {
      final multiRaw = prefs.getString('multi_condition_rules_v1');
      if (multiRaw != null) {
        final list = List<Map<String, dynamic>>.from(jsonDecode(multiRaw));
        _multiConditionRules
          ..clear()
          ..addAll(list.map(MultiConditionAutomationRule.fromJson));
      }
    } catch (_) {}

    try {
      final logsRaw = prefs.getString('automation_execution_logs_v1');
      if (logsRaw != null) {
        final list = List<Map<String, dynamic>>.from(jsonDecode(logsRaw));
        smartEngine.executionLogs
          ..clear()
          ..addAll(list.map(AutomationExecutionLog.fromJson));
      }
    } catch (_) {}

    final bssid = prefs.getString('home_router_bssid');
    if (bssid != null) {
      osBridge.homeRouterBssid = bssid;
    }
    final todayStr = '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}';
    final savedDate = prefs.getString('energy_date_ymd');
    if (savedDate == todayStr) {
      todayAccumulatedKwh = prefs.getDouble('energy_today_kwh') ?? 0.0;
    } else {
      todayAccumulatedKwh = 0.0;
      await prefs.setString('energy_date_ymd', todayStr);
      await prefs.setDouble('energy_today_kwh', 0.0);
    }
    _lastEnergySampleTime = DateTime.now();
    if (_isDisposed) return;
    notifyListeners();
    await syncAllDevicesSilent();
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    if (_devices.isNotEmpty || _hasExplicitlyClearedDevices) {
      final jsonDevices = jsonEncode(_devices.map((d) => d.toJson()).toList());
      await prefs.setString('unified_home_paired_devices_v4', jsonDevices);
      await prefs.setString('real_devices_v2', jsonDevices);
    }
    await prefs.setString(
      'real_automations_v2',
      jsonEncode(_automations.map((a) => a.toJson()).toList()),
    );
    await prefs.setString(
      'multi_condition_rules_v1',
      jsonEncode(_multiConditionRules.map((r) => r.toJson()).toList()),
    );
    await prefs.setString(
      'automation_execution_logs_v1',
      jsonEncode(smartEngine.executionLogs.take(50).map((l) => l.toJson()).toList()),
    );

    final brandTokens = <String, String>{};
    if (linkedSmartThingsPat != null) {
      brandTokens['st_pat'] = linkedSmartThingsPat!;
      await prefs.setString('linked_st_pat_token', linkedSmartThingsPat!);
    }
    if (linkedLgThinqPat != null) {
      brandTokens['lg_pat'] = linkedLgThinqPat!;
      await prefs.setString('linked_lg_pat_token', linkedLgThinqPat!);
    }
    if (linkedHomeAssistantHubUrl != null) {
      brandTokens['ha_hub_url'] = linkedHomeAssistantHubUrl!;
      await prefs.setString('linked_ha_hub_url', linkedHomeAssistantHubUrl!);
    }
    if (linkedHomeAssistantToken != null) {
      brandTokens['ha_token'] = linkedHomeAssistantToken!;
      await prefs.setString('linked_ha_token', linkedHomeAssistantToken!);
    }
    if (linkedHueBridgeIp != null) {
      brandTokens['hue_bridge_ip'] = linkedHueBridgeIp!;
      await prefs.setString('linked_hue_bridge_ip', linkedHueBridgeIp!);
    }
    if (linkedHueUsername != null) {
      brandTokens['hue_username'] = linkedHueUsername!;
      await prefs.setString('linked_hue_username', linkedHueUsername!);
    }
    await prefs.setString('unified_home_brand_tokens_v4', jsonEncode(brandTokens));

    if (osBridge.homeRouterBssid != null) {
      await prefs.setString('home_router_bssid', osBridge.homeRouterBssid!);
    }
    final todayStr = '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}';
    await prefs.setString('energy_date_ymd', todayStr);
    await prefs.setDouble('energy_today_kwh', todayAccumulatedKwh);
  }

  Future<void> togglePower(String id) async {
    final match = _devices.where((d) => d.id == id);
    if (match.isNotEmpty) {
      await toggleDevicePower(match.first);
    }
  }

  RealSmartDevice sanitizeDeviceCredentials(RealSmartDevice dev) {
    final Map<String, dynamic> creds = Map<String, dynamic>.from(dev.credentials);
    final hubUrl = creds['hubUrl']?.toString().trim();
    final localKey = creds['localKey']?.toString().trim();
    final token = creds['token']?.toString().trim();
    final controlUrl = creds['controlUrl']?.toString().trim();
    final onUrl = creds['onUrl']?.toString().trim();
    final offUrl = creds['offUrl']?.toString().trim();

    final hasRealHardware = dev.hasRealHardwareCredentials ||
        (hubUrl != null && hubUrl.isNotEmpty && !hubUrl.toLowerCase().contains('demo')) ||
        (localKey != null && localKey.length == 16) ||
        (token != null && token.length > 10 && !token.toLowerCase().contains('demo')) ||
        (controlUrl != null && controlUrl.isNotEmpty && !controlUrl.toLowerCase().contains('demo')) ||
        (onUrl != null && onUrl.isNotEmpty && !onUrl.toLowerCase().contains('demo')) ||
        (offUrl != null && offUrl.isNotEmpty && !offUrl.toLowerCase().contains('demo'));

    if (!hasRealHardware) {
      return dev;
    }

    bool modified = false;
    if (creds['vendor']?.toString().toLowerCase() == 'demo') {
      creds.remove('vendor');
      modified = true;
    }
    if (creds['token']?.toString().toLowerCase().contains('demo') == true) {
      creds.remove('token');
      modified = true;
    }
    if (creds['isDemo'] == true || creds['isDemo']?.toString().toLowerCase() == 'true') {
      creds.remove('isDemo');
      modified = true;
    }

    if (!modified) {
      return dev;
    }

    try {
      if (dev.credentials.containsKey('vendor') && dev.credentials['vendor']?.toLowerCase() == 'demo') {
        dev.credentials.remove('vendor');
      }
      if (dev.credentials['token']?.toLowerCase().contains('demo') == true) {
        dev.credentials.remove('token');
      }
      dev.credentials.remove('isDemo');
      return dev;
    } catch (_) {
      final Map<String, String> safeCreds = {};
      for (final entry in creds.entries) {
        if (entry.value != null) {
          safeCreds[entry.key] = entry.value.toString();
        }
      }
      return dev.copyWith(credentials: safeCreds);
    }
  }

  Future<void> updateDevice(RealSmartDevice dev) async {
    final sanitized = sanitizeDeviceCredentials(dev);
    final idx = _devices.indexWhere((d) => d.id == sanitized.id);
    if (idx != -1) {
      _devices[idx] = sanitized;
      await _saveState();
      notifyListeners();
    }
  }

  Future<void> addDevice(RealSmartDevice dev) async => addDirectLanDevice(dev);

  bool _isHardwareExecutable(RealSmartDevice dev) {
    if (dev.hasRealHardwareCredentials) return true;
    if (dev.isDummy) return false;
    if (dev.id.contains('demo') || dev.id.contains('sample') || dev.id.contains('test')) return false;

    switch (dev.protocol) {
      case ConnectionProtocol.smartThingsCloud:
        final token = dev.credentials['token'] ?? linkedSmartThingsPat;
        return token != null && token.isNotEmpty && !token.contains('demo') && token.length > 10;

      case ConnectionProtocol.lgThinqCloud:
        final token = dev.credentials['token'] ?? linkedLgThinqPat;
        return token != null && token.isNotEmpty && !token.contains('demo') && token.length > 10;

      case ConnectionProtocol.customHttpWebhook:
        if (dev.isLgThinq || dev.credentials['vendor'] == 'lg_thinq' || dev.credentials['vendor'] == 'lg') {
          final token = dev.credentials['token'] ?? linkedLgThinqPat;
          return token != null && token.isNotEmpty && !token.contains('demo') && token.length > 10;
        }
        return dev.credentials['controlUrl']?.isNotEmpty == true || dev.credentials['onUrl']?.isNotEmpty == true;

      case ConnectionProtocol.tuyaLocalLan:
        final key = dev.credentials['localKey'];
        final ip = dev.credentials['ip'];
        return ip != null && ip.isNotEmpty && key != null && key.length == 16;

      case ConnectionProtocol.tuyaCloudDirect:
        final token = dev.credentials['accessToken'];
        return token != null && token.isNotEmpty && !token.contains('demo');

      case ConnectionProtocol.onePlusTvLan:
        final ip = dev.credentials['ip'];
        return ip != null && ip.isNotEmpty && !ip.startsWith('127.') && !dev.id.contains('test');

      case ConnectionProtocol.philipsHueLocal:
        final bridgeIp = dev.credentials['bridgeIp'] ?? linkedHueBridgeIp;
        final username = dev.credentials['username'] ?? linkedHueUsername;
        return bridgeIp != null && bridgeIp.isNotEmpty && username != null && username.isNotEmpty;

      case ConnectionProtocol.philipsWizUdp:
        final ip = dev.credentials['ip'];
        return ip != null && ip.isNotEmpty && !ip.startsWith('127.');

      case ConnectionProtocol.rtspOnvifCamera:
        final ip = dev.credentials['ip'] ?? dev.credentials['rtspUrl'];
        return ip != null && ip.isNotEmpty && !ip.toLowerCase().contains('demo');

      default:
        return false;
    }
  }

  // 1. updateWasher
  void updateWasher(String id, {String? cycle, int? waterTemp, String? spinSpeed, bool? steam}) {
    final idx = _devices.indexWhere((d) => d.id == id);
    if (idx == -1) return;
    final dev = _devices[idx];
    final prevAttrs = Map<String, dynamic>.from(dev.liveAttributes);
    final prevWatts = dev.liveWatts;

    final attrs = Map<String, dynamic>.from(dev.liveAttributes);
    if (cycle != null) attrs['cycle'] = cycle;
    if (waterTemp != null) attrs['waterTemperature'] = waterTemp;
    if (spinSpeed != null) attrs['spinSpeed'] = spinSpeed;
    if (steam != null) attrs['steam'] = steam;
    dev.liveAttributes = attrs;
    _controller.computeDeviceLiveWattage(dev);
    _saveState();
    notifyListeners();

    if (!_isHardwareExecutable(dev)) return;

    unawaited(() async {
      try {
        if (cycle != null) await _controller.executeDeviceCommand(dev, 'custom.washerCycle', 'setWasherCycle', [cycle]);
        if (waterTemp != null) await _controller.executeDeviceCommand(dev, 'custom.washerWaterTemperature', 'setWasherWaterTemperature', ['$waterTemp°C']);
        if (spinSpeed != null) await _controller.executeDeviceCommand(dev, 'washerSpinSpeed', 'setWasherSpinSpeed', [spinSpeed]);
      } catch (e) {
        dev.liveAttributes = prevAttrs;
        dev.liveWatts = prevWatts;
        _controller.computeDeviceLiveWattage(dev);
        lastGlobalError = e.toString().replaceAll('Exception: ', '');
        await _saveState();
        notifyListeners();
      }
    }());
  }

  // 2. updateSamsungWasher
  void updateSamsungWasher(
    String id, {
    String? cycle,
    int? waterTemp,
    String? waterTempStr,
    String? spinSpeed,
    bool? ecoBubble,
    bool? superSpeed,
    bool? aiWash,
    bool? addWashDoorLocked,
    String? recommendedRecipe,
    String? stage,
    int? remainingMinutes,
    int? rinseCount,
    bool? autoCycleLink,
    int? detergentPercent,
    int? softenerPercent,
    int? drumCleanCount,
  }) {
    final idx = _devices.indexWhere((d) => d.id == id);
    if (idx == -1) return;
    final dev = _devices[idx];
    final prevAttrs = Map<String, dynamic>.from(dev.liveAttributes);
    final prevWatts = dev.liveWatts;

    final attrs = Map<String, dynamic>.from(dev.liveAttributes);
    if (cycle != null) attrs['cycle'] = cycle;
    if (waterTemp != null) attrs['waterTemperature'] = waterTemp;
    if (waterTempStr != null) attrs['waterTemp'] = waterTempStr;
    if (spinSpeed != null) attrs['spinSpeed'] = spinSpeed;
    if (ecoBubble != null) attrs['ecoBubble'] = ecoBubble;
    if (superSpeed != null) attrs['superSpeed'] = superSpeed;
    if (aiWash != null) attrs['aiWash'] = aiWash;
    if (addWashDoorLocked != null) attrs['addWashDoorLocked'] = addWashDoorLocked;
    if (recommendedRecipe != null) attrs['recommendedRecipe'] = recommendedRecipe;
    if (stage != null) attrs['stage'] = stage;
    if (remainingMinutes != null) attrs['remainingMinutes'] = remainingMinutes;
    if (rinseCount != null) attrs['rinseCount'] = rinseCount;
    if (autoCycleLink != null) attrs['autoCycleLink'] = autoCycleLink;
    if (detergentPercent != null) attrs['detergentPercent'] = detergentPercent;
    if (softenerPercent != null) attrs['softenerPercent'] = softenerPercent;
    if (drumCleanCount != null) attrs['drumCleanCount'] = drumCleanCount;
    dev.liveAttributes = attrs;
    _controller.computeDeviceLiveWattage(dev);
    _saveState();
    notifyListeners();

    if (!_isHardwareExecutable(dev)) return;

    unawaited(() async {
      try {
        if (cycle != null) await _controller.executeDeviceCommand(dev, 'custom.washerCycle', 'setWasherCycle', [cycle]);
        if (waterTempStr != null || waterTemp != null) {
          await _controller.executeDeviceCommand(dev, 'custom.washerWaterTemperature', 'setWasherWaterTemperature', [waterTempStr ?? '$waterTemp°C']);
        }
        if (spinSpeed != null) await _controller.executeDeviceCommand(dev, 'washerSpinSpeed', 'setWasherSpinSpeed', [spinSpeed]);
        if (ecoBubble != null) await _controller.executeDeviceCommand(dev, 'custom.washerEcoBubble', 'setEcoBubble', [ecoBubble ? 'on' : 'off']);
        if (superSpeed != null) await _controller.executeDeviceCommand(dev, 'custom.washerSuperSpeed', 'setSuperSpeed', [superSpeed ? 'on' : 'off']);
        if (aiWash != null) await _controller.executeDeviceCommand(dev, 'custom.washerAiWash', 'setAiWash', [aiWash ? 'on' : 'off']);
        if (stage != null) await _controller.executeDeviceCommand(dev, 'washerOperatingState', 'setWasherJobState', [stage]);
        if (rinseCount != null) await _controller.executeDeviceCommand(dev, 'custom.washerRinseCycles', 'setRinseCycles', [rinseCount]);
      } catch (e) {
        dev.liveAttributes = prevAttrs;
        dev.liveWatts = prevWatts;
        _controller.computeDeviceLiveWattage(dev);
        lastGlobalError = e.toString().replaceAll('Exception: ', '');
        await _saveState();
        notifyListeners();
      }
    }());
  }

  // 3. setDevicePrimaryValue
  void setDevicePrimaryValue(String id, double val) {
    final idx = _devices.indexWhere((d) => d.id == id);
    if (idx == -1) return;
    final dev = _devices[idx];
    final prevVal = dev.primaryValue;
    final prevWatts = dev.liveWatts;

    dev.primaryValue = val;
    _controller.computeDeviceLiveWattage(dev);
    _saveState();
    notifyListeners();

    if (!_isHardwareExecutable(dev)) return;

    _applianceDebounceTimers[dev.id]?.cancel();
    _applianceDebounceTimers[dev.id] = Timer(const Duration(milliseconds: 300), () async {
      try {
        await _controller.setPrimaryLevel(dev, val);
      } catch (e) {
        dev.primaryValue = prevVal;
        dev.liveWatts = prevWatts;
        _controller.computeDeviceLiveWattage(dev);
        lastGlobalError = e.toString().replaceAll('Exception: ', '');
        await _saveState();
        notifyListeners();
      }
    });
  }

  // 4. updateSamsungAc
  void updateSamsungAc(
    String id, {
    double? targetTemp,
    bool? windFree,
    bool? goodSleep,
    int? pm1AirQuality,
    bool? aiEnergyMode,
  }) {
    final idx = _devices.indexWhere((d) => d.id == id);
    if (idx == -1) return;
    final dev = _devices[idx];
    final prevAttrs = Map<String, dynamic>.from(dev.liveAttributes);
    final prevPrimaryValue = dev.primaryValue;
    final prevWatts = dev.liveWatts;

    if (targetTemp != null) dev.primaryValue = targetTemp;
    final attrs = Map<String, dynamic>.from(dev.liveAttributes);
    if (windFree != null) attrs['windFree'] = windFree;
    if (goodSleep != null) attrs['goodSleep'] = goodSleep;
    if (pm1AirQuality != null) attrs['pm1AirQuality'] = pm1AirQuality;
    if (aiEnergyMode != null) attrs['aiEnergyMode'] = aiEnergyMode;
    dev.liveAttributes = attrs;
    _controller.computeDeviceLiveWattage(dev);
    _saveState();
    notifyListeners();

    if (!_isHardwareExecutable(dev)) return;

    _applianceDebounceTimers[dev.id]?.cancel();
    _applianceDebounceTimers[dev.id] = Timer(const Duration(milliseconds: 300), () async {
      try {
        if (targetTemp != null) {
          await _controller.executeDeviceCommand(dev, 'thermostatCoolingSetpoint', 'setCoolingSetpoint', [targetTemp.round()]);
        }
        if (windFree != null) {
          await _controller.executeDeviceCommand(dev, 'custom.airConditionerOptionalMode', 'setAirConditionerOptionalMode', [windFree ? 'windFree' : 'off']);
        }
        if (goodSleep != null) {
          await _controller.executeDeviceCommand(dev, 'custom.airConditionerOptionalMode', 'setAirConditionerOptionalMode', [goodSleep ? 'sleep' : 'off']);
        }
        if (aiEnergyMode != null) {
          await _controller.executeDeviceCommand(dev, 'samsungce.energySavingOperation', 'setEnergySavingOperation', [aiEnergyMode ? 'on' : 'off']);
        }
      } catch (e) {
        dev.liveAttributes = prevAttrs;
        dev.primaryValue = prevPrimaryValue;
        dev.liveWatts = prevWatts;
        _controller.computeDeviceLiveWattage(dev);
        lastGlobalError = e.toString().replaceAll('Exception: ', '');
        await _saveState();
        notifyListeners();
      }
    });
  }

  // 5. updateSamsungFridge
  void updateSamsungFridge(
    String id, {
    double? fridgeTemp,
    double? freezerTemp,
    String? flexZoneMode,
    bool? powerCool,
    bool? powerFreeze,
    bool? iceBites,
  }) {
    final idx = _devices.indexWhere((d) => d.id == id);
    if (idx == -1) return;
    final dev = _devices[idx];
    final prevAttrs = Map<String, dynamic>.from(dev.liveAttributes);
    final prevWatts = dev.liveWatts;

    final attrs = Map<String, dynamic>.from(dev.liveAttributes);
    if (fridgeTemp != null) attrs['fridgeTemp'] = fridgeTemp;
    if (freezerTemp != null) attrs['freezerTemp'] = freezerTemp;
    if (flexZoneMode != null) attrs['flexZoneMode'] = flexZoneMode;
    if (powerCool != null) attrs['powerCool'] = powerCool;
    if (powerFreeze != null) attrs['powerFreeze'] = powerFreeze;
    if (iceBites != null) attrs['iceBites'] = iceBites;
    dev.liveAttributes = attrs;
    _controller.computeDeviceLiveWattage(dev);
    _saveState();
    notifyListeners();

    if (!_isHardwareExecutable(dev)) return;

    unawaited(() async {
      try {
        if (fridgeTemp != null) await _controller.executeDeviceCommand(dev, 'custom.fridgeSetpoint', 'setFridgeTemperature', [fridgeTemp.round()]);
        if (freezerTemp != null) await _controller.executeDeviceCommand(dev, 'custom.freezerSetpoint', 'setFreezerTemperature', [freezerTemp.round()]);
        if (flexZoneMode != null) await _controller.executeDeviceCommand(dev, 'custom.fridgeFlexZone', 'setFlexZoneMode', [flexZoneMode]);
        if (powerCool != null) await _controller.executeDeviceCommand(dev, 'custom.fridgePowerCool', 'setPowerCool', [powerCool ? 'on' : 'off']);
        if (powerFreeze != null) await _controller.executeDeviceCommand(dev, 'custom.fridgePowerFreeze', 'setPowerFreeze', [powerFreeze ? 'on' : 'off']);
        if (iceBites != null) await _controller.executeDeviceCommand(dev, 'custom.iceMaker', 'setIceMakerMode', [iceBites ? 'iceBites' : 'off']);
      } catch (e) {
        dev.liveAttributes = prevAttrs;
        dev.liveWatts = prevWatts;
        _controller.computeDeviceLiveWattage(dev);
        lastGlobalError = e.toString().replaceAll('Exception: ', '');
        await _saveState();
        notifyListeners();
      }
    }());
  }

  // 6. updateSamsungTv
  void updateSamsungTv(
    String id, {
    bool? artMode,
    bool? lightSync,
    String? selectedArtwork,
  }) {
    final idx = _devices.indexWhere((d) => d.id == id);
    if (idx == -1) return;
    final dev = _devices[idx];
    final prevAttrs = Map<String, dynamic>.from(dev.liveAttributes);
    final prevWatts = dev.liveWatts;

    final attrs = Map<String, dynamic>.from(dev.liveAttributes);
    if (artMode != null) attrs['artMode'] = artMode;
    if (lightSync != null) attrs['lightSync'] = lightSync;
    if (selectedArtwork != null) attrs['selectedArtwork'] = selectedArtwork;
    dev.liveAttributes = attrs;
    _controller.computeDeviceLiveWattage(dev);
    _saveState();
    notifyListeners();

    if (!_isHardwareExecutable(dev)) return;

    unawaited(() async {
      try {
        if (artMode != null) await _controller.executeDeviceCommand(dev, 'custom.artMode', 'setArtMode', [artMode ? 'on' : 'off']);
        if (lightSync != null) await _controller.executeDeviceCommand(dev, 'custom.lightSync', 'setLightSync', [lightSync ? 'on' : 'off']);
        if (selectedArtwork != null) await _controller.executeDeviceCommand(dev, 'custom.artMode', 'selectArtwork', [selectedArtwork]);
      } catch (e) {
        dev.liveAttributes = prevAttrs;
        dev.liveWatts = prevWatts;
        _controller.computeDeviceLiveWattage(dev);
        lastGlobalError = e.toString().replaceAll('Exception: ', '');
        await _saveState();
        notifyListeners();
      }
    }());
  }

  // 7. updateTv
  void updateTv(String id, {String? app, int? volume, String? pictureMode}) {
    final idx = _devices.indexWhere((d) => d.id == id);
    if (idx == -1) return;
    final dev = _devices[idx];
    final prevAttrs = Map<String, dynamic>.from(dev.liveAttributes);
    final prevWatts = dev.liveWatts;

    final attrs = Map<String, dynamic>.from(dev.liveAttributes);
    if (app != null) attrs['currentApp'] = app;
    if (volume != null) attrs['volume'] = volume;
    if (pictureMode != null) attrs['pictureMode'] = pictureMode;
    dev.liveAttributes = attrs;
    _controller.computeDeviceLiveWattage(dev);
    _saveState();
    notifyListeners();

    if (!_isHardwareExecutable(dev)) return;

    unawaited(() async {
      try {
        if (app != null) await _controller.executeDeviceCommand(dev, 'mediaPlayback', 'launchApp', [app]);
        if (volume != null) await _controller.executeDeviceCommand(dev, 'audioVolume', 'setVolume', [volume]);
        if (pictureMode != null) await _controller.executeDeviceCommand(dev, 'custom.pictureMode', 'setPictureMode', [pictureMode]);
      } catch (e) {
        dev.liveAttributes = prevAttrs;
        dev.liveWatts = prevWatts;
        _controller.computeDeviceLiveWattage(dev);
        lastGlobalError = e.toString().replaceAll('Exception: ', '');
        await _saveState();
        notifyListeners();
      }
    }());
  }

  // 8. updateWiproBulb
  void updateWiproBulb(String id, {double? brightness, Color? color, int? colorTempKelvin, String? scene, bool? musicSync}) {
    final idx = _devices.indexWhere((d) => d.id == id);
    if (idx == -1) return;
    final dev = _devices[idx];
    final prevAttrs = Map<String, dynamic>.from(dev.liveAttributes);
    final prevPrimaryValue = dev.primaryValue;
    final prevWatts = dev.liveWatts;

    if (brightness != null) dev.primaryValue = (brightness * 100.0).clamp(0.0, 100.0);
    final attrs = Map<String, dynamic>.from(dev.liveAttributes);
    if (scene != null) attrs['activeScene'] = scene;
    if (musicSync != null) attrs['musicSync'] = musicSync;
    if (color != null) attrs['color'] = color.value.toRadixString(16);
    if (colorTempKelvin != null) attrs['colorTempKelvin'] = colorTempKelvin;
    dev.liveAttributes = attrs;
    _controller.computeDeviceLiveWattage(dev);
    _saveState();
    notifyListeners();

    if (!_isHardwareExecutable(dev)) return;

    _applianceDebounceTimers[dev.id]?.cancel();
    _applianceDebounceTimers[dev.id] = Timer(const Duration(milliseconds: 250), () async {
      try {
        if (dev.protocol == ConnectionProtocol.tuyaLocalLan) {
          final Map<String, dynamic> dps = {'20': dev.isOn};
          if (brightness != null) {
            dps['21'] = 'white';
            dps['22'] = (brightness * 1000).round().clamp(10, 1000);
          }
          if (colorTempKelvin != null) {
            dps['21'] = 'white';
            dps['23'] = ((colorTempKelvin - 2700) / (6500 - 2700) * 1000).round().clamp(0, 1000);
          }
          if (color != null) {
            final hsv = HSVColor.fromColor(color);
            final hHex = hsv.hue.round().toRadixString(16).padLeft(4, '0');
            final sHex = (hsv.saturation * 1000).round().toRadixString(16).padLeft(4, '0');
            final vHex = (hsv.value * 1000).round().toRadixString(16).padLeft(4, '0');
            dps['21'] = 'colour';
            dps['24'] = '$hHex$sHex$vHex';
          }
          if (scene != null) {
            dps['21'] = 'scene';
            dps['25'] = scene;
          }
          if (musicSync != null) {
            dps['21'] = musicSync ? 'music' : 'white';
            dps['26'] = musicSync ? '0100000000' : '00';
          }
          await _controller.sendTuyaLocalDps(dev, dps);
        } else if (dev.protocol == ConnectionProtocol.tuyaCloudDirect) {
          if (brightness != null) await _controller.setPrimaryLevel(dev, dev.primaryValue);
        }
      } catch (e) {
        dev.liveAttributes = prevAttrs;
        dev.primaryValue = prevPrimaryValue;
        dev.liveWatts = prevWatts;
        _controller.computeDeviceLiveWattage(dev);
        lastGlobalError = e.toString().replaceAll('Exception: ', '');
        await _saveState();
        notifyListeners();
      }
    });
  }

  // 9. updateLgAc
  void updateLgAc(String id, {double? targetTemp, String? fanSpeed, bool? jetCool}) {
    final idx = _devices.indexWhere((d) => d.id == id);
    if (idx == -1) return;
    final dev = _devices[idx];
    final prevAttrs = Map<String, dynamic>.from(dev.liveAttributes);
    final prevPrimaryValue = dev.primaryValue;
    final prevWatts = dev.liveWatts;

    if (targetTemp != null) dev.primaryValue = targetTemp;
    final attrs = Map<String, dynamic>.from(dev.liveAttributes);
    if (fanSpeed != null) attrs['fanSpeed'] = fanSpeed;
    if (jetCool != null) attrs['jetCool'] = jetCool;
    dev.liveAttributes = attrs;
    _controller.computeDeviceLiveWattage(dev);
    _saveState();
    notifyListeners();

    if (!_isHardwareExecutable(dev)) return;

    _applianceDebounceTimers[dev.id]?.cancel();
    _applianceDebounceTimers[dev.id] = Timer(const Duration(milliseconds: 300), () async {
      try {
        await zeroTouch.controlLgAirConditioner(
          device: dev,
          targetCelsius: targetTemp,
          jetCoolMode: jetCool,
          patTokenOverride: linkedLgThinqPat,
        );
      } catch (e) {
        dev.liveAttributes = prevAttrs;
        dev.primaryValue = prevPrimaryValue;
        dev.liveWatts = prevWatts;
        _controller.computeDeviceLiveWattage(dev);
        lastGlobalError = e.toString().replaceAll('Exception: ', '');
        await _saveState();
        notifyListeners();
      }
    });
  }

  // 10. updateLgWashTower
  void updateLgWashTower(
    String id, {
    bool? turboWash360,
    int? ezDispenseDetergent,
    int? ezDispenseSoftener,
    bool? steamPlus,
    bool? smartPairing,
    String? stage,
    int? remainingMinutes,
    String? dryLevel,
    int? dryerRemainingMinutes,
    String? dryerStage,
  }) {
    final idx = _devices.indexWhere((d) => d.id == id);
    if (idx == -1) return;
    final dev = _devices[idx];
    final prevAttrs = Map<String, dynamic>.from(dev.liveAttributes);
    final prevWatts = dev.liveWatts;

    final attrs = Map<String, dynamic>.from(dev.liveAttributes);
    if (turboWash360 != null) attrs['turboWash360'] = turboWash360;
    if (ezDispenseDetergent != null) attrs['ezDispenseDetergent'] = ezDispenseDetergent;
    if (ezDispenseSoftener != null) attrs['ezDispenseSoftener'] = ezDispenseSoftener;
    if (steamPlus != null) attrs['steamPlus'] = steamPlus;
    if (smartPairing != null) attrs['smartPairing'] = smartPairing;
    if (stage != null) attrs['stage'] = stage;
    if (remainingMinutes != null) attrs['remainingMinutes'] = remainingMinutes;
    if (dryLevel != null) attrs['dryLevel'] = dryLevel;
    if (dryerRemainingMinutes != null) attrs['dryerRemainingMinutes'] = dryerRemainingMinutes;
    if (dryerStage != null) attrs['dryerStage'] = dryerStage;
    dev.liveAttributes = attrs;
    _controller.computeDeviceLiveWattage(dev);
    _saveState();
    notifyListeners();

    if (!_isHardwareExecutable(dev)) return;

    unawaited(() async {
      try {
        await zeroTouch.controlLgWashTower(
          dev,
          {
            if (turboWash360 != null) 'turboWash360': turboWash360,
            if (ezDispenseDetergent != null) 'ezDispenseDetergent': ezDispenseDetergent,
            if (ezDispenseSoftener != null) 'ezDispenseSoftener': ezDispenseSoftener,
            if (steamPlus != null) 'steamPlus': steamPlus,
            if (smartPairing != null) 'smartPairing': smartPairing,
            if (stage != null) 'stage': stage,
            if (dryLevel != null) 'dryLevel': dryLevel,
            if (dryerStage != null) 'dryerStage': dryerStage,
          },
          patTokenOverride: linkedLgThinqPat,
        );
      } catch (e) {
        dev.liveAttributes = prevAttrs;
        dev.liveWatts = prevWatts;
        _controller.computeDeviceLiveWattage(dev);
        lastGlobalError = e.toString().replaceAll('Exception: ', '');
        await _saveState();
        notifyListeners();
      }
    }());
  }

  // 11. updateLgFridge
  void updateLgFridge(
    String id, {
    bool? instaViewTransparent,
    bool? craftIce,
    bool? doorCooling,
    String? hygieneFresh,
    bool? expressFreeze,
    bool? expressCool,
    double? fridgeTemp,
    double? freezerTemp,
  }) {
    final idx = _devices.indexWhere((d) => d.id == id);
    if (idx == -1) return;
    final dev = _devices[idx];
    final prevAttrs = Map<String, dynamic>.from(dev.liveAttributes);
    final prevWatts = dev.liveWatts;

    final attrs = Map<String, dynamic>.from(dev.liveAttributes);
    if (instaViewTransparent != null) attrs['instaViewTransparent'] = instaViewTransparent;
    if (craftIce != null) attrs['craftIce'] = craftIce;
    if (doorCooling != null) attrs['doorCooling'] = doorCooling;
    if (hygieneFresh != null) attrs['hygieneFresh'] = hygieneFresh;
    if (expressFreeze != null) attrs['expressFreeze'] = expressFreeze;
    if (expressCool != null) attrs['expressCool'] = expressCool;
    if (fridgeTemp != null) attrs['fridgeTemp'] = fridgeTemp;
    if (freezerTemp != null) attrs['freezerTemp'] = freezerTemp;
    dev.liveAttributes = attrs;
    _controller.computeDeviceLiveWattage(dev);
    _saveState();
    notifyListeners();

    if (!_isHardwareExecutable(dev)) return;

    unawaited(() async {
      try {
        await zeroTouch.controlLgFridge(
          dev,
          {
            if (instaViewTransparent != null) 'instaViewTransparent': instaViewTransparent,
            if (craftIce != null) 'craftIce': craftIce,
            if (doorCooling != null) 'doorCooling': doorCooling,
            if (hygieneFresh != null) 'hygieneFresh': hygieneFresh,
            if (expressFreeze != null) 'expressFreeze': expressFreeze,
            if (expressCool != null) 'expressCool': expressCool,
            if (fridgeTemp != null) 'fridgeTemp': fridgeTemp,
            if (freezerTemp != null) 'freezerTemp': freezerTemp,
          },
          patTokenOverride: linkedLgThinqPat,
        );
      } catch (e) {
        dev.liveAttributes = prevAttrs;
        dev.liveWatts = prevWatts;
        _controller.computeDeviceLiveWattage(dev);
        lastGlobalError = e.toString().replaceAll('Exception: ', '');
        await _saveState();
        notifyListeners();
      }
    }());
  }

  // 12. updateLgAeroTower
  void updateLgAeroTower(
    String id, {
    int? cleanBoosterTilt,
    String? airflowMode,
    bool? uvNano,
    int? pm1Laser,
    bool? petCare,
  }) {
    final idx = _devices.indexWhere((d) => d.id == id);
    if (idx == -1) return;
    final dev = _devices[idx];
    final prevAttrs = Map<String, dynamic>.from(dev.liveAttributes);
    final prevWatts = dev.liveWatts;

    final attrs = Map<String, dynamic>.from(dev.liveAttributes);
    if (cleanBoosterTilt != null) attrs['cleanBoosterTilt'] = cleanBoosterTilt;
    if (airflowMode != null) attrs['airflowMode'] = airflowMode;
    if (uvNano != null) attrs['uvNano'] = uvNano;
    if (pm1Laser != null) attrs['pm1Laser'] = pm1Laser;
    if (petCare != null) attrs['petCare'] = petCare;
    dev.liveAttributes = attrs;
    _controller.computeDeviceLiveWattage(dev);
    _saveState();
    notifyListeners();

    if (!_isHardwareExecutable(dev)) return;

    unawaited(() async {
      try {
        await zeroTouch.controlLgAeroTower(
          dev,
          {
            if (cleanBoosterTilt != null) 'cleanBoosterTilt': cleanBoosterTilt,
            if (airflowMode != null) 'airflowMode': airflowMode,
            if (uvNano != null) 'uvNano': uvNano,
            if (petCare != null) 'petCare': petCare,
          },
          patTokenOverride: linkedLgThinqPat,
        );
      } catch (e) {
        dev.liveAttributes = prevAttrs;
        dev.liveWatts = prevWatts;
        _controller.computeDeviceLiveWattage(dev);
        lastGlobalError = e.toString().replaceAll('Exception: ', '');
        await _saveState();
        notifyListeners();
      }
    }());
  }

  // 13. updateLgStyler
  void updateLgStyler(
    String id, {
    String? movingHangerSpeed,
    int? movingHangerRpm,
    bool? trueSteam,
    bool? pantsCrease,
    bool? gentleDry,
    String? stylerCourse,
  }) {
    final idx = _devices.indexWhere((d) => d.id == id);
    if (idx == -1) return;
    final dev = _devices[idx];
    final prevAttrs = Map<String, dynamic>.from(dev.liveAttributes);
    final prevWatts = dev.liveWatts;

    final attrs = Map<String, dynamic>.from(dev.liveAttributes);
    if (movingHangerSpeed != null) attrs['movingHangerSpeed'] = movingHangerSpeed;
    if (movingHangerRpm != null) attrs['movingHangerRpm'] = movingHangerRpm;
    if (trueSteam != null) attrs['trueSteam'] = trueSteam;
    if (pantsCrease != null) attrs['pantsCrease'] = pantsCrease;
    if (gentleDry != null) attrs['gentleDry'] = gentleDry;
    if (stylerCourse != null) attrs['stylerCourse'] = stylerCourse;
    dev.liveAttributes = attrs;
    _controller.computeDeviceLiveWattage(dev);
    _saveState();
    notifyListeners();

    if (!_isHardwareExecutable(dev)) return;

    unawaited(() async {
      try {
        await zeroTouch.controlLgStyler(
          dev,
          {
            if (movingHangerSpeed != null) 'movingHangerSpeed': movingHangerSpeed,
            if (movingHangerRpm != null) 'movingHangerRpm': movingHangerRpm,
            if (trueSteam != null) 'trueSteam': trueSteam,
            if (pantsCrease != null) 'pantsCrease': pantsCrease,
            if (gentleDry != null) 'gentleDry': gentleDry,
            if (stylerCourse != null) 'stylerCourse': stylerCourse,
          },
          patTokenOverride: linkedLgThinqPat,
        );
      } catch (e) {
        dev.liveAttributes = prevAttrs;
        dev.liveWatts = prevWatts;
        _controller.computeDeviceLiveWattage(dev);
        lastGlobalError = e.toString().replaceAll('Exception: ', '');
        await _saveState();
        notifyListeners();
      }
    }());
  }

  // 14. updateLgDishwasher
  void updateLgDishwasher(
    String id, {
    String? quadWashArmPressure,
    bool? trueSteamDishwash,
    bool? autoDoorOpen,
    String? dishwasherCourse,
  }) {
    final idx = _devices.indexWhere((d) => d.id == id);
    if (idx == -1) return;
    final dev = _devices[idx];
    final prevAttrs = Map<String, dynamic>.from(dev.liveAttributes);
    final prevWatts = dev.liveWatts;

    final attrs = Map<String, dynamic>.from(dev.liveAttributes);
    if (quadWashArmPressure != null) attrs['quadWashArmPressure'] = quadWashArmPressure;
    if (trueSteamDishwash != null) attrs['trueSteamDishwash'] = trueSteamDishwash;
    if (autoDoorOpen != null) attrs['autoDoorOpen'] = autoDoorOpen;
    if (dishwasherCourse != null) attrs['dishwasherCourse'] = dishwasherCourse;
    dev.liveAttributes = attrs;
    _controller.computeDeviceLiveWattage(dev);
    _saveState();
    notifyListeners();

    if (!_isHardwareExecutable(dev)) return;

    unawaited(() async {
      try {
        await zeroTouch.controlLgDishwasher(
          dev,
          {
            if (quadWashArmPressure != null) 'quadWashArmPressure': quadWashArmPressure,
            if (trueSteamDishwash != null) 'trueSteamDishwash': trueSteamDishwash,
            if (autoDoorOpen != null) 'autoDoorOpen': autoDoorOpen,
            if (dishwasherCourse != null) 'dishwasherCourse': dishwasherCourse,
          },
          patTokenOverride: linkedLgThinqPat,
        );
      } catch (e) {
        dev.liveAttributes = prevAttrs;
        dev.liveWatts = prevWatts;
        _controller.computeDeviceLiveWattage(dev);
        lastGlobalError = e.toString().replaceAll('Exception: ', '');
        await _saveState();
        notifyListeners();
      }
    }());
  }

  // 15. triggerLgThinqUp
  void triggerLgThinqUp(String id, {required String installedFeature}) {
    final idx = _devices.indexWhere((d) => d.id == id);
    if (idx == -1) return;
    final dev = _devices[idx];
    final prevAttrs = Map<String, dynamic>.from(dev.liveAttributes);
    final prevWatts = dev.liveWatts;

    final attrs = Map<String, dynamic>.from(dev.liveAttributes);
    attrs['thinqUpUpdate'] = false;
    attrs['thinqUpInstalledFeature'] = installedFeature;
    dev.liveAttributes = attrs;
    _controller.computeDeviceLiveWattage(dev);
    _saveState();
    notifyListeners();

    if (!_isHardwareExecutable(dev)) return;

    unawaited(() async {
      try {
        await zeroTouch.activateLgThinqUpFeature(
          dev,
          installedFeature,
          patTokenOverride: linkedLgThinqPat,
        );
      } catch (e) {
        dev.liveAttributes = prevAttrs;
        dev.liveWatts = prevWatts;
        _controller.computeDeviceLiveWattage(dev);
        lastGlobalError = e.toString().replaceAll('Exception: ', '');
        await _saveState();
        notifyListeners();
      }
    }());
  }


  // ---------------------------------------------------------------------------
  // IMPORT & PAIRING METHODS
  // ---------------------------------------------------------------------------
  Future<int> linkSmartThingsAccount(String patToken) async {
    isBusy = true;
    lastGlobalError = null;
    notifyListeners();
    try {
      linkedSmartThingsPat = patToken;
      final found = await _controller.discoverSmartThingsDevices(patToken);
      for (final d in found) {
        _devices.removeWhere((existing) => existing.id == d.id);
        _devices.add(d);
      }
      await _saveState();
      return found.length;
    } catch (e) {
      lastGlobalError = e.toString().replaceAll('Exception: ', '');
      rethrow;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<int> linkHomeAssistantHub(String hubUrl, String token) async {
    isBusy = true;
    lastGlobalError = null;
    notifyListeners();
    try {
      linkedHomeAssistantHubUrl = hubUrl;
      linkedHomeAssistantToken = token;
      final found = await _controller.discoverHomeAssistantDevices(hubUrl, token);
      for (final d in found) {
        _devices.removeWhere((existing) => existing.id == d.id);
        _devices.add(d);
      }
      await _saveState();
      return found.length;
    } catch (e) {
      lastGlobalError = e.toString().replaceAll('Exception: ', '');
      rethrow;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<int> linkLgThinqAccount(String patToken, {String countryCode = 'IN'}) async {
    isBusy = true;
    lastGlobalError = null;
    notifyListeners();
    try {
      linkedLgThinqPat = patToken;
      final found = await zeroTouch.discoverLgThinqDevices(
        patToken: patToken,
        countryCode: countryCode,
      );
      for (final d in found) {
        _devices.removeWhere((existing) => existing.id == d.id);
        _devices.add(d);
      }
      await _saveState();
      return found.length;
    } catch (e) {
      lastGlobalError = e.toString().replaceAll('Exception: ', '');
      rethrow;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<int> autoHarvestWiproKeys({
    required String accessId,
    required String accessSecret,
    required String sampleDeviceId,
  }) async {
    isBusy = true;
    lastGlobalError = null;
    notifyListeners();
    try {
      final found = await zeroTouch.autoHarvestWiproTuyaKeys(
        accessId: accessId,
        accessSecret: accessSecret,
        sampleDeviceId: sampleDeviceId,
      );
      for (final d in found) {
        _devices.removeWhere((existing) => existing.id == d.id);
        _devices.add(d);
      }
      await _saveState();
      return found.length;
    } catch (e) {
      lastGlobalError = e.toString().replaceAll('Exception: ', '');
      rethrow;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<int> linkWiproSmartLifeAccount({
    required String username,
    required String password,
    String countryCode = '91',
    String bizType = 'smart_life',
  }) async {
    isBusy = true;
    lastGlobalError = null;
    notifyListeners();
    try {
      final found = await _controller.discoverWiproOrSmartLifeCloudDevices(
        username: username,
        password: password,
        countryCode: countryCode,
        bizType: bizType,
      );
      for (final d in found) {
        _devices.removeWhere((existing) => existing.id == d.id);
        _devices.add(d);
      }
      await _saveState();
      return found.length;
    } catch (e) {
      lastGlobalError = e.toString().replaceAll('Exception: ', '');
      rethrow;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<List<String>> discoverHueBridgeIps() => _controller.discoverHueBridgeIps();

  Future<String> pairHueBridge(String bridgeIp) => _controller.pairHueBridge(bridgeIp: bridgeIp);

  Future<int> linkPhilipsHueBridge({
    required String bridgeIp,
    required String username,
  }) async {
    isBusy = true;
    lastGlobalError = null;
    notifyListeners();
    try {
      linkedHueBridgeIp = bridgeIp;
      linkedHueUsername = username;
      final found = await _controller.discoverHueLights(
        bridgeIp: bridgeIp,
        username: username,
      );
      for (final d in found) {
        _devices.removeWhere((existing) => existing.id == d.id);
        _devices.add(d);
      }
      await _saveState();
      return found.length;
    } catch (e) {
      lastGlobalError = e.toString().replaceAll('Exception: ', '');
      rethrow;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<int> scanAndLinkWiproLanBulbs({String subnet = '192.168.1.'}) async {
    isBusy = true;
    lastGlobalError = null;
    notifyListeners();
    try {
      final found = await _controller.discoverLocalWiproBulbs(subnet: subnet);
      for (final d in found) {
        _devices.removeWhere((existing) => existing.id == d.id);
        _devices.add(d);
      }
      await _saveState();
      return found.length;
    } catch (e) {
      lastGlobalError = e.toString().replaceAll('Exception: ', '');
      rethrow;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<int> linkPhilipsWizLights({String subnet = '192.168.1.'}) async {
    isBusy = true;
    lastGlobalError = null;
    notifyListeners();
    try {
      final found = await _controller.discoverWizLights(subnet: subnet);
      for (final d in found) {
        _devices.removeWhere((existing) => existing.id == d.id);
        _devices.add(d);
      }
      await _saveState();
      return found.length;
    } catch (e) {
      lastGlobalError = e.toString().replaceAll('Exception: ', '');
      rethrow;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<RealSmartDevice> linkRtspCamera({
    required String brand,
    required String ip,
    String port = '554',
    String username = 'admin',
    String password = '',
    String customStreamPath = '',
    String room = 'Living Room',
    String? customName,
  }) async {
    isBusy = true;
    lastGlobalError = null;
    notifyListeners();
    try {
      final cam = await _controller.probeAndPairCamera(
        brand: brand,
        ip: ip,
        port: port,
        username: username,
        password: password,
        customStreamPath: customStreamPath,
        room: room,
        customName: customName,
      );
      _devices.removeWhere((existing) => existing.id == cam.id);
      _devices.add(cam);
      await _saveState();
      return cam;
    } catch (e) {
      lastGlobalError = e.toString().replaceAll('Exception: ', '');
      rethrow;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> addDirectLanDevice(RealSmartDevice device) async {
    final sanitized = sanitizeDeviceCredentials(device);
    isBusy = true;
    lastGlobalError = null;
    notifyListeners();
    try {
      await _controller.refreshDeviceStatus(sanitized);
      _devices.removeWhere((d) => d.id == sanitized.id);
      _devices.add(sanitized);
      await _saveState();
    } catch (e) {
      lastGlobalError = 'Could not reach ${sanitized.name} at ${sanitized.credentials['ip']}: $e';
      rethrow;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  void addDeviceDirect(RealSmartDevice device) {
    final sanitized = sanitizeDeviceCredentials(device);
    if (sanitized.liveWatts == 0.0) {
      _controller.computeDeviceLiveWattage(sanitized);
    }
    _devices.removeWhere((d) => d.id == sanitized.id);
    _devices.add(sanitized);
    _saveState();
    notifyListeners();
  }

  /// Exposes the leaving-home power-off logic for unit tests without requiring
  /// a real OS bridge. Devices in the [exemptCategories] set are preserved.
  @visibleForTesting
  Future<void> simulatePresenceDeparture() async {
    const exemptCategories = {'fridge', 'camera', 'washer'};
    for (final d
        in List<RealSmartDevice>.from(
          _devices.where((d) => d.isOn && !exemptCategories.contains(d.category)),
        )) {
      try {
        await toggleDevicePower(d);
      } catch (_) {}
    }
  }

  /// Exposes the time-automation evaluation loop for unit tests without
  /// starting the real polling timer.
  @visibleForTesting
  Future<void> evaluateTimeAutomationsForTesting() =>
      _evaluateTimeAutomations();

  Future<void> clearAllDevices() async {
    _devices.clear();
    _hasExplicitlyClearedDevices = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('unified_home_paired_devices_v4', '[]');
    await prefs.setString('real_devices_v2', '[]');
    await _saveState();
    notifyListeners();
  }

  Future<void> loadSampleSmartHome() async {
    _hasExplicitlyClearedDevices = false;
    _devices.clear();
    final List<RealSmartDevice> sampleDevices = [
      RealSmartDevice(
        id: 'samsung_washer_ecobubble_01',
        name: 'Samsung AI Ecobubble™ Washer',
        room: 'Laundry',
        category: 'washer',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: const {'vendor': 'demo', 'token': 'demo_st_token', 'type': 'samsung_washer'},
        isOn: true,
        isOnline: true,
        primaryValue: 1400.0,
        liveAttributes: {
          'machineState': 'run',
          'cycle': 'AI Wash',
          'remainingMinutes': 38,
          'detergentLevel': 78,
          'softenerLevel': 62,
          'ecobubbleActive': true,
          'drumCleanCycleCount': 12,
        },
      ),
      RealSmartDevice(
        id: 'lg_ac_dualcool_01',
        name: 'LG ThinQ DualCool™ AI AC',
        room: 'Living',
        category: 'ac',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: const {'vendor': 'demo', 'token': 'demo_lg_token', 'type': 'lg_ac'},
        isOn: true,
        isOnline: true,
        primaryValue: 23.0,
        liveAttributes: {
          'mode': 'cool',
          'fanSpeed': 'auto',
          'jetCool': true,
          'goodSleep': false,
          'roomTemp': 24.5,
          'pm1_0': 12,
          'pm2_5': 18,
          'energySaving': true,
        },
      ),
      RealSmartDevice(
        id: 'samsung_ac_windfree_01',
        name: 'Samsung WindFree™ Micro-Hole AC',
        room: 'Bedroom',
        category: 'ac',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: const {'vendor': 'demo', 'token': 'demo_st_token', 'type': 'samsung_ac'},
        isOn: true,
        isOnline: true,
        primaryValue: 22.0,
        liveAttributes: {
          'mode': 'windfree',
          'fanSpeed': 'quiet',
          'goodSleep': true,
          'roomTemp': 22.8,
        },
      ),
      RealSmartDevice(
        id: 'lg_washtower_01',
        name: 'LG WashTower™ AI DirectDrive',
        room: 'Laundry',
        category: 'washer',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: const {'vendor': 'demo', 'token': 'demo_lg_token', 'type': 'lg_washtower'},
        isOn: false,
        isOnline: true,
        primaryValue: 1200.0,
        liveAttributes: {
          'turboWash360': true,
          'ezDispenseDetergent': 85,
          'ezDispenseSoftener': 90,
          'steamPlus': true,
          'smartPairing': true,
        },
      ),
      RealSmartDevice(
        id: 'samsung_fridge_familyhub_01',
        name: 'Samsung Family Hub™ Refrigerator',
        room: 'Kitchen',
        category: 'fridge',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: const {'vendor': 'demo', 'token': 'demo_st_token', 'type': 'samsung_fridge'},
        isOn: true,
        isOnline: true,
        primaryValue: 3.0,
        liveAttributes: {
          'fridgeTemp': 3.0,
          'freezerTemp': -19.0,
          'flexZoneMode': 'Beverage (1°C)',
          'doorOpen': false,
        },
      ),
      RealSmartDevice(
        id: 'samsung_tv_theframe_01',
        name: 'Samsung The Frame 65" 4K',
        room: 'Living',
        category: 'tv',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: const {'vendor': 'demo', 'token': 'demo_st_token', 'type': 'samsung_tv'},
        isOn: true,
        isOnline: true,
        primaryValue: 65.0,
        liveAttributes: {
          'artMode': true,
          'ambientLightSync': true,
          'currentArt': 'Starry Night',
        },
      ),
      RealSmartDevice(
        id: 'lg_fridge_instaview_01',
        name: 'LG InstaView™ Door-in-Door Refrigerator',
        room: 'Kitchen',
        category: 'fridge',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: const {'vendor': 'demo', 'token': 'demo_lg_token', 'type': 'lg_fridge'},
        isOn: true,
        isOnline: true,
        primaryValue: 2.0,
        liveAttributes: {
          'craftIce': true,
          'linearCooling': true,
          'pureNFresh': true,
        },
      ),
      RealSmartDevice(
        id: 'light_living_chandelier_01',
        name: 'Living Room Halo Chandelier',
        room: 'Living',
        category: 'light',
        protocol: ConnectionProtocol.homeAssistantBridge,
        credentials: const {'vendor': 'demo', 'token': 'demo_ha_token'},
        isOn: true,
        isOnline: true,
        primaryValue: 80.0,
        liveAttributes: {'colorTemp': 'warm_white'},
      ),
      RealSmartDevice(
        id: 'light_living_backlight_01',
        name: 'TV Bias Ambilight Strip',
        room: 'Living',
        category: 'light',
        protocol: ConnectionProtocol.tuyaLocalLan,
        credentials: const {'vendor': 'demo', 'ip': '192.168.1.101', 'key': 'demokey'},
        isOn: true,
        isOnline: true,
        primaryValue: 60.0,
        liveAttributes: {'color': 'cyan'},
      ),
      RealSmartDevice(
        id: 'light_bed_pendant_01',
        name: 'Bedroom Nightstand Lamp',
        room: 'Bedroom',
        category: 'light',
        protocol: ConnectionProtocol.tuyaCloudDirect,
        credentials: const {'vendor': 'demo', 'token': 'demo_wipro_token'},
        isOn: true,
        isOnline: true,
        primaryValue: 35.0,
        liveAttributes: {'colorTemp': 'amber'},
      ),
      RealSmartDevice(
        id: 'light_kitchen_island_01',
        name: 'Kitchen Island Downlights',
        room: 'Kitchen',
        category: 'light',
        protocol: ConnectionProtocol.homeAssistantBridge,
        credentials: const {'vendor': 'demo', 'token': 'demo_ha_token'},
        isOn: false,
        isOnline: true,
        primaryValue: 100.0,
        liveAttributes: {},
      ),
      RealSmartDevice(
        id: 'charger_garage_01',
        name: 'Tesla Wall Connector EV Charger',
        room: 'Garage',
        category: 'socket',
        protocol: ConnectionProtocol.homeAssistantBridge,
        credentials: const {'vendor': 'demo', 'token': 'demo_ha_token'},
        isOn: true,
        isOnline: true,
        primaryValue: 7.4,
        liveAttributes: {'power_kw': 7.4, 'charge_rate': '32A'},
      ),
    ];

    for (final dev in sampleDevices) {
      _controller.computeDeviceLiveWattage(dev);
    }
    _devices.addAll(sampleDevices);
    await _saveState();
    notifyListeners();
  }

  void notifyUi() {
    _saveState();
    notifyListeners();
  }

  Future<void> sendCameraPtzCommand(RealSmartDevice device, String direction) async {
    await _controller.sendCameraPtzCommand(device, direction);
    await _saveState();
    notifyListeners();
  }

  Future<void> removeDevice(String id) async {
    _devices.removeWhere((d) => d.id == id);
    await _saveState();
    notifyListeners();
  }

  Future<void> refreshDevice(RealSmartDevice device) async {
    isBusy = true;
    lastGlobalError = null;
    notifyListeners();
    try {
      await _controller.refreshDeviceStatus(device);
      await _checkWasherStateChange(device);
      await _saveState();
    } catch (e) {
      lastGlobalError = e.toString().replaceAll('Exception: ', '');
      rethrow;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> flashDevice(
    RealSmartDevice device, {
    int pulses = 3,
    Duration pulseDuration = const Duration(milliseconds: 800),
  }) async {
    await _controller.flashDevice(device, pulses: pulses, pulseDuration: pulseDuration);
    await _saveState();
    notifyListeners();
  }

  Future<void> executeDeviceCommand(
    RealSmartDevice device,
    String capability,
    String command, [
    List<dynamic> arguments = const [],
    String? component,
  ]) async {
    lastGlobalError = null;
    try {
      await _controller.executeDeviceCommand(device, capability, command, arguments, component);
      await _saveState();
      notifyListeners();
    } catch (e) {
      lastGlobalError = e.toString().replaceAll('Exception: ', '');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // REAL HARDWARE EXECUTION WITH OPTIMISTIC ROLLBACK & CROSS-BRAND REFLEXES
  // ---------------------------------------------------------------------------
  Future<void> toggleDevicePower(RealSmartDevice device) async {
    final previousState = device.isOn;
    final targetState = !previousState;
    lastGlobalError = null;

    // Optimistic toggle with instant UI feedback
    device.isOn = targetState;
    _controller.computeDeviceLiveWattage(device);
    notifyListeners();

    if (device.isDummy) {
      device.markOnlineSuccess();
      _controller.computeDeviceLiveWattage(device);
      await _saveState();
      return;
    }

    try {
      await _controller.setPower(device, targetState);
      device.markOnlineSuccess();
    } catch (e) {
      // Revert on network/controller failure
      device.isOn = previousState;
      _controller.computeDeviceLiveWattage(device);
      lastGlobalError = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      rethrow;
    }

    await _saveState();

    // Emit Cross-Brand Reflex Event (e.g., OnePlus TV ON -> Dim Wipro Bulbs & Quiet LG AC)
    final event = HardwareReflexEvent(
      sourceDeviceId: device.id,
      sourceCategory: device.category,
      eventType: targetState ? 'power_on' : 'power_off',
    );
    reflexBus.emitEvent(event);

    final logs = await reflexBus.evaluateReflexes(
      event: event,
      allDevices: _devices,
      executeAction: (targetDev, power, level) async {
        if (targetDev.isOn != power) {
          await _controller.setPower(targetDev, power);
        }
        if (level != null && power) {
          await _controller.setPrimaryLevel(targetDev, level);
        }
      },
    );
    if (logs.isNotEmpty) {
      reflexActivityLog.insertAll(0, logs);
      notifyListeners();
    }

    // Evaluate reactive device-state automations immediately
    await _evaluateDeviceStateAutomations(device);

    // Update Lock-Screen Live Notification if Samsung Washer is toggled
    if (device.category == 'washer') {
      if (device.isOn) {
        await osBridge.showLiveApplianceNotification(
          title: '🧺 ${device.name} Running',
          subtitle: 'EcoBubble Active • Live Telemetry Connected',
          progressPercent: 45,
        );
      } else {
        await osBridge.dismissLiveApplianceNotification();
      }
    }
  }

  Future<void> setDevicePrimaryLevel(RealSmartDevice device, double newValue) =>
      setDeviceLevel(device, newValue);

  Future<void> setDeviceLevel(RealSmartDevice device, double newValue) async {
    lastGlobalError = null;
    final previousLevel = device.primaryValue;
    final previousIsOn = device.isOn;

    // Optimistic instant slider response for smooth 60/120fps tracking
    device.primaryValue = newValue;
    if (device.normalizedCategory == 'light' || device.category == 'light') {
      device.isOn = newValue > 0;
    }
    _controller.computeDeviceLiveWattage(device);
    notifyListeners();

    if (device.isDummy) {
      device.markOnlineSuccess();
      _controller.computeDeviceLiveWattage(device);
      await _saveState();
      return;
    }

    // 250ms debouncer to avoid flooding IoT hardware with socket requests
    _levelDebounceTimers[device.id]?.cancel();
    _levelDebounceTimers[device.id] = Timer(const Duration(milliseconds: 250), () async {
      try {
        await _controller.setPrimaryLevel(device, newValue);
        device.markOnlineSuccess();
        await _saveState();
      } catch (e) {
        device.primaryValue = previousLevel;
        device.isOn = previousIsOn;
        _controller.computeDeviceLiveWattage(device);
        lastGlobalError = e.toString().replaceAll('Exception: ', '');
      } finally {
        notifyListeners();
      }
    });
  }

  // NFC & Deep-Link Execution Handler:
  Future<void> handleNfcOrDeepLink(String uri) async {
    // Format: unifiedhome://toggle/<deviceId> or unifiedhome://all_off
    if (uri.contains('all_off')) {
      for (final d in _devices.where((d) => d.isOn)) {
        try {
          await toggleDevicePower(d);
        } catch (_) {}
      }
    } else if (uri.contains('toggle/')) {
      final id = uri.split('toggle/').last.trim();
      final match = _devices.where((d) => d.id == id).toList();
      if (match.isNotEmpty) {
        await toggleDevicePower(match.first);
      }
    }
  }

  Future<void> lockCurrentBssidAsHome() async {
    final bssid = await osBridge.getCurrentRouterBssid();
    if (bssid != null) {
      osBridge.homeRouterBssid = bssid;
      osBridge.isUserAtHome = true;
      await _saveState();
      notifyListeners();
    } else {
      throw Exception('Could not read current Wi-Fi BSSID. Ensure Wi-Fi is connected.');
    }
  }

  Future<void> syncAllDevicesSilent() async {
    if (_isPollingInFlight) return;
    try {
      _isPollingInFlight = true;
      await Future.wait(
        _devices.map((dev) async {
          try {
            await _controller.refreshDeviceStatus(dev).timeout(const Duration(seconds: 8));
            dev.markOnlineSuccess();
          } catch (e) {
            dev.consecutiveFailedPolls++;
            dev.lastError = e.toString().replaceAll('Exception: ', '');
            if (dev.consecutiveFailedPolls >= 3) {
              // Mark device offline after 3 consecutive failures, but preserve
              // the last-known isOn state so that running appliances (e.g. a
              // Samsung Washer that had a momentary Wi-Fi hiccup) are not
              // falsely reported as powered off (Bug 19).
              dev.isOnline = false;
            }
            _controller.computeDeviceLiveWattage(dev);
          }
          await _checkWasherStateChange(dev);
        }),
      );
    } finally {
      _isPollingInFlight = false;
    }

    // Real-Time Energy Accumulator (Riemann sum integration: ΔE = P_total * Δt)
    final now = DateTime.now();
    if (_lastEnergySampleTime != null && _lastEnergySampleTime!.day != now.day) {
      // Midnight rollover reset
      todayAccumulatedKwh = 0.0;
    }
    if (_lastEnergySampleTime != null) {
      final dtSeconds = now.difference(_lastEnergySampleTime!).inMilliseconds / 1000.0;
      if (dtSeconds > 0 && dtSeconds < 300) {
        final deltaKwh = (totalLiveWatts / 1000.0) * (dtSeconds / 3600.0);
        todayAccumulatedKwh += deltaKwh;
      }
    }
    _lastEnergySampleTime = now;
    await _saveState();

    notifyListeners();
  }

  Future<void> _checkWasherStateChange(RealSmartDevice dev) async {
    if (dev.category != 'washer') return;
    final newState = dev.liveAttributes['state']?.toString().toLowerCase() ??
        dev.liveAttributes['machineState']?.toString().toLowerCase() ??
        (dev.isOn ? 'run' : 'stop');
    final prevState = _lastWasherMachineState[dev.id];
    if (prevState == 'run' && newState != 'run') {
      await _evaluateWasherFinishedAutomations(dev);
    }
    _lastWasherMachineState[dev.id] = newState;
  }

  Future<void> _evaluateWasherFinishedAutomations(RealSmartDevice washer) async {
    final expectedOff = '${washer.id}:off';
    final expectedFinish = '${washer.id}:finish';

    // 1. Fire matching simple automations
    for (final rule in _automations) {
      if (!rule.isEnabled) continue;
      if (rule.triggerType == 'device_state' &&
          (rule.triggerValue == expectedOff || rule.triggerValue == expectedFinish)) {
        try {
          await executeAutomationRuleNow(rule);
        } catch (_) {}
      }
    }

    // 2. Fire matching multi-condition automation rules
    for (final rule in _multiConditionRules) {
      if (!rule.isEnabled) continue;
      if (rule.trigger.kind != TriggerKind.deviceState) continue;
      if (rule.trigger.sourceDeviceId != null &&
          rule.trigger.sourceDeviceId != washer.id) {
        continue;
      }
      final trigVal = rule.trigger.value.toLowerCase();
      final isMatching = trigVal == 'off' ||
          trigVal == 'finish' ||
          trigVal == 'stop' ||
          trigVal == expectedOff.toLowerCase() ||
          trigVal == expectedFinish.toLowerCase();
      if (!isMatching) continue;

      final satisfiesGuards = smartEngine.evaluatePreconditions(
        rule,
        isUserAtHome: isUserAtHome,
        devices: _devices,
      );
      if (!satisfiesGuards) continue;

      await smartEngine.executeSequence(
        rule,
        _controller,
        _devices,
        onLog: (_) => _saveState(),
      );
      notifyListeners();
    }

    // 3. Emit hardware reflex bus event
    reflexBus.emitEvent(
      HardwareReflexEvent(
        sourceDeviceId: washer.id,
        sourceCategory: 'washer',
        eventType: 'cycle_complete',
      ),
    );

    // 4. Trigger Native Android Notification & Audible Chime Alert
    await ApplianceNotificationBridge.triggerApplianceAlert(
      title: '🧺 ${washer.name} Finished',
      body: 'Your laundry cycle is complete! Clean clothes are ready to unload.',
      withChime: true,
      withVibration: true,
    );
  }

  // ---------------------------------------------------------------------------
  // REAL AUTOMATION ENGINE (TIME + REACTIVE DEVICE TRIGGERS + MANUAL RUN)
  // ---------------------------------------------------------------------------
  Future<void> addAutomation(SmartAutomationRule rule) async {
    _automations.add(rule);
    await _saveState();
    notifyListeners();
  }

  Future<void> toggleAutomationEnabled(String ruleId) async {
    final rule = _automations.firstWhere((r) => r.id == ruleId);
    rule.isEnabled = !rule.isEnabled;
    await _saveState();
    notifyListeners();
  }

  Future<void> deleteAutomation(String ruleId) async {
    _automations.removeWhere((r) => r.id == ruleId);
    await _saveState();
    notifyListeners();
  }

  /// Immediately executes the target hardware action of an automation rule
  Future<void> executeAutomationRuleNow(SmartAutomationRule rule) async {
    final targetIdx = _devices.indexWhere((d) => d.id == rule.targetDeviceId);
    if (targetIdx == -1) {
      throw Exception('Target device for "${rule.name}" is no longer paired.');
    }
    final targetDevice = _devices[targetIdx];
    await _controller.setPower(targetDevice, rule.targetPowerState);
    if (rule.targetLevel != null && rule.targetPowerState) {
      await _controller.setPrimaryLevel(targetDevice, rule.targetLevel!);
    }
    rule.lastTriggeredAt = DateTime.now();
    await _saveState();
    notifyListeners();
  }

  Future<void> addMultiConditionRule(MultiConditionAutomationRule rule) async {
    _multiConditionRules.add(rule);
    await _saveState();
    notifyListeners();
  }

  Future<void> updateMultiConditionRule(MultiConditionAutomationRule rule) async {
    final idx = _multiConditionRules.indexWhere((r) => r.id == rule.id);
    if (idx != -1) {
      _multiConditionRules[idx] = rule;
      await _saveState();
      notifyListeners();
    }
  }

  Future<void> deleteMultiConditionRule(String ruleId) async {
    _multiConditionRules.removeWhere((r) => r.id == ruleId);
    await _saveState();
    notifyListeners();
  }

  Future<void> toggleMultiConditionRule(String ruleId) async {
    final rule = _multiConditionRules.firstWhere((r) => r.id == ruleId);
    rule.isEnabled = !rule.isEnabled;
    await _saveState();
    notifyListeners();
  }

  Future<bool> executeMultiConditionRuleNow(MultiConditionAutomationRule rule) async {
    final success = await smartEngine.executeSequence(
      rule,
      _controller,
      _devices,
      onLog: (_) => _saveState(),
    );
    await _saveState();
    notifyListeners();
    return success;
  }

  Future<MultiConditionAutomationRule?> parseAndAddNaturalLanguageRule(String prompt) async {
    final rule = smartEngine.parseNaturalLanguageToRule(prompt, _devices);
    if (rule != null) {
      await addMultiConditionRule(rule);
    }
    return rule;
  }

  Future<void> _evaluateDeviceStateAutomations(RealSmartDevice changedDevice) async {
    final now = DateTime.now();
    final stateKey = '${changedDevice.id}:${changedDevice.isOn ? "on" : "off"}';
    for (final rule in _automations) {
      if (!rule.isEnabled) continue;
      if (rule.lastTriggeredAt != null && now.difference(rule.lastTriggeredAt!).inSeconds < 45) {
        continue;
      }
      if (rule.triggerType == 'device_state' &&
          rule.triggerValue == stateKey) {
        try {
          await executeAutomationRuleNow(rule);
        } catch (_) {}
      }
    }

    for (final rule in _multiConditionRules) {
      if (!rule.isEnabled) continue;
      final satisfiesGuards = smartEngine.evaluatePreconditions(
        rule,
        isUserAtHome: isUserAtHome,
        devices: _devices,
      );
      if (!satisfiesGuards) continue;

      final isDevState = smartEngine.shouldTriggerDeviceState(
        rule,
        changedDevice,
        changedDevice.isOn ? 'on' : 'off',
      );
      final isThreshold = smartEngine.shouldTriggerThreshold(rule, changedDevice);

      if (isDevState || isThreshold) {
        await smartEngine.executeSequence(
          rule,
          _controller,
          _devices,
          onLog: (_) => _saveState(),
        );
        notifyListeners();
      }
    }
  }

  Future<void> _evaluateTimeAutomations() async {
    final now = DateTime.now();
    final currentHm =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    for (final rule in _automations) {
      if (!rule.isEnabled || rule.triggerType != 'time') continue;
      // Guard: skip if this rule already fired during the current clock minute.
      // Using a same-minute comparison avoids the 45 s cooldown < 60 s tick
      // window that caused double-fires (Bug 16).
      if (rule.lastTriggeredAt != null &&
          rule.lastTriggeredAt!.year == now.year &&
          rule.lastTriggeredAt!.month == now.month &&
          rule.lastTriggeredAt!.day == now.day &&
          rule.lastTriggeredAt!.hour == now.hour &&
          rule.lastTriggeredAt!.minute == now.minute) {
        continue;
      }
      if (rule.triggerValue == currentHm) {
        try {
          await executeAutomationRuleNow(rule);
        } catch (_) {}
      }
    }

    for (final rule in _multiConditionRules) {
      if (!rule.isEnabled) continue;
      final satisfiesGuards = smartEngine.evaluatePreconditions(
        rule,
        isUserAtHome: isUserAtHome,
        devices: _devices,
        now: now,
      );
      if (!satisfiesGuards) continue;

      final isTimeTrigger = smartEngine.shouldTriggerTime(rule, now);
      final isSolarTrigger = smartEngine.shouldTriggerSolar(rule, now);
      if (isTimeTrigger || isSolarTrigger) {
        await smartEngine.executeSequence(
          rule,
          _controller,
          _devices,
          onLog: (_) => _saveState(),
        );
        notifyListeners();
      }
    }
  }
}
