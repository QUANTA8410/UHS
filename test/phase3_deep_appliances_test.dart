import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:unified_home/models/appliance_recipes.dart';
import 'package:unified_home/models/device_model.dart';
import 'package:unified_home/providers/home_state.dart';
import 'package:unified_home/services/diagnostics/smart_diagnosis_service.dart';
import 'package:unified_home/services/energy/energy_optimizer_service.dart';
import 'package:unified_home/ui/views/energy_view.dart';
import 'package:unified_home/ui/widgets/dialogs/smart_diagnosis_dialog.dart';
import 'package:unified_home/ui/widgets/sheets/appliance_cycle_store_sheet.dart';

void main() {
  group('SmartDiagnosisService Tests', () {
    final service = SmartDiagnosisService();

    test('runDiagnosis returns nominal report for normal conditions', () async {
      final report = await service.runDiagnosis(deviceId: 'washer_1');

      expect(report.deviceId, 'washer_1');
      expect(report.overallHealth, DiagnosticHealth.good);
      expect(report.activeErrorCode, isNull);
      expect(report.componentChecks, isNotEmpty);
      expect(
        report.componentChecks.any((c) => c.componentName.contains('DirectDrive')),
        isTrue,
      );
      expect(
        report.componentChecks.any((c) => c.componentName.contains('Drain Pump')),
        isTrue,
      );
      expect(report.resolutionSteps, isNotEmpty);
    });

    test('runDiagnosis handles simulated OE error with resolution checklist', () async {
      final report = await service.runDiagnosis(
        deviceId: 'washer_1',
        simulatedFaultCode: 'OE',
      );

      expect(report.deviceId, 'washer_1');
      expect(report.overallHealth, DiagnosticHealth.fault);
      expect(report.activeErrorCode, 'OE');
      expect(report.errorSummary, contains('Drain Pump Error'));
      expect(report.resolutionSteps.length, greaterThanOrEqualTo(3));
      expect(report.resolutionSteps.any((s) => s.contains('drain filter')), isTrue);

      final pumpCheck = report.componentChecks.firstWhere((c) => c.componentName.contains('Drain Pump'));
      expect(pumpCheck.status, DiagnosticHealth.fault);
      expect(pumpCheck.healthScore, lessThan(50));
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

    test('getPeakHourAdvice returns proper guidance for peak and off-peak', () {
      final peakTime = DateTime(2026, 10, 13, 17, 30);
      final offPeakTime = DateTime(2026, 10, 13, 11, 0);

      expect(service.getPeakHourAdvice(peakTime), contains('Peak Hours'));
      expect(service.getPeakHourAdvice(offPeakTime), contains('Off-Peak Tariff'));
    });
  });

  group('HomeState Phase 3 Integration Tests', () {
    late HomeState state;

    setUp(() {
      state = HomeState();
    });

    test('downloadCycle adds cycle to availableWashCycles and ignores duplicates', () {
      final initialCount = state.availableWashCycles.length;
      const newCycle = WashCycleRecipe(
        id: 'cycle_denim_pro',
        name: 'Denim Heavy',
        description: 'Deep soak and low mechanical stress for jeans',
        durationMinutes: 70,
        defaultTempC: 30,
        defaultSpinSpeed: 'Med',
      );

      state.downloadCycle(newCycle);
      expect(state.availableWashCycles.length, initialCount + 1);
      expect(state.availableWashCycles.any((c) => c.id == 'cycle_denim_pro'), isTrue);

      // Duplicate download attempt
      state.downloadCycle(newCycle);
      expect(state.availableWashCycles.length, initialCount + 1);
    });

    test('updateWasher updates parameters including ThinQ UP cycles', () {
      final washer = state.allDevices.firstWhere((d) => d is WasherDevice) as WasherDevice;

      state.updateWasher(
        washer.id,
        cycle: 'Baby Wear Care',
        waterTemp: 60,
        spinSpeed: 'Low',
        steam: true,
        turboWash: true,
      );

      final updated = state.allDevices.firstWhere((d) => d.id == washer.id) as WasherDevice;
      expect(updated.selectedCycle, 'Baby Wear Care');
      expect(updated.waterTempC, 60);
      expect(updated.spinSpeed, 'Low');
      expect(updated.steamEnabled, isTrue);
      expect(updated.turboWashEnabled, isTrue);
    });
  });

  group('Phase 3 Widget Tests', () {
    testWidgets('ApplianceCycleStoreSheet renders downloadable catalog', (tester) async {
      final state = HomeState();
      final washer = state.allDevices.firstWhere((d) => d is WasherDevice) as WasherDevice;

      await tester.pumpWidget(
        ChangeNotifierProvider<HomeState>.value(
          value: state,
          child: MaterialApp(
            home: Scaffold(
              body: ApplianceCycleStoreSheet(washer: washer),
            ),
          ),
        ),
      );

      expect(find.text('LG ThinQ UP™ Cycle Store'), findsOneWidget);
      expect(find.text('Gym & Activewear Odor Care'), findsOneWidget);
      expect(find.text('Baby Wear Sanitization'), findsOneWidget);
      expect(find.text('Denim & Color Lock'), findsOneWidget);
    });

    testWidgets('SmartDiagnosisDialog runs diagnosis and renders health meters', (tester) async {
      final state = HomeState();
      final washer = state.allDevices.firstWhere((d) => d is WasherDevice) as WasherDevice;

      await tester.pumpWidget(
        ChangeNotifierProvider<HomeState>.value(
          value: state,
          child: MaterialApp(
            home: Scaffold(
              body: SmartDiagnosisDialog(washer: washer),
            ),
          ),
        ),
      );

      // Loading state initially
      expect(find.text('LG Smart Diagnosis™'), findsOneWidget);

      // Settle diagnosis simulation
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('Appliance in Optimal Health'), findsOneWidget);
      expect(find.text('Subsystem Health Telemetry'), findsOneWidget);
      expect(find.text('Inverter DirectDrive Motor'), findsOneWidget);
      expect(find.text('Drain Pump Assembly'), findsOneWidget);
    });

    testWidgets('EnergyView displays tariff metrics and AI Energy Mode controls', (tester) async {
      final state = HomeState();

      await tester.pumpWidget(
        ChangeNotifierProvider<HomeState>.value(
          value: state,
          child: const MaterialApp(
            home: EnergyView(),
          ),
        ),
      );

      expect(find.text('SmartThings Energy Hub'), findsOneWidget);
      expect(find.text('Real-Time Household Power Draw'), findsOneWidget);
      expect(find.text('Tariff & Cost Projections'), findsOneWidget);
      expect(find.text('Current Cost'), findsOneWidget);
      expect(find.text('Estimated Bill'), findsOneWidget);
      expect(find.text('AI Mode Savings'), findsOneWidget);
      expect(find.text('Carbon Avoided'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('AI Energy Mode (SmartThings)'), 200);
      expect(find.text('AI Energy Mode (SmartThings)'), findsOneWidget);
    });
  });
}
