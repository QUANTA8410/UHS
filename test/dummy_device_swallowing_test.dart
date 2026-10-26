import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_home/providers/real_home_provider.dart';
import 'package:unified_home/services/real_iot_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Bug 3 Fix: Dummy Device Swallowing & Credential Sanitization Tests', () {
    late RealHomeProvider provider;
    late RealIotController controller;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      provider = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);
      controller = provider.iot;
    });

    tearDown(() {
      provider.dispose();
    });

    test('1. A device with vendor: demo and real 16-char Tuya localKey + IP has hasRealHardwareCredentials == true and isDummy == false', () {
      final device = RealSmartDevice(
        id: 'sample_tuya_socket_01',
        name: 'Wipro Smart Plug',
        room: 'Kitchen',
        category: 'switch',
        protocol: ConnectionProtocol.tuyaLocalLan,
        credentials: {
          'vendor': 'demo',
          'ip': '192.168.1.150',
          'localKey': '0123456789abcdef', // 16 characters
        },
      );

      expect(device.hasRealHardwareCredentials, isTrue);
      expect(device.isDummy, isFalse);
    });

    test('2. When updated via updateDevice, vendor: demo is automatically stripped', () async {
      final initialDevice = RealSmartDevice(
        id: 'sample_tuya_plug_02',
        name: 'Tuya Living Room Plug',
        room: 'Living Room',
        category: 'switch',
        protocol: ConnectionProtocol.tuyaLocalLan,
        credentials: {
          'vendor': 'demo',
          'token': 'demo_token_123',
        },
      );

      provider.addDeviceDirect(initialDevice);
      expect(provider.devices.length, 1);
      expect(provider.devices.first.isDummy, isTrue);
      expect(provider.devices.first.credentials['vendor'], 'demo');

      // Now update with real hardware credentials
      final updatedDevice = initialDevice.copyWith(
        credentials: {
          'vendor': 'demo',
          'token': 'demo_token_123',
          'ip': '192.168.1.188',
          'localKey': 'abcdef0123456789', // 16 characters
        },
      );

      await provider.updateDevice(updatedDevice);

      final stored = provider.devices.first;
      expect(stored.credentials.containsKey('vendor'), isFalse);
      expect(stored.credentials.containsKey('token'), isFalse); // demo token stripped
      expect(stored.credentials['ip'], '192.168.1.188');
      expect(stored.credentials['localKey'], 'abcdef0123456789');
      expect(stored.hasRealHardwareCredentials, isTrue);
      expect(stored.isDummy, isFalse);
    });

    test('3. An unconfigured device (credentials: {}) does not crash on !, but throws descriptive missing credential exception', () async {
      final unconfiguredHaDevice = RealSmartDevice(
        id: 'light.living_room_ceiling',
        name: 'HA Ceiling Light',
        room: 'Living Room',
        category: 'light',
        protocol: ConnectionProtocol.homeAssistantBridge,
        credentials: {},
      );

      // It must NOT be treated as a dummy, so commands are not silently swallowed
      expect(unconfiguredHaDevice.hasRealHardwareCredentials, isFalse);
      expect(unconfiguredHaDevice.isDummy, isFalse);

      // Testing setPower: must throw descriptive missing credential exception, never null check operator crash
      expect(
        () async => await controller.setPower(unconfiguredHaDevice, true),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains("Missing required credential 'hubUrl' for device 'HA Ceiling Light'"),
          ),
        ),
      );

      // Testing refreshDeviceStatus
      expect(
        () async => await controller.refreshDeviceStatus(unconfiguredHaDevice),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains("Missing required credential 'hubUrl' for device 'HA Ceiling Light'"),
          ),
        ),
      );

      // Testing setPrimaryLevel
      expect(
        () async => await controller.setPrimaryLevel(unconfiguredHaDevice, 80.0),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains("Missing required credential 'hubUrl' for device 'HA Ceiling Light'"),
          ),
        ),
      );

      // Testing executeDeviceCommand
      expect(
        () async => await controller.executeDeviceCommand(unconfiguredHaDevice, 'light', 'turn_on'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains("Missing required credential 'hubUrl' for device 'HA Ceiling Light'"),
          ),
        ),
      );

      // Testing toggleDevicePower in provider: optimistic rollback and clean lastGlobalError
      provider.addDeviceDirect(unconfiguredHaDevice);
      try {
        await provider.toggleDevicePower(provider.devices.first);
        fail('Should have thrown missing credential exception');
      } catch (e) {
        expect(e, isA<Exception>());
      }
      expect(provider.devices.first.isOn, isFalse);
      expect(provider.lastGlobalError, contains("Missing required credential 'hubUrl'"));
    });

    test('3b. Empty IP/URLs for customHttpWebhook, philipsHueLocal, and philipsWizUdp throw descriptive exceptions', () async {
      final unconfiguredHue = RealSmartDevice(
        id: 'hue_light_1',
        name: 'Philips Hue Bulb',
        room: 'Bedroom',
        category: 'light',
        protocol: ConnectionProtocol.philipsHueLocal,
        credentials: {},
      );

      expect(
        () async => await controller.setPower(unconfiguredHue, true),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains("Missing required credential 'bridgeIp' (or 'ip')"),
          ),
        ),
      );

      final unconfiguredWiz = RealSmartDevice(
        id: 'wiz_bulb_1',
        name: 'Philips WiZ Bulb',
        room: 'Living Room',
        category: 'light',
        protocol: ConnectionProtocol.philipsWizUdp,
        credentials: {},
      );

      expect(
        () async => await controller.setPower(unconfiguredWiz, true),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains("Missing required credential 'ip'"),
          ),
        ),
      );

      final unconfiguredWebhook = RealSmartDevice(
        id: 'webhook_relay_1',
        name: 'Custom Webhook Relay',
        room: 'Garage',
        category: 'switch',
        protocol: ConnectionProtocol.customHttpWebhook,
        credentials: {},
      );

      expect(
        () async => await controller.setPower(unconfiguredWebhook, true),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains("Missing required credential 'onUrl' (or 'controlUrl', 'url')"),
          ),
        ),
      );
    });

    test('4. Sample devices from loadSampleSmartHome() remain demo until real credentials are attached', () async {
      await provider.loadSampleSmartHome();
      expect(provider.devices.isNotEmpty, isTrue);

      final sampleWasher = provider.devices.firstWhere((d) => d.id == 'samsung_washer_ecobubble_01');
      expect(sampleWasher.isDummy, isTrue);
      expect(sampleWasher.hasRealHardwareCredentials, isFalse);

      // Toggling power on demo sample device succeeds optimistically without throwing network errors
      await provider.toggleDevicePower(sampleWasher);
      expect(sampleWasher.isOn, isFalse);
      expect(provider.lastGlobalError, isNull);

      // Now attach real SmartThings token to the sample washer
      final realWasher = sampleWasher.copyWith(
        credentials: {
          'vendor': 'demo',
          'token': 'a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6', // valid 32-char token
        },
      );

      await provider.updateDevice(realWasher);
      final updatedWasher = provider.devices.firstWhere((d) => d.id == 'samsung_washer_ecobubble_01');

      expect(updatedWasher.hasRealHardwareCredentials, isTrue);
      expect(updatedWasher.isDummy, isFalse);
      expect(updatedWasher.credentials.containsKey('vendor'), isFalse); // 'vendor': 'demo' stripped!
      expect(updatedWasher.credentials['token'], 'a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6');

      // Check that provider recognizes it as hardware executable despite having 'sample' in ID or category
      expect(provider.devices.any((d) => d.id == 'samsung_washer_ecobubble_01' && d.hasRealHardwareCredentials), isTrue);
    });

    test('5. Multi-protocol hasRealHardwareCredentials and _isHardwareExecutable validation', () {
      // Tuya Cloud Direct
      final tuyaCloud = RealSmartDevice(
        id: 'sample_tuya_cloud_01',
        name: 'Tuya Cloud Light',
        room: 'Study',
        category: 'light',
        protocol: ConnectionProtocol.tuyaCloudDirect,
        credentials: {'accessToken': 'valid_cloud_access_token_123'},
      );
      expect(tuyaCloud.hasRealHardwareCredentials, isTrue);
      expect(tuyaCloud.isDummy, isFalse);

      // OnePlus TV
      final tv = RealSmartDevice(
        id: 'demo_tv_01',
        name: 'Living Room TV',
        room: 'Living Room',
        category: 'tv',
        protocol: ConnectionProtocol.onePlusTvLan,
        credentials: {'ip': '192.168.1.125'},
      );
      expect(tv.hasRealHardwareCredentials, isTrue);
      expect(tv.isDummy, isFalse);

      // Philips Hue Local
      final hue = RealSmartDevice(
        id: 'sample_hue_01',
        name: 'Hue Ambient',
        room: 'Living Room',
        category: 'light',
        protocol: ConnectionProtocol.philipsHueLocal,
        credentials: {'bridgeIp': '192.168.1.40', 'username': 'user_hue_12345', 'lightId': '1'},
      );
      expect(hue.hasRealHardwareCredentials, isTrue);
      expect(hue.isDummy, isFalse);

      // Philips WiZ UDP
      final wiz = RealSmartDevice(
        id: 'demo_wiz_bulb',
        name: 'WiZ Color',
        room: 'Balcony',
        category: 'light',
        protocol: ConnectionProtocol.philipsWizUdp,
        credentials: {'ip': '192.168.1.75'},
      );
      expect(wiz.hasRealHardwareCredentials, isTrue);
      expect(wiz.isDummy, isFalse);

      // RTSP / ONVIF Camera
      final cam = RealSmartDevice(
        id: 'test_cam_01',
        name: 'Security Cam 360',
        room: 'Entrance',
        category: 'camera',
        protocol: ConnectionProtocol.rtspOnvifCamera,
        credentials: {'ip': '192.168.1.200'},
      );
      expect(cam.hasRealHardwareCredentials, isTrue);
      expect(cam.isDummy, isFalse);

      // Custom Webhook
      final webhook = RealSmartDevice(
        id: 'sample_relay',
        name: 'Shelly Webhook',
        room: 'Balcony',
        category: 'switch',
        protocol: ConnectionProtocol.customHttpWebhook,
        credentials: {'controlUrl': 'http://192.168.1.99/relay/0'},
      );
      expect(webhook.hasRealHardwareCredentials, isTrue);
      expect(webhook.isDummy, isFalse);
    });
  });
}
