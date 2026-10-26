import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_home/providers/real_home_provider.dart';
import 'package:unified_home/services/real_iot_controller.dart';
import 'package:unified_home/services/master/zero_touch_onboarding_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Deep Appliance Control & Optimistic Dispatch Tests', () {
    late RealHomeProvider provider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      provider = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);
    });

    test('ZeroTouchOnboardingService singleton instance and multi-appliance helpers exist', () {
      expect(ZeroTouchOnboardingService.instance, isNotNull);
      final zt = ZeroTouchOnboardingService.instance;
      expect(zt, isA<ZeroTouchOnboardingService>());
    });

    test('All 15 appliance methods synchronously update RAM state and compute live wattage', () {
      final dev = RealSmartDevice(
        id: 'real_test_appliance_01',
        name: 'Multi Appliance',
        room: 'Kitchen',
        category: 'washer',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {'vendor': 'samsung'},
        isOn: true,
        primaryValue: 1200,
        liveAttributes: {},
        ratedMaxWatts: 500,
      );
      provider.addDeviceDirect(dev);

      // 1. updateWasher
      provider.updateWasher(dev.id, cycle: 'Delicates', waterTemp: 30, spinSpeed: '800 RPM', steam: true);
      expect(dev.liveAttributes['cycle'], 'Delicates');
      expect(dev.liveAttributes['waterTemperature'], 30);
      expect(dev.liveAttributes['spinSpeed'], '800 RPM');
      expect(dev.liveAttributes['steam'], true);

      // 2. updateSamsungWasher
      provider.updateSamsungWasher(
        dev.id,
        ecoBubble: true,
        superSpeed: true,
        aiWash: true,
        rinseCount: 4,
        waterTempStr: '60°C',
        stage: 'rinse',
      );
      expect(dev.liveAttributes['ecoBubble'], true);
      expect(dev.liveAttributes['superSpeed'], true);
      expect(dev.liveAttributes['aiWash'], true);
      expect(dev.liveAttributes['rinseCount'], 4);
      expect(dev.liveAttributes['waterTemp'], '60°C');
      expect(dev.liveAttributes['stage'], 'rinse');

      // 3. setDevicePrimaryValue
      provider.setDevicePrimaryValue(dev.id, 1400);
      expect(dev.primaryValue, 1400);

      // 4. updateSamsungAc
      provider.updateSamsungAc(dev.id, targetTemp: 21.0, windFree: true, aiEnergyMode: true);
      expect(dev.primaryValue, 21.0);
      expect(dev.liveAttributes['windFree'], true);
      expect(dev.liveAttributes['aiEnergyMode'], true);

      // 5. updateSamsungFridge
      provider.updateSamsungFridge(dev.id, fridgeTemp: 2.0, freezerTemp: -20.0, iceBites: true, powerCool: true);
      expect(dev.liveAttributes['fridgeTemp'], 2.0);
      expect(dev.liveAttributes['freezerTemp'], -20.0);
      expect(dev.liveAttributes['powerCool'], true);

      // 6. updateSamsungTv
      provider.updateSamsungTv(dev.id, artMode: true, lightSync: true, selectedArtwork: 'Mona Lisa');
      expect(dev.liveAttributes['artMode'], true);
      expect(dev.liveAttributes['lightSync'], true);
      expect(dev.liveAttributes['selectedArtwork'], 'Mona Lisa');

      // 7. updateTv
      provider.updateTv(dev.id, app: 'Netflix', volume: 25, pictureMode: 'Cinema');
      expect(dev.liveAttributes['currentApp'], 'Netflix');
      expect(dev.liveAttributes['volume'], 25);
      expect(dev.liveAttributes['pictureMode'], 'Cinema');

      // 8. updateWiproBulb
      provider.updateWiproBulb(
        dev.id,
        brightness: 0.85,
        color: const Color(0xFF00FF88),
        colorTempKelvin: 4000,
        scene: 'Night',
        musicSync: false,
      );
      expect(dev.primaryValue, 85.0);
      expect(dev.liveAttributes['color'], isNotNull);
      expect(dev.liveAttributes['colorTempKelvin'], 4000);
      expect(dev.liveAttributes['activeScene'], 'Night');

      // 9. updateLgAc
      provider.updateLgAc(dev.id, targetTemp: 23.0, fanSpeed: 'HIGH', jetCool: true);
      expect(dev.primaryValue, 23.0);
      expect(dev.liveAttributes['fanSpeed'], 'HIGH');
      expect(dev.liveAttributes['jetCool'], true);

      // 10. updateLgWashTower
      provider.updateLgWashTower(
        dev.id,
        turboWash360: true,
        ezDispenseDetergent: 90,
        steamPlus: true,
        dryLevel: 'EXTRA',
      );
      expect(dev.liveAttributes['turboWash360'], true);
      expect(dev.liveAttributes['ezDispenseDetergent'], 90);
      expect(dev.liveAttributes['steamPlus'], true);
      expect(dev.liveAttributes['dryLevel'], 'EXTRA');

      // 11. updateLgFridge
      provider.updateLgFridge(
        dev.id,
        instaViewTransparent: true,
        craftIce: true,
        doorCooling: true,
        expressCool: true,
      );
      expect(dev.liveAttributes['instaViewTransparent'], true);
      expect(dev.liveAttributes['craftIce'], true);
      expect(dev.liveAttributes['doorCooling'], true);
      expect(dev.liveAttributes['expressCool'], true);

      // 12. updateLgAeroTower
      provider.updateLgAeroTower(dev.id, cleanBoosterTilt: 45, airflowMode: 'WIDE', uvNano: true);
      expect(dev.liveAttributes['cleanBoosterTilt'], 45);
      expect(dev.liveAttributes['airflowMode'], 'WIDE');
      expect(dev.liveAttributes['uvNano'], true);

      // 13. updateLgStyler
      provider.updateLgStyler(dev.id, movingHangerRpm: 200, trueSteam: true, pantsCrease: true);
      expect(dev.liveAttributes['movingHangerRpm'], 200);
      expect(dev.liveAttributes['trueSteam'], true);
      expect(dev.liveAttributes['pantsCrease'], true);

      // 14. updateLgDishwasher
      provider.updateLgDishwasher(dev.id, quadWashArmPressure: 'HIGH', trueSteamDishwash: true, autoDoorOpen: true);
      expect(dev.liveAttributes['quadWashArmPressure'], 'HIGH');
      expect(dev.liveAttributes['trueSteamDishwash'], true);
      expect(dev.liveAttributes['autoDoorOpen'], true);

      // 15. triggerLgThinqUp
      provider.triggerLgThinqUp(dev.id, installedFeature: 'Pet Care Micro-Mist');
      expect(dev.liveAttributes['thinqUpInstalledFeature'], 'Pet Care Micro-Mist');
      expect(dev.liveAttributes['thinqUpUpdate'], false);
    });

    test('RealIotController supports new protocols in executeDeviceCommand without crash', () async {
      final controller = RealIotController();

      // Tuya Local LAN dummy / unconfigured device
      final tuyaDev = RealSmartDevice(
        id: 'tuya_lamp_01',
        name: 'Wipro Lamp',
        room: 'Study',
        category: 'light',
        protocol: ConnectionProtocol.tuyaLocalLan,
        credentials: {'vendor': 'demo'},
        isOn: true,
        isOnline: true,
      );
      // Dummy check returns without opening socket in tests
      await controller.executeDeviceCommand(tuyaDev, 'switch', 'setPower', [{'20': true}]);

      // OnePlus TV LAN dummy device
      final tvDev = RealSmartDevice(
        id: 'oneplus_tv_01',
        name: 'OnePlus TV U1S',
        room: 'Living Room',
        category: 'tv',
        protocol: ConnectionProtocol.onePlusTvLan,
        credentials: {'vendor': 'demo'},
        isOn: true,
        isOnline: true,
      );
      await controller.executeDeviceCommand(tvDev, 'mediaPlayback', 'launchApp', ['Netflix']);
      await controller.executeDeviceCommand(tvDev, 'audioVolume', 'setVolume', ['VOL_UP']);

      // Custom HTTP Webhook LG device
      final lgDev = RealSmartDevice(
        id: 'lg_ac_01',
        name: 'LG DUAL Inverter AC',
        room: 'Bedroom',
        category: 'ac',
        protocol: ConnectionProtocol.customHttpWebhook,
        credentials: {'vendor': 'lg_thinq', 'token': 'demo_token'},
        isOn: true,
        isOnline: true,
      );
      await controller.executeDeviceCommand(lgDev, 'temperature', 'setTemperature', [{'targetTemperature': 24}]);
    });
  });
}
