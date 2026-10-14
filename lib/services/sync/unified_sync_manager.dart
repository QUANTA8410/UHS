import 'dart:async';
import '../discovery/network_discovery_service.dart';
import '../matter/matter_controller_service.dart';
import '../cloud/smartthings_api_service.dart';
import '../cloud/lg_thinq_api_service.dart';
import '../wipro/wipro_tuya_service.dart';
import '../tv/oneplus_connect_service.dart';
import '../../models/device_model.dart';
import '../../providers/home_state.dart';

enum RoutingPath { localMatter, localLan, smartThingsCloud, lgThinQCloud }

class UnifiedSyncManager {
  final NetworkDiscoveryService discoveryService;
  final MatterControllerService matterService;
  final SmartThingsApiService smartThingsService;
  final LgThinqApiService lgThinQService;
  final HomeState homeState;
  final WiproTuyaService wiproService;
  final OnePlusConnectService tvService;

  Timer? _pollingTimer;

  UnifiedSyncManager({
    required this.discoveryService,
    required this.matterService,
    required this.smartThingsService,
    required this.lgThinQService,
    required this.homeState,
    WiproTuyaService? wiproService,
    OnePlusConnectService? tvService,
  })  : wiproService = wiproService ?? WiproTuyaService(),
        tvService = tvService ?? OnePlusConnectService();

  /// Starts background telemetry synchronization across all protocol drivers
  void startBackgroundSync({Duration interval = const Duration(seconds: 15)}) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(interval, (_) => syncAll());
  }

  void stopBackgroundSync() {
    _pollingTimer?.cancel();
  }

  /// Resolve optimal routing path based on protocol and network presence
  RoutingPath resolveRoutingPath(SmartDevice device) {
    if (device.protocol == DeviceProtocol.matter) {
      return RoutingPath.localMatter;
    } else if (device.protocol == DeviceProtocol.localLan) {
      return RoutingPath.localLan;
    } else if (device.protocol == DeviceProtocol.smartThings) {
      return RoutingPath.smartThingsCloud;
    } else {
      return RoutingPath.lgThinQCloud;
    }
  }

  /// Dispatch unified command to target device using optimal protocol driver
  Future<bool> sendCommand(SmartDevice device, String action, Map<String, dynamic> params) async {
    final path = resolveRoutingPath(device);

    switch (path) {
      case RoutingPath.localMatter:
        return matterService.invokeCommand(
          nodeId: 1,
          endpointId: 1,
          clusterId: MatterClusterId.onOff,
          commandId: action == 'toggle' ? 0x02 : 0x01,
          arguments: params,
        );

      case RoutingPath.smartThingsCloud:
        final targetId = device.cloudDeviceId ?? device.id;
        if (device is WasherDevice) {
          return smartThingsService.sendWasherCommand(
            deviceId: targetId,
            action: action,
            args: params['args'] as List<dynamic>? ?? [],
          );
        }
        return smartThingsService.executeCommand(
          deviceId: targetId,
          capability: params['capability'] as String? ?? 'switch',
          command: action == 'toggle' ? (device.isPowered ? 'off' : 'on') : action,
          arguments: params['args'] as List<dynamic>? ?? [],
        );

      case RoutingPath.lgThinQCloud:
        final targetId = device.cloudDeviceId ?? device.id;
        return lgThinQService.sendControlCommand(
          deviceId: targetId,
          commandType: action,
          payload: params,
        );

      case RoutingPath.localLan:
        if (device is TvDevice) {
          if (action == 'launchApp') {
            return tvService.launchApp(
              tvId: device.id,
              appName: params['app'] as String? ?? 'OxygenPlay',
              host: device.host,
            );
          }
          return tvService.sendRemoteKey(
            tvId: device.id,
            keyAction: action,
            host: device.host,
          );
        } else if (device is LightDevice) {
          final host = device.host ?? '';
          if (action == 'toggle' || action == 'power') {
            return wiproService.setPower(host: host, isPowered: device.isPowered);
          } else if (action == 'brightness') {
            return wiproService.setBrightness(
              host: host,
              brightness: params['brightness'] as double? ?? 1.0,
            );
          } else if (action == 'colorTemp') {
            return wiproService.setColorTemp(
              host: host,
              kelvin: params['kelvin'] as int? ?? 3000,
            );
          }
        }
        return true;
    }
  }

  /// Trigger single synchronization cycle across all device drivers
  Future<void> syncAll() async {
    // 1. Scan Local LAN for new or active devices
    await discoveryService.scanLocalNetwork(timeout: const Duration(milliseconds: 200));

    // 2. Poll LG Appliance Shadows
    for (final dev in homeState.allDevices.where((d) => d.protocol == DeviceProtocol.lgThinQ)) {
      final shadow = await lgThinQService.getApplianceShadow(dev.cloudDeviceId ?? dev.id);
      if (dev is WasherDevice && shadow.containsKey('washer')) {
        final wData = shadow['washer'] as Map<String, dynamic>;
        homeState.updateWasher(
          dev.id,
          cycle: wData['cycle'] as String?,
          remainingMinutes: wData['remainTime'] as int?,
        );
      }
    }

    // 3. Poll SmartThings live statuses if authenticated
    if (smartThingsService.isAuthenticated) {
      for (final dev in homeState.allDevices.where((d) => d.protocol == DeviceProtocol.smartThings && d.cloudDeviceId != null)) {
        final status = await smartThingsService.getDeviceStatus(dev.cloudDeviceId!);
        if (status.isNotEmpty) {
          dev.isOnline = true;
        }
      }
    }

    // 4. Verify LAN device reachability
    for (final dev in homeState.allDevices.where((d) => d.protocol == DeviceProtocol.localLan && d.host != null)) {
      if (dev is TvDevice) {
        final online = await tvService.checkConnectivity(dev.host!, timeout: const Duration(milliseconds: 250));
        dev.isOnline = online;
      } else if (dev is LightDevice) {
        final online = await wiproService.checkConnectivity(dev.host!, timeout: const Duration(milliseconds: 250));
        dev.isOnline = online;
      }
    }

    // 5. Mark all default devices online
    for (final dev in homeState.allDevices) {
      if (dev.isDummy) {
        dev.isOnline = true;
      }
    }
    homeState.refresh();
  }
}
