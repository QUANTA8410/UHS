import 'package:flutter_test/flutter_test.dart';
import 'package:unified_home/models/ota_update_model.dart';
import 'package:unified_home/services/ota/app_ota_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
}
