import 'dart:async';
import '../real_iot_controller.dart';

class HardwareReflexEvent {
  final String sourceDeviceId;
  final String sourceCategory; // 'tv', 'washer', 'ac', 'light', 'phone_call'
  final String eventType; // 'power_on', 'power_off', 'cycle_complete', 'incoming_call'
  final DateTime timestamp;

  HardwareReflexEvent({
    required this.sourceDeviceId,
    required this.sourceCategory,
    required this.eventType,
  }) : timestamp = DateTime.now();
}

class CrossBrandReflexRule {
  final String id;
  final String title;
  final String description;
  final String triggerCategory;
  final String triggerEvent;
  final String targetCategory;
  final bool targetPower;
  final double? targetLevel;
  bool isEnabled;

  CrossBrandReflexRule({
    required this.id,
    required this.title,
    required this.description,
    required this.triggerCategory,
    required this.triggerEvent,
    required this.targetCategory,
    required this.targetPower,
    this.targetLevel,
    this.isEnabled = true,
  });
}

class CrossBrandReflexBus {
  final StreamController<HardwareReflexEvent> _bus =
      StreamController<HardwareReflexEvent>.broadcast();

  Stream<HardwareReflexEvent> get events => _bus.stream;

  final List<CrossBrandReflexRule> reflexRules = [
    CrossBrandReflexRule(
      id: 'reflex_cinema',
      title: '🎬 OnePlus TV → Wipro Cinema Dimmer',
      description: 'When OnePlus TV turns ON, automatically dim Wipro Bulbs to 15%.',
      triggerCategory: 'tv',
      triggerEvent: 'power_on',
      targetCategory: 'light',
      targetPower: true,
      targetLevel: 15.0,
    ),
    CrossBrandReflexRule(
      id: 'reflex_cinema_ac',
      title: '❄️ OnePlus TV → LG AC Silent Comfort',
      description: 'When OnePlus TV turns ON, set LG DualCool AC to 23°C.',
      triggerCategory: 'tv',
      triggerEvent: 'power_on',
      targetCategory: 'ac',
      targetPower: true,
      targetLevel: 23.0,
    ),
    CrossBrandReflexRule(
      id: 'reflex_laundry_done',
      title: '🧺 Samsung Washer Done → Wipro Visual Alert',
      description: 'When Samsung Washer finishes its cycle, set Wipro Bulbs to 100% alert glow.',
      triggerCategory: 'washer',
      triggerEvent: 'power_off',
      targetCategory: 'light',
      targetPower: true,
      targetLevel: 100.0,
    ),
  ];

  void emitEvent(HardwareReflexEvent event) {
    if (!_bus.isClosed) {
      _bus.add(event);
    }
  }

  Future<List<String>> evaluateReflexes({
    required HardwareReflexEvent event,
    required List<RealSmartDevice> allDevices,
    required Future<void> Function(RealSmartDevice dev, bool power, double? level) executeAction,
  }) async {
    final List<String> executedLogs = [];

    for (final rule in reflexRules) {
      if (!rule.isEnabled) continue;
      if (rule.triggerCategory == event.sourceCategory &&
          rule.triggerEvent == event.eventType) {
        final matchingTargets =
            allDevices.where((d) => d.category == rule.targetCategory).toList();
        for (final target in matchingTargets) {
          try {
            await executeAction(target, rule.targetPower, rule.targetLevel);
            executedLogs.add('${rule.title} → Executed on ${target.name}');
          } catch (_) {}
        }
      }
    }
    return executedLogs;
  }

  void dispose() {
    _bus.close();
  }
}
