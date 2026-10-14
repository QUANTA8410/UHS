import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_home/providers/real_home_provider.dart';
import 'package:unified_home/services/auth/brand_oauth_catalog.dart';
import 'package:unified_home/services/real_iot_controller.dart';
import 'package:unified_home/ui/widgets/animations/universal_device_animations.dart';
import 'package:unified_home/ui/widgets/dialogs/camera_cockpit_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Cameras & Philips Fleet Protocols & Archetypes', () {
    test('ConnectionProtocol enum contains all required protocols', () {
      expect(ConnectionProtocol.values.map((e) => e.name), containsAll([
        'philipsHueLocal',
        'philipsWizUdp',
        'rtspOnvifCamera',
      ]));
    });

    test('BrandOAuthCatalog defines Philips Hue, WiZ, Realme Camera, and Philips Camera', () {
      final providers = BrandOAuthCatalog.providers;
      final ids = providers.map((p) => p.id).toList();

      expect(ids, contains('philips_hue'));
      expect(ids, contains('philips_wiz'));
      expect(ids, contains('realme_camera'));
      expect(ids, contains('philips_camera'));

      final hue = providers.firstWhere((p) => p.id == 'philips_hue');
      expect(hue.vendorType, equals('philips_hue'));

      final wiz = providers.firstWhere((p) => p.id == 'philips_wiz');
      expect(wiz.vendorType, equals('philips_wiz'));

      final realme = providers.firstWhere((p) => p.id == 'realme_camera');
      expect(realme.vendorType, equals('realme_camera'));

      final philipsCam = providers.firstWhere((p) => p.id == 'philips_camera');
      expect(philipsCam.vendorType, equals('philips_camera'));
    });

    test('UniversalCategoryClassifier categorizes Camera and Philips lights properly', () {
      final cam = RealSmartDevice(
        id: 'cam_realme_01',
        name: 'Realme Smart Cam 360',
        room: 'Living Room',
        category: 'camera',
        protocol: ConnectionProtocol.rtspOnvifCamera,
        credentials: const {},
      );

      final hue = RealSmartDevice(
        id: 'hue_light_01',
        name: 'Philips Hue White & Color Ambiance',
        room: 'Bedroom',
        category: 'light',
        protocol: ConnectionProtocol.philipsHueLocal,
        credentials: const {},
      );

      expect(
        UniversalCategoryClassifier.classify(cam),
        equals(UniversalDeviceArchetype.cameraSecurity),
      );
      expect(
        UniversalCategoryClassifier.classify(hue),
        equals(UniversalDeviceArchetype.lighting),
      );
    });

    test('RealSmartDevice serialization with Camera & Philips protocols', () {
      final cam = RealSmartDevice(
        id: 'cam_001',
        name: 'Front Door Camera',
        room: 'Entrance',
        category: 'camera',
        protocol: ConnectionProtocol.rtspOnvifCamera,
        credentials: {
          'ip': '192.168.1.120',
          'port': '554',
          'rtspUrl': 'rtsp://admin:pass@192.168.1.120:554/live/ch0',
        },
        isOn: true,
        isOnline: true,
        primaryValue: 1080.0,
        ratedMaxWatts: 4.5,
      );

      final json = cam.toJson();
      final reconstructed = RealSmartDevice.fromJson(json);

      expect(reconstructed.id, equals('cam_001'));
      expect(reconstructed.category, equals('camera'));
      expect(reconstructed.protocol, equals(ConnectionProtocol.rtspOnvifCamera));
      expect(reconstructed.credentials['ip'], equals('192.168.1.120'));
      expect(reconstructed.ratedMaxWatts, equals(4.5));
      expect(reconstructed.isOn, isTrue);
    });
  });

  group('Camera & Philips Fleet Physics-Calibrated Wattage Curves', () {
    final controller = RealIotController();

    test('Realme Smart Cam 360: Active 1080p Stream vs Privacy Standby vs Offline', () {
      final cam = RealSmartDevice(
        id: 'cam_realme',
        name: 'Realme 360',
        room: 'Living Room',
        category: 'camera',
        protocol: ConnectionProtocol.rtspOnvifCamera,
        credentials: {'brand': 'realme'},
        isOn: true,
        isOnline: true,
        ratedMaxWatts: 4.5,
      );

      // 1. Active 1080p Stream
      final activeWatts = controller.computeDeviceLiveWattage(cam);
      expect(activeWatts, equals(4.5));
      expect(cam.liveWatts, equals(4.5));
      expect(cam.liveAttributes['powerSource'], contains('Active 1080p Stream'));

      // 2. Privacy Mode (Toggled power off)
      cam.isOn = false;
      final standbyWatts = controller.computeDeviceLiveWattage(cam);
      expect(standbyWatts, equals(2.0));
      expect(cam.liveWatts, equals(2.0));
      expect(cam.liveAttributes['powerSource'], contains('Standby (Privacy Mode)'));

      // 3. Physically Offline
      cam.isOnline = false;
      final offlineWatts = controller.computeDeviceLiveWattage(cam);
      expect(offlineWatts, equals(0.0));
      expect(cam.liveWatts, equals(0.0));
      expect(cam.liveAttributes['powerSource'], contains('Offline'));
    });

    test('Philips Hue Light: 9.5W Calibrated Curve', () {
      final hue = RealSmartDevice(
        id: 'hue_bulb',
        name: 'Hue Color Lamp',
        room: 'Office',
        category: 'light',
        protocol: ConnectionProtocol.philipsHueLocal,
        credentials: const {},
        isOn: true,
        isOnline: true,
        primaryValue: 100.0,
        ratedMaxWatts: 9.5,
      );

      // 100% Brightness: 0.4 standby + (1.0 * 9.5) = 9.9W
      final w100 = controller.computeDeviceLiveWattage(hue);
      expect(w100, closeTo(9.9, 0.01));
      expect(hue.liveAttributes['powerSource'], contains('Philips Hue White & Color'));

      // 50% Brightness: 0.4 + (0.5 * 9.5) = 5.15W
      hue.primaryValue = 50.0;
      final w50 = controller.computeDeviceLiveWattage(hue);
      expect(w50, closeTo(5.15, 0.01));

      // Light Off (Standby Zigbee draw)
      hue.isOn = false;
      final wOff = controller.computeDeviceLiveWattage(hue);
      expect(wOff, equals(0.4));
      expect(hue.liveAttributes['powerSource'], contains('Zigbee Standby'));
    });

    test('Philips WiZ Smart Bulb: 8.5W Calibrated Curve', () {
      final wiz = RealSmartDevice(
        id: 'wiz_bulb',
        name: 'WiZ Warm White',
        room: 'Kitchen',
        category: 'light',
        protocol: ConnectionProtocol.philipsWizUdp,
        credentials: const {},
        isOn: true,
        isOnline: true,
        primaryValue: 100.0,
        ratedMaxWatts: 8.5,
      );

      // 100% Dimming: 0.4 standby + (1.0 * 8.5) = 8.9W
      final w100 = controller.computeDeviceLiveWattage(wiz);
      expect(w100, closeTo(8.9, 0.01));
      expect(wiz.liveAttributes['powerSource'], contains('Philips WiZ Smart LED'));

      // 50% Dimming: 0.4 + (0.5 * 8.5) = 4.65W
      wiz.primaryValue = 50.0;
      final w50 = controller.computeDeviceLiveWattage(wiz);
      expect(w50, closeTo(4.65, 0.01));

      // Bulb Off (Wi-Fi standby)
      wiz.isOn = false;
      final wOff = controller.computeDeviceLiveWattage(wiz);
      expect(wOff, equals(0.4));
      expect(wiz.liveAttributes['powerSource'], contains('Wi-Fi Standby'));
    });
  });

  group('RealHomeProvider Camera & Philips Fleet Operations', () {
    test('PTZ and Privacy Mode commands update device state correctly', () async {
      final provider = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);

      final cam = RealSmartDevice(
        id: 'cam_test_01',
        name: 'Realme 360 Cam',
        room: 'Balcony',
        category: 'camera',
        protocol: ConnectionProtocol.rtspOnvifCamera,
        credentials: {'brand': 'realme', 'ip': '127.0.0.1'},
        isOn: true,
        isOnline: true,
        ratedMaxWatts: 4.5,
      );

      provider.addDeviceDirect(cam);
      expect(provider.devices.length, equals(1));
      expect(provider.totalLiveWatts, equals(4.5));

      // Test PTZ Command execution
      await provider.executeDeviceCommand(cam, 'ptz', 'ptzMove', ['left']);
      expect(cam.liveAttributes['lastPtzDirection'], equals('left'));

      // Test Camera Privacy Toggle (Power Toggle)
      await provider.toggleDevicePower(cam);
      expect(cam.isOn, isFalse);
      expect(cam.liveAttributes['privacyMode'], isTrue);
      expect(cam.liveWatts, equals(2.0));
      expect(provider.totalLiveWatts, equals(2.0));

      provider.dispose();
    });

    test('Fleet Aggregation with Cameras and Philips Bulbs', () {
      final provider = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);

      final cam = RealSmartDevice(
        id: 'cam_01',
        name: 'Philips Camera',
        room: 'Garden',
        category: 'camera',
        protocol: ConnectionProtocol.rtspOnvifCamera,
        credentials: const {},
        isOn: true,
        isOnline: true,
        ratedMaxWatts: 4.5,
      );

      final hue = RealSmartDevice(
        id: 'hue_01',
        name: 'Hue Living Room',
        room: 'Living Room',
        category: 'light',
        protocol: ConnectionProtocol.philipsHueLocal,
        credentials: const {},
        isOn: true,
        isOnline: true,
        primaryValue: 100.0,
        ratedMaxWatts: 9.5,
      );

      final wiz = RealSmartDevice(
        id: 'wiz_01',
        name: 'WiZ Bedroom',
        room: 'Bedroom',
        category: 'light',
        protocol: ConnectionProtocol.philipsWizUdp,
        credentials: const {},
        isOn: true,
        isOnline: true,
        primaryValue: 100.0,
        ratedMaxWatts: 8.5,
      );

      provider.addDeviceDirect(cam);
      provider.addDeviceDirect(hue);
      provider.addDeviceDirect(wiz);

      final controller = RealIotController();
      controller.computeDeviceLiveWattage(cam); // 4.5W
      controller.computeDeviceLiveWattage(hue); // 9.9W
      controller.computeDeviceLiveWattage(wiz); // 8.9W

      // Total Live Watts = 4.5 + 9.9 + 8.9 = 23.3W
      expect(provider.totalLiveWatts, closeTo(23.3, 0.05));
      expect(provider.lightingAndMediaWatts, closeTo(23.3, 0.05));
      expect(provider.hvacAndLaundryWatts, equals(0.0));
      expect(provider.activeDrawingDevicesCount, equals(3));

      provider.dispose();
    });
  });

  group('CameraCockpitSheet Widget UI Tests', () {
    testWidgets('Renders 16:9 Viewfinder, HUD, 360 PTZ Gimbal, and 4 Toggle Pills', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final iot = RealIotController();
      final cam = RealSmartDevice(
        id: 'cockpit_cam_01',
        name: 'Realme 360 Front Door',
        room: 'Porch',
        category: 'camera',
        protocol: ConnectionProtocol.rtspOnvifCamera,
        credentials: {
          'brand': 'realme',
          'rtspUrl': 'rtsp://admin:pass@192.168.1.120:554/live/ch0',
        },
        isOn: true,
        isOnline: true,
        liveWatts: 4.5,
        ratedMaxWatts: 4.5,
      );

      bool stateChanged = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CameraCockpitSheet(
              device: cam,
              iot: iot,
              onStateChanged: () {
                stateChanged = true;
              },
            ),
          ),
        ),
      );

      // Verify Header
      expect(find.text('Realme 360 Front Door'), findsOneWidget);
      expect(find.textContaining('REALME • Porch • 4.5 W'), findsOneWidget);

      // Verify 16:9 Viewfinder & HUD Elements
      expect(find.text('LIVE RTSP'), findsOneWidget);
      expect(find.text('1080P • 30 FPS • 2.4 Mbps • H.264'), findsOneWidget);
      expect(find.text('Launch Fullscreen Hardware Stream'), findsOneWidget);

      // Verify 360 PTZ Gimbal Pad
      expect(find.text('360° PTZ Gimbal Pad'), findsOneWidget);
      expect(find.textContaining('Pan: 0° • Tilt: 0°'), findsOneWidget);

      // Verify 4 Apple Glass Hardware Toggle Pills
      expect(find.text('Night Vision (IR)'), findsOneWidget);
      expect(find.text('AI Motion Track'), findsOneWidget);
      expect(find.text('360° Patrol'), findsOneWidget);
      expect(find.text('Privacy Mask'), findsOneWidget);

      // Test Tapping a PTZ button (e.g. Left)
      final leftBtn = find.byIcon(Icons.arrow_back_rounded);
      expect(leftBtn, findsOneWidget);
      await tester.tap(leftBtn);
      await tester.pump();

      expect(stateChanged, isTrue);
      expect(cam.liveAttributes['lastPtzDirection'], equals('left'));
      expect(cam.liveAttributes['panAngle'], equals(-30.0));
      expect(find.textContaining('Pan: -30° • Tilt: 0°'), findsOneWidget);

      // Test Stream Quality Toggle (HD vs Sub-Stream)
      expect(find.text('MAIN HD'), findsOneWidget);
      await tester.tap(find.text('MAIN HD'));
      await tester.pump();
      expect(find.text('SUB'), findsOneWidget);
      expect(find.text('640x360 • 15 FPS • 512 Kbps'), findsOneWidget);

      // Switch back to Main HD
      await tester.tap(find.text('SUB'));
      await tester.pump();
      expect(find.text('MAIN HD'), findsOneWidget);
      expect(find.text('1080P • 30 FPS • 2.4 Mbps • H.264'), findsOneWidget);

      // Test Audio Mute / Unmute Toggle
      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.volume_off_rounded));
      await tester.pump();
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

      // Test Tapping Hardware Feature Toggles
      stateChanged = false;
      await tester.tap(find.text('Night Vision (IR)'));
      await tester.pump();
      expect(stateChanged, isTrue);
      expect(cam.liveAttributes['nightVision'], isTrue);

      stateChanged = false;
      await tester.tap(find.text('AI Motion Track'));
      await tester.pump();
      expect(stateChanged, isTrue);
      expect(cam.liveAttributes['motionTrack'], isTrue);

      stateChanged = false;
      await tester.tap(find.text('360° Patrol'));
      await tester.pump();
      expect(stateChanged, isTrue);
      expect(cam.liveAttributes['patrol360'], isTrue);

      // Test Privacy Mask Toggle
      stateChanged = false;
      await tester.tap(find.text('Privacy Mask'));
      await tester.pump();
      expect(stateChanged, isTrue);
      expect(cam.isOn, isFalse);
      expect(cam.liveAttributes['privacyMode'], isTrue);
      expect(find.text('Privacy Mask Active'), findsOneWidget);
    });
  });
}
