import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:unified_home/models/device_model.dart';
import 'package:unified_home/providers/home_state.dart';
import 'package:unified_home/services/smartthings/smartthings_laundry_service.dart';
import 'package:unified_home/ui/widgets/sheets/samsung_washer_sheet.dart';
import 'package:unified_home/ui/widgets/sheets/oneplus_tv_sheet.dart';
import 'package:unified_home/ui/widgets/sheets/light_sheet.dart';
import 'package:unified_home/ui/widgets/sheets/thermostat_sheet.dart';

void main() {
  group('User Specific Fleet - Service & State Tests', () {
    late HomeState state;

    setUp(() {
      state = HomeState();
    });

    test('Initializes with user exact hardware fleet', () {
      final devices = state.allDevices;
      expect(devices.any((d) => d is WasherDevice && d.name.contains('Samsung')), isTrue);
      expect(devices.any((d) => d is ThermostatDevice && d.name.contains('LG DualCool')), isTrue);
      expect(devices.any((d) => d is LightDevice && d.name.contains('Wipro')), isTrue);
      expect(devices.any((d) => d is TvDevice && d.name.contains('OnePlus')), isTrue);
    });

    test('SmartThings Laundry Service generates fabric-specific recipes', () {
      final service = SmartThingsLaundryService();

      // Test Denim Recipe
      final denimRecipe = service.recommendRecipe({GarmentType.jeansDenim});
      expect(denimRecipe.recommendedCycle, contains('Denim'));
      expect(denimRecipe.enableEcoBubble, isTrue);

      // Test Delicates Recipe
      final delicatesRecipe = service.recommendRecipe({GarmentType.delicates});
      expect(delicatesRecipe.recommendedCycle, contains('Delicates'));
      expect(delicatesRecipe.recommendedSpin, 'Low');

      // Test Home Care Status
      final homeCare = service.checkHomeCareStatus(
        drumCleanCount: 38,
        detergentPercent: 15,
        softenerPercent: 40,
      );
      expect(homeCare['detergentLow'], isTrue);
      expect(homeCare['softenerLow'], isFalse);
    });

    test('Samsung Washer updates EcoBubble, AI Wash, and Auto Dispenser levels', () {
      final washer = state.allDevices.firstWhere((d) => d is WasherDevice) as WasherDevice;

      state.updateSamsungWasher(
        washer.id,
        ecoBubble: true,
        aiWash: true,
        superSpeed: true,
        detergent: 80,
        softener: 50,
        addWashDoorLocked: false,
      );

      final updated = state.allDevices.firstWhere((d) => d.id == washer.id) as WasherDevice;
      expect(updated.ecoBubbleEnabled, isTrue);
      expect(updated.aiWashEnabled, isTrue);
      expect(updated.superSpeedEnabled, isTrue);
      expect(updated.detergentLevelPercent, 80);
      expect(updated.softenerLevelPercent, 50);
      expect(updated.addWashDoorLocked, isFalse);
    });

    test('OnePlus TV updates volume, input, apps, and OnePlus Connect Smart Volume', () async {
      final tv = state.allDevices.firstWhere((d) => d is TvDevice) as TvDevice;

      state.updateTv(
        tv.id,
        volume: 35,
        input: 'HDMI 1 (Gaming)',
        app: 'Netflix',
        smartVolume: true,
        pictureMode: 'Cinema',
      );

      final updated = state.allDevices.firstWhere((d) => d.id == tv.id) as TvDevice;
      expect(updated.volume, 35);
      expect(updated.currentInput, 'HDMI 1 (Gaming)');
      expect(updated.currentApp, 'Netflix');
      expect(updated.smartVolumeEnabled, isTrue);
      expect(updated.pictureMode, 'Cinema');

      await state.sendTvKey(tv.id, 'dpad_up');
    });

    test('Wipro Smart Bulb updates CCT Kelvin tunable white and 16M RGB colors', () {
      final bulb = state.allDevices.firstWhere((d) => d is LightDevice) as LightDevice;

      state.updateWiproBulb(
        bulb.id,
        brightness: 0.95,
        colorTempKelvin: 6500,
        color: const Color(0xFFE0F7FA),
        scene: 'Focus Work',
        musicSync: true,
      );

      final updated = state.allDevices.firstWhere((d) => d.id == bulb.id) as LightDevice;
      expect(updated.brightness, 0.95);
      expect(updated.colorTempKelvin, 6500);
      expect(updated.activeScene, 'Focus Work');
      expect(updated.musicSyncActive, isTrue);
    });

    test('LG DualCool AC updates fan speed, 4-way vane swing, and Plasmaster Ionizer', () {
      final ac = state.allDevices.firstWhere((d) => d is ThermostatDevice) as ThermostatDevice;

      state.updateLgAc(
        ac.id,
        targetTemp: 22.0,
        fanSpeed: 'High',
        vaneSwing: true,
        airClean: true,
        jetCool: true,
      );

      final updated = state.allDevices.firstWhere((d) => d.id == ac.id) as ThermostatDevice;
      expect(updated.targetTempC, 22.0);
      expect(updated.fanSpeed, 'High');
      expect(updated.vaneSwingActive, isTrue);
      expect(updated.airCleanActive, isTrue);
      expect(updated.jetCoolActive, isTrue);
    });
  });

  group('User Specific Fleet - Widget Sheets Tests', () {
    testWidgets('SamsungWasherSheet renders Auto Dispenser, EcoBubble, and Laundry Recipe', (tester) async {
      final state = HomeState();
      final washer = state.allDevices.firstWhere((d) => d is WasherDevice) as WasherDevice;

      await tester.pumpWidget(
        ChangeNotifierProvider<HomeState>.value(
          value: state,
          child: MaterialApp(
            home: Scaffold(
              body: SamsungWasherSheet(device: washer),
            ),
          ),
        ),
      );

      expect(find.text('Auto Dispense System (SmartThings)'), findsOneWidget);
      expect(find.text('Liquid Detergent'), findsOneWidget);
      expect(find.text('Fabric Softener'), findsOneWidget);
      expect(find.text('SmartThings Laundry Recipe'), findsOneWidget);
      expect(find.text('EcoBubble™'), findsOneWidget);
      expect(find.text('AI Wash (Sensors)'), findsOneWidget);
      expect(find.text('Apply Smart Recipe'), findsOneWidget);
    });

    testWidgets('OnePlusTvSheet renders D-Pad remote, OxygenPlay apps, and volume controls', (tester) async {
      final state = HomeState();
      final tv = state.allDevices.firstWhere((d) => d is TvDevice) as TvDevice;

      await tester.pumpWidget(
        ChangeNotifierProvider<HomeState>.value(
          value: state,
          child: MaterialApp(
            home: Scaffold(
              body: OnePlusTvSheet(device: tv),
            ),
          ),
        ),
      );

      expect(find.text('OnePlus Connect'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
      expect(find.text('Quick App Switcher'), findsOneWidget);
      expect(find.text('Smart Volume (OnePlus Connect)'), findsOneWidget);
      expect(find.text('OxygenPlay'), findsWidgets);
    });

    testWidgets('LightSheet renders Wipro CCT Kelvin slider and 16M color palette', (tester) async {
      final state = HomeState();
      final bulb = state.allDevices.firstWhere((d) => d is LightDevice) as LightDevice;

      await tester.pumpWidget(
        ChangeNotifierProvider<HomeState>.value(
          value: state,
          child: MaterialApp(
            home: Scaffold(
              body: LightSheet(device: bulb),
            ),
          ),
        ),
      );

      expect(find.text('Wipro Smart'), findsOneWidget);
      expect(find.text('Tunable White (CCT)'), findsOneWidget);
      expect(find.text('16M Colors (RGB Palette)'), findsOneWidget);
      expect(find.text('Smart Scenes'), findsOneWidget);
      expect(find.text('Music Rhythm Sync'), findsOneWidget);
    });

    testWidgets('ThermostatSheet renders LG DualCool Jet Cool, Ionizer, and Swing', (tester) async {
      final state = HomeState();
      final ac = state.allDevices.firstWhere((d) => d is ThermostatDevice) as ThermostatDevice;

      await tester.pumpWidget(
        ChangeNotifierProvider<HomeState>.value(
          value: state,
          child: MaterialApp(
            home: Scaffold(
              body: ThermostatSheet(device: ac),
            ),
          ),
        ),
      );

      expect(find.text('LG DualCool & Google Nest • Living Room'), findsOneWidget);
      expect(find.text('LG Jet Cool (Turbo)'), findsOneWidget);
      expect(find.text('Plasmaster™ Ionizer'), findsOneWidget);
      expect(find.text('Dual Vane 4-Way Swing'), findsOneWidget);
      expect(find.text('Fan Speed:'), findsOneWidget);
      expect(find.text('Cleanable Filter'), findsOneWidget);
    });
  });
}
