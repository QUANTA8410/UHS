import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_home/providers/real_home_provider.dart';
import 'package:unified_home/services/diagnostics/smart_diagnosis_service.dart';
import 'package:unified_home/services/energy/energy_optimizer_service.dart';
import 'package:unified_home/services/real_iot_controller.dart';
import 'package:unified_home/ui/widgets/dialogs/smart_diagnosis_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SmartDiagnosisService Real Telemetry Tests', () {
    final service = SmartDiagnosisService();

    test('runDiagnosis returns nominal report for online normal device', () async {
      final washer = RealSmartDevice(
        id: 'washer_1',
        name: 'Samsung AI Ecobubble Washer',
        room: 'Laundry',
        category: 'washer',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {},
        isOnline: true,
        liveWatts: 150.0,
        ratedMaxWatts: 2000.0,
      );

      final report = await service.runDiagnosis(
        deviceId: washer.id,
        device: washer,
      );

      expect(report.deviceId, 'washer_1');
      expect(report.overallHealth, DiagnosticHealth.good);
      expect(report.activeErrorCode, isNull);
      expect(report.componentChecks, isNotEmpty);
      expect(
        report.componentChecks.any((c) => c.componentName.contains('Network') || c.componentName.contains('Power')),
        isTrue,
      );
    });

    test('runDiagnosis detects offline hardware error', () async {
      final offlineDev = RealSmartDevice(
        id: 'washer_offline',
        name: 'Samsung Washer',
        room: 'Laundry',
        category: 'washer',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {},
        isOnline: false,
      );

      final report = await service.runDiagnosis(
        deviceId: offlineDev.id,
        device: offlineDev,
      );

      expect(report.overallHealth, DiagnosticHealth.fault);
      expect(report.activeErrorCode, 'NET_OFFLINE');
      expect(report.resolutionSteps.isNotEmpty, isTrue);
    });
  });

  group('EnergyOptimizerService & Tariff Tests', () {
    const tariff = UtilityTariff(
      offPeakRatePerKWh: 0.14,
      peakRatePerKWh: 0.38,
      peakStartHour: 16,
      peakEndHour: 21,
    );
    const service = EnergyOptimizerService(tariff: tariff);

    test('tariff correctly determines peak vs off-peak hours', () {
      final offPeakMorning = DateTime(2026, 10, 13, 10, 0);
      final peakAfternoon = DateTime(2026, 10, 13, 18, 0);
      final offPeakNight = DateTime(2026, 10, 13, 22, 0);

      expect(tariff.isPeakHour(offPeakMorning), isFalse);
      expect(tariff.currentRate(offPeakMorning), 0.14);

      expect(tariff.isPeakHour(peakAfternoon), isTrue);
      expect(tariff.currentRate(peakAfternoon), 0.38);

      expect(tariff.isPeakHour(offPeakNight), isFalse);
      expect(tariff.currentRate(offPeakNight), 0.14);
    });

    test('calculateProjections returns accurate savings when AI mode is active', () {
      final normalProj = service.calculateProjections(
        currentPowerWatts: 1500.0,
        aiEnergyModeActive: false,
      );

      final aiProj = service.calculateProjections(
        currentPowerWatts: 1500.0,
        aiEnergyModeActive: true,
      );

      expect(normalProj.monthlyCostEstimate, greaterThan(aiProj.monthlyCostEstimate));
      expect(aiProj.monthlySavingsWithAiMode, greaterThan(0));
      expect(aiProj.carbonAvoidedKgPerMonth, greaterThan(0));
    });

    test('calculateFromRealHome integrates directly with RealHomeProvider wattage', () {
      final home = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);
      final dev = RealSmartDevice(
        id: 'ac_living',
        name: 'LG DualCool AC',
        room: 'Living Room',
        category: 'ac',
        protocol: ConnectionProtocol.customHttpWebhook,
        credentials: {},
        liveWatts: 1200.0,
      );
      home.addDeviceDirect(dev);

      final proj = service.calculateFromRealHome(home, aiEnergyModeActive: true);
      expect(proj.hourlyCostNow, greaterThan(0));
      expect(proj.monthlySavingsWithAiMode, greaterThan(0));
      home.dispose();
    });

    test('getPeakHourAdvice returns proper guidance for peak and off-peak', () {
      final peakTime = DateTime(2026, 10, 13, 17, 30);
      final offPeakTime = DateTime(2026, 10, 13, 11, 0);

      expect(service.getPeakHourAdvice(peakTime), contains('Peak Hours'));
      expect(service.getPeakHourAdvice(offPeakTime), contains('Off-Peak Tariff'));
    });
  });

  group('Phase 3 Widget Tests', () {
    testWidgets('SmartDiagnosisDialog runs diagnosis and renders health meters', (tester) async {
      final home = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);
      final washer = RealSmartDevice(
        id: 'washer_1',
        name: 'Samsung Ecobubble Washer',
        room: 'Laundry Room',
        category: 'washer',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {},
        isOnline: true,
        liveWatts: 180.0,
        ratedMaxWatts: 2000.0,
      );
      home.addDeviceDirect(washer);

      await tester.pumpWidget(
        ChangeNotifierProvider<RealHomeProvider>.value(
          value: home,
          child: MaterialApp(
            home: Scaffold(
              body: SmartDiagnosisDialog(device: washer),
            ),
          ),
        ),
      );

      expect(find.text('LG Smart Diagnosis™'), findsOneWidget);

      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('Appliance in Optimal Health'), findsOneWidget);
      expect(find.text('Subsystem Health Telemetry'), findsOneWidget);
      expect(find.text('Network Radio & TCP Socket'), findsOneWidget);

      home.dispose();
    });
  });
}
