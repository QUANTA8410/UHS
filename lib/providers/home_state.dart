import 'package:flutter/material.dart';
import '../models/device_model.dart';
import '../models/appliance_recipes.dart';
import '../services/diagnostics/smart_diagnosis_service.dart';
import '../services/energy/energy_optimizer_service.dart';
import '../services/smartthings/smartthings_laundry_service.dart';
import '../services/tv/oneplus_connect_service.dart';
import '../services/security/secure_credential_vault.dart';
import '../services/storage/device_storage_service.dart';
import '../services/cloud/smartthings_api_service.dart';
import '../services/cloud/lg_thinq_api_service.dart';
import '../services/discovery/network_discovery_service.dart';
import '../services/matter/matter_controller_service.dart';
import '../services/wipro/wipro_tuya_service.dart';
import '../services/sync/unified_sync_manager.dart';
import '../models/ota_update_model.dart';
import '../services/ota/app_ota_service.dart';
import '../services/ota/device_ota_service.dart';

class HomeState extends ChangeNotifier {
  String homeName = 'My Smart Home';
  DeviceCategory? selectedFilter;
  bool aiEnergyModeEnabled = false;

  final DeviceStorageService storageService = DeviceStorageService();
  final SmartDiagnosisService smartDiagnosisService = SmartDiagnosisService();
  final EnergyOptimizerService energyOptimizerService = const EnergyOptimizerService();
  final SmartThingsLaundryService laundryService = SmartThingsLaundryService();
  final OnePlusConnectService tvService = OnePlusConnectService();
  final WiproTuyaService wiproService = WiproTuyaService();
  final SecureCredentialVault credentialVault = SecureCredentialVault();

  final SmartThingsApiService smartThingsService = SmartThingsApiService();
  final LgThinqApiService lgThinQService = LgThinqApiService();
  final NetworkDiscoveryService discoveryService = NetworkDiscoveryService();
  final MatterControllerService matterService = MatterControllerService();
  late final UnifiedSyncManager syncManager;

  final AppOtaService appOtaService = AppOtaService();
  final DeviceOtaService deviceOtaService = DeviceOtaService();

  AppOtaManifest? availableAppUpdate;
  bool isCheckingAppUpdate = false;
  OtaProgress? appOtaProgress;
  String? appOtaDownloadedApkPath;

  Map<String, DeviceFirmwareUpdate> availableDeviceUpdates = {};
  bool isCheckingDeviceUpdates = false;
  final Map<String, OtaProgress> deviceOtaProgress = {};

  bool get hasAppUpdate => availableAppUpdate != null;
  bool get hasDeviceUpdates => availableDeviceUpdates.isNotEmpty;
  bool get hasUpdatesAvailable => hasAppUpdate || hasDeviceUpdates;
  int get totalUpdatesCount => (hasAppUpdate ? 1 : 0) + availableDeviceUpdates.length;

  final List<WashCycleRecipe> availableWashCycles = List.from(WashCycleRecipe.builtInCatalog);

  final List<String> rooms = [
    'Living Room',
    'Kitchen',
    'Laundry Room',
    'Master Bedroom',
  ];

  late final List<SmartDevice> _devices;

  HomeState({bool autoInitStorage = false}) {
    _devices = _getDemoDevices();
    syncManager = UnifiedSyncManager(
      discoveryService: discoveryService,
      matterService: matterService,
      smartThingsService: smartThingsService,
      lgThinQService: lgThinQService,
      homeState: this,
      wiproService: wiproService,
      tvService: tvService,
    );
    if (autoInitStorage) {
      initStorage();
    }
  }

  Future<void> initStorage() async {
    await _initStorageAndSync();
  }

  static List<SmartDevice> _getDemoDevices() => [
        LightDevice(
          id: 'light_1',
          name: 'Wipro Smart Next Bulb',
          room: 'Living Room',
          protocol: DeviceProtocol.matter,
          isPowered: true,
          brightness: 0.85,
          color: const Color(0xFFFFD54F),
          colorTempKelvin: 3000,
          brand: 'Wipro Smart',
          activeScene: 'Reading',
          powerUsageWatts: 12.0,
          isDummy: true,
        ),
        LightDevice(
          id: 'light_2',
          name: 'Wipro Smart Candle Bulb',
          room: 'Master Bedroom',
          protocol: DeviceProtocol.smartThings,
          isPowered: false,
          brightness: 0.45,
          color: const Color(0xFFFFB74D),
          colorTempKelvin: 2700,
          brand: 'Wipro Smart',
          activeScene: 'Relax',
          powerUsageWatts: 7.0,
          isDummy: true,
        ),
        ThermostatDevice(
          id: 'ac_1',
          name: 'LG DualCool Air Conditioner',
          room: 'Living Room',
          protocol: DeviceProtocol.lgThinQ,
          isPowered: true,
          currentTempC: 24.0,
          targetTempC: 21.5,
          mode: ThermostatMode.cool,
          humidityPercent: 48,
          jetCoolActive: false,
          airCleanActive: true,
          brand: 'LG DualCool',
          fanSpeed: 'Auto',
          vaneSwingActive: true,
          filterLifePercent: 92,
          energyConsumedKwh: 4.2,
          powerUsageWatts: 580.0,
          isDummy: true,
        ),
        WasherDevice(
          id: 'washer_1',
          name: 'Samsung AI Ecobubble™ Washer',
          room: 'Laundry Room',
          protocol: DeviceProtocol.smartThings,
          isPowered: true,
          selectedCycle: 'AI Wash (Auto Sense)',
          stage: WasherStage.wash,
          remainingMinutes: 28,
          waterTempC: 40,
          spinSpeed: 'Max',
          steamEnabled: true,
          turboWashEnabled: true,
          brand: 'Samsung SmartThings',
          ecoBubbleEnabled: true,
          aiWashEnabled: true,
          superSpeedEnabled: false,
          detergentLevelPercent: 75,
          softenerLevelPercent: 45,
          addWashDoorLocked: true,
          drumCleanCount: 28,
          powerUsageWatts: 880.0,
          isDummy: true,
        ),
        TvDevice(
          id: 'tv_1',
          name: 'OnePlus TV 55 U1S 4K',
          room: 'Living Room',
          protocol: DeviceProtocol.localLan,
          isPowered: true,
          volume: 24,
          isMuted: false,
          currentInput: 'OxygenPlay / OTT',
          currentApp: 'OxygenPlay',
          pictureMode: 'Vivid',
          smartVolumeEnabled: true,
          powerUsageWatts: 115.0,
          isDummy: true,
        ),
        RefrigeratorDevice(
          id: 'fridge_1',
          name: 'LG InstaView Refrigerator',
          room: 'Kitchen',
          protocol: DeviceProtocol.lgThinQ,
          isPowered: true,
          fridgeTempC: 3.0,
          freezerTempC: -19.0,
          craftIceMode: CraftIceMode.sixPerDay,
          expressFreeze: false,
          waterFilterLifePercent: 86,
          powerUsageWatts: 140.0,
          isDummy: true,
        ),
      ];

  Future<void> _initStorageAndSync() async {
    try {
      final hasCleared = await storageService.getHasClearedDummy();
      final savedDevices = await storageService.loadDevices();

      if (savedDevices.isNotEmpty) {
        _devices.clear();
        _devices.addAll(savedDevices);
        for (final dev in savedDevices) {
          if (!rooms.contains(dev.room)) rooms.add(dev.room);
        }
      } else if (hasCleared) {
        _devices.clear();
      }

      final stToken = await storageService.getSmartThingsToken();
      if (stToken != null && stToken.isNotEmpty) {
        smartThingsService.setAuthToken(stToken);
      }

      final lgToken = await storageService.getLgThinqToken();
      if (lgToken != null && lgToken.isNotEmpty) {
        lgThinQService.setSessionToken(lgToken);
      }

      syncManager.startBackgroundSync();
      notifyListeners();
    } catch (_) {}
  }

  // Device Management & Fleet Control
  bool get hasDummyDevices => _devices.any((d) => d.isDummy);
  int get realDevicesCount => _devices.where((d) => !d.isDummy).length;

  Future<void> clearDummyDevices() async {
    _devices.removeWhere((d) => d.isDummy);
    await storageService.setHasClearedDummy(true);
    await storageService.saveDevices(_devices);
    notifyListeners();
  }

  Future<void> restoreDemoFleet() async {
    _devices.clear();
    _devices.addAll(_getDemoDevices());
    await storageService.setHasClearedDummy(false);
    await storageService.saveDevices(_devices);
    notifyListeners();
  }

  Future<void> addDevice(SmartDevice dev) async {
    // Avoid duplicate IDs
    _devices.removeWhere((d) => d.id == dev.id);
    _devices.add(dev);
    if (!rooms.contains(dev.room)) {
      rooms.add(dev.room);
    }
    await storageService.saveDevices(_devices);
    notifyListeners();
  }

  Future<void> removeDevice(String id) async {
    _devices.removeWhere((d) => d.id == id);
    await storageService.saveDevices(_devices);
    notifyListeners();
  }

  Future<void> updateDevice(SmartDevice dev) async {
    final idx = _devices.indexWhere((d) => d.id == dev.id);
    if (idx != -1) {
      _devices[idx] = dev;
      await storageService.saveDevices(_devices);
      notifyListeners();
    }
  }

  // Account & Direct Device Integration Handlers
  Future<bool> connectSmartThings(String patToken) async {
    smartThingsService.setAuthToken(patToken);
    final isValid = await smartThingsService.validateToken();
    if (!isValid) return false;

    await storageService.saveSmartThingsToken(patToken);
    final remoteDevices = await smartThingsService.listDevices();
    for (final raw in remoteDevices) {
      final parsed = smartThingsService.parseSmartThingsDevice(raw);
      if (parsed != null) {
        _devices.removeWhere((d) => d.id == parsed.id || d.cloudDeviceId == parsed.cloudDeviceId);
        _devices.add(parsed);
      }
    }
    await storageService.saveDevices(_devices);
    notifyListeners();
    return true;
  }

  Future<bool> connectLgThinq(String token) async {
    lgThinQService.setSessionToken(token);
    final isValid = await lgThinQService.validateToken();
    if (!isValid) return false;

    await storageService.saveLgThinqToken(token);
    final remoteDevices = await lgThinQService.listDevices();
    for (final raw in remoteDevices) {
      final parsed = lgThinQService.parseLgDevice(raw);
      if (parsed != null) {
        _devices.removeWhere((d) => d.id == parsed.id || d.cloudDeviceId == parsed.cloudDeviceId);
        _devices.add(parsed);
      }
    }
    await storageService.saveDevices(_devices);
    notifyListeners();
    return true;
  }

  Future<bool> addOnePlusTvDevice({
    required String name,
    required String host,
    required String room,
  }) async {
    final dev = TvDevice(
      id: 'oneplus_${host.replaceAll('.', '_')}',
      name: name,
      room: room,
      protocol: DeviceProtocol.localLan,
      host: host,
      isDummy: false,
    );
    await addDevice(dev);
    // Background check connectivity
    tvService.checkConnectivity(host).then((online) {
      dev.isOnline = online;
      notifyListeners();
    });
    return true;
  }

  Future<bool> addWiproBulbDevice({
    required String name,
    required String host,
    required String room,
  }) async {
    final dev = LightDevice(
      id: 'wipro_${host.replaceAll('.', '_')}',
      name: name,
      room: room,
      protocol: DeviceProtocol.localLan,
      host: host,
      brand: 'Wipro Smart Next',
      isDummy: false,
    );
    await addDevice(dev);
    wiproService.checkConnectivity(host).then((online) {
      dev.isOnline = online;
      notifyListeners();
    });
    return true;
  }

  List<SmartDevice> get devices {
    if (selectedFilter == null) return _devices;
    return _devices.where((d) => d.category == selectedFilter).toList();
  }

  List<SmartDevice> get allDevices => _devices;

  List<SmartDevice> devicesInRoom(String room) {
    return _devices.where((d) => d.room == room).toList();
  }

  // Summary Getters
  int get activeLightsCount => _devices
      .where((d) => d.category == DeviceCategory.lighting && d.isPowered)
      .length;

  double get averageClimateTemp {
    final climateDevs = _devices
        .whereType<ThermostatDevice>()
        .where((d) => d.isPowered);
    if (climateDevs.isEmpty) return 22.0;
    final total = climateDevs.map((d) => d.currentTempC).reduce((a, b) => a + b);
    return total / climateDevs.length;
  }

  int get activeAppliancesCount => _devices
      .where((d) =>
          (d.category == DeviceCategory.washer ||
              d.category == DeviceCategory.refrigerator) &&
          d.isPowered)
      .length;

  double get totalPowerWatts {
    double total = 0.0;
    for (final dev in _devices) {
      if (dev.isPowered) total += dev.powerUsageWatts;
    }
    if (aiEnergyModeEnabled) {
      total *= 0.85; // 15% estimated savings under AI Energy Mode
    }
    return total;
  }

  void setFilter(DeviceCategory? cat) {
    if (selectedFilter == cat) {
      selectedFilter = null;
    } else {
      selectedFilter = cat;
    }
    notifyListeners();
  }

  void togglePower(String id) {
    final dev = _devices.firstWhere((d) => d.id == id);
    dev.isPowered = !dev.isPowered;
    syncManager.sendCommand(dev, 'toggle', {});
    storageService.saveDevices(_devices);
    notifyListeners();
  }

  void updateLightBrightness(String id, double val) {
    final dev = _devices.firstWhere((d) => d.id == id) as LightDevice;
    dev.brightness = val;
    if (val > 0 && !dev.isPowered) dev.isPowered = true;
    if (val == 0 && dev.isPowered) dev.isPowered = false;
    syncManager.sendCommand(dev, 'brightness', {'brightness': val});
    storageService.saveDevices(_devices);
    notifyListeners();
  }

  void updateThermostat(String id, {
    double? targetTemp,
    ThermostatMode? mode,
    bool? jetCool,
  }) {
    final dev = _devices.firstWhere((d) => d.id == id) as ThermostatDevice;
    if (targetTemp != null) dev.targetTempC = targetTemp;
    if (mode != null) dev.mode = mode;
    if (jetCool != null) dev.jetCoolActive = jetCool;

    syncManager.sendCommand(dev, 'Set', {
      'targetTemp': dev.targetTempC,
      'mode': dev.mode.name,
      'jetCool': dev.jetCoolActive,
    });
    storageService.saveDevices(_devices);
    notifyListeners();
  }

  void updateWasher(String id, {
    String? cycle,
    String? spinSpeed,
    int? waterTemp,
    bool? steam,
    bool? turboWash,
    int? remainingMinutes,
  }) {
    final dev = _devices.firstWhere((d) => d.id == id) as WasherDevice;
    if (cycle != null) dev.selectedCycle = cycle;
    if (spinSpeed != null) dev.spinSpeed = spinSpeed;
    if (waterTemp != null) dev.waterTempC = waterTemp;
    if (steam != null) dev.steamEnabled = steam;
    if (turboWash != null) dev.turboWashEnabled = turboWash;
    if (remainingMinutes != null) dev.remainingMinutes = remainingMinutes;

    syncManager.sendCommand(dev, 'setCycle', {
      'args': [dev.selectedCycle]
    });
    storageService.saveDevices(_devices);
    notifyListeners();
  }

  void updateRefrigerator(String id, {
    double? fridgeTemp,
    double? freezerTemp,
    CraftIceMode? craftIce,
    bool? expressFreeze,
  }) {
    final dev = _devices.firstWhere((d) => d.id == id) as RefrigeratorDevice;
    if (fridgeTemp != null) dev.fridgeTempC = fridgeTemp;
    if (freezerTemp != null) dev.freezerTempC = freezerTemp;
    if (craftIce != null) dev.craftIceMode = craftIce;
    if (expressFreeze != null) dev.expressFreeze = expressFreeze;

    syncManager.sendCommand(dev, 'Set', {
      'fridgeTemp': dev.fridgeTempC,
      'freezerTemp': dev.freezerTempC,
    });
    storageService.saveDevices(_devices);
    notifyListeners();
  }

  void toggleAiEnergyMode() {
    aiEnergyModeEnabled = !aiEnergyModeEnabled;
    notifyListeners();
  }

  void refresh() {
    notifyListeners();
  }

  EnergyPrediction get energyPrediction => energyOptimizerService.calculateProjections(
        currentPowerWatts: totalPowerWatts,
        aiEnergyModeActive: aiEnergyModeEnabled,
      );

  void downloadCycle(WashCycleRecipe recipe) {
    if (!availableWashCycles.any((c) => c.id == recipe.id)) {
      availableWashCycles.add(recipe);
      notifyListeners();
    }
  }

  void updateWiproBulb(String id, {
    double? brightness,
    Color? color,
    int? colorTempKelvin,
    String? scene,
    bool? musicSync,
  }) {
    final dev = _devices.firstWhere((d) => d.id == id) as LightDevice;
    if (brightness != null) dev.brightness = brightness;
    if (color != null) dev.color = color;
    if (colorTempKelvin != null) dev.colorTempKelvin = colorTempKelvin;
    if (scene != null) dev.activeScene = scene;
    if (musicSync != null) dev.musicSyncActive = musicSync;
    if (!dev.isPowered && (brightness ?? 0) > 0) dev.isPowered = true;

    syncManager.sendCommand(dev, 'brightness', {'brightness': dev.brightness});
    if (colorTempKelvin != null) {
      syncManager.sendCommand(dev, 'colorTemp', {'kelvin': colorTempKelvin});
    }
    storageService.saveDevices(_devices);
    notifyListeners();
  }

  void updateSamsungWasher(String id, {
    bool? ecoBubble,
    bool? aiWash,
    bool? superSpeed,
    int? detergent,
    int? softener,
    bool? addWashDoorLocked,
    String? cycle,
    int? waterTemp,
    String? spinSpeed,
    String? recommendedRecipe,
  }) {
    final dev = _devices.firstWhere((d) => d.id == id) as WasherDevice;
    if (ecoBubble != null) dev.ecoBubbleEnabled = ecoBubble;
    if (aiWash != null) dev.aiWashEnabled = aiWash;
    if (superSpeed != null) dev.superSpeedEnabled = superSpeed;
    if (detergent != null) dev.detergentLevelPercent = detergent;
    if (softener != null) dev.softenerLevelPercent = softener;
    if (addWashDoorLocked != null) dev.addWashDoorLocked = addWashDoorLocked;
    if (cycle != null) dev.selectedCycle = cycle;
    if (waterTemp != null) dev.waterTempC = waterTemp;
    if (spinSpeed != null) dev.spinSpeed = spinSpeed;
    if (recommendedRecipe != null) dev.recommendedLaundryRecipe = recommendedRecipe;

    if (cycle != null) {
      syncManager.sendCommand(dev, 'setCycle', {'args': [cycle]});
    }
    storageService.saveDevices(_devices);
    notifyListeners();
  }

  void updateLgAc(String id, {
    double? targetTemp,
    ThermostatMode? mode,
    bool? jetCool,
    bool? airClean,
    String? fanSpeed,
    bool? vaneSwing,
  }) {
    final dev = _devices.firstWhere((d) => d.id == id) as ThermostatDevice;
    if (targetTemp != null) dev.targetTempC = targetTemp;
    if (mode != null) dev.mode = mode;
    if (jetCool != null) dev.jetCoolActive = jetCool;
    if (airClean != null) dev.airCleanActive = airClean;
    if (fanSpeed != null) dev.fanSpeed = fanSpeed;
    if (vaneSwing != null) dev.vaneSwingActive = vaneSwing;

    syncManager.sendCommand(dev, 'Set', {
      'targetTemp': dev.targetTempC,
      'mode': dev.mode.name,
      'jetCool': dev.jetCoolActive,
    });
    storageService.saveDevices(_devices);
    notifyListeners();
  }

  void updateTv(String id, {
    int? volume,
    bool? isMuted,
    String? input,
    String? app,
    String? pictureMode,
    bool? smartVolume,
  }) {
    final dev = _devices.firstWhere((d) => d.id == id) as TvDevice;
    if (volume != null) dev.volume = volume.clamp(0, 100);
    if (isMuted != null) dev.isMuted = isMuted;
    if (input != null) dev.currentInput = input;
    if (app != null) dev.currentApp = app;
    if (pictureMode != null) dev.pictureMode = pictureMode;
    if (smartVolume != null) dev.smartVolumeEnabled = smartVolume;

    storageService.saveDevices(_devices);
    notifyListeners();
  }

  Future<void> sendTvKey(String id, String key) async {
    final dev = _devices.firstWhere((d) => d.id == id);
    await syncManager.sendCommand(dev, key, {});
    notifyListeners();
  }

  Future<void> launchTvApp(String id, String app) async {
    final dev = _devices.firstWhere((d) => d.id == id) as TvDevice;
    dev.currentApp = app;
    await syncManager.sendCommand(dev, 'launchApp', {'app': app});
    storageService.saveDevices(_devices);
    notifyListeners();
  }

  // ==========================================
  // OTA Update Methods (App Software & IoT Fleet)
  // ==========================================

  Future<void> checkForAppUpdate({bool simulate = true, String? manifestUrl}) async {
    isCheckingAppUpdate = true;
    notifyListeners();
    try {
      availableAppUpdate = await appOtaService.checkForAppUpdate(
        manifestUrl: manifestUrl,
        forceSimulate: simulate,
      );
    } catch (_) {
      availableAppUpdate = null;
    } finally {
      isCheckingAppUpdate = false;
      notifyListeners();
    }
  }

  Future<void> downloadAppUpdate() async {
    if (availableAppUpdate == null) return;
    appOtaProgress = const OtaProgress(stage: OtaStage.checking, statusMessage: 'Starting download...');
    notifyListeners();

    await for (final progress in appOtaService.downloadAndVerifyApk(availableAppUpdate!)) {
      appOtaProgress = progress;
      if (progress.isCompleted) {
        appOtaDownloadedApkPath = progress.statusMessage;
      }
      notifyListeners();
    }
  }

  Future<bool> installAppUpdate() async {
    if (appOtaDownloadedApkPath == null) return false;
    return await appOtaService.triggerApkInstall(appOtaDownloadedApkPath!);
  }

  Future<void> checkFleetFirmwareUpdates() async {
    isCheckingDeviceUpdates = true;
    notifyListeners();
    try {
      availableDeviceUpdates = await deviceOtaService.checkFleetFirmware(_devices);
    } finally {
      isCheckingDeviceUpdates = false;
      notifyListeners();
    }
  }

  Future<void> startDeviceFirmwareUpdate(String deviceId) async {
    final update = availableDeviceUpdates[deviceId];
    if (update == null) return;
    final dev = _devices.firstWhere((d) => d.id == deviceId, orElse: () => _devices.first);

    deviceOtaProgress[deviceId] = const OtaProgress(stage: OtaStage.checking, statusMessage: 'Connecting...');
    notifyListeners();

    await for (final progress in deviceOtaService.flashDeviceFirmware(dev, update)) {
      deviceOtaProgress[deviceId] = progress;
      if (progress.isCompleted) {
        dev.firmwareVersion = update.availableVersion;
        availableDeviceUpdates.remove(deviceId);
        await storageService.saveDevices(_devices);
      }
      notifyListeners();
    }
  }

  Future<void> updateAllDevices() async {
    final ids = List<String>.from(availableDeviceUpdates.keys);
    for (final id in ids) {
      await startDeviceFirmwareUpdate(id);
    }
  }
}
