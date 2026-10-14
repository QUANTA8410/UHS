import 'package:flutter_test/flutter_test.dart';
import 'package:unified_home/models/device_model.dart';
import 'package:unified_home/providers/home_state.dart';

void main() {
  group('HomeState Model & Capability Tests (Phase 1)', () {
    late HomeState state;

    setUp(() {
      state = HomeState();
    });

    test('Initializes with default devices across ecosystems', () {
      expect(state.allDevices.length, greaterThanOrEqualTo(5));
      expect(state.rooms.length, 4);
      expect(state.activeLightsCount, greaterThan(0));
      expect(state.activeAppliancesCount, greaterThan(0));
    });

    test('Toggle device power toggles state and notifies listeners', () {
      final initialPower = state.devices.first.isPowered;
      final devId = state.devices.first.id;

      state.togglePower(devId);
      expect(state.devices.firstWhere((d) => d.id == devId).isPowered, !initialPower);
    });

    test('LG Washer updates cycle, water temperature, and spin speed', () {
      final washer = state.allDevices.firstWhere((d) => d is WasherDevice) as WasherDevice;

      state.updateWasher(
        washer.id,
        cycle: 'Steam Refresh',
        waterTemp: 60,
        spinSpeed: 'Max',
        steam: true,
      );

      expect(washer.selectedCycle, 'Steam Refresh');
      expect(washer.waterTempC, 60);
      expect(washer.spinSpeed, 'Max');
      expect(washer.steamEnabled, true);
    });

    test('LG Refrigerator updates Craft Ice mode and dual compartment temps', () {
      final fridge = state.allDevices.firstWhere((d) => d is RefrigeratorDevice) as RefrigeratorDevice;

      state.updateRefrigerator(
        fridge.id,
        craftIce: CraftIceMode.threePerDay,
        fridgeTemp: 2.0,
        freezerTemp: -21.0,
        expressFreeze: true,
      );

      expect(fridge.craftIceMode, CraftIceMode.threePerDay);
      expect(fridge.fridgeTempC, 2.0);
      expect(fridge.freezerTempC, -21.0);
      expect(fridge.expressFreeze, true);
    });

    test('Thermostat updates target temperature and LG Jet Cool mode', () {
      final climate = state.allDevices.firstWhere((d) => d is ThermostatDevice) as ThermostatDevice;

      state.updateThermostat(
        climate.id,
        targetTemp: 19.5,
        mode: ThermostatMode.cool,
        jetCool: true,
      );

      expect(climate.targetTempC, 19.5);
      expect(climate.jetCoolActive, true);
      expect(climate.statusSummary, contains('Jet Cool Active'));
    });

    test('SmartThings AI Energy Mode reduces total power consumption by 15%', () {
      final initialPower = state.totalPowerWatts;
      expect(state.aiEnergyModeEnabled, false);

      state.toggleAiEnergyMode();
      expect(state.aiEnergyModeEnabled, true);
      expect(state.totalPowerWatts, closeTo(initialPower * 0.85, 0.1));
    });
  });
}
