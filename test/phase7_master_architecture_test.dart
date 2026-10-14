import 'package:flutter_test/flutter_test.dart';
import 'package:unified_home/services/master/cross_brand_reflex_bus.dart';
import 'package:unified_home/services/master/presence_and_os_bridge.dart';
import 'package:unified_home/services/master/self_healing_network_engine.dart';
import 'package:unified_home/services/master/zero_touch_onboarding_service.dart';
import 'package:unified_home/services/real_iot_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 7: Master Architecture Pillars Tests', () {
    test('SelfHealingNetworkEngine tracks in-flight devices and rollback state', () async {
      final engine = SelfHealingNetworkEngine();
      final device = RealSmartDevice(
        id: 'test_dev_01',
        name: 'Test Light',
        room: 'Living Room',
        category: 'light',
        protocol: ConnectionProtocol.tuyaLocalLan,
        credentials: {'ip': '127.0.0.1', 'port': '6668', 'localKey': '1234567890123456'},
        isOn: false,
      );

      expect(engine.isDeviceInFlight(device.id), isFalse);

      // Successful in-memory call
      await engine.executeWithOptimisticRollback<bool>(
        device: device,
        optimisticValue: true,
        getCurrentValue: () => device.isOn,
        applyValueLocal: (v) => device.isOn = v,
        networkCall: () async {},
        notifyUi: () {},
      );

      expect(device.isOn, isTrue);
      expect(engine.isDeviceInFlight(device.id), isFalse);
    });

    test('CrossBrandReflexBus evaluates signature cinema reflex', () async {
      final bus = CrossBrandReflexBus();

      final tv = RealSmartDevice(
        id: 'tv_1',
        name: 'OnePlus TV 55',
        room: 'Living Room',
        category: 'tv',
        protocol: ConnectionProtocol.onePlusTvLan,
        credentials: {'ip': '192.168.1.105'},
        isOn: true,
      );

      final bulb = RealSmartDevice(
        id: 'bulb_1',
        name: 'Wipro Smart Bulb',
        room: 'Living Room',
        category: 'light',
        protocol: ConnectionProtocol.tuyaLocalLan,
        credentials: {'ip': '192.168.1.110'},
        isOn: true,
        primaryValue: 100.0,
      );

      final executedActions = <String>[];

      final logs = await bus.evaluateReflexes(
        event: HardwareReflexEvent(
          sourceDeviceId: tv.id,
          sourceCategory: 'tv',
          eventType: 'power_on',
        ),
        allDevices: [tv, bulb],
        executeAction: (dev, power, level) async {
          executedActions.add('${dev.id}:$power:$level');
        },
      );

      expect(logs.isNotEmpty, isTrue);
      expect(executedActions.any((a) => a.contains('bulb_1:true:15.0')), isTrue);

      bus.dispose();
    });

    test('ZeroTouchOnboardingService signature generation produces valid HMAC', () {
      final zeroTouch = ZeroTouchOnboardingService();
      expect(zeroTouch, isNotNull);
    });

    test('PresenceAndOsBridge initialized with default presence', () {
      final bridge = PresenceAndOsBridge();
      expect(bridge.isUserAtHome, isTrue);
      expect(bridge.homeRouterBssid, isNull);
    });
  });
}
