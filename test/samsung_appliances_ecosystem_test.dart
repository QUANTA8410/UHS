import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_home/models/house_3d_twin_model.dart';
import 'package:unified_home/providers/real_home_provider.dart';
import 'package:unified_home/services/real_iot_controller.dart';
import 'package:unified_home/ui/widgets/map3d/isometric_house_3d_widget.dart';
import 'package:unified_home/ui/widgets/sheets/samsung_future_devices_sheet.dart';
import 'package:unified_home/ui/widgets/sheets/samsung_washer_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RealHomeProvider provider;
  late RealSmartDevice samsungWasher;
  late RealSmartDevice samsungAc;
  late RealSmartDevice samsungFridge;
  late RealSmartDevice samsungTv;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    provider = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);

    samsungWasher = RealSmartDevice(
      id: 'samsung_washer_test',
      name: 'Samsung Ecobubble™ AI DD Washer',
      room: 'Laundry',
      category: 'washer',
      protocol: ConnectionProtocol.smartThingsCloud,
      credentials: {'vendor': 'samsung', 'cloudDeviceId': 'samsung-washer-live-1'},
      isOn: true,
      primaryValue: 1200,
      liveAttributes: {
        'cycle': 'AI Wash',
        'stage': 'rinse',
        'remainingMinutes': 24,
        'waterTemperature': 40,
        'waterTemp': '40°C',
        'spinSpeed': '1200 RPM',
        'rinseCount': 3,
        'ecoBubble': true,
        'superSpeed': true,
        'aiWash': true,
        'addWashDoorLocked': true,
        'detergentPercent': 72,
        'softenerPercent': 85,
        'drumCleanCount': 28,
        'autoCycleLink': true,
      },
    );

    samsungAc = RealSmartDevice(
      id: 'samsung_windfree_ac',
      name: 'Samsung WindFree™ Premium AC',
      room: 'Master Bedroom',
      category: 'ac',
      protocol: ConnectionProtocol.smartThingsCloud,
      credentials: {'vendor': 'samsung'},
      isOn: true,
      primaryValue: 23.0,
      liveAttributes: {
        'windFree': true,
        'goodSleep': true,
        'pm1AirQuality': 12,
        'aiEnergyMode': true,
      },
    );

    samsungFridge = RealSmartDevice(
      id: 'samsung_family_hub_fridge',
      name: 'Samsung Family Hub™ Refrigerator',
      room: 'Kitchen',
      category: 'fridge',
      protocol: ConnectionProtocol.smartThingsCloud,
      credentials: {'vendor': 'samsung'},
      isOn: true,
      primaryValue: 3.0,
      liveAttributes: {
        'fridgeTemp': 3.0,
        'freezerTemp': -19.0,
        'flexZoneMode': 'Beverage',
        'powerCool': true,
        'powerFreeze': false,
        'iceBites': true,
      },
    );

    samsungTv = RealSmartDevice(
      id: 'samsung_the_frame_tv',
      name: 'Samsung The Frame 65" 4K',
      room: 'Living Room',
      category: 'tv',
      protocol: ConnectionProtocol.smartThingsCloud,
      credentials: {'vendor': 'samsung'},
      isOn: true,
      primaryValue: 50.0,
      liveAttributes: {
        'artMode': true,
        'lightSync': true,
        'selectedArtwork': 'Starry Night',
      },
    );

    provider.addDeviceDirect(samsungWasher);
    provider.addDeviceDirect(samsungAc);
    provider.addDeviceDirect(samsungFridge);
    provider.addDeviceDirect(samsungTv);
  });

  tearDown(() {
    provider.dispose();
  });

  group('Samsung Washing Machine UI & Feature Tests', () {
    testWidgets('SamsungWasherSheet renders Real-Time Cycle Dial, Ecobubble Foam, and Auto Dispenser', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<RealHomeProvider>.value(
          value: provider,
          child: MaterialApp(
            home: Scaffold(
              body: SamsungWasherSheet(device: samsungWasher),
            ),
          ),
        ),
      );

      // Header verification
      expect(find.text('Samsung Ecobubble™ AI DD Washer'), findsOneWidget);
      expect(find.text('SmartThings'), findsOneWidget);

      // Real-Time Cycle Dial verification
      expect(find.text('24 min'), findsOneWidget);
      expect(find.text('RINSE'), findsOneWidget);
      expect(find.text('AI Wash'), findsOneWidget);
      expect(find.text('Pause Cycle'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // AI Ecobubble Foam simulation & energy savings
      expect(find.text('AI Ecobubble™ Active Foam'), findsOneWidget);
      expect(find.text('~70% Energy Saved'), findsOneWidget);
      expect(find.text('Bubble Soak: Active'), findsOneWidget);

      // HomeCare Auto Dispenser system
      expect(find.text('Auto Dispenser System (HomeCare Wizard)'), findsOneWidget);
      expect(find.text('Liquid Detergent'), findsOneWidget);
      expect(find.text('72%'), findsOneWidget);
      expect(find.text('Fabric Softener'), findsOneWidget);
      expect(find.text('85%'), findsOneWidget);

      // SmartThings Laundry Recipe
      expect(find.text('SmartThings Laundry Recipe'), findsOneWidget);
      expect(find.text('Shirts & Daily'), findsOneWidget);
      expect(find.text('Apply Smart Recipe'), findsOneWidget);

      // Auto Cycle Link (Smart Forwarding to Dryer)
      expect(find.text('Auto Cycle Link (Smart Forwarding)'), findsOneWidget);

      // Drum Clean Tracker
      expect(find.text('Self Clean+ / Drum Clean Tracker'), findsOneWidget);
      expect(find.text('Clean Now'), findsOneWidget);
    });

    testWidgets('Tapping cycle stage chip transitions washer stage', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<RealHomeProvider>.value(
          value: provider,
          child: MaterialApp(
            home: Scaffold(
              body: SamsungWasherSheet(device: samsungWasher),
            ),
          ),
        ),
      );

      // Tap 'Spin' stage chip
      await tester.tap(find.text('Spin'));
      await tester.pump();

      expect(samsungWasher.washerStage, 'spin');
    });
  });

  group('Future Samsung Devices Studio Sheet Tests', () {
    testWidgets('SamsungFutureDevicesSheet renders WindFree AC, Family Hub Refrigerator, and The Frame TV', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<RealHomeProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: Scaffold(
              body: SamsungFutureDevicesSheet(initialTabIndex: 0),
            ),
          ),
        ),
      );

      // Tab bar verification
      expect(find.text('WindFree™ AC'), findsOneWidget);
      expect(find.text('Family Hub Fridge'), findsOneWidget);
      expect(find.text('The Frame TV'), findsOneWidget);

      // WindFree AC contents
      expect(find.text('WindFree™ Still Air Cooling'), findsOneWidget);
      expect(find.text('Dispersing through 23,000 micro-holes (<0.15 m/s)'), findsOneWidget);
      expect(find.text('GoodSleep™ AI Nocturnal Curve'), findsOneWidget);
      expect(find.text('PM1.0 Laser Halo'), findsOneWidget);
      expect(find.text('AI Energy Mode'), findsOneWidget);

      // Switch to Family Hub Fridge Tab
      await tester.tap(find.text('Family Hub Fridge'));
      await tester.pumpAndSettle();

      expect(find.text('Family Hub View Inside™ Camera'), findsOneWidget);
      expect(find.text('Triple Cooling Independent Zones'), findsOneWidget);
      expect(find.text('Fridge'), findsOneWidget);
      expect(find.text('Freezer'), findsOneWidget);
      expect(find.text('Power Cool'), findsOneWidget);
      expect(find.text('Ice Bites™'), findsOneWidget);

      // Switch to The Frame TV Tab
      await tester.tap(find.text('The Frame TV'));
      await tester.pumpAndSettle();

      expect(find.text('The Frame Art Mode'), findsOneWidget);
      expect(find.text('Starry Night'), findsWidgets);
      expect(find.text('Ambient Light Sync (lightsync)'), findsOneWidget);
      expect(find.text('Built-in SmartThings & Matter Hub'), findsOneWidget);
    });
  });

  group('Spatial 3D MapView Bubbles & Now Bar System Telemetry Tests', () {
    testWidgets('IsometricHouse3DWidget renders MapViewBubble over washer fixture with stage & time telemetry', (tester) async {
      final layout = House3DTwinLayout.defaultApartment();
      layout.fixtures.add(
        Fixture3DNode(
          id: 'fix_washer',
          label: 'Washer',
          roomId: 'bath',
          fixtureType: 'washer',
          x: 0.8,
          y: 0.25,
          zHeight: 0.3,
          linkedRealDeviceId: 'samsung_washer_test',
        ),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<RealHomeProvider>.value(
          value: provider,
          child: MaterialApp(
            home: Scaffold(
              body: IsometricHouse3DWidget(
                layout: layout,
                selectedRoomId: 'all',
                height: 400,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify MapViewBubble telemetry rendering (e.g. RINSE · 24m)
      expect(find.text('RINSE · 24m'), findsOneWidget);
    });
  });
}
