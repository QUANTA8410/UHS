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
  final List<MultiConditionAutomationRule> _multiConditionRules = [];
  final Map<String, String> _lastWasherMachineState = {};
  Timer? _pollingTimer;
  bool _isPollingInFlight = false;
  final Map<String, Timer> _levelDebounceTimers = {};
  bool isBusy = false;
  String? lastGlobalError;

  double todayAccumulatedKwh = 0.0;
  DateTime? _lastEnergySampleTime;

  List<RealSmartDevice> get devices => List.unmodifiable(_devices);
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
    reflexBus.dispose();
    nodeServer.stopServer();
    nodeServer.dispose();
    super.dispose();
  }

  Future<void> _checkPresenceAutomations() async {
    final transition = await osBridge.checkPresenceTransition();
    if (transition != null) {
      if (!transition) {
        // Left Home -> Auto turn off running devices
        for (final d in _devices.where((d) => d.isOn)) {
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
      final devRaw = prefs.getString('real_devices_v2');
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
      debugPrint('Error loading real_devices_v2: $e');
    }

    linkedSmartThingsPat = prefs.getString('linked_st_pat_token');
    linkedLgThinqPat = prefs.getString('linked_lg_pat_token');
    linkedHomeAssistantHubUrl = prefs.getString('linked_ha_hub_url');
    linkedHomeAssistantToken = prefs.getString('linked_ha_token');
    linkedHueBridgeIp = prefs.getString('linked_hue_bridge_ip');
    linkedHueUsername = prefs.getString('linked_hue_username');

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
      await prefs.setString(
        'real_devices_v2',
        jsonEncode(_devices.map((d) => d.toJson()).toList()),
      );
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
    if (linkedSmartThingsPat != null) {
      await prefs.setString('linked_st_pat_token', linkedSmartThingsPat!);
    }
    if (linkedLgThinqPat != null) {
      await prefs.setString('linked_lg_pat_token', linkedLgThinqPat!);
    }
    if (linkedHomeAssistantHubUrl != null) {
      await prefs.setString('linked_ha_hub_url', linkedHomeAssistantHubUrl!);
    }
    if (linkedHomeAssistantToken != null) {
      await prefs.setString('linked_ha_token', linkedHomeAssistantToken!);
    }
    if (linkedHueBridgeIp != null) {
      await prefs.setString('linked_hue_bridge_ip', linkedHueBridgeIp!);
    }
    if (linkedHueUsername != null) {
      await prefs.setString('linked_hue_username', linkedHueUsername!);
    }
    if (osBridge.homeRouterBssid != null) {
      await prefs.setString('home_router_bssid', osBridge.homeRouterBssid!);
    }
    final todayStr = '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}';
    await prefs.setString('energy_date_ymd', todayStr);
    await prefs.setDouble('energy_today_kwh', todayAccumulatedKwh);
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
    isBusy = true;
    lastGlobalError = null;
    notifyListeners();
    try {
      await _controller.refreshDeviceStatus(device);
      _devices.removeWhere((d) => d.id == device.id);
      _devices.add(device);
      await _saveState();
    } catch (e) {
      lastGlobalError = 'Could not reach ${device.name} at ${device.credentials['ip']}: $e';
      rethrow;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  void addDeviceDirect(RealSmartDevice device) {
    if (device.liveWatts == 0.0) {
      _controller.computeDeviceLiveWattage(device);
    }
    _devices.removeWhere((d) => d.id == device.id);
    _devices.add(device);
    _saveState();
    notifyListeners();
  }

  Future<void> clearAllDevices() async {
    _devices.clear();
    _hasExplicitlyClearedDevices = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('real_devices_v2', '[]');
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
  ]) async {
    lastGlobalError = null;
    try {
      await _controller.executeDeviceCommand(device, capability, command, arguments);
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

    try {
      if (device.credentials['vendor'] == 'lg_thinq') {
        await zeroTouch.controlLgAirConditioner(device: device, powerOn: targetState);
      } else {
        await _controller.setPower(device, targetState);
      }
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
    // Optimistic instant slider response for smooth 60/120fps tracking
    device.primaryValue = newValue;
    device.isOn = newValue > 0;
    _controller.computeDeviceLiveWattage(device);
    notifyListeners();

    // 250ms debouncer to avoid flooding IoT hardware with socket requests
    _levelDebounceTimers[device.id]?.cancel();
    _levelDebounceTimers[device.id] = Timer(const Duration(milliseconds: 250), () async {
      try {
        if (device.credentials['vendor'] == 'lg_thinq' && device.category == 'ac') {
          await zeroTouch.controlLgAirConditioner(device: device, targetCelsius: newValue);
        } else {
          await _controller.setPrimaryLevel(device, newValue);
        }
        await _saveState();
      } catch (e) {
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
            await _controller.refreshDeviceStatus(dev).timeout(const Duration(seconds: 3));
            await _checkWasherStateChange(dev);
          } catch (_) {
            _controller.computeDeviceLiveWattage(dev);
          }
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
      if (rule.lastTriggeredAt != null && now.difference(rule.lastTriggeredAt!).inSeconds < 45) {
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
