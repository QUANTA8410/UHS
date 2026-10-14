import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:unified_home/providers/real_home_provider.dart';
import 'package:unified_home/services/automation/smart_automation_engine.dart';
import 'package:unified_home/services/real_iot_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_home/ui/views/smart_automations_studio_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final testLight = RealSmartDevice(
    id: 'light_01',
    name: 'Living Room Light',
    room: 'Living Room',
    category: 'light',
    protocol: ConnectionProtocol.smartThingsCloud,
    credentials: {'token': 'dummy_token'},
    isOn: false,
    primaryValue: 100.0,
  );

  final testTv = RealSmartDevice(
    id: 'tv_01',
    name: 'OnePlus TV',
    room: 'Living Room',
    category: 'tv',
    protocol: ConnectionProtocol.onePlusTvLan,
    credentials: {'ip': '192.168.1.50'},
    isOn: true,
  );

  final testAc = RealSmartDevice(
    id: 'ac_01',
    name: 'LG DualCool AC',
    room: 'Bedroom',
    category: 'ac',
    protocol: ConnectionProtocol.smartThingsCloud,
    credentials: {'token': 'dummy_token'},
    isOn: false,
    primaryValue: 24.0,
  );

  final allDevices = [testLight, testTv, testAc];

  group('Smart Automation Engine - Models & Serialization', () {
    test('MultiConditionAutomationRule serializes and deserializes accurately', () {
      final rule = MultiConditionAutomationRule(
        id: 'rule_101',
        name: 'Night Energy Saver',
        isEnabled: true,
        trigger: SmartTrigger(
          kind: TriggerKind.timeSchedule,
          value: '23:30',
          weekdays: [1, 2, 3, 4, 5],
        ),
        preconditions: [
          SmartPrecondition(kind: PreconditionKind.onlyAtNight),
          SmartPrecondition(kind: PreconditionKind.onlyWhenHome),
        ],
        actions: [
          SmartActionStep(
            targetDeviceId: 'light_01',
            targetDeviceName: 'Living Room Light',
            turnOn: false,
            delaySecondsBefore: 0,
          ),
          SmartActionStep(
            targetDeviceId: 'tv_01',
            targetDeviceName: 'OnePlus TV',
            turnOn: false,
            delaySecondsBefore: 5,
          ),
        ],
        executionCount: 2,
      );

      final json = rule.toJson();
      expect(json['id'], equals('rule_101'));
      expect(json['name'], equals('Night Energy Saver'));

      final restored = MultiConditionAutomationRule.fromJson(json);
      expect(restored.id, equals(rule.id));
      expect(restored.name, equals(rule.name));
      expect(restored.trigger.kind, equals(TriggerKind.timeSchedule));
      expect(restored.trigger.value, equals('23:30'));
      expect(restored.trigger.weekdays, equals([1, 2, 3, 4, 5]));
      expect(restored.preconditions.length, equals(2));
      expect(restored.preconditions[0].kind, equals(PreconditionKind.onlyAtNight));
      expect(restored.preconditions[1].kind, equals(PreconditionKind.onlyWhenHome));
      expect(restored.actions.length, equals(2));
      expect(restored.actions[1].delaySecondsBefore, equals(5));
      expect(restored.executionCount, equals(2));
    });

    test('AutomationExecutionLog records timestamps and failure/success state', () {
      final log = AutomationExecutionLog(
        id: 'log_01',
        ruleId: 'rule_101',
        ruleName: 'Night Energy Saver',
        timestamp: DateTime(2026, 10, 14, 23, 30),
        summary: 'Turn OFF Living Room Light -> [Wait 5s] Turn OFF OnePlus TV',
        success: true,
      );

      final json = log.toJson();
      final restored = AutomationExecutionLog.fromJson(json);
      expect(restored.id, equals('log_01'));
      expect(restored.success, isTrue);
      expect(restored.summary.contains('Wait 5s'), isTrue);
    });
  });

  group('Smart Automation Engine - Guard Precondition Evaluation', () {
    final engine = SmartAutomationEngine();

    test('evaluatePreconditions validates time-of-day guards', () {
      final nightRule = MultiConditionAutomationRule(
        id: 'r_night',
        name: 'Night Only',
        trigger: SmartTrigger(kind: TriggerKind.timeSchedule, value: '23:00'),
        preconditions: [SmartPrecondition(kind: PreconditionKind.onlyAtNight)],
        actions: [],
      );

      final nightTime = DateTime(2026, 10, 14, 23, 0); // 23:00 is night (>= 18:30)
      final dayTime = DateTime(2026, 10, 14, 12, 0);   // 12:00 is day (< 18:30 and >= 06:00)

      expect(
        engine.evaluatePreconditions(nightRule, isUserAtHome: true, devices: allDevices, now: nightTime),
        isTrue,
      );
      expect(
        engine.evaluatePreconditions(nightRule, isUserAtHome: true, devices: allDevices, now: dayTime),
        isFalse,
      );
    });

    test('evaluatePreconditions validates presence and weekday guards', () {
      final homeWeekdayRule = MultiConditionAutomationRule(
        id: 'r_hw',
        name: 'Home on Weekday',
        trigger: SmartTrigger(kind: TriggerKind.solarEvent, value: 'sunset'),
        preconditions: [
          SmartPrecondition(kind: PreconditionKind.onlyWhenHome),
          SmartPrecondition(kind: PreconditionKind.onlyWeekdays),
        ],
        actions: [],
      );

      final wednesday = DateTime(2026, 10, 14); // Wednesday (weekday = 3)
      final sunday = DateTime(2026, 10, 18);    // Sunday (weekday = 7)

      // At home on Wednesday -> Pass
      expect(
        engine.evaluatePreconditions(homeWeekdayRule, isUserAtHome: true, devices: allDevices, now: wednesday),
        isTrue,
      );
      // Away from home on Wednesday -> Fail
      expect(
        engine.evaluatePreconditions(homeWeekdayRule, isUserAtHome: false, devices: allDevices, now: wednesday),
        isFalse,
      );
      // At home on Sunday -> Fail (not weekday)
      expect(
        engine.evaluatePreconditions(homeWeekdayRule, isUserAtHome: true, devices: allDevices, now: sunday),
        isFalse,
      );
    });
  });

  group('Smart Automation Engine - Trigger Evaluation', () {
    final engine = SmartAutomationEngine();

    test('shouldTriggerTime checks schedule and weekday', () {
      final rule = MultiConditionAutomationRule(
        id: 'r1',
        name: 'Morning Wakeup',
        trigger: SmartTrigger(kind: TriggerKind.timeSchedule, value: '07:15', weekdays: [1, 2, 3, 4, 5]),
        actions: [],
      );

      final matchTime = DateTime(2026, 10, 14, 7, 15); // Wednesday 07:15
      final nonMatchTime = DateTime(2026, 10, 14, 7, 16);

      expect(engine.shouldTriggerTime(rule, matchTime), isTrue);
      expect(engine.shouldTriggerTime(rule, nonMatchTime), isFalse);
    });

    test('shouldTriggerSolar checks sunset and sunrise', () {
      final sunsetRule = MultiConditionAutomationRule(
        id: 'r2',
        name: 'Sunset Lights',
        trigger: SmartTrigger(kind: TriggerKind.solarEvent, value: 'sunset'),
        actions: [],
      );

      final sunsetTime = DateTime(2026, 10, 14, 18, 30);
      final midday = DateTime(2026, 10, 14, 12, 0);

      expect(engine.shouldTriggerSolar(sunsetRule, sunsetTime), isTrue);
      expect(engine.shouldTriggerSolar(sunsetRule, midday), isFalse);
    });

    test('shouldTriggerPresence checks arrive and leave', () {
      final arriveRule = MultiConditionAutomationRule(
        id: 'r3',
        name: 'Welcome Home',
        trigger: SmartTrigger(kind: TriggerKind.wifiPresence, value: 'arrive_home'),
        actions: [],
      );

      expect(engine.shouldTriggerPresence(arriveRule, true), isTrue);
      expect(engine.shouldTriggerPresence(arriveRule, false), isFalse);
    });
  });

  group('Smart Automation Engine - Natural Language Rule Parser', () {
    final engine = SmartAutomationEngine();

    test('parses scheduled time and turn-off actions for devices', () {
      final rule = engine.parseNaturalLanguageToRule(
        'At 11:00 PM turn off Living Room Light and TV',
        allDevices,
      );

      expect(rule, isNotNull);
      expect(rule!.trigger.kind, equals(TriggerKind.timeSchedule));
      expect(rule.trigger.value, equals('23:00'));
      expect(rule.actions.isNotEmpty, isTrue);
      expect(rule.actions.any((a) => a.targetDeviceName.contains('Light')), isTrue);
      expect(rule.actions.any((a) => a.targetDeviceName.contains('TV')), isTrue);
      expect(rule.actions.every((a) => a.turnOn == false), isTrue);
    });

    test('parses sunset trigger with brightness level', () {
      final rule = engine.parseNaturalLanguageToRule(
        'At sunset turn on Living Room Light to 80%',
        allDevices,
      );

      expect(rule, isNotNull);
      expect(rule!.trigger.kind, equals(TriggerKind.solarEvent));
      expect(rule.trigger.value, equals('sunset'));
      expect(rule.actions.first.turnOn, isTrue);
      expect(rule.actions.first.targetLevel, equals(80.0));
    });

    test('parses presence trigger with weekday guard', () {
      final rule = engine.parseNaturalLanguageToRule(
        'When I leave home turn off all lights only on weekdays',
        allDevices,
      );

      expect(rule, isNotNull);
      expect(rule!.trigger.kind, equals(TriggerKind.wifiPresence));
      expect(rule.trigger.value, equals('leave_home'));
      expect(rule.preconditions.any((p) => p.kind == PreconditionKind.onlyWeekdays), isTrue);
      expect(rule.actions.any((a) => a.targetDeviceName.contains('Light')), isTrue);
      expect(rule.actions.first.turnOn, isFalse);
    });
  });

  group('SmartRuleStudioSheet UI Widget Tests', () {
    testWidgets('SmartRuleStudioSheet renders WHEN, ONLY IF, and THEN sections', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final homeProvider = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);

      await tester.pumpWidget(
        ChangeNotifierProvider<RealHomeProvider>.value(
          value: homeProvider,
          child: const MaterialApp(
            home: Scaffold(
              body: SmartRuleStudioSheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Visual Apple Glass Rule Studio'), findsOneWidget);
      expect(find.text('1. WHEN (TRIGGER)'), findsOneWidget);
      expect(find.text('2. ONLY IF (PRECONDITIONS)'), findsOneWidget);
      expect(find.text('3. THEN (MULTI-STEP ACTION SEQUENCE)'), findsOneWidget);
      expect(find.text('Save & Deploy Rule'), findsOneWidget);
    });

    testWidgets('Tapping Washer Finished Alert preset configures 4-step pulse on light and washer off trigger', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final homeProvider = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);
      final washer = RealSmartDevice(
        id: 'washer_test',
        name: 'Samsung AI Ecobubble Washer',
        room: 'Laundry',
        category: 'washer',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {'token': 'dummy'},
        isOn: false,
      );
      final bulb = RealSmartDevice(
        id: 'bulb_test',
        name: 'Wipro Smart Bulb',
        room: 'Living Room',
        category: 'light',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {'token': 'dummy'},
        isOn: false,
      );
      homeProvider.addDeviceDirect(washer);
      homeProvider.addDeviceDirect(bulb);

      await tester.pumpWidget(
        ChangeNotifierProvider<RealHomeProvider>.value(
          value: homeProvider,
          child: const MaterialApp(
            home: Scaffold(
              body: SmartRuleStudioSheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the Washer Finished Alert template chip
      final templateChip = find.byKey(const Key('template_washer_finished_alert'));
      expect(templateChip, findsOneWidget);
      await tester.tap(templateChip);
      await tester.pumpAndSettle();

      // Verify Rule Name was populated (1 in template chip, 1 in textfield)
      expect(find.text('🧺 Washer Finished Alert'), findsNWidgets(2));

      // Verify 4 sequenced steps exist
      expect(find.text('Step 1'), findsOneWidget);
      expect(find.text('Step 2'), findsOneWidget);
      expect(find.text('Step 3'), findsOneWidget);
      expect(find.text('Step 4'), findsOneWidget);

      // Verify wait delays: Step 1 (No delay), Steps 2, 3, 4 (Wait 2s)
      expect(find.text('No delay'), findsOneWidget);
      expect(find.text('Wait 2s'), findsNWidgets(3));
    });

    testWidgets('SmartAutomationsStudioView initializes with initialTemplate washer_finished', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final homeProvider = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);
      final washer = RealSmartDevice(
        id: 'washer_test_2',
        name: 'LG ThinQ Washer',
        room: 'Laundry',
        category: 'washer',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {'token': 'dummy'},
        isOn: false,
      );
      final bulb = RealSmartDevice(
        id: 'bulb_test_2',
        name: 'Wipro RGB Bulb',
        room: 'Balcony',
        category: 'light',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {'token': 'dummy'},
        isOn: false,
      );
      homeProvider.addDeviceDirect(washer);
      homeProvider.addDeviceDirect(bulb);

      await tester.pumpWidget(
        ChangeNotifierProvider<RealHomeProvider>.value(
          value: homeProvider,
          child: const MaterialApp(
            home: SmartAutomationsStudioView(initialTemplate: 'washer_finished'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('🧺 Washer Finished Alert'), findsNWidgets(2));
      expect(find.text('Step 1'), findsOneWidget);
      expect(find.text('Step 2'), findsOneWidget);
      expect(find.text('Step 3'), findsOneWidget);
      expect(find.text('Step 4'), findsOneWidget);
    });
  });

  group('Washer Cycle Completion Edge Trigger Tests', () {
    test('Detects washer edge transition run -> stop and evaluates automations', () async {
      final homeProvider = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);
      final washer = RealSmartDevice(
        id: 'washer_edge',
        name: 'Samsung Washer',
        room: 'Laundry',
        category: 'washer',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {'token': 'dummy'},
        isOn: true,
        liveAttributes: {'state': 'run'},
      );
      final bulb = RealSmartDevice(
        id: 'bulb_edge',
        name: 'Corridor Light',
        room: 'Corridor',
        category: 'light',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {'token': 'dummy'},
        isOn: false,
      );
      homeProvider.addDeviceDirect(washer);
      homeProvider.addDeviceDirect(bulb);

      // Initialize initial running state
      await homeProvider.syncAllDevicesSilent();
      expect(homeProvider.lastWasherMachineState[washer.id], equals('run'));

      bool automationFired = false;
      final rule = MultiConditionAutomationRule(
        id: 'rule_washer_finished',
        name: 'Washer Done Alert',
        trigger: SmartTrigger(
          kind: TriggerKind.deviceState,
          sourceDeviceId: washer.id,
          value: 'off',
        ),
        preconditions: [],
        actions: [
          SmartActionStep(
            targetDeviceId: bulb.id,
            targetDeviceName: bulb.name,
            turnOn: true,
            targetLevel: 100.0,
            delaySecondsBefore: 0,
          ),
        ],
      );
      await homeProvider.addMultiConditionRule(rule);

      // Listen to hardware reflex event to verify cycle_complete event
      homeProvider.reflexBus.events.listen((ev) {
        if (ev.sourceDeviceId == washer.id && ev.eventType == 'cycle_complete') {
          automationFired = true;
        }
      });

      // Now washer finishes: state transitions from 'run' to 'stop' (device turns off)
      washer.isOn = false;
      washer.liveAttributes = {'state': 'stop'};

      // Silent sync check simulates polling cycle
      await homeProvider.syncAllDevicesSilent();

      // State is updated
      expect(homeProvider.lastWasherMachineState[washer.id], equals('stop'));
      expect(automationFired, isTrue);

      // Subsequent sync while still in 'stop' does NOT re-trigger
      automationFired = false;
      await homeProvider.syncAllDevicesSilent();
      expect(automationFired, isFalse);
    });
  });
}
