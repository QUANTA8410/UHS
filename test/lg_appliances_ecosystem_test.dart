import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_home/models/house_3d_twin_model.dart';
import 'package:unified_home/providers/real_home_provider.dart';
import 'package:unified_home/services/real_iot_controller.dart';
import 'package:unified_home/ui/widgets/map3d/isometric_house_3d_widget.dart';
import 'package:unified_home/ui/widgets/sheets/lg_future_appliances_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RealHomeProvider provider;
  late RealSmartDevice lgWashTower;
  late RealSmartDevice lgInstaViewFridge;
  late RealSmartDevice lgAeroTower;
  late RealSmartDevice lgStyler;
  late RealSmartDevice lgDishwasher;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    provider = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);

    lgWashTower = RealSmartDevice(
      id: 'lg_washtower_1',
      name: 'LG WashTower™ AI DD Stack',
      room: 'Laundry',
      category: 'washer',
      protocol: ConnectionProtocol.smartThingsCloud,
      credentials: {'vendor': 'lg', 'cloudDeviceId': 'lg-washtower-device-1'},
      isOn: true,
      primaryValue: 1400,
      liveAttributes: {
        'stage': 'rinse',
        'remainingMinutes': 24,
        'turboWash360': true,
        'ezDispenseDetergent': 82,
        'ezDispenseSoftener': 68,
        'steamPlus': true,
        'smartPairing': true,
        'dryLevel': 'Normal',
        'dryerRemainingMinutes': 34,
        'dryerStage': 'drying',
      },
    );

    lgInstaViewFridge = RealSmartDevice(
      id: 'lg_instaview_fridge_1',
      name: 'LG InstaView™ Door-in-Door Fridge',
      room: 'Kitchen',
      category: 'fridge',
      protocol: ConnectionProtocol.smartThingsCloud,
      credentials: {'vendor': 'lg'},
      isOn: true,
      primaryValue: 3.0,
      liveAttributes: {
        'instaViewTransparent': false,
        'craftIce': true,
        'doorCooling': true,
        'hygieneFresh': 'Auto',
        'expressFreeze': false,
        'expressCool': false,
        'fridgeTemp': 3.0,
        'freezerTemp': -19.0,
      },
    );

    lgAeroTower = RealSmartDevice(
      id: 'lg_puricare_aerotower_1',
      name: 'LG PuriCare™ AeroTower',
      room: 'Living Room',
      category: 'air_purifier',
      protocol: ConnectionProtocol.smartThingsCloud,
      credentials: {'vendor': 'lg'},
      isOn: true,
      primaryValue: 9.0,
      liveAttributes: {
        'cleanBoosterTilt': 55,
        'airflowMode': 'Wide',
        'uvNano': true,
        'pm1Laser': 9,
        'petCare': false,
      },
    );

    lgStyler = RealSmartDevice(
      id: 'lg_styler_steam_closet_1',
      name: 'LG Styler® Steam Closet',
      room: 'Master Bedroom',
      category: 'styler',
      protocol: ConnectionProtocol.smartThingsCloud,
      credentials: {'vendor': 'lg'},
      isOn: true,
      primaryValue: 180.0,
      liveAttributes: {
        'movingHangerSpeed': 'Normal',
        'movingHangerRpm': 180,
        'trueSteam': true,
        'pantsCrease': true,
        'gentleDry': true,
        'stylerCourse': 'Refresh',
        'thinqUpUpdate': true,
        'thinqUpFeature': 'Pet Care Cycle & Gentle Dry Wave',
      },
    );

    lgDishwasher = RealSmartDevice(
      id: 'lg_quadwash_dishwasher_1',
      name: 'LG QuadWash™ Steam Dishwasher',
      room: 'Kitchen',
      category: 'dishwasher',
      protocol: ConnectionProtocol.smartThingsCloud,
      credentials: {'vendor': 'lg'},
      isOn: false,
      primaryValue: 0.0,
      liveAttributes: {
        'quadWashArmPressure': 'Dual Zone',
        'trueSteamDishwash': true,
        'autoDoorOpen': true,
        'dishwasherCourse': 'Auto',
      },
    );

    provider.addDeviceDirect(lgWashTower);
    provider.addDeviceDirect(lgInstaViewFridge);
    provider.addDeviceDirect(lgAeroTower);
    provider.addDeviceDirect(lgStyler);
    provider.addDeviceDirect(lgDishwasher);
  });

  tearDown(() {
    provider.dispose();
  });

  group('LG Smart Appliances - Telemetry Getters & Model Tests', () {
    test('LG WashTower exposes correct attributes and smart pairing specs', () {
      expect(lgWashTower.turboWash360Enabled, isTrue);
      expect(lgWashTower.ezDispenseDetergentPercent, equals(82));
      expect(lgWashTower.ezDispenseSoftenerPercent, equals(68));
      expect(lgWashTower.steamPlusEnabled, isTrue);
      expect(lgWashTower.smartPairingActive, isTrue);
      expect(lgWashTower.dryerRemainingMinutes, equals(34));
      expect(lgWashTower.dryerStage, equals('drying'));
      expect(lgWashTower.dryerDryLevel, equals('Normal'));
    });

    test('LG InstaView Refrigerator exposes Craft Ice and temperature zones', () {
      expect(lgInstaViewFridge.instaViewGlassTransparent, isFalse);
      expect(lgInstaViewFridge.craftIceEnabled, isTrue);
      expect(lgInstaViewFridge.doorCoolingActive, isTrue);
      expect(lgInstaViewFridge.fridgeTemp, equals(3.0));
      expect(lgInstaViewFridge.freezerTemp, equals(-19.0));
      expect(lgInstaViewFridge.expressFreezeActive, isFalse);
      expect(lgInstaViewFridge.expressCoolActive, isFalse);
    });

    test('LG PuriCare AeroTower exposes Clean Booster and PM1.0 laser indices', () {
      expect(lgAeroTower.cleanBoosterTiltAngle, equals(55));
      expect(lgAeroTower.aeroTowerAirflowMode, equals('Wide'));
      expect(lgAeroTower.uvNanoEnabled, isTrue);
      expect(lgAeroTower.pm1LaserIndex, equals(9));
      expect(lgAeroTower.petCareModeActive, isFalse);
    });

    test('LG Styler Steam Closet exposes Moving Hanger RPM and TrueSteam', () {
      expect(lgStyler.movingHangerRpm, equals(180));
      expect(lgStyler.trueSteamActive, isTrue);
      expect(lgStyler.pantsCreaseCare, isTrue);
      expect(lgStyler.gentleDryActive, isTrue);
      expect(lgStyler.stylerCourse, equals('Refresh'));
      expect(lgStyler.thinqUpUpdateAvailable, isTrue);
    });

    test('LG QuadWash Dishwasher exposes Multi-Motion arm pressure and steam', () {
      expect(lgDishwasher.quadWashArmPressure, equals('Dual Zone'));
      expect(lgDishwasher.trueSteamDishwash, isTrue);
      expect(lgDishwasher.autoDoorOpenDry, isTrue);
      expect(lgDishwasher.dishwasherCourse, equals('Auto'));
    });
  });

  group('RealHomeProvider - LG Mutation & State Update Tests', () {
    test('updateLgWashTower modifies TurboWash 360 and ezDispense levels', () {
      provider.updateLgWashTower(
        lgWashTower.id,
        turboWash360: false,
        ezDispenseDetergent: 95,
        ezDispenseSoftener: 50,
        smartPairing: false,
      );

      expect(lgWashTower.turboWash360Enabled, isFalse);
      expect(lgWashTower.ezDispenseDetergentPercent, equals(95));
      expect(lgWashTower.ezDispenseSoftenerPercent, equals(50));
      expect(lgWashTower.smartPairingActive, isFalse);
    });

    test('updateLgFridge modifies Craft Ice and compartment temperatures', () {
      provider.updateLgFridge(
        lgInstaViewFridge.id,
        instaViewTransparent: true,
        craftIce: false,
        expressFreeze: true,
        fridgeTemp: 2.0,
      );

      expect(lgInstaViewFridge.instaViewGlassTransparent, isTrue);
      expect(lgInstaViewFridge.craftIceEnabled, isFalse);
      expect(lgInstaViewFridge.expressFreezeActive, isTrue);
      expect(lgInstaViewFridge.fridgeTemp, equals(2.0));
    });

    test('updateLgAeroTower modifies Clean Booster tilt angle and airflow mode', () {
      provider.updateLgAeroTower(
        lgAeroTower.id,
        cleanBoosterTilt: 30,
        airflowMode: 'Diffusion',
        uvNano: false,
      );

      expect(lgAeroTower.cleanBoosterTiltAngle, equals(30));
      expect(lgAeroTower.aeroTowerAirflowMode, equals('Diffusion'));
      expect(lgAeroTower.uvNanoEnabled, isFalse);
    });

    test('updateLgStyler modifies Moving Hanger RPM and pants crease press', () {
      provider.updateLgStyler(
        lgStyler.id,
        movingHangerRpm: 200,
        pantsCrease: false,
        stylerCourse: 'Sanitize',
      );

      expect(lgStyler.movingHangerRpm, equals(200));
      expect(lgStyler.pantsCreaseCare, isFalse);
      expect(lgStyler.stylerCourse, equals('Sanitize'));
    });

    test('triggerLgThinqUp installs downloadable firmware upgrade', () {
      expect(lgStyler.thinqUpUpdateAvailable, isTrue);
      provider.triggerLgThinqUp(
        lgStyler.id,
        installedFeature: 'Pet Care Cycle & Gentle Dry Wave',
      );
      expect(lgStyler.thinqUpUpdateAvailable, isFalse);
      expect(lgStyler.liveAttributes['thinqUpInstalledFeature'],
          equals('Pet Care Cycle & Gentle Dry Wave'));
    });
  });

  group('LgFutureAppliancesSheet UI Widget Tests', () {
    testWidgets('Renders LG ThinQ Appliance Studio and WashTower tab', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<RealHomeProvider>.value(
            value: provider,
            child: Scaffold(
              body: LgFutureAppliancesSheet(
                initialDevice: lgWashTower,
                initialTabIndex: 0,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('LG ThinQ™ Appliance Studio'), findsOneWidget);
      expect(find.text('LG WashTower™ Center Control'), findsOneWidget);
      expect(find.text('TurboWash™ 360 Jets'), findsOneWidget);
      expect(find.text('ezDispense™ Auto Dosing Tanks'), findsOneWidget);
      expect(find.text('Smart Pairing™ Auto Cycle Transfer'), findsOneWidget);
      expect(find.text('82%'), findsOneWidget); // Detergent
      expect(find.text('68%'), findsOneWidget); // Softener
    });

    testWidgets('InstaView Tab: Double knock illuminates tinted glass panel', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<RealHomeProvider>.value(
            value: provider,
            child: Scaffold(
              body: LgFutureAppliancesSheet(
                initialDevice: lgInstaViewFridge,
                initialTabIndex: 1,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('InstaView™ Tinted Glass (Knock Twice)'), findsOneWidget);
      expect(find.text('TINTED'), findsOneWidget);

      // Tap on the glass panel to simulate double-knock
      await tester.tap(find.text('InstaView™ Tinted Glass (Knock Twice)'));
      await tester.pumpAndSettle();

      // Now glass is transparent and reveals interior shelves
      expect(find.text('InstaView™ Illuminated (Glass Transparent)'), findsOneWidget);
      expect(find.text('TRANSPARENT'), findsOneWidget);
      expect(find.text('Beverages'), findsOneWidget);
      expect(find.text('Fresh Milk'), findsOneWidget);
      expect(find.text('Craft Ice™ Dual Maker'), findsOneWidget);
    });

    testWidgets('AeroTower Tab: Renders Clean Booster tilt and Airflow chips', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<RealHomeProvider>.value(
            value: provider,
            child: Scaffold(
              body: LgFutureAppliancesSheet(
                initialDevice: lgAeroTower,
                initialTabIndex: 2,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('PM1.0 Laser Sensor: Good (Blue)'), findsOneWidget);
      expect(find.text('Clean Booster™ Pop-up Fan'), findsOneWidget);
      expect(find.text('Tilt: 55°'), findsOneWidget);
      expect(find.text('Direct'), findsOneWidget);
      expect(find.text('Wide'), findsOneWidget);
      expect(find.text('Diffusion'), findsOneWidget);
      expect(find.text('UVnano™ Fan Blade Sterilization'), findsOneWidget);
    });

    testWidgets('Styler Tab: Renders Moving Hanger, ThinQ UP & Smart Diagnosis', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<RealHomeProvider>.value(
            value: provider,
            child: Scaffold(
              body: LgFutureAppliancesSheet(
                initialDevice: lgStyler,
                initialTabIndex: 3,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('LG Styler® Moving Hanger™'), findsOneWidget);
      expect(find.text('180 RPM'), findsOneWidget);
      expect(find.text('LG QuadWash™ Steam Dishwasher'), findsOneWidget);
      expect(find.text('LG ThinQ UP™ Upgrade Center'), findsOneWidget);
      expect(find.text('Install ThinQ UP Feature'), findsOneWidget);
      expect(find.text('Run LG Smart Diagnosis™ 3.0'), findsOneWidget);

      // Tap install ThinQ UP
      await tester.tap(find.text('Install ThinQ UP Feature'));
      await tester.pumpAndSettle();

      expect(find.text('UPDATED'), findsOneWidget);
    });
  });

  group('3D Map View & Dynamic Island Integration Tests for LG Devices', () {
    testWidgets('IsometricHouse3DWidget renders LG WashTower and AeroTower bubbles', (tester) async {
      final layout = House3DTwinLayout.defaultApartment();
      layout.fixtures.add(
        Fixture3DNode(
          id: 'fix_lg_washtower',
          roomId: 'utility',
          fixtureType: 'washer',
          x: 0.8,
          y: 0.8,
          zHeight: 0.0,
          label: 'LG WashTower',
          linkedRealDeviceId: 'lg_washtower_1',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<RealHomeProvider>.value(
            value: provider,
            child: Scaffold(
              body: IsometricHouse3DWidget(
                layout: layout,
                isInteractive: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('WASHTOWER · 24m'), findsOneWidget);
    });
  });
}
