import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_home/providers/real_home_provider.dart';
import 'package:unified_home/services/ai/ai_home_copilot_service.dart';
import 'package:unified_home/services/real_iot_controller.dart';
import 'package:unified_home/ui/widgets/copilot/ai_copilot_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 4: AI Home Copilot Service Tests', () {
    late RealHomeProvider home;
    late AiHomeCopilotService copilot;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      home = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);
      copilot = AiHomeCopilotService();

      // Seed real test hardware
      home.addDeviceDirect(RealSmartDevice(
        id: 'oneplus_tv',
        name: 'OnePlus TV 55 U1S',
        room: 'Living Room',
        category: 'tv',
        protocol: ConnectionProtocol.onePlusTvLan,
        credentials: {'ip': '192.168.1.100', 'vendor': 'demo'},
      ));
      home.addDeviceDirect(RealSmartDevice(
        id: 'wipro_light_living',
        name: 'Wipro Smart Next Bulb',
        room: 'Living Room',
        category: 'light',
        protocol: ConnectionProtocol.tuyaLocalLan,
        credentials: {'ip': '192.168.1.101', 'vendor': 'demo'},
      ));
      home.addDeviceDirect(RealSmartDevice(
        id: 'lg_ac',
        name: 'LG DualCool AI Inverter AC',
        room: 'Living Room',
        category: 'ac',
        protocol: ConnectionProtocol.customHttpWebhook,
        credentials: {'devId': 'lg_ac_01', 'vendor': 'demo'},
      ));
      home.addDeviceDirect(RealSmartDevice(
        id: 'samsung_washer',
        name: 'Samsung Ecobubble AI DD Washer',
        room: 'Laundry Room',
        category: 'washer',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {'cloudDeviceId': 'st_washer_01', 'vendor': 'demo'},
      ));
    });

    tearDown(() {
      home.dispose();
    });

    test('Coordinates Movie Night scene across TV, Wipro lights, and LG AC', () {
      final response = copilot.processPrompt('Set up movie night in living room', home);

      expect(response.isUser, isFalse);
      expect(response.text, contains('Movie Night activated'));
      expect(response.executedActions.length, greaterThanOrEqualTo(3));

      // Verify OnePlus TV state
      final tv = home.devices.firstWhere((d) => d.id == 'oneplus_tv');
      expect(tv.currentApp, 'OxygenPlay');
      expect(tv.pictureMode, 'Cinema');
      expect(tv.volume, 20);

      // Verify Wipro Bulb state
      final livingLight = home.devices.firstWhere((d) => d.id == 'wipro_light_living');
      expect(livingLight.brightness, 0.20);
      expect(livingLight.activeScene, 'Relax');

      // Verify LG AC state
      final ac = home.devices.firstWhere((d) => d.id == 'lg_ac');
      expect(ac.targetTempC, 22.0);
    });

    test('Coordinates Bedtime routine turning off TV and setting night lighting and Eco AC', () {
      final response = copilot.processPrompt('Goodnight, going to sleep', home);

      expect(response.text, contains('Goodnight routine complete'));
      expect(response.executedActions.isNotEmpty, isTrue);

      final ac = home.devices.firstWhere((d) => d.id == 'lg_ac');
      expect(ac.targetTempC, 24.0);
    });

    test('Triggers Samsung Laundry Recipe for denim jeans', () {
      final response = copilot.processPrompt('What cycle should I run for my jeans?', home);

      expect(response.text, contains('Samsung Laundry Recipe for Jeans'));
      final washer = home.devices.firstWhere((d) => d.id == 'samsung_washer');
      expect(washer.selectedCycle, contains('Denim'));
      expect(washer.ecoBubbleEnabled, isTrue);
    });

    test('Triggers LG AC Jet Cool command', () {
      final response = copilot.processPrompt('Turn on jet cool, it is hot', home);

      expect(response.text, contains('LG Jet Cool activated'));
      final ac = home.devices.firstWhere((d) => d.id == 'lg_ac');
      expect(ac.jetCoolActive, isTrue);
      expect(ac.targetTempC, 18.0);
    });

    test('Triggers Wipro Bulbs Party Mode with Music Sync', () {
      final response = copilot.processPrompt('Start party mode lights', home);

      expect(response.text, contains('Party Mode engaged'));
      final light = home.devices.firstWhere((d) => d.id == 'wipro_light_living');
      expect(light.activeScene, 'Party Mode');
      expect(light.musicSyncActive, isTrue);
    });

    test('Answers energy draw and utility tariff queries', () {
      final response = copilot.processPrompt('How much power is the house consuming?', home);

      expect(response.text, contains('Current house draw'));
      expect(response.text, contains('SmartThings AI Energy Mode'));
    });
  });

  group('Phase 4: AI Copilot Sheet Widget Tests', () {
    testWidgets('AiCopilotSheet renders input bar and handles quick prompts', (tester) async {
      final home = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);

      await tester.pumpWidget(
        ChangeNotifierProvider<RealHomeProvider>.value(
          value: home,
          child: const MaterialApp(
            home: Scaffold(
              body: AiCopilotSheet(),
            ),
          ),
        ),
      );

      expect(find.text('AI Home Copilot'), findsOneWidget);
      expect(find.text('Multimodal Intent & Function Execution'), findsOneWidget);
      expect(find.text('🎬 Movie night scene'), findsOneWidget);

      await tester.tap(find.text('🎬 Movie night scene'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Movie Night activated'), findsOneWidget);

      home.dispose();
    });
  });
}
