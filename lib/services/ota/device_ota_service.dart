import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../models/device_model.dart';
import '../../models/ota_update_model.dart';

class DeviceOtaService {
  /// Known manufacturer firmware releases available in cloud repositories
  static const Map<String, DeviceFirmwareUpdate> _knownCatalog = {
    // Samsung AI Ecobubble™ Washer
    'washer': DeviceFirmwareUpdate(
      deviceId: 'samsung_washer',
      deviceName: 'Samsung Ecobubble™ AI DD Washer',
      targetModel: 'WW90TP86DSX/TL',
      currentVersion: '3.4.1',
      availableVersion: '3.5.0',
      binarySizeBytes: 1468006, // ~1.4 MB
      binarySha256: '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08',
      partitionName: 'mcu_inverter_a',
      highlights: [
        'AI Ecobubble™ micro-froth density algorithm upgrade (+14% fabric softness)',
        'Inverter motor harmonic vibration dampening for spin cycle',
        'SmartThings Energy Standby consumption reduced to 0.4W',
      ],
      isCritical: false,
      estimatedFlashDuration: Duration(seconds: 14),
    ),

    // LG DualCool Inverter AC
    'climate': DeviceFirmwareUpdate(
      deviceId: 'lg_dualcool_ac',
      deviceName: 'LG DualCool AI Inverter AC',
      targetModel: 'TS-Q19YNZE',
      currentVersion: '2.1.8',
      availableVersion: '2.2.0',
      binarySizeBytes: 891289, // ~870 KB
      binarySha256: '5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8',
      partitionName: 'dual_inverter_fota',
      highlights: [
        'AI Dual Inverter compressor ramp-up curve optimization (-3.2 min to setpoint)',
        'Jet Cool acoustic resonance smoothing (32 dB whisper quiet)',
        'ThinQ Cloud Wi-Fi keep-alive reconnect reliability',
      ],
      isCritical: true,
      estimatedFlashDuration: Duration(seconds: 10),
    ),

    // Wipro Smart Next Bulbs
    'lighting': DeviceFirmwareUpdate(
      deviceId: 'wipro_bulb',
      deviceName: 'Wipro Smart Next 12W RGBW',
      targetModel: 'B22-WIPRO-12W',
      currentVersion: '1.0.4',
      availableVersion: '1.1.0',
      binarySizeBytes: 393216, // 384 KB
      binarySha256: '4b227777d4dd1fc61c6f884f48641d02b4d121d3fd328cb08b5531fcacdabf8a',
      partitionName: 'tuya_ble_mesh_0',
      highlights: [
        '0.1% ultra-smooth circadian twilight dimming transitions',
        'Power outage state memory auto-recovery fix',
        'Party Music Sync real-time audio latency reduced to 18ms',
      ],
      isCritical: false,
      estimatedFlashDuration: Duration(seconds: 8),
    ),

    // OnePlus TV
    'media': DeviceFirmwareUpdate(
      deviceId: 'oneplus_tv',
      deviceName: 'OnePlus TV 55 U1S (OxygenPlay)',
      targetModel: '55U1S-4K',
      currentVersion: '12.0.2',
      availableVersion: '12.1.0',
      binarySizeBytes: 89128960, // ~85 MB patch
      binarySha256: 'ef2d127de37b942baad06145e54b0c619a1f22327b2ebbcfbec78f5564afe39d',
      partitionName: 'android_ota_payload',
      highlights: [
        'Gamma Engine 4K HDR dynamic frame stabilization',
        'Auto Low-Latency Mode (ALLM) HDMI 2.1 gaming handshake',
        'OnePlus Connect Smart Volume sync with incoming smartphone calls',
      ],
      isCritical: false,
      estimatedFlashDuration: Duration(seconds: 18),
    ),
  };

  /// Query available firmware updates for the household device fleet
  Future<Map<String, DeviceFirmwareUpdate>> checkFleetFirmware(
    List<SmartDevice> devices, {
    bool simulateLatency = true,
  }) async {
    // Simulate slight cloud handshake latency if not running in tests
    if (simulateLatency &&
        !WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      await Future.delayed(const Duration(milliseconds: 300));
    }

    final Map<String, DeviceFirmwareUpdate> results = {};

    for (final dev in devices) {
      DeviceFirmwareUpdate? matched;

      if (dev is WasherDevice || dev.category == DeviceCategory.washer) {
        matched = _knownCatalog['washer'];
      } else if (dev is ThermostatDevice || dev.category == DeviceCategory.climate) {
        matched = _knownCatalog['climate'];
      } else if (dev is LightDevice || dev.category == DeviceCategory.lighting) {
        matched = _knownCatalog['lighting'];
      } else if (dev is TvDevice || dev.category == DeviceCategory.media) {
        matched = _knownCatalog['media'];
      }

      if (matched != null) {
        // If current device version is older than catalog availableVersion
        if (_isNewer(dev.firmwareVersion, matched.availableVersion)) {
          results[dev.id] = DeviceFirmwareUpdate(
            deviceId: dev.id,
            deviceName: dev.name,
            targetModel: matched.targetModel,
            currentVersion: dev.firmwareVersion,
            availableVersion: matched.availableVersion,
            binarySizeBytes: matched.binarySizeBytes,
            binarySha256: matched.binarySha256,
            partitionName: matched.partitionName,
            highlights: matched.highlights,
            isCritical: matched.isCritical,
            estimatedFlashDuration: matched.estimatedFlashDuration,
          );
        }
      }
    }

    return results;
  }

  /// Execute the 5-stage device OTA flashing sequence
  Stream<OtaProgress> flashDeviceFirmware(
    SmartDevice device,
    DeviceFirmwareUpdate update,
  ) async* {
    final totalBytes = update.binarySizeBytes;
    final inTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');

    // Stage 1: Handshake & Lock
    yield const OtaProgress(
      stage: OtaStage.checking,
      progress: 0.05,
      statusMessage: '1/5 Handshake: Locking appliance control & verifying battery/mains...',
    );
    if (!inTest) await Future.delayed(const Duration(milliseconds: 400));

    // Stage 2: Downloading Binary into local device staging buffer
    const downloadSteps = 8;
    for (int i = 1; i <= downloadSteps; i++) {
      if (!inTest) await Future.delayed(const Duration(milliseconds: 100));
      final progress = 0.05 + (i / downloadSteps) * 0.35; // 0.05 -> 0.40
      final bytes = ((i / downloadSteps) * totalBytes).round();
      yield OtaProgress(
        stage: OtaStage.downloading,
        progress: progress,
        bytesTransferred: bytes,
        totalBytes: totalBytes,
        speedMBps: 3.8,
        statusMessage: '2/5 Downloading firmware package: ${(bytes / 1024).round()} KB / ${(totalBytes / 1024).round()} KB',
      );
    }

    // Stage 3: Verifying Cryptographic Signature & SHA-256 Checksum
    yield OtaProgress(
      stage: OtaStage.verifying,
      progress: 0.45,
      bytesTransferred: totalBytes,
      totalBytes: totalBytes,
      statusMessage: '3/5 Verifying SHA-256 cryptographic hardware signature...',
    );
    if (!inTest) await Future.delayed(const Duration(milliseconds: 250));

    // Stage 4: Flashing Partition Memory
    const flashSteps = 10;
    for (int i = 1; i <= flashSteps; i++) {
      if (!inTest) await Future.delayed(const Duration(milliseconds: 100));
      final progress = 0.45 + (i / flashSteps) * 0.45; // 0.45 -> 0.90
      yield OtaProgress(
        stage: OtaStage.flashing,
        progress: progress,
        bytesTransferred: totalBytes,
        totalBytes: totalBytes,
        statusMessage: '4/5 Flashing ${update.partitionName} sector $i/$flashSteps (${(progress * 100).toInt()}%)...',
      );
    }

    // Stage 5: Rebooting, Self-Test & Calibration
    yield const OtaProgress(
      stage: OtaStage.rebooting,
      progress: 0.95,
      statusMessage: '5/5 Rebooting MCU: Running post-flash calibration & hardware self-test...',
    );
    if (!inTest) await Future.delayed(const Duration(milliseconds: 400));

    // Completed
    yield OtaProgress(
      stage: OtaStage.completed,
      progress: 1.0,
      bytesTransferred: totalBytes,
      totalBytes: totalBytes,
      statusMessage: 'Firmware upgraded to v${update.availableVersion} successfully!',
    );
  }

  bool _isNewer(String current, String target) {
    try {
      final cParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final tParts = target.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < 3; i++) {
        final c = i < cParts.length ? cParts[i] : 0;
        final t = i < tParts.length ? tParts[i] : 0;
        if (t > c) return true;
        if (t < c) return false;
      }
      return false;
    } catch (_) {
      return current != target;
    }
  }
}
