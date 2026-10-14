import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:unified_home/models/device_model.dart';
import 'package:unified_home/models/ota_update_model.dart';
import 'package:unified_home/providers/home_state.dart';
import 'package:unified_home/services/ota/app_ota_service.dart';
import 'package:unified_home/services/ota/device_ota_service.dart';
import 'package:unified_home/ui/views/ota_update_view.dart';

void main() {
  group('Phase 6: OTA Models & Data Structures Tests', () {
    test('AppOtaManifest serializes and deserializes correctly', () {
      final manifest = AppOtaManifest.sampleUpdate();
      expect(manifest.versionName, '1.1.0');
      expect(manifest.versionCode, 2);
      expect(manifest.fileSizeBytes, greaterThan(50 * 1024 * 1024));
      expect(manifest.formattedSize, contains('MB'));
      expect(manifest.releaseNotes.isNotEmpty, true);

      final json = manifest.toJson();
      final restored = AppOtaManifest.fromJson(json);
      expect(restored.versionName, '1.1.0');
      expect(restored.versionCode, 2);
      expect(restored.sha256Checksum, manifest.sha256Checksum);
    });

    test('DeviceFirmwareUpdate model preserves partition and cryptographic hash', () {
      const update = DeviceFirmwareUpdate(
        deviceId: 'washer_1',
        deviceName: 'Samsung Washer',
        targetModel: 'WW90T',
        currentVersion: '3.4.1',
        availableVersion: '3.5.0',
        binarySizeBytes: 1468006,
        binarySha256: '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08',
        partitionName: 'mcu_inverter_a',
        highlights: ['AI Ecobubble upgrade', 'Vibration dampening'],
        isCritical: true,
      );

      expect(update.formattedSize, contains('MB'));
      expect(update.partitionName, 'mcu_inverter_a');
      expect(update.isCritical, true);

      final json = update.toJson();
      final restored = DeviceFirmwareUpdate.fromJson(json);
      expect(restored.deviceId, 'washer_1');
      expect(restored.availableVersion, '3.5.0');
      expect(restored.binarySha256, update.binarySha256);
    });
  });

  group('Phase 6: App Software OTA Service Tests', () {
    late AppOtaService service;

    setUp(() {
      service = AppOtaService(currentVersionName: '1.0.0', currentVersionCode: 1);
    });

    test('checkForAppUpdate returns newer release manifest', () async {
      final update = await service.checkForAppUpdate(forceSimulate: true);
      expect(update, isNotNull);
      expect(update!.versionName, '1.1.0');
      expect(update.releaseNotes.length, greaterThanOrEqualTo(4));
    });

    test('downloadAndVerifyApk streams progress through downloading to completed', () async {
      final manifest = AppOtaManifest.sampleUpdate();
      final progressList = <OtaProgress>[];

      await for (final p in service.downloadAndVerifyApk(manifest)) {
        progressList.add(p);
      }

      expect(progressList.isNotEmpty, true);
      expect(progressList.any((p) => p.stage == OtaStage.downloading), true);
      expect(progressList.any((p) => p.stage == OtaStage.verifying), true);
      expect(progressList.last.stage, OtaStage.completed);
      expect(progressList.last.progress, 1.0);
    });

    test('triggerApkInstall completes gracefully', () async {
      final result = await service.triggerApkInstall('test_path.apk');
      expect(result, isTrue);
    });
  });

  group('Phase 6: Device Fleet Firmware OTA Service Tests', () {
    late DeviceOtaService service;

    setUp(() {
      service = DeviceOtaService();
    });

    test('checkFleetFirmware identifies pending updates across appliances', () async {
      final devices = <SmartDevice>[
        WasherDevice(
          id: 'washer_test',
          name: 'My Samsung Washer',
          room: 'Laundry Room',
          protocol: DeviceProtocol.smartThings,
          firmwareVersion: '3.4.1',
        ),
        ThermostatDevice(
          id: 'ac_test',
          name: 'My LG AC',
          room: 'Living Room',
          protocol: DeviceProtocol.lgThinQ,
          firmwareVersion: '2.1.8',
        ),
        LightDevice(
          id: 'bulb_test',
          name: 'My Wipro Bulb',
          room: 'Bedroom',
          protocol: DeviceProtocol.localLan,
          firmwareVersion: '1.0.4',
        ),
      ];

      final updates = await service.checkFleetFirmware(devices);
      expect(updates.containsKey('washer_test'), true);
      expect(updates['washer_test']!.availableVersion, '3.5.0');

      expect(updates.containsKey('ac_test'), true);
      expect(updates['ac_test']!.availableVersion, '2.2.0');

      expect(updates.containsKey('bulb_test'), true);
      expect(updates['bulb_test']!.availableVersion, '1.1.0');
    });

    test('flashDeviceFirmware executes 5-stage lifecycle to completion', () async {
      final washer = WasherDevice(
        id: 'washer_test',
        name: 'Samsung Washer',
        room: 'Laundry',
        protocol: DeviceProtocol.smartThings,
        firmwareVersion: '3.4.1',
      );

      const update = DeviceFirmwareUpdate(
        deviceId: 'washer_test',
        deviceName: 'Samsung Washer',
        targetModel: 'WW90T',
        currentVersion: '3.4.1',
        availableVersion: '3.5.0',
        binarySizeBytes: 1468006,
        binarySha256: '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08',
        partitionName: 'mcu_inverter_a',
        highlights: ['Ecobubble AI'],
      );

      final stages = <OtaStage>[];
      await for (final p in service.flashDeviceFirmware(washer, update)) {
        if (!stages.contains(p.stage)) {
          stages.add(p.stage);
        }
      }

      expect(stages.contains(OtaStage.checking), true);
      expect(stages.contains(OtaStage.downloading), true);
      expect(stages.contains(OtaStage.verifying), true);
      expect(stages.contains(OtaStage.flashing), true);
      expect(stages.contains(OtaStage.rebooting), true);
      expect(stages.contains(OtaStage.completed), true);
    });
  });

  group('Phase 6: HomeState OTA Integration Tests', () {
    late HomeState state;

    setUp(() {
      state = HomeState();
    });

    test('checkForAppUpdate populates availableAppUpdate and updates pending count', () async {
      expect(state.hasAppUpdate, false);
      await state.checkForAppUpdate(simulate: true);
      expect(state.hasAppUpdate, true);
      expect(state.availableAppUpdate!.versionName, '1.1.0');
      expect(state.totalUpdatesCount, greaterThanOrEqualTo(1));
    });

    test('checkFleetFirmwareUpdates and startDeviceFirmwareUpdate completes and upgrades version', () async {
      await state.checkFleetFirmwareUpdates();
      expect(state.hasDeviceUpdates, true);

      final deviceId = state.availableDeviceUpdates.keys.first;
      final targetVersion = state.availableDeviceUpdates[deviceId]!.availableVersion;

      await state.startDeviceFirmwareUpdate(deviceId);

      final dev = state.allDevices.firstWhere((d) => d.id == deviceId);
      expect(dev.firmwareVersion, targetVersion);
      expect(state.availableDeviceUpdates.containsKey(deviceId), false);
    });
  });

  group('Phase 6: OtaUpdateView Widget UI Tests', () {
    testWidgets('Renders App Software and Fleet Firmware tabs with update controls', (tester) async {
      final state = HomeState();
      await state.checkForAppUpdate(simulate: true);
      await state.checkFleetFirmwareUpdates();

      await tester.pumpWidget(
        ChangeNotifierProvider<HomeState>.value(
          value: state,
          child: const MaterialApp(
            home: OtaUpdateView(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('System & Device Updates'), findsOneWidget);
      expect(find.text('App Software'), findsOneWidget);
      expect(find.text('Fleet Firmware'), findsOneWidget);

      // App tab shows current and new version
      expect(find.text('Unified Smart Home'), findsOneWidget);
      expect(find.text('UPDATE AVAILABLE'), findsOneWidget);
      expect(find.text('Unified Smart Home v1.1.0'), findsOneWidget);

      // Switch to Fleet Firmware tab
      await tester.tap(find.text('Fleet Firmware'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Firmware Updates Available'), findsOneWidget);
      expect(find.text('Update All'), findsOneWidget);
    });
  });
}
