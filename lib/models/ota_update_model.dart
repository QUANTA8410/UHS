/// High-level stage of an Over-The-Air (OTA) update lifecycle
enum OtaStage {
  idle,
  checking,
  downloading,
  verifying,
  flashing,
  rebooting,
  completed,
  failed,
}

/// Progress metrics streamed during an active OTA update
class OtaProgress {
  final double progress; // 0.0 to 1.0
  final int bytesTransferred;
  final int totalBytes;
  final double speedMBps;
  final OtaStage stage;
  final String statusMessage;
  final String? errorMessage;

  const OtaProgress({
    this.progress = 0.0,
    this.bytesTransferred = 0,
    this.totalBytes = 0,
    this.speedMBps = 0.0,
    this.stage = OtaStage.idle,
    this.statusMessage = 'Ready',
    this.errorMessage,
  });

  bool get isInProgress =>
      stage == OtaStage.downloading ||
      stage == OtaStage.verifying ||
      stage == OtaStage.flashing ||
      stage == OtaStage.rebooting;

  bool get isCompleted => stage == OtaStage.completed;
  bool get isFailed => stage == OtaStage.failed;

  String get progressPercentage => '${(progress * 100).toStringAsFixed(1)}%';

  String get formattedTransferred {
    if (totalBytes <= 0) return '0 MB';
    final mbTransferred = (bytesTransferred / (1024 * 1024)).toStringAsFixed(1);
    final mbTotal = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
    return '$mbTransferred / $mbTotal MB';
  }
}

/// Official manifest structure for In-App Application Software OTA updates
class AppOtaManifest {
  final String versionName;
  final int versionCode;
  final String downloadUrl;
  final int fileSizeBytes;
  final String sha256Checksum;
  final String releaseDate;
  final List<String> releaseNotes;
  final bool isMandatory;
  final String minSupportedVersion;

  const AppOtaManifest({
    required this.versionName,
    required this.versionCode,
    required this.downloadUrl,
    required this.fileSizeBytes,
    required this.sha256Checksum,
    required this.releaseDate,
    required this.releaseNotes,
    this.isMandatory = false,
    this.minSupportedVersion = '1.0.0',
  });

  String get formattedSize {
    final mb = (fileSizeBytes / (1024 * 1024)).toStringAsFixed(1);
    return '$mb MB';
  }

  factory AppOtaManifest.fromJson(Map<String, dynamic> json) {
    return AppOtaManifest(
      versionName: json['versionName'] as String? ?? '1.1.0',
      versionCode: json['versionCode'] as int? ?? 2,
      downloadUrl: json['downloadUrl'] as String? ?? '',
      fileSizeBytes: json['fileSizeBytes'] as int? ?? (51 * 1024 * 1024),
      sha256Checksum: json['sha256Checksum'] as String? ?? '',
      releaseDate: json['releaseDate'] as String? ?? '2026-10-14',
      releaseNotes: (json['releaseNotes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      isMandatory: json['isMandatory'] as bool? ?? false,
      minSupportedVersion: json['minSupportedVersion'] as String? ?? '1.0.0',
    );
  }

  Map<String, dynamic> toJson() => {
        'versionName': versionName,
        'versionCode': versionCode,
        'downloadUrl': downloadUrl,
        'fileSizeBytes': fileSizeBytes,
        'sha256Checksum': sha256Checksum,
        'releaseDate': releaseDate,
        'releaseNotes': releaseNotes,
        'isMandatory': isMandatory,
        'minSupportedVersion': minSupportedVersion,
      };

  /// High-fidelity sample manifest for testing & simulation
  factory AppOtaManifest.sampleUpdate() {
    return const AppOtaManifest(
      versionName: '1.1.0',
      versionCode: 2,
      downloadUrl: 'https://github.com/unified-home/releases/download/v1.1.0/app-release.apk',
      fileSizeBytes: 54251546, // ~51.7 MB matching compiled release APK
      sha256Checksum: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      releaseDate: '2026-10-14',
      releaseNotes: [
        '✨ 3D Spatial Digital Twin with dynamic lighting & camera presets',
        '🌐 Works with Google Home catalog (32+ partner brand ecosystems)',
        '🚀 Native OTA updater with SHA-256 cryptographic verification',
        '⚡ Matter 1.3 FOTA Cluster and SmartThings Ecobubble™ optimization',
        '🛡️ Hardened Android FileProvider installer integration',
      ],
      isMandatory: false,
    );
  }
}

/// Firmware update specification for connected smart IoT appliances
class DeviceFirmwareUpdate {
  final String deviceId;
  final String deviceName;
  final String targetModel;
  final String currentVersion;
  final String availableVersion;
  final int binarySizeBytes;
  final String binarySha256;
  final String partitionName;
  final List<String> highlights;
  final bool isCritical;
  final Duration estimatedFlashDuration;

  const DeviceFirmwareUpdate({
    required this.deviceId,
    required this.deviceName,
    required this.targetModel,
    required this.currentVersion,
    required this.availableVersion,
    required this.binarySizeBytes,
    required this.binarySha256,
    this.partitionName = 'app_mcu_0',
    required this.highlights,
    this.isCritical = false,
    this.estimatedFlashDuration = const Duration(seconds: 12),
  });

  String get formattedSize {
    final kb = (binarySizeBytes / 1024).toStringAsFixed(1);
    if (binarySizeBytes >= 1024 * 1024) {
      final mb = (binarySizeBytes / (1024 * 1024)).toStringAsFixed(2);
      return '$mb MB';
    }
    return '$kb KB';
  }

  factory DeviceFirmwareUpdate.fromJson(Map<String, dynamic> json) {
    return DeviceFirmwareUpdate(
      deviceId: json['deviceId'] as String,
      deviceName: json['deviceName'] as String,
      targetModel: json['targetModel'] as String,
      currentVersion: json['currentVersion'] as String,
      availableVersion: json['availableVersion'] as String,
      binarySizeBytes: json['binarySizeBytes'] as int? ?? 524288,
      binarySha256: json['binarySha256'] as String? ?? '',
      partitionName: json['partitionName'] as String? ?? 'app_mcu_0',
      highlights: (json['highlights'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      isCritical: json['isCritical'] as bool? ?? false,
      estimatedFlashDuration: Duration(
        seconds: json['estimatedDurationSec'] as int? ?? 12,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'deviceName': deviceName,
        'targetModel': targetModel,
        'currentVersion': currentVersion,
        'availableVersion': availableVersion,
        'binarySizeBytes': binarySizeBytes,
        'binarySha256': binarySha256,
        'partitionName': partitionName,
        'highlights': highlights,
        'isCritical': isCritical,
        'estimatedDurationSec': estimatedFlashDuration.inSeconds,
      };
}
