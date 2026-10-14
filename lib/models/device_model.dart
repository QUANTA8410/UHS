import 'package:flutter/material.dart';

enum DeviceCategory {
  lighting,
  climate,
  washer,
  dryer,
  refrigerator,
  camera,
  media,
  plug,
  sensor,
}

enum DeviceProtocol {
  matter,
  lgThinQ,
  smartThings,
  localLan,
}

abstract class SmartDevice {
  final String id;
  String name;
  String room;
  final DeviceCategory category;
  DeviceProtocol protocol;
  bool isOnline;
  bool isPowered;
  double powerUsageWatts;
  String? host;
  int? port;
  String? cloudDeviceId;
  bool isDummy;
  String firmwareVersion;

  SmartDevice({
    required this.id,
    required this.name,
    required this.room,
    required this.category,
    required this.protocol,
    this.isOnline = true,
    this.isPowered = false,
    this.powerUsageWatts = 0.0,
    this.host,
    this.port,
    this.cloudDeviceId,
    this.isDummy = false,
    this.firmwareVersion = '1.0.0',
  });

  String get statusSummary;
  IconData get icon;

  Map<String, dynamic> toJson();

  static SmartDevice fromJson(Map<String, dynamic> json) {
    final catName = json['category'] as String? ?? 'lighting';
    final category = DeviceCategory.values.firstWhere(
      (c) => c.name == catName,
      orElse: () => DeviceCategory.lighting,
    );

    switch (category) {
      case DeviceCategory.lighting:
        return LightDevice.fromJson(json);
      case DeviceCategory.climate:
        return ThermostatDevice.fromJson(json);
      case DeviceCategory.washer:
      case DeviceCategory.dryer:
        return WasherDevice.fromJson(json);
      case DeviceCategory.media:
        return TvDevice.fromJson(json);
      case DeviceCategory.refrigerator:
        return RefrigeratorDevice.fromJson(json);
      default:
        return LightDevice.fromJson(json);
    }
  }
}

class LightDevice extends SmartDevice {
  double brightness; // 0.0 to 1.0
  Color color;
  int colorTempKelvin;
  String brand;
  String activeScene;
  bool musicSyncActive;

  LightDevice({
    required super.id,
    required super.name,
    required super.room,
    required super.protocol,
    super.isOnline = true,
    super.isPowered = false,
    super.powerUsageWatts = 9.5,
    super.host,
    super.port,
    super.cloudDeviceId,
    super.isDummy = false,
    super.firmwareVersion = '1.0.4',
    this.brightness = 0.8,
    this.color = const Color(0xFFFFD54F),
    this.colorTempKelvin = 3000,
    this.brand = 'Wipro Smart',
    this.activeScene = 'Normal',
    this.musicSyncActive = false,
  }) : super(category: DeviceCategory.lighting);

  @override
  String get statusSummary => isPowered
      ? '${(brightness * 100).round()}% Brightness'
      : 'Off';

  @override
  IconData get icon => Icons.lightbulb_rounded;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'room': room,
        'category': category.name,
        'protocol': protocol.name,
        'isOnline': isOnline,
        'isPowered': isPowered,
        'powerUsageWatts': powerUsageWatts,
        'host': host,
        'port': port,
        'cloudDeviceId': cloudDeviceId,
        'isDummy': isDummy,
        'firmwareVersion': firmwareVersion,
        'brightness': brightness,
        'colorValue': color.toARGB32(),
        'colorTempKelvin': colorTempKelvin,
        'brand': brand,
        'activeScene': activeScene,
        'musicSyncActive': musicSyncActive,
      };

  factory LightDevice.fromJson(Map<String, dynamic> json) => LightDevice(
        id: json['id'] as String,
        name: json['name'] as String,
        room: json['room'] as String,
        protocol: DeviceProtocol.values.firstWhere(
          (p) => p.name == json['protocol'],
          orElse: () => DeviceProtocol.localLan,
        ),
        isOnline: json['isOnline'] as bool? ?? true,
        isPowered: json['isPowered'] as bool? ?? false,
        powerUsageWatts: (json['powerUsageWatts'] as num?)?.toDouble() ?? 9.5,
        host: json['host'] as String?,
        port: json['port'] as int?,
        cloudDeviceId: json['cloudDeviceId'] as String?,
        isDummy: json['isDummy'] as bool? ?? false,
        firmwareVersion: json['firmwareVersion'] as String? ?? '1.0.4',
        brightness: (json['brightness'] as num?)?.toDouble() ?? 0.8,
        color: Color(json['colorValue'] as int? ?? 0xFFFFD54F),
        colorTempKelvin: json['colorTempKelvin'] as int? ?? 3000,
        brand: json['brand'] as String? ?? 'Wipro Smart',
        activeScene: json['activeScene'] as String? ?? 'Normal',
        musicSyncActive: json['musicSyncActive'] as bool? ?? false,
      );
}

enum ThermostatMode { off, cool, heat, auto, eco }

class ThermostatDevice extends SmartDevice {
  double currentTempC;
  double targetTempC;
  ThermostatMode mode;
  int humidityPercent;
  bool jetCoolActive;
  bool airCleanActive;
  String brand;
  String fanSpeed;
  bool vaneSwingActive;
  int filterLifePercent;
  double energyConsumedKwh;

  ThermostatDevice({
    required super.id,
    required super.name,
    required super.room,
    required super.protocol,
    super.isOnline = true,
    super.isPowered = true,
    super.powerUsageWatts = 450.0,
    super.host,
    super.port,
    super.cloudDeviceId,
    super.isDummy = false,
    super.firmwareVersion = '2.1.8',
    this.currentTempC = 23.5,
    this.targetTempC = 21.0,
    this.mode = ThermostatMode.cool,
    this.humidityPercent = 45,
    this.jetCoolActive = false,
    this.airCleanActive = true,
    this.brand = 'LG DualCool',
    this.fanSpeed = 'Auto',
    this.vaneSwingActive = true,
    this.filterLifePercent = 92,
    this.energyConsumedKwh = 4.2,
  }) : super(category: DeviceCategory.climate);

  @override
  String get statusSummary {
    if (!isPowered || mode == ThermostatMode.off) return 'Off';
    if (jetCoolActive) return 'Jet Cool Active (${targetTempC.toStringAsFixed(1)}°C)';
    return '${mode.name.toUpperCase()} to ${targetTempC.toStringAsFixed(1)}°C';
  }

  @override
  IconData get icon => Icons.thermostat_rounded;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'room': room,
        'category': category.name,
        'protocol': protocol.name,
        'isOnline': isOnline,
        'isPowered': isPowered,
        'powerUsageWatts': powerUsageWatts,
        'host': host,
        'port': port,
        'cloudDeviceId': cloudDeviceId,
        'isDummy': isDummy,
        'firmwareVersion': firmwareVersion,
        'currentTempC': currentTempC,
        'targetTempC': targetTempC,
        'mode': mode.name,
        'humidityPercent': humidityPercent,
        'jetCoolActive': jetCoolActive,
        'airCleanActive': airCleanActive,
        'brand': brand,
        'fanSpeed': fanSpeed,
        'vaneSwingActive': vaneSwingActive,
        'filterLifePercent': filterLifePercent,
        'energyConsumedKwh': energyConsumedKwh,
      };

  factory ThermostatDevice.fromJson(Map<String, dynamic> json) => ThermostatDevice(
        id: json['id'] as String,
        name: json['name'] as String,
        room: json['room'] as String,
        protocol: DeviceProtocol.values.firstWhere(
          (p) => p.name == json['protocol'],
          orElse: () => DeviceProtocol.lgThinQ,
        ),
        isOnline: json['isOnline'] as bool? ?? true,
        isPowered: json['isPowered'] as bool? ?? true,
        powerUsageWatts: (json['powerUsageWatts'] as num?)?.toDouble() ?? 450.0,
        host: json['host'] as String?,
        port: json['port'] as int?,
        cloudDeviceId: json['cloudDeviceId'] as String?,
        isDummy: json['isDummy'] as bool? ?? false,
        firmwareVersion: json['firmwareVersion'] as String? ?? '2.1.8',
        currentTempC: (json['currentTempC'] as num?)?.toDouble() ?? 23.5,
        targetTempC: (json['targetTempC'] as num?)?.toDouble() ?? 21.0,
        mode: ThermostatMode.values.firstWhere(
          (m) => m.name == json['mode'],
          orElse: () => ThermostatMode.cool,
        ),
        humidityPercent: json['humidityPercent'] as int? ?? 45,
        jetCoolActive: json['jetCoolActive'] as bool? ?? false,
        airCleanActive: json['airCleanActive'] as bool? ?? true,
        brand: json['brand'] as String? ?? 'LG DualCool',
        fanSpeed: json['fanSpeed'] as String? ?? 'Auto',
        vaneSwingActive: json['vaneSwingActive'] as bool? ?? true,
        filterLifePercent: json['filterLifePercent'] as int? ?? 92,
        energyConsumedKwh: (json['energyConsumedKwh'] as num?)?.toDouble() ?? 4.2,
      );
}

enum WasherStage { idle, wash, rinse, spin, done }

class WasherDevice extends SmartDevice {
  String selectedCycle;
  WasherStage stage;
  int remainingMinutes;
  int waterTempC; // e.g. 40
  String spinSpeed; // 'Low', 'Med', 'High', 'Max'
  bool steamEnabled;
  bool turboWashEnabled;
  bool remoteStartActive;
  bool doorLocked;
  int tubCleanCount;
  String brand;
  bool ecoBubbleEnabled;
  bool aiWashEnabled;
  bool superSpeedEnabled;
  int detergentLevelPercent;
  int softenerLevelPercent;
  bool addWashDoorLocked;
  int drumCleanCount;
  String? recommendedLaundryRecipe;

  WasherDevice({
    required super.id,
    required super.name,
    required super.room,
    required super.protocol,
    super.isOnline = true,
    super.isPowered = true,
    super.powerUsageWatts = 850.0,
    super.host,
    super.port,
    super.cloudDeviceId,
    super.isDummy = false,
    super.firmwareVersion = '3.4.1',
    this.selectedCycle = 'AI DD Normal',
    this.stage = WasherStage.wash,
    this.remainingMinutes = 24,
    this.waterTempC = 40,
    this.spinSpeed = 'High',
    this.steamEnabled = true,
    this.turboWashEnabled = true,
    this.remoteStartActive = true,
    this.doorLocked = true,
    this.tubCleanCount = 18,
    this.brand = 'Samsung SmartThings',
    this.ecoBubbleEnabled = true,
    this.aiWashEnabled = true,
    this.superSpeedEnabled = false,
    this.detergentLevelPercent = 75,
    this.softenerLevelPercent = 45,
    this.addWashDoorLocked = true,
    this.drumCleanCount = 28,
    this.recommendedLaundryRecipe,
  }) : super(category: DeviceCategory.washer);

  @override
  String get statusSummary {
    if (!isPowered) return 'Off';
    if (stage == WasherStage.idle) return 'Ready ($selectedCycle)';
    if (stage == WasherStage.done) return 'Cycle Complete';
    return '${stage.name.toUpperCase()} ($remainingMinutes min remaining)';
  }

  @override
  IconData get icon => Icons.local_laundry_service_rounded;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'room': room,
        'category': category.name,
        'protocol': protocol.name,
        'isOnline': isOnline,
        'isPowered': isPowered,
        'powerUsageWatts': powerUsageWatts,
        'host': host,
        'port': port,
        'cloudDeviceId': cloudDeviceId,
        'isDummy': isDummy,
        'firmwareVersion': firmwareVersion,
        'selectedCycle': selectedCycle,
        'stage': stage.name,
        'remainingMinutes': remainingMinutes,
        'waterTempC': waterTempC,
        'spinSpeed': spinSpeed,
        'steamEnabled': steamEnabled,
        'turboWashEnabled': turboWashEnabled,
        'remoteStartActive': remoteStartActive,
        'doorLocked': doorLocked,
        'tubCleanCount': tubCleanCount,
        'brand': brand,
        'ecoBubbleEnabled': ecoBubbleEnabled,
        'aiWashEnabled': aiWashEnabled,
        'superSpeedEnabled': superSpeedEnabled,
        'detergentLevelPercent': detergentLevelPercent,
        'softenerLevelPercent': softenerLevelPercent,
        'addWashDoorLocked': addWashDoorLocked,
        'drumCleanCount': drumCleanCount,
        'recommendedLaundryRecipe': recommendedLaundryRecipe,
      };

  factory WasherDevice.fromJson(Map<String, dynamic> json) => WasherDevice(
        id: json['id'] as String,
        name: json['name'] as String,
        room: json['room'] as String,
        protocol: DeviceProtocol.values.firstWhere(
          (p) => p.name == json['protocol'],
          orElse: () => DeviceProtocol.smartThings,
        ),
        isOnline: json['isOnline'] as bool? ?? true,
        isPowered: json['isPowered'] as bool? ?? true,
        powerUsageWatts: (json['powerUsageWatts'] as num?)?.toDouble() ?? 850.0,
        host: json['host'] as String?,
        port: json['port'] as int?,
        cloudDeviceId: json['cloudDeviceId'] as String?,
        isDummy: json['isDummy'] as bool? ?? false,
        firmwareVersion: json['firmwareVersion'] as String? ?? '3.4.1',
        selectedCycle: json['selectedCycle'] as String? ?? 'Normal',
        stage: WasherStage.values.firstWhere(
          (s) => s.name == json['stage'],
          orElse: () => WasherStage.idle,
        ),
        remainingMinutes: json['remainingMinutes'] as int? ?? 24,
        waterTempC: json['waterTempC'] as int? ?? 40,
        spinSpeed: json['spinSpeed'] as String? ?? 'High',
        steamEnabled: json['steamEnabled'] as bool? ?? true,
        turboWashEnabled: json['turboWashEnabled'] as bool? ?? true,
        remoteStartActive: json['remoteStartActive'] as bool? ?? true,
        doorLocked: json['doorLocked'] as bool? ?? true,
        tubCleanCount: json['tubCleanCount'] as int? ?? 18,
        brand: json['brand'] as String? ?? 'Samsung SmartThings',
        ecoBubbleEnabled: json['ecoBubbleEnabled'] as bool? ?? true,
        aiWashEnabled: json['aiWashEnabled'] as bool? ?? true,
        superSpeedEnabled: json['superSpeedEnabled'] as bool? ?? false,
        detergentLevelPercent: json['detergentLevelPercent'] as int? ?? 75,
        softenerLevelPercent: json['softenerLevelPercent'] as int? ?? 45,
        addWashDoorLocked: json['addWashDoorLocked'] as bool? ?? true,
        drumCleanCount: json['drumCleanCount'] as int? ?? 28,
        recommendedLaundryRecipe: json['recommendedLaundryRecipe'] as String?,
      );
}

class TvDevice extends SmartDevice {
  int volume; // 0 to 100
  bool isMuted;
  String currentInput; // 'HDMI 1', 'HDMI 2 (eARC)', 'HDMI 3', 'OxygenPlay / OTT'
  String currentApp; // 'OxygenPlay', 'Netflix', 'YouTube', 'Prime Video', 'Hotstar'
  String pictureMode; // 'Vivid', 'Cinema', 'Standard', 'Eye Comfort'
  bool smartVolumeEnabled; // OnePlus Connect feature: auto volume reduction on call

  TvDevice({
    required super.id,
    required super.name,
    required super.room,
    required super.protocol,
    super.isOnline = true,
    super.isPowered = true,
    super.powerUsageWatts = 110.0,
    super.host,
    super.port,
    super.cloudDeviceId,
    super.isDummy = false,
    super.firmwareVersion = '12.0.2',
    this.volume = 24,
    this.isMuted = false,
    this.currentInput = 'OxygenPlay / OTT',
    this.currentApp = 'OxygenPlay',
    this.pictureMode = 'Vivid',
    this.smartVolumeEnabled = true,
  }) : super(category: DeviceCategory.media);

  @override
  String get statusSummary {
    if (!isPowered) return 'Off';
    if (isMuted) return '$currentApp • Muted';
    return '$currentApp • Vol $volume';
  }

  @override
  IconData get icon => Icons.tv_rounded;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'room': room,
        'category': category.name,
        'protocol': protocol.name,
        'isOnline': isOnline,
        'isPowered': isPowered,
        'powerUsageWatts': powerUsageWatts,
        'host': host,
        'port': port,
        'cloudDeviceId': cloudDeviceId,
        'isDummy': isDummy,
        'firmwareVersion': firmwareVersion,
        'volume': volume,
        'isMuted': isMuted,
        'currentInput': currentInput,
        'currentApp': currentApp,
        'pictureMode': pictureMode,
        'smartVolumeEnabled': smartVolumeEnabled,
      };

  factory TvDevice.fromJson(Map<String, dynamic> json) => TvDevice(
        id: json['id'] as String,
        name: json['name'] as String,
        room: json['room'] as String,
        protocol: DeviceProtocol.values.firstWhere(
          (p) => p.name == json['protocol'],
          orElse: () => DeviceProtocol.localLan,
        ),
        isOnline: json['isOnline'] as bool? ?? true,
        isPowered: json['isPowered'] as bool? ?? true,
        powerUsageWatts: (json['powerUsageWatts'] as num?)?.toDouble() ?? 110.0,
        host: json['host'] as String?,
        port: json['port'] as int?,
        cloudDeviceId: json['cloudDeviceId'] as String?,
        isDummy: json['isDummy'] as bool? ?? false,
        firmwareVersion: json['firmwareVersion'] as String? ?? '12.0.2',
        volume: json['volume'] as int? ?? 24,
        isMuted: json['isMuted'] as bool? ?? false,
        currentInput: json['currentInput'] as String? ?? 'OxygenPlay / OTT',
        currentApp: json['currentApp'] as String? ?? 'OxygenPlay',
        pictureMode: json['pictureMode'] as String? ?? 'Vivid',
        smartVolumeEnabled: json['smartVolumeEnabled'] as bool? ?? true,
      );
}

enum CraftIceMode { off, threePerDay, sixPerDay }

class RefrigeratorDevice extends SmartDevice {
  double fridgeTempC;
  double freezerTempC;
  CraftIceMode craftIceMode;
  bool expressFreeze;
  bool doorOpen;
  int waterFilterLifePercent;
  bool hygieneFresh;

  RefrigeratorDevice({
    required super.id,
    required super.name,
    required super.room,
    required super.protocol,
    super.isOnline = true,
    super.isPowered = true,
    super.powerUsageWatts = 120.0,
    super.host,
    super.port,
    super.cloudDeviceId,
    super.isDummy = false,
    super.firmwareVersion = '1.0.0',
    this.fridgeTempC = 3.0,
    this.freezerTempC = -19.0,
    this.craftIceMode = CraftIceMode.sixPerDay,
    this.expressFreeze = false,
    this.doorOpen = false,
    this.waterFilterLifePercent = 88,
    this.hygieneFresh = true,
  }) : super(category: DeviceCategory.refrigerator);

  @override
  String get statusSummary {
    if (doorOpen) return '⚠️ Door Open Alarm!';
    if (expressFreeze) return 'Express Freeze Active';
    return 'Fridge ${fridgeTempC.toInt()}°C / Freezer ${freezerTempC.toInt()}°C';
  }

  @override
  IconData get icon => Icons.kitchen_rounded;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'room': room,
        'category': category.name,
        'protocol': protocol.name,
        'isOnline': isOnline,
        'isPowered': isPowered,
        'powerUsageWatts': powerUsageWatts,
        'host': host,
        'port': port,
        'cloudDeviceId': cloudDeviceId,
        'isDummy': isDummy,
        'firmwareVersion': firmwareVersion,
        'fridgeTempC': fridgeTempC,
        'freezerTempC': freezerTempC,
        'craftIceMode': craftIceMode.name,
        'expressFreeze': expressFreeze,
        'doorOpen': doorOpen,
        'waterFilterLifePercent': waterFilterLifePercent,
        'hygieneFresh': hygieneFresh,
      };

  factory RefrigeratorDevice.fromJson(Map<String, dynamic> json) => RefrigeratorDevice(
        id: json['id'] as String,
        name: json['name'] as String,
        room: json['room'] as String,
        protocol: DeviceProtocol.values.firstWhere(
          (p) => p.name == json['protocol'],
          orElse: () => DeviceProtocol.lgThinQ,
        ),
        isOnline: json['isOnline'] as bool? ?? true,
        isPowered: json['isPowered'] as bool? ?? true,
        powerUsageWatts: (json['powerUsageWatts'] as num?)?.toDouble() ?? 120.0,
        host: json['host'] as String?,
        port: json['port'] as int?,
        cloudDeviceId: json['cloudDeviceId'] as String?,
        isDummy: json['isDummy'] as bool? ?? false,
        firmwareVersion: json['firmwareVersion'] as String? ?? '1.0.0',
        fridgeTempC: (json['fridgeTempC'] as num?)?.toDouble() ?? 3.0,
        freezerTempC: (json['freezerTempC'] as num?)?.toDouble() ?? -19.0,
        craftIceMode: CraftIceMode.values.firstWhere(
          (m) => m.name == json['craftIceMode'],
          orElse: () => CraftIceMode.sixPerDay,
        ),
        expressFreeze: json['expressFreeze'] as bool? ?? false,
        doorOpen: json['doorOpen'] as bool? ?? false,
        waterFilterLifePercent: json['waterFilterLifePercent'] as int? ?? 88,
        hygieneFresh: json['hygieneFresh'] as bool? ?? true,
      );
}
