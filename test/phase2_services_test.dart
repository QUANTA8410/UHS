import 'package:flutter_test/flutter_test.dart';
import 'package:unified_home/models/device_model.dart';
import 'package:unified_home/providers/home_state.dart';
import 'package:unified_home/services/discovery/network_discovery_service.dart';
import 'package:unified_home/services/matter/matter_controller_service.dart';
import 'package:unified_home/services/cloud/smartthings_api_service.dart';
import 'package:unified_home/services/cloud/lg_thinq_api_service.dart';
import 'package:unified_home/services/sync/unified_sync_manager.dart';

void main() {
  group('Phase 2: Protocol Engines & Cloud Integrations Tests', () {
    late NetworkDiscoveryService discoveryService;
    late MatterControllerService matterService;
    late SmartThingsApiService smartThingsService;
    late LgThinqApiService lgThinqService;
    late HomeState homeState;
    late UnifiedSyncManager syncManager;

    setUp(() {
      discoveryService = NetworkDiscoveryService();
      matterService = MatterControllerService();
      smartThingsService = SmartThingsApiService();
      lgThinqService = LgThinqApiService();
      homeState = HomeState();

      syncManager = UnifiedSyncManager(
        discoveryService: discoveryService,
        matterService: matterService,
        smartThingsService: smartThingsService,
        lgThinQService: lgThinqService,
        homeState: homeState,
      );
    });

    test('NetworkDiscoveryService scans and discovers local Matter, LG, and Samsung devices', () async {
      final devices = await discoveryService.scanLocalNetwork(timeout: const Duration(milliseconds: 50));

      expect(devices.length, 3);
      expect(devices.any((d) => d.serviceType.contains('_matter')), true);
      expect(devices.any((d) => d.manufacturer.contains('LG Electronics')), true);
      expect(devices.any((d) => d.manufacturer.contains('Samsung Electronics')), true);
    });

    test('MatterControllerService commissions device and invokes cluster commands', () async {
      final commissioned = await matterService.commissionDevice(
        setupPayload: 'MT:Y.K9042C00KA0648G00',
        threadNetworkKey: '00112233445566778899AABBCCDDEEFF',
      );
      expect(commissioned, true);

      final success = await matterService.invokeCommand(
        nodeId: 1,
        endpointId: 1,
        clusterId: MatterClusterId.onOff,
        commandId: 0x01,
        arguments: {'value': true},
      );
      expect(success, true);
    });

    test('SmartThingsApiService executes capability commands and lists devices', () async {
      final devices = await smartThingsService.listDevices();
      expect(devices.isNotEmpty, true);
      expect(devices.first['deviceId'], 'st_plug_01');

      final executed = await smartThingsService.executeCommand(
        deviceId: 'st_plug_01',
        capability: 'switch',
        command: 'on',
      );
      expect(executed, true);
    });

    test('LgThinqApiService fetches shadow telemetry and parses wash cycle data', () async {
      final shadow = await lgThinqService.getApplianceShadow('washer_1');
      expect(shadow.containsKey('washer'), true);

      final washerData = shadow['washer'] as Map<String, dynamic>;
      expect(washerData['cycle'], 'TurboWash 39');
      expect(washerData['waterTemp'], 40);
      expect(washerData['remainTime'], 19);
    });

    test('UnifiedSyncManager routes Matter to local and LG to cloud with full sync', () async {
      final matterLight = homeState.allDevices.firstWhere((d) => d.protocol == DeviceProtocol.matter);
      final lgWasher = homeState.allDevices.firstWhere((d) => d.protocol == DeviceProtocol.lgThinQ);
      final stDevice = homeState.allDevices.firstWhere((d) => d.protocol == DeviceProtocol.smartThings);

      expect(syncManager.resolveRoutingPath(matterLight), RoutingPath.localMatter);
      expect(syncManager.resolveRoutingPath(lgWasher), RoutingPath.lgThinQCloud);
      expect(syncManager.resolveRoutingPath(stDevice), RoutingPath.smartThingsCloud);

      // Perform sync cycle
      await syncManager.syncAll();
      expect(matterLight.isOnline, true);
      expect(lgWasher.isOnline, true);
    });
  });
}
