import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_home/providers/real_home_provider.dart';
import 'package:unified_home/services/real_iot_controller.dart';
import 'package:unified_home/services/smartthings/smartthings_laundry_service.dart';
import 'package:unified_home/ui/widgets/sheets/samsung_washer_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('User Specific Fleet - Service & State Tests', () {
    late RealHomeProvider provider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      provider = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);

      // Add user exact 4 hardware fleet devices
      provider.addDeviceDirect(RealSmartDevice(
        id: 'samsung_washer',
        name: 'Samsung Ecobubble™ AI DD Washer',
        room: 'Laundry Room',
        category: 'washer',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {'cloudDeviceId': 'samsung_washer_01'},
        isOn: true,
        liveWatts: 180.0,
      ));
      provider.addDeviceDirect(RealSmartDevice(
        id: 'lg_ac',
        name: 'LG DualCool AI Inverter AC',
        room: 'Living Room',
        category: 'ac',
        protocol: ConnectionProtocol.customHttpWebhook,
        credentials: {'devId': 'lg_ac_01'},
        isOn: true,
        liveWatts: 1100.0,
      ));
      provider.addDeviceDirect(RealSmartDevice(
        id: 'wipro_bulb',
        name: 'Wipro Smart Next Bulb',
        room: 'Living Room',
        category: 'light',
        protocol: ConnectionProtocol.tuyaLocalLan,
        credentials: {'ip': '192.168.1.102'},
        isOn: true,
        liveWatts: 12.0,
      ));
      provider.addDeviceDirect(RealSmartDevice(
        id: 'oneplus_tv',
        name: 'OnePlus TV 55 U1S',
        room: 'Living Room',
        category: 'tv',
        protocol: ConnectionProtocol.onePlusTvLan,
        credentials: {'ip': '192.168.1.103'},
        isOn: true,
        liveWatts: 140.0,
      ));
    });

    tearDown(() {
      provider.dispose();
    });

    test('Initializes with user exact hardware fleet', () {
      final devices = provider.devices;
      expect(devices.any((d) => d.category == 'washer' && d.name.contains('Samsung')), isTrue);
      expect(devices.any((d) => d.category == 'ac' && d.name.contains('LG DualCool')), isTrue);
      expect(devices.any((d) => d.category == 'light' && d.name.contains('Wipro')), isTrue);
      expect(devices.any((d) => d.category == 'tv' && d.name.contains('OnePlus')), isTrue);
    });

    test('SmartThings Laundry Service generates fabric-specific recipes', () {
      final service = SmartThingsLaundryService();

      // Test Denim Recipe
      final denimRecipe = service.recommendRecipe({GarmentType.jeansDenim});
      expect(denimRecipe.recommendedCycle, contains('Denim'));
      expect(denimRecipe.enableEcoBubble, isTrue);

      // Test Delicates Recipe
      final delicatesRecipe = service.recommendRecipe({GarmentType.delicates});
      expect(delicatesRecipe.recommendedCycle, contains('Delicates'));
      expect(delicatesRecipe.recommendedSpin, 'Low');

      // Test Home Care Status
      final homeCare = service.checkHomeCareStatus(
        drumCleanCount: 38,
        detergentPercent: 15,
        softenerPercent: 40,
      );
      expect(homeCare['detergentLow'], isTrue);
      expect(homeCare['softenerLow'], isFalse);
    });

    test('Samsung Washer updates EcoBubble, AI Wash, and cycle parameters', () {
      provider.updateSamsungWasher(
        'samsung_washer',
        cycle: 'AI Wash (Auto Sense)',
        ecoBubble: true,
        aiWash: true,
        superSpeed: true,
        waterTemp: 40,
        spinSpeed: 'High',
      );

      final washer = provider.devices.firstWhere((d) => d.id == 'samsung_washer');
      expect(washer.selectedCycle, 'AI Wash (Auto Sense)');
      expect(washer.ecoBubbleEnabled, isTrue);
      expect(washer.aiWashEnabled, isTrue);
      expect(washer.superSpeedEnabled, isTrue);
    });

    testWidgets('SamsungWasherSheet renders SmartThings AI Laundry Recipe and technologies', (tester) async {
      final washer = provider.devices.firstWhere((d) => d.id == 'samsung_washer');

      await tester.pumpWidget(
        ChangeNotifierProvider<RealHomeProvider>.value(
          value: provider,
          child: MaterialApp(
            home: Scaffold(
              body: SamsungWasherSheet(device: washer),
            ),
          ),
        ),
      );

      expect(find.text('Samsung Ecobubble™ AI DD Washer'), findsOneWidget);
      expect(find.text('SmartThings'), findsOneWidget);
      expect(find.text('SmartThings Laundry Recipe'), findsOneWidget);
      expect(find.text('EcoBubble™'), findsOneWidget);
      expect(find.text('SuperSpeed'), findsOneWidget);
      expect(find.text('AI Wash (Sensors)'), findsOneWidget);
    });
  });
}
