import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:unified_home/models/device_model.dart';
import 'package:unified_home/providers/home_state.dart';
import 'package:unified_home/services/ai/ai_home_copilot_service.dart';
import 'package:unified_home/ui/views/map_view.dart';
import 'package:unified_home/ui/widgets/copilot/ai_copilot_sheet.dart';

void main() {
  group('Phase 4: AI Home Copilot Service Tests', () {
    late HomeState state;
    late AiHomeCopilotService copilot;

    setUp(() {
      state = HomeState();
      copilot = AiHomeCopilotService();
    });

    test('Coordinates Movie Night scene across TV, Wipro lights, and LG AC', () {
      final response = copilot.processPrompt('Set up movie night in living room', state);

      expect(response.isUser, isFalse);
      expect(response.text, contains('Movie Night activated'));
      expect(response.executedActions.length, greaterThanOrEqualTo(3));

      // Verify OnePlus TV state
      final tv = state.allDevices.whereType<TvDevice>().first;
      expect(tv.currentApp, 'OxygenPlay');
      expect(tv.pictureMode, 'Cinema');
      expect(tv.volume, 20);

      // Verify Wipro Bulb state
      final livingLight = state.allDevices.whereType<LightDevice>().firstWhere((d) => d.room == 'Living Room');
      expect(livingLight.brightness, 0.20);
      expect(livingLight.activeScene, 'Relax');

      // Verify LG AC state
      final ac = state.allDevices.whereType<ThermostatDevice>().first;
      expect(ac.targetTempC, 22.0);
      expect(ac.fanSpeed, 'Low');
    });

    test('Coordinates Bedtime routine turning off TV and setting night lighting and Eco AC', () {
      final response = copilot.processPrompt('Goodnight, going to sleep', state);

      expect(response.text, contains('Goodnight routine complete'));
      expect(response.executedActions.isNotEmpty, isTrue);

      final ac = state.allDevices.whereType<ThermostatDevice>().first;
      expect(ac.mode, ThermostatMode.eco);
      expect(ac.targetTempC, 24.0);
    });

    test('Triggers Samsung Laundry Recipe for denim jeans', () {
      final response = copilot.processPrompt('What cycle should I run for my jeans?', state);

      expect(response.text, contains('Samsung Laundry Recipe for Jeans'));
      final washer = state.allDevices.whereType<WasherDevice>().first;
      expect(washer.selectedCycle, contains('Denim'));
      expect(washer.ecoBubbleEnabled, isTrue);
    });

    test('Triggers LG AC Jet Cool command', () {
      final response = copilot.processPrompt('Turn on jet cool, it is hot', state);

      expect(response.text, contains('LG Jet Cool activated'));
      final ac = state.allDevices.whereType<ThermostatDevice>().first;
      expect(ac.jetCoolActive, isTrue);
      expect(ac.targetTempC, 18.0);
    });

    test('Triggers Wipro Bulbs Party Mode with Music Sync', () {
      final response = copilot.processPrompt('Start party mode lights', state);

      expect(response.text, contains('Party Mode engaged'));
      final lights = state.allDevices.whereType<LightDevice>();
      for (final l in lights) {
        expect(l.activeScene, 'Party Mode');
        expect(l.musicSyncActive, isTrue);
      }
    });

    test('Answers energy draw and utility tariff queries', () {
      final response = copilot.processPrompt('How much power is the house consuming?', state);

      expect(response.text, contains('Current house draw'));
      expect(response.text, contains('SmartThings AI Energy Mode'));
    });
  });

  group('Phase 4: Spatial 3D Map View & Copilot Widget Tests', () {
    testWidgets('MapView renders 3D Spatial canvas, layer controls, and AI Copilot FAB', (tester) async {
      final state = HomeState();

      await tester.pumpWidget(
        ChangeNotifierProvider<HomeState>.value(
          value: state,
          child: const MaterialApp(
            home: MapView(),
          ),
        ),
      );

      expect(find.text('SmartThings 3D Map View'), findsOneWidget);
      expect(find.text('3D Spatial'), findsOneWidget);
      expect(find.text('Thermal Flow (LG AC)'), findsOneWidget);
      expect(find.text('Energy Overlay'), findsOneWidget);
      expect(find.text('AI Copilot'), findsOneWidget);
      expect(find.text('Living Room'), findsOneWidget);
      expect(find.text('Kitchen'), findsOneWidget);
      expect(find.text('Laundry Room'), findsOneWidget);
      expect(find.text('Master Bedroom'), findsOneWidget);

      // Switch to Thermal Flow layer
      await tester.tap(find.text('Thermal Flow (LG AC)'));
      await tester.pumpAndSettle();
      expect(find.text('Cooling Flow: 21.5°C Active'), findsOneWidget);
    });

    testWidgets('AiCopilotSheet renders message thread, quick prompt chips, and executes query', (tester) async {
      final state = HomeState();

      await tester.pumpWidget(
        ChangeNotifierProvider<HomeState>.value(
          value: state,
          child: const MaterialApp(
            home: Scaffold(
              body: AiCopilotSheet(),
            ),
          ),
        ),
      );

      expect(find.text('AI Home Copilot'), findsOneWidget);
      expect(find.text('🎬 Movie night scene'), findsOneWidget);
      expect(find.text('❄️ Activate LG Jet Cool'), findsOneWidget);

      // Tap quick prompt
      await tester.tap(find.text('🎬 Movie night scene'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Movie Night activated'), findsOneWidget);
    });
  });
}
