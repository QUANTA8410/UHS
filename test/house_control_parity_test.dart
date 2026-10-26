import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:unified_home/models/house_3d_twin_model.dart';
import 'package:unified_home/providers/real_home_provider.dart';
import 'package:unified_home/services/wipro/wipro_tuya_service.dart';
import 'package:unified_home/ui/widgets/map3d/floor_plan_editor_sheet.dart';
import 'package:unified_home/ui/widgets/map3d/isometric_house_3d_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('House Control Parity: Data Models & Schema Tests', () {
    test('FloorMaterialType provides exact House Control floor colors and grout', () {
      expect(FloorMaterialType.oak.color, const Color(0xFFC7A47C));
      expect(FloorMaterialType.walnut.color, const Color(0xFF94705A));
      expect(FloorMaterialType.tile.color, const Color(0xFFD5DADE));
      expect(FloorMaterialType.stone.color, const Color(0xFFA2A7AE));

      expect(FloorMaterialType.fromString('oak'), FloorMaterialType.oak);
      expect(FloorMaterialType.fromString('walnut'), FloorMaterialType.walnut);
      expect(FloorMaterialType.fromString('tile'), FloorMaterialType.tile);
      expect(FloorMaterialType.fromString('stone'), FloorMaterialType.stone);
    });

    test('Opening3D serializes doors, windows, and open archways correctly', () {
      const door = Opening3D(
        type: 'door',
        from: Offset(3.1, 3.6),
        to: Offset(4.0, 3.6),
      );
      final json = door.toJson();
      expect(json['type'], 'door');
      expect(json['from'], [3.1, 3.6]);
      expect(json['to'], [4.0, 3.6]);

      final parsed = Opening3D.fromJson(json);
      expect(parsed.type, 'door');
      expect(parsed.from, const Offset(3.1, 3.6));
      expect(parsed.to, const Offset(4.0, 3.6));
    });

    test('House3DTwinLayout defaultApartment matches authentic House Control plan', () {
      final layout = House3DTwinLayout.defaultApartment();
      expect(layout.name, 'Home');
      expect(layout.wallHeight, 2.6);
      expect(layout.interiorWallHeight, 1.25);
      expect(layout.outdoorTemp, 29.0);
      expect(layout.rooms.length, 5);
      expect(layout.openings.length, greaterThanOrEqualTo(6));
      expect(layout.fixtures.length, greaterThanOrEqualTo(10));
      expect(layout.furniture.length, greaterThanOrEqualTo(12));

      // Verifies House Control furniture types are present
      final furnitureTypes = layout.furniture.map((p) => p.type).toSet();
      expect(furnitureTypes.contains('sofa'), isTrue);
      expect(furnitureTypes.contains('tv'), isTrue);
      expect(furnitureTypes.contains('diningSet'), isTrue);
      expect(furnitureTypes.contains('island'), isTrue);
      expect(furnitureTypes.contains('kitchen'), isTrue);
      expect(furnitureTypes.contains('fridge'), isTrue);
      expect(furnitureTypes.contains('bed'), isTrue);
      expect(furnitureTypes.contains('bathtub'), isTrue);
      expect(furnitureTypes.contains('plant'), isTrue);
    });

    test('House3DTwinLayout fromHouseControlJson parses native home.json accurately', () {
      final houseControlHomeJson = {
        'version': 1,
        'name': 'Home',
        'wallHeight': 2.6,
        'interiorWallHeight': 1.25,
        'camera': {'azimuth': 34, 'elevation': 47},
        'outdoorTemp': 29,
        'rooms': [
          {'id': 'living', 'name': 'Living', 'rect': [0, 3.6, 6.4, 4.6], 'floor': 'oak'},
          {'id': 'dining', 'name': 'Dining', 'rect': [6.4, 3.6, 4.0, 4.6], 'floor': 'oak'},
          {'id': 'kitchen', 'name': 'Kitchen', 'rect': [6.4, 0, 4.0, 3.6], 'floor': 'stone'},
          {'id': 'bedroom', 'name': 'Bedroom', 'rect': [0, 0, 4.2, 3.6], 'floor': 'walnut'},
          {'id': 'bath', 'name': 'Bathroom', 'rect': [4.2, 0, 2.2, 3.6], 'floor': 'tile'},
        ],
      };

      final layout = House3DTwinLayout.fromHouseControlJson(houseControlHomeJson);
      expect(layout.name, 'Home');
      expect(layout.rooms.length, 5);
      expect(layout.rooms.firstWhere((r) => r.id == 'living').floorType, FloorMaterialType.oak);
      expect(layout.rooms.firstWhere((r) => r.id == 'bedroom').floorType, FloorMaterialType.walnut);
      expect(layout.rooms.firstWhere((r) => r.id == 'kitchen').floorType, FloorMaterialType.stone);
      expect(layout.rooms.firstWhere((r) => r.id == 'bath').floorType, FloorMaterialType.tile);
    });

    test('House3DTwinLayout studioApartment loads authentic Studio floor plan and scenes', () {
      final studio = House3DTwinLayout.studioApartment();
      expect(studio.name, 'Studio');
      expect(studio.rooms.length, 3);
      expect(studio.rooms.map((r) => r.id), containsAll(['main', 'bath', 'hall']));
      expect(studio.furniture.length, greaterThanOrEqualTo(10));
      expect(studio.fixtures.length, greaterThanOrEqualTo(6));
      expect(studio.scenes.length, greaterThanOrEqualTo(4));

      final sceneIds = studio.scenes.map((s) => s.id).toList();
      expect(sceneIds, containsAll(['bright', 'work', 'chill', 'off']));
    });
  });

  group('House Control Parity: Lighting & Kelvin Shaders', () {
    test('tempToColor accurately maps Kelvin temperature to realistic physical colors', () {
      // 2200K -> Warm Amber (#FF9438)
      final c2200 = IsometricHouse3DWidget.tempToColor(2200);
      expect(c2200.r, greaterThan(0.9));
      expect(c2200.b, lessThan(0.3));

      // 4200K -> Neutral White (#FFE2C2)
      final c4200 = IsometricHouse3DWidget.tempToColor(4200);
      expect(c4200.r, greaterThan(0.9));
      expect(c4200.g, greaterThan(0.8));

      // 6500K -> Cool Daylight (#DFE9FF)
      final c6500 = IsometricHouse3DWidget.tempToColor(6500);
      expect(c6500.b, greaterThan(0.9));
    });
  });

  group('House Control Parity: TuyaService & TuyaMapper Swift Port', () {
    test('TuyaCredentials and regional host endpoints match House Control TuyaService.swift', () {
      expect(TuyaService.hosts['in'], 'openapi.tuyain.com');
      expect(TuyaService.hosts['eu'], 'openapi.tuyaeu.com');
      expect(TuyaService.hosts['us'], 'openapi.tuyaus.com');
      expect(TuyaService.hosts['cn'], 'openapi.tuyacn.com');
      expect(TuyaService.hosts['sg'], 'openapi-sg.iotbing.com');

      const creds = TuyaCredentials(
        accessId: 'test_client_id',
        accessSecret: 'test_secret_12345',
        region: 'in',
      );
      expect(creds.isConfigured, isTrue);

      final tuya = TuyaService(credentials: creds);
      expect(tuya.isConfigured, isTrue);
      expect(tuya.publicInfo['region'], 'in');
      expect(tuya.publicInfo['hasSecret'], isTrue);
    });

    test('TuyaMapper generates standard light commands with scale & kelvin mapping', () {
      final codes = {'switch_led', 'bright_value_v2', 'temp_value_v2', 'colour_data_v2', 'work_mode'};

      // 1. Power On
      final powerCmd = TuyaMapper.lightCommands(
        patch: {'on': true},
        codes: codes,
      );
      expect(powerCmd.any((c) => c['code'] == 'switch_led' && c['value'] == true), isTrue);

      // 2. Brightness 80% (mapped to 10..1000 scale)
      final brightCmd = TuyaMapper.lightCommands(
        patch: {'brightness': 0.8},
        codes: codes,
      );
      expect(brightCmd.first['code'], 'bright_value_v2');
      expect(brightCmd.first['value'], inInclusiveRange(780, 820));

      // 3. Color Temperature 3000K (mapped 2200K..6500K to 0..1000)
      final tempCmd = TuyaMapper.lightCommands(
        patch: {'temp': 3000.0},
        codes: codes,
      );
      expect(tempCmd.any((c) => c['code'] == 'temp_value_v2'), isTrue);
      expect(tempCmd.any((c) => c['code'] == 'work_mode' && c['value'] == 'white'), isTrue);

      // 4. Color RGB Hex
      final colorCmd = TuyaMapper.lightCommands(
        patch: {'color': '#FF0000'},
        codes: codes,
      );
      expect(colorCmd.any((c) => c['code'] == 'colour_data_v2'), isTrue);
      expect(colorCmd.any((c) => c['code'] == 'work_mode' && c['value'] == 'colour'), isTrue);
    });

    test('TuyaMapper generates standard AC unit commands matching ac.js & TuyaService.swift', () {
      final codes = {'switch', 'temp_set', 'mode', 'fan_speed_enum', 'sleep', 'eco'};

      final acCmd = TuyaMapper.acCommands(
        patch: {
          'on': true,
          'target': 23.0,
          'mode': 'cool',
          'fan': 'high',
          'sleep': true,
        },
        codes: codes,
      );

      expect(acCmd.any((c) => c['code'] == 'switch' && c['value'] == true), isTrue);
      expect(acCmd.any((c) => c['code'] == 'temp_set' && c['value'] == 23), isTrue);
      expect(acCmd.any((c) => c['code'] == 'mode' && c['value'] == 'cold'), isTrue);
      expect(acCmd.any((c) => c['code'] == 'fan_speed_enum' && c['value'] == 'high'), isTrue);
      expect(acCmd.any((c) => c['code'] == 'sleep' && c['value'] == true), isTrue);
    });

    test('TuyaMapper supports Infrared Remote AC keycodes (PowerOn/PowerOff/T/M/F)', () {
      final irCodes = {'PowerOn', 'PowerOff', 'T', 'M', 'F'};
      expect(TuyaMapper.isInfraredAC(irCodes), isTrue);

      final irCmd = TuyaMapper.acCommands(
        patch: {
          'on': true,
          'target': 24.0,
          'mode': 'cool',
          'fan': 'medium',
        },
        codes: irCodes,
      );

      expect(irCmd.any((c) => c['code'] == 'PowerOn'), isTrue);
      expect(irCmd.any((c) => c['code'] == 'T' && c['value'] == 24), isTrue);
      expect(irCmd.any((c) => c['code'] == 'M' && c['value'] == 0), isTrue); // 0 = cool
      expect(irCmd.any((c) => c['code'] == 'F' && c['value'] == 2), isTrue); // 2 = medium
    });
  });

  group('House Control Parity: FloorPlanEditorSheet 2D Blueprint & Inspector Tests', () {
    testWidgets('FloorPlanEditorSheet renders blueprint canvas with 5cm grid and templates', (tester) async {
      final home = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);
      final layout = House3DTwinLayout.defaultApartment();

      await tester.pumpWidget(
        ChangeNotifierProvider<RealHomeProvider>.value(
          value: home,
          child: MaterialApp(
            home: Scaffold(
              body: FloorPlanEditorSheet(initialLayout: layout),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('2D Blueprint Editor'), findsOneWidget);
      expect(find.text('Save & Apply'), findsOneWidget);
      expect(find.text('Templates'), findsOneWidget);
      expect(find.text('Add Fixture'), findsOneWidget);
      expect(find.text('Reset Default'), findsOneWidget);

      // Open Templates modal
      await tester.tap(find.text('Templates'));
      await tester.pumpAndSettle();

      expect(find.text('Select House Control Blueprint'), findsOneWidget);
      expect(find.text('Authentic 5-Room Home'), findsOneWidget);
      expect(find.text('Studio Apartment'), findsOneWidget);

      // Close templates modal
      await tester.tap(find.text('Authentic 5-Room Home'));
      await tester.pumpAndSettle();

      // Open Blueprint JSON Schema modal
      await tester.tap(find.byIcon(Icons.data_object_rounded));
      await tester.pumpAndSettle();

      expect(find.text('House Control Blueprint JSON'), findsOneWidget);
      expect(find.text('Import & Apply'), findsOneWidget);

      home.dispose();
    });

    test('WiproTuyaService discoverLocalTuyaDevices completes without throwing', () async {
      final service = WiproTuyaService();
      final devices = await service.discoverLocalTuyaDevices(timeout: const Duration(milliseconds: 50));
      expect(devices, isA<List<Map<String, dynamic>>>());
    });
  });

  group('House Control Parity: 3D Isometric Widget Canvas Tests', () {
    testWidgets('IsometricHouse3DWidget renders authentic House Control canvas', (tester) async {
      final home = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);
      final layout = House3DTwinLayout.defaultApartment();

      await tester.pumpWidget(
        ChangeNotifierProvider<RealHomeProvider>.value(
          value: home,
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: IsometricHouse3DWidget(
                  layout: layout,
                  selectedRoomId: 'all',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(IsometricHouse3DWidget), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      home.dispose();
    });
  });
}
