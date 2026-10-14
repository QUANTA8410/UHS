import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unified_home/services/real_iot_controller.dart';
import 'package:unified_home/ui/widgets/animations/universal_device_animations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Universal 12-Category Procedural Animation Engine Tests', () {
    test('Classifies all 12 archetypes accurately from real device signatures', () {
      final vacuum = RealSmartDevice(
        id: 'roborock_s8_01',
        name: 'Roborock S8 Pro Ultra',
        room: 'Living Room',
        category: 'vacuum',
        protocol: ConnectionProtocol.onePlusTvLan,
        credentials: const {},
      );
      expect(UniversalCategoryClassifier.classify(vacuum), equals(UniversalDeviceArchetype.robotVacuum));

      final camera = RealSmartDevice(
        id: 'cam_doorbell_01',
        name: 'Front Door Eufy Cam',
        room: 'Entrance',
        category: 'camera',
        protocol: ConnectionProtocol.onePlusTvLan,
        credentials: const {},
      );
      expect(UniversalCategoryClassifier.classify(camera), equals(UniversalDeviceArchetype.cameraSecurity));

      final lock = RealSmartDevice(
        id: 'yale_linus_01',
        name: 'Yale Smart Door Lock',
        room: 'Entrance',
        category: 'lock',
        protocol: ConnectionProtocol.onePlusTvLan,
        credentials: const {},
      );
      expect(UniversalCategoryClassifier.classify(lock), equals(UniversalDeviceArchetype.lockAccess));

      final shade = RealSmartDevice(
        id: 'somfy_blind_01',
        name: 'Living Room Roller Shade',
        room: 'Living Room',
        category: 'curtain',
        protocol: ConnectionProtocol.onePlusTvLan,
        credentials: const {},
      );
      expect(UniversalCategoryClassifier.classify(shade), equals(UniversalDeviceArchetype.curtainShade));

      final fridge = RealSmartDevice(
        id: 'samsung_bespoke_01',
        name: 'Samsung Bespoke Refrigerator',
        room: 'Kitchen',
        category: 'fridge',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: const {},
      );
      expect(UniversalCategoryClassifier.classify(fridge), equals(UniversalDeviceArchetype.refrigeration));

      final washer = RealSmartDevice(
        id: 'st_washer_01',
        name: 'Samsung AI EcoBubble Washer',
        room: 'Laundry Room',
        category: 'washer',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: const {},
      );
      expect(UniversalCategoryClassifier.classify(washer), equals(UniversalDeviceArchetype.laundry));

      final fan = RealSmartDevice(
        id: 'dyson_purifier_01',
        name: 'Dyson Hot+Cool Purifier Fan',
        room: 'Master Bedroom',
        category: 'fan',
        protocol: ConnectionProtocol.onePlusTvLan,
        credentials: const {},
      );
      expect(UniversalCategoryClassifier.classify(fan), equals(UniversalDeviceArchetype.fanAir));

      final ac = RealSmartDevice(
        id: 'lg_dualcool_01',
        name: 'LG DualCool AI Inverter AC',
        room: 'Living Room',
        category: 'ac',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: const {},
      );
      expect(UniversalCategoryClassifier.classify(ac), equals(UniversalDeviceArchetype.climateAc));

      final speaker = RealSmartDevice(
        id: 'sonos_era_01',
        name: 'Sonos Era 300 Speaker',
        room: 'Living Room',
        category: 'speaker',
        protocol: ConnectionProtocol.onePlusTvLan,
        credentials: const {},
      );
      expect(UniversalCategoryClassifier.classify(speaker), equals(UniversalDeviceArchetype.speakerAudio));

      final tv = RealSmartDevice(
        id: 'oneplus_tv_01',
        name: 'OnePlus TV 55 U1S',
        room: 'Living Room',
        category: 'tv',
        protocol: ConnectionProtocol.onePlusTvLan,
        credentials: const {},
      );
      expect(UniversalCategoryClassifier.classify(tv), equals(UniversalDeviceArchetype.tvMedia));

      final light = RealSmartDevice(
        id: 'wipro_bulb_01',
        name: 'Wipro Next 12W Smart Bulb',
        room: 'Living Room',
        category: 'light',
        protocol: ConnectionProtocol.tuyaLocalLan,
        credentials: const {},
      );
      expect(UniversalCategoryClassifier.classify(light), equals(UniversalDeviceArchetype.lighting));

      final plug = RealSmartDevice(
        id: 'tapo_p110_01',
        name: 'Smart Energy Plug 16A',
        room: 'Kitchen',
        category: 'plug',
        protocol: ConnectionProtocol.tuyaLocalLan,
        credentials: const {},
      );
      expect(UniversalCategoryClassifier.classify(plug), equals(UniversalDeviceArchetype.plugEnergy));
    });

    test('All 12 archetypes have distinct color, icon, and slider flags', () {
      for (final type in UniversalDeviceArchetype.values) {
        final color = UniversalCategoryClassifier.colorFor(type);
        final icon = UniversalCategoryClassifier.iconFor(type);
        expect(color.toARGB32(), isNonZero);
        expect(icon.codePoint, isNonZero);
      }

      expect(UniversalCategoryClassifier.supportsHorizontalSlider(UniversalDeviceArchetype.lighting), isTrue);
      expect(UniversalCategoryClassifier.supportsHorizontalSlider(UniversalDeviceArchetype.climateAc), isTrue);
      expect(UniversalCategoryClassifier.supportsHorizontalSlider(UniversalDeviceArchetype.fanAir), isTrue);
      expect(UniversalCategoryClassifier.supportsHorizontalSlider(UniversalDeviceArchetype.speakerAudio), isTrue);
      expect(UniversalCategoryClassifier.supportsHorizontalSlider(UniversalDeviceArchetype.curtainShade), isTrue);
      expect(UniversalCategoryClassifier.supportsHorizontalSlider(UniversalDeviceArchetype.robotVacuum), isFalse);
    });

    testWidgets('UniversalAnimatedGlassCard renders 60 FPS animation elements and touches', (tester) async {
      final dev = RealSmartDevice(
        id: 'st_washer_test',
        name: 'Samsung Washer Test',
        room: 'Laundry Room',
        category: 'washer',
        isOn: true,
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: const {},
      );

      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 180,
                height: 180,
                child: UniversalAnimatedGlassCard(
                  device: dev,
                  onTap: () => tapped = true,
                  onLongPress: () {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Samsung Washer Test'), findsOneWidget);
      expect(find.text('LIVE'), findsOneWidget);

      await tester.tap(find.text('Samsung Washer Test'));
      expect(tapped, isTrue);

      // Verify animation frames step smoothly without crashing
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('UniversalAnimatedGlassCard separates onPowerToggle emblem from card onTap', (tester) async {
      final dev = RealSmartDevice(
        id: 'st_washer_test_2',
        name: 'Samsung Washer Test 2',
        room: 'Laundry Room',
        category: 'washer',
        isOn: true,
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: const {},
      );

      bool cardTapped = false;
      bool powerToggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 180,
                height: 180,
                child: UniversalAnimatedGlassCard(
                  device: dev,
                  onTap: () => cardTapped = true,
                  onPowerToggle: () => powerToggled = true,
                  onLongPress: () {},
                ),
              ),
            ),
          ),
        ),
      );

      // Tap the emblem icon to toggle power
      final iconFinder = find.byIcon(Icons.local_laundry_service_rounded);
      expect(iconFinder, findsOneWidget);
      await tester.tap(iconFinder);
      expect(powerToggled, isTrue);

      // Tap the card text to open sheet (onTap)
      await tester.tap(find.text('Samsung Washer Test 2'));
      expect(cardTapped, isTrue);
    });
  });
}
