enum DiagnosticHealth { good, warning, fault }

class ComponentHealthCheck {
  final String componentName;
  final int healthScore; // 0 to 100
  final DiagnosticHealth status;
  final String metricDetail;

  const ComponentHealthCheck({
    required this.componentName,
    required this.healthScore,
    required this.status,
    required this.metricDetail,
  });
}

class DiagnosticReport {
  final String deviceId;
  final DateTime timestamp;
  final DiagnosticHealth overallHealth;
  final String? activeErrorCode;
  final String? errorSummary;
  final List<String> resolutionSteps;
  final List<ComponentHealthCheck> componentChecks;

  const DiagnosticReport({
    required this.deviceId,
    required this.timestamp,
    required this.overallHealth,
    this.activeErrorCode,
    this.errorSummary,
    this.resolutionSteps = const [],
    this.componentChecks = const [],
  });
}

class SmartDiagnosisService {
  /// Simulates LG Smart Diagnosis acoustic or Wi-Fi telemetry inspection
  Future<DiagnosticReport> runDiagnosis({
    required String deviceId,
    String? simulatedFaultCode,
  }) async {
    await Future.delayed(const Duration(milliseconds: 650));

    if (simulatedFaultCode == 'OE') {
      return DiagnosticReport(
        deviceId: deviceId,
        timestamp: DateTime.now(),
        overallHealth: DiagnosticHealth.fault,
        activeErrorCode: 'OE',
        errorSummary: 'Drain Pump Error: Water did not drain within expected window.',
        resolutionSteps: [
          'Unplug washer and locate lower-front drain filter cap.',
          'Place a towel down and unscrew the filter plug counterclockwise.',
          'Clean out any trapped coins, hairpins, or debris from the impeller.',
          'Reinsert filter tightly and run a quick rinse cycle.',
        ],
        componentChecks: const [
          ComponentHealthCheck(
            componentName: 'Inverter DirectDrive Motor',
            healthScore: 98,
            status: DiagnosticHealth.good,
            metricDetail: 'Vibration & magnetic flux nominal',
          ),
          ComponentHealthCheck(
            componentName: 'Drain Pump Assembly',
            healthScore: 32,
            status: DiagnosticHealth.fault,
            metricDetail: 'Flow resistance high (blocked impeller detected)',
          ),
          ComponentHealthCheck(
            componentName: 'Water Inlet Valves',
            healthScore: 95,
            status: DiagnosticHealth.good,
            metricDetail: 'Water pressure 4.2 bar nominal',
          ),
          ComponentHealthCheck(
            componentName: 'Door Lock Solenoid',
            healthScore: 100,
            status: DiagnosticHealth.good,
            metricDetail: 'Latch interlock secure',
          ),
        ],
      );
    }

    // Default healthy diagnostic report
    return DiagnosticReport(
      deviceId: deviceId,
      timestamp: DateTime.now(),
      overallHealth: DiagnosticHealth.good,
      activeErrorCode: null,
      errorSummary: 'All appliance subsystems operating within factory specifications.',
      resolutionSteps: [
        'Run monthly Tub Clean cycle with washer cleaner powder.',
        'Wipe door gasket with microfiber cloth to prevent mildew.',
      ],
      componentChecks: const [
        ComponentHealthCheck(
          componentName: 'Inverter DirectDrive Motor',
          healthScore: 99,
          status: DiagnosticHealth.good,
          metricDetail: '0 rpm drift, stator coils balanced',
        ),
        ComponentHealthCheck(
          componentName: 'Drain Pump Assembly',
          healthScore: 96,
          status: DiagnosticHealth.good,
          metricDetail: 'Drain flow rate 18.5 L/min',
        ),
        ComponentHealthCheck(
          componentName: 'Water Inlet Valves (Hot/Cold)',
          healthScore: 94,
          status: DiagnosticHealth.good,
          metricDetail: 'Solenoids responsive, zero leak rate',
        ),
        ComponentHealthCheck(
          componentName: 'Tub Cleanliness Index',
          healthScore: 78,
          status: DiagnosticHealth.warning,
          metricDetail: '18/30 cycles completed since last tub clean',
        ),
      ],
    );
  }
}
