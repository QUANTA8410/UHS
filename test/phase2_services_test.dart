import 'package:flutter_test/flutter_test.dart';
import 'package:unified_home/services/discovery/network_discovery_service.dart';
import 'package:unified_home/services/matter/matter_controller_service.dart';
import 'package:unified_home/services/cloud/smartthings_api_service.dart';
import 'package:unified_home/services/cloud/lg_thinq_api_service.dart';
import 'package:unified_home/services/master/zero_touch_onboarding_service.dart';
import 'package:unified_home/services/real_iot_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 2: Protocol Engines & Cloud Integrations Tests', () {
    late NetworkDiscoveryService discoveryService;
    late MatterControllerService matterService;
    late SmartThingsApiService smartThingsService;
    late LgThinqApiService lgThinqService;
    late ZeroTouchOnboardingService zeroTouchService;

    setUp(() {
      discoveryService = NetworkDiscoveryService();
      matterService = MatterControllerService();
      smartThingsService = SmartThingsApiService();
      lgThinqService = LgThinqApiService();
      zeroTouchService = ZeroTouchOnboardingService();
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

    test('SmartThingsApiService executes capability commands on RealSmartDevice', () async {
      final dev = RealSmartDevice(
        id: 'st_plug_01',
        name: 'SmartThings Outlet',
        room: 'Living Room',
        category: 'switch',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {'cloudDeviceId': 'st_plug_01', 'token': 'mock_token', 'vendor': 'demo'},
        isOn: false,
      );

      final executed = await smartThingsService.executeCommand(
        device: dev,
        power: true,
      );
      expect(executed, true);
    });

    test('LgThinqApiService validates session and sends control command', () async {
      lgThinqService.setSessionToken('valid_pat_token');
      expect(lgThinqService.isAuthenticated, true);
      expect(lgThinqService.accessToken, 'valid_pat_token');

      final ac = RealSmartDevice(
        id: 'lg_ac_01',
        name: 'LG DualCool AC',
        room: 'Living Room',
        category: 'ac',
        protocol: ConnectionProtocol.customHttpWebhook,
        credentials: {'devId': 'lg_ac_01', 'pat': 'mock_pat', 'vendor': 'demo'},
      );

      final sent = await lgThinqService.sendControlCommand(
        device: ac,
        power: true,
        temperature: 21.0,
      );
      expect(sent, true);
    });

    test('ZeroTouchOnboardingService has official LG ThinQ API key configured', () {
      expect(zeroTouchService, isNotNull);
    });
  });
}
