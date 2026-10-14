import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/real_home_provider.dart';
import '../../../services/diagnostics/smart_diagnosis_service.dart';
import '../../../services/real_iot_controller.dart';

class SmartDiagnosisDialog extends StatefulWidget {
  final RealSmartDevice device;

  const SmartDiagnosisDialog({super.key, required this.device});

  static Future<void> show(BuildContext context, RealSmartDevice device) {
    return showDialog(
      context: context,
      builder: (ctx) => SmartDiagnosisDialog(device: device),
    );
  }

  @override
  State<SmartDiagnosisDialog> createState() => _SmartDiagnosisDialogState();
}

class _SmartDiagnosisDialogState extends State<SmartDiagnosisDialog> {
  final SmartDiagnosisService _service = SmartDiagnosisService();
  DiagnosticReport? _report;
  bool _isLoading = true;
  String? _simulatedFault;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _executeDiagnosis());
  }

  Future<void> _executeDiagnosis({String? faultCode}) async {
    setState(() {
      _isLoading = true;
      _simulatedFault = faultCode;
    });

    List<RealSmartDevice> allDevices = const [];
    try {
      allDevices = context.read<RealHomeProvider>().devices;
    } catch (_) {}

    final report = await _service.runDiagnosis(
      deviceId: widget.device.id,
      device: widget.device,
      allDevices: allDevices,
      simulatedFaultCode: faultCode,
    );

    if (mounted) {
      setState(() {
        _report = report;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 650, maxWidth: 440),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.health_and_safety_rounded, color: Colors.blue, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'LG Smart Diagnosis™',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                      Text(
                        'Acoustic & Wi-Fi Diagnostic Telemetry',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_isLoading) ...[
              const SizedBox(height: 40),
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(strokeWidth: 3),
                    SizedBox(height: 18),
                    Text(
                      'Interrogating inverter motor & pump sensors...',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ] else if (_report != null) ...[
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Overall Status Banner
                      _buildOverallStatusBanner(_report!),
                      const SizedBox(height: 16),

                      // Fault Simulation Switcher
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Diagnostic Profile:',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<String?>(
                              segments: const [
                                ButtonSegment(value: null, label: Text('Normal Health')),
                                ButtonSegment(value: 'OE', label: Text('Simulate Error OE')),
                              ],
                              selected: {_simulatedFault},
                              onSelectionChanged: (set) {
                                _executeDiagnosis(faultCode: set.first);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Component Health Checks
                      const Text(
                        'Subsystem Health Telemetry',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      ..._report!.componentChecks.map((check) => _buildComponentCard(check)),

                      // Resolution Guide if Error
                      if (_report!.resolutionSteps.isNotEmpty && _report!.overallHealth != DiagnosticHealth.good) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.build_circle_outlined, color: Colors.red, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Resolution Guide for Code ${_report!.activeErrorCode}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 14),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ..._report!.resolutionSteps.asMap().entries.map((entry) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${entry.key + 1}. ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        Expanded(
                                          child: Text(entry.value, style: const TextStyle(fontSize: 12)),
                                        ),
                                      ],
                                    ),
                                  )),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close Diagnosis'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallStatusBanner(DiagnosticReport report) {
    final isGood = report.overallHealth == DiagnosticHealth.good;
    final color = isGood ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(isGood ? Icons.check_circle : Icons.warning_rounded, color: color, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isGood ? 'Appliance in Optimal Health' : 'Fault Detected: Error ${report.activeErrorCode}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  report.errorSummary ?? 'All sensors within normal limits.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComponentCard(ComponentHealthCheck check) {
    Color statusColor;
    switch (check.status) {
      case DiagnosticHealth.good:
        statusColor = Colors.green;
        break;
      case DiagnosticHealth.warning:
        statusColor = Colors.amber.shade700;
        break;
      case DiagnosticHealth.fault:
        statusColor = Colors.red;
        break;
    }

    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    check.componentName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${check.healthScore}%',
                  style: TextStyle(fontWeight: FontWeight.bold, color: statusColor, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: check.healthScore / 100.0,
              color: statusColor,
              backgroundColor: Colors.grey.shade300,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 6),
            Text(
              check.metricDetail,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
