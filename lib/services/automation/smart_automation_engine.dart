import 'dart:async';
import '../real_iot_controller.dart';

enum TriggerKind {
  timeSchedule,   // e.g. "22:30" on selected weekdays
  solarEvent,     // "sunset" or "sunrise"
  deviceState,    // e.g. OnePlus TV turns ON or Samsung Washer turns OFF
  thresholdAbove, // e.g. AC temp > 26
  thresholdBelow, // e.g. Brightness < 30
  wifiPresence,   // "arrive_home" or "leave_home"
}

enum PreconditionKind {
  none,
  onlyAtNight,    // Between 18:30 and 06:00
  onlyDaytime,    // Between 06:00 and 18:30
  onlyWhenHome,   // Requires home Wi-Fi BSSID connected
  onlyWeekdays,   // Mon - Fri (1..5)
  onlyWeekends,   // Sat - Sun (6..7)
  deviceMustBeOn, // Specified device must be ON
  deviceMustBeOff,// Specified device must be OFF
}

class SmartTrigger {
  final TriggerKind kind;
  final String value; // "22:30", "sunset", "sunrise", "on", "off", "arrive_home", "leave_home", "26"
  final String? sourceDeviceId;
  final String? sourceDeviceName;
  final List<int> weekdays; // 1 = Mon ... 7 = Sun (default: all)

  SmartTrigger({
    required this.kind,
    required this.value,
    this.sourceDeviceId,
    this.sourceDeviceName,
    this.weekdays = const [1, 2, 3, 4, 5, 6, 7],
  });

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'value': value,
        'sourceDeviceId': sourceDeviceId,
        'sourceDeviceName': sourceDeviceName,
        'weekdays': weekdays,
      };

  factory SmartTrigger.fromJson(Map<String, dynamic> json) => SmartTrigger(
        kind: TriggerKind.values.firstWhere(
          (k) => k.name == json['kind'],
          orElse: () => TriggerKind.timeSchedule,
        ),
        value: json['value'] as String? ?? '22:00',
        sourceDeviceId: json['sourceDeviceId'] as String?,
        sourceDeviceName: json['sourceDeviceName'] as String?,
        weekdays: List<int>.from(json['weekdays'] ?? [1, 2, 3, 4, 5, 6, 7]),
      );
}

class SmartPrecondition {
  final PreconditionKind kind;
  final String? checkDeviceId;
  final String? checkDeviceName;

  SmartPrecondition({
    required this.kind,
    this.checkDeviceId,
    this.checkDeviceName,
  });

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'checkDeviceId': checkDeviceId,
        'checkDeviceName': checkDeviceName,
      };

  factory SmartPrecondition.fromJson(Map<String, dynamic> json) => SmartPrecondition(
        kind: PreconditionKind.values.firstWhere(
          (k) => k.name == json['kind'],
          orElse: () => PreconditionKind.none,
        ),
        checkDeviceId: json['checkDeviceId'] as String?,
        checkDeviceName: json['checkDeviceName'] as String?,
      );

  String get label {
    switch (kind) {
      case PreconditionKind.none:
        return 'Always Allow';
      case PreconditionKind.onlyAtNight:
        return 'Only at Night (18:30 - 06:00)';
      case PreconditionKind.onlyDaytime:
        return 'Only during Daytime (06:00 - 18:30)';
      case PreconditionKind.onlyWhenHome:
        return 'Only When at Home (Wi-Fi)';
      case PreconditionKind.onlyWeekdays:
        return 'Only on Weekdays (Mon-Fri)';
      case PreconditionKind.onlyWeekends:
        return 'Only on Weekends (Sat-Sun)';
      case PreconditionKind.deviceMustBeOn:
        return '${checkDeviceName ?? "Device"} must be ON';
      case PreconditionKind.deviceMustBeOff:
        return '${checkDeviceName ?? "Device"} must be OFF';
    }
  }
}

class SmartActionStep {
  final String targetDeviceId;
  final String targetDeviceName;
  final bool turnOn;
  final double? targetLevel; // Brightness % or Temp °C
  final int delaySecondsBefore; // e.g., Wait 5s or 60s before running this step

  SmartActionStep({
    required this.targetDeviceId,
    required this.targetDeviceName,
    required this.turnOn,
    this.targetLevel,
    this.delaySecondsBefore = 0,
  });

  Map<String, dynamic> toJson() => {
        'targetDeviceId': targetDeviceId,
        'targetDeviceName': targetDeviceName,
        'turnOn': turnOn,
        'targetLevel': targetLevel,
        'delaySecondsBefore': delaySecondsBefore,
      };

  factory SmartActionStep.fromJson(Map<String, dynamic> json) => SmartActionStep(
        targetDeviceId: json['targetDeviceId'] as String? ?? '',
        targetDeviceName: json['targetDeviceName'] as String? ?? 'Device',
        turnOn: json['turnOn'] as bool? ?? true,
        targetLevel: (json['targetLevel'] as num?)?.toDouble(),
        delaySecondsBefore: (json['delaySecondsBefore'] as num?)?.toInt() ?? 0,
      );

  String get summary {
    final act = turnOn ? 'Turn ON' : 'Turn OFF';
    final lvl = targetLevel != null ? ' ($targetLevel)' : '';
    final dly = delaySecondsBefore > 0 ? ' [Wait ${delaySecondsBefore}s] ' : '';
    return '$dly$act $targetDeviceName$lvl';
  }
}

class MultiConditionAutomationRule {
  final String id;
  String name;
  bool isEnabled;
  SmartTrigger trigger;
  List<SmartPrecondition> preconditions;
  List<SmartActionStep> actions;
  DateTime? lastTriggeredAt;
  int executionCount;

  MultiConditionAutomationRule({
    required this.id,
    required this.name,
    this.isEnabled = true,
    required this.trigger,
    this.preconditions = const [],
    required this.actions,
    this.lastTriggeredAt,
    this.executionCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isEnabled': isEnabled,
        'trigger': trigger.toJson(),
        'preconditions': preconditions.map((p) => p.toJson()).toList(),
        'actions': actions.map((a) => a.toJson()).toList(),
        'lastTriggeredAt': lastTriggeredAt?.toIso8601String(),
        'executionCount': executionCount,
      };

  factory MultiConditionAutomationRule.fromJson(Map<String, dynamic> json) =>
      MultiConditionAutomationRule(
        id: json['id'] as String,
        name: json['name'] as String,
        isEnabled: json['isEnabled'] as bool? ?? true,
        trigger: SmartTrigger.fromJson(Map<String, dynamic>.from(json['trigger'] ?? {})),
        preconditions: (json['preconditions'] as List<dynamic>?)
                ?.map((p) => SmartPrecondition.fromJson(Map<String, dynamic>.from(p)))
                .toList() ??
            [],
        actions: (json['actions'] as List<dynamic>?)
                ?.map((a) => SmartActionStep.fromJson(Map<String, dynamic>.from(a)))
                .toList() ??
            [],
        lastTriggeredAt: json['lastTriggeredAt'] != null
            ? DateTime.tryParse(json['lastTriggeredAt'] as String)
            : null,
        executionCount: (json['executionCount'] as num?)?.toInt() ?? 0,
      );
}

class AutomationExecutionLog {
  final String id;
  final String ruleId;
  final String ruleName;
  final DateTime timestamp;
  final String summary;
  final bool success;
  final String? errorMessage;

  AutomationExecutionLog({
    required this.id,
    required this.ruleId,
    required this.ruleName,
    required this.timestamp,
    required this.summary,
    required this.success,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'ruleId': ruleId,
        'ruleName': ruleName,
        'timestamp': timestamp.toIso8601String(),
        'summary': summary,
        'success': success,
        'errorMessage': errorMessage,
      };

  factory AutomationExecutionLog.fromJson(Map<String, dynamic> json) =>
      AutomationExecutionLog(
        id: json['id'] as String,
        ruleId: json['ruleId'] as String? ?? '',
        ruleName: json['ruleName'] as String? ?? 'Automation',
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
            : DateTime.now(),
        summary: json['summary'] as String? ?? '',
        success: json['success'] as bool? ?? true,
        errorMessage: json['errorMessage'] as String?,
      );
}

class SmartAutomationEngine {
  final List<AutomationExecutionLog> executionLogs = [];

  // Approximate solar times for local evaluation (can be customized or geolocated)
  static const int sunsetHour = 18;
  static const int sunsetMinute = 30;
  static const int sunriseHour = 6;
  static const int sunriseMinute = 0;

  /// Evaluates guard preconditions for a rule.
  bool evaluatePreconditions(
    MultiConditionAutomationRule rule, {
    required bool isUserAtHome,
    required List<RealSmartDevice> devices,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();

    for (final cond in rule.preconditions) {
      switch (cond.kind) {
        case PreconditionKind.none:
          break;

        case PreconditionKind.onlyAtNight:
          final hour = current.hour + (current.minute / 60.0);
          final isNight = hour >= 18.5 || hour < 6.0;
          if (!isNight) return false;
          break;

        case PreconditionKind.onlyDaytime:
          final hour = current.hour + (current.minute / 60.0);
          final isDay = hour >= 6.0 && hour < 18.5;
          if (!isDay) return false;
          break;

        case PreconditionKind.onlyWhenHome:
          if (!isUserAtHome) return false;
          break;

        case PreconditionKind.onlyWeekdays:
          if (current.weekday > 5) return false; // Mon=1 ... Fri=5
          break;

        case PreconditionKind.onlyWeekends:
          if (current.weekday < 6) return false; // Sat=6, Sun=7
          break;

        case PreconditionKind.deviceMustBeOn:
          if (cond.checkDeviceId != null) {
            final dev = devices.firstWhere(
              (d) => d.id == cond.checkDeviceId,
              orElse: () => RealSmartDevice(
                id: '',
                name: '',
                room: '',
                category: '',
                protocol: ConnectionProtocol.smartThingsCloud,
                credentials: {},
                isOn: false,
              ),
            );
            if (!dev.isOn) return false;
          }
          break;

        case PreconditionKind.deviceMustBeOff:
          if (cond.checkDeviceId != null) {
            final dev = devices.firstWhere(
              (d) => d.id == cond.checkDeviceId,
              orElse: () => RealSmartDevice(
                id: '',
                name: '',
                room: '',
                category: '',
                protocol: ConnectionProtocol.smartThingsCloud,
                credentials: {},
                isOn: false,
              ),
            );
            if (dev.isOn) return false;
          }
          break;
      }
    }
    return true;
  }

  /// Checks if a timeSchedule rule matches the current time and weekday.
  bool shouldTriggerTime(MultiConditionAutomationRule rule, DateTime now) {
    if (rule.trigger.kind != TriggerKind.timeSchedule) return false;
    if (!rule.trigger.weekdays.contains(now.weekday)) return false;

    final parts = rule.trigger.value.split(':');
    if (parts.length != 2) return false;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return false;

    final matches = now.hour == h && now.minute == m;
    if (!matches) return false;

    // Prevent re-triggering within the same minute
    if (rule.lastTriggeredAt != null) {
      final diff = now.difference(rule.lastTriggeredAt!);
      if (diff.inSeconds < 65) return false;
    }
    return true;
  }

  /// Checks if a solarEvent rule matches the current approximate solar time.
  bool shouldTriggerSolar(MultiConditionAutomationRule rule, DateTime now) {
    if (rule.trigger.kind != TriggerKind.solarEvent) return false;

    final isSunset = rule.trigger.value.toLowerCase() == 'sunset';
    final targetH = isSunset ? sunsetHour : sunriseHour;
    final targetM = isSunset ? sunsetMinute : sunriseMinute;

    final matches = now.hour == targetH && now.minute == targetM;
    if (!matches) return false;

    if (rule.lastTriggeredAt != null) {
      final diff = now.difference(rule.lastTriggeredAt!);
      if (diff.inSeconds < 65) return false;
    }
    return true;
  }

  /// Checks if a device state change triggers the rule.
  bool shouldTriggerDeviceState(
    MultiConditionAutomationRule rule,
    RealSmartDevice device,
    String stateChange, // "on", "off", "finish", "stop"
  ) {
    if (rule.trigger.kind != TriggerKind.deviceState) return false;
    if (rule.trigger.sourceDeviceId != null &&
        rule.trigger.sourceDeviceId != device.id) {
      return false;
    }
    return rule.trigger.value.toLowerCase() == stateChange.toLowerCase();
  }

  /// Checks if threshold triggers the rule.
  bool shouldTriggerThreshold(
    MultiConditionAutomationRule rule,
    RealSmartDevice device,
  ) {
    if (rule.trigger.sourceDeviceId != null &&
        rule.trigger.sourceDeviceId != device.id) {
      return false;
    }
    final targetVal = double.tryParse(rule.trigger.value);
    if (targetVal == null) return false;

    if (rule.trigger.kind == TriggerKind.thresholdAbove) {
      return device.primaryValue > targetVal;
    } else if (rule.trigger.kind == TriggerKind.thresholdBelow) {
      return device.primaryValue < targetVal;
    }
    return false;
  }

  /// Checks if Wi-Fi presence transition triggers the rule.
  bool shouldTriggerPresence(
    MultiConditionAutomationRule rule,
    bool isArriving,
  ) {
    if (rule.trigger.kind != TriggerKind.wifiPresence) return false;
    final expected = isArriving ? 'arrive_home' : 'leave_home';
    return rule.trigger.value == expected;
  }

  /// Executes multi-step actions sequentially on real hardware.
  Future<bool> executeSequence(
    MultiConditionAutomationRule rule,
    RealIotController controller,
    List<RealSmartDevice> availableDevices, {
    Function(AutomationExecutionLog)? onLog,
  }) async {
    final startTime = DateTime.now();
    final executedSteps = <String>[];
    String? failureMsg;

    try {
      for (final step in rule.actions) {
        if (step.delaySecondsBefore > 0) {
          await Future.delayed(Duration(seconds: step.delaySecondsBefore));
        }

        final targetDevice = availableDevices.firstWhere(
          (d) => d.id == step.targetDeviceId,
          orElse: () => throw Exception('Device "${step.targetDeviceName}" is not linked.'),
        );

        // Execute power command
        await controller.setPower(targetDevice, step.turnOn);

        // Execute level command (brightness or temperature) if specified
        if (step.targetLevel != null && step.turnOn) {
          await controller.setPrimaryLevel(targetDevice, step.targetLevel!);
        }

        executedSteps.add(step.summary);
      }

      rule.lastTriggeredAt = startTime;
      rule.executionCount++;

      final log = AutomationExecutionLog(
        id: 'log_${DateTime.now().millisecondsSinceEpoch}',
        ruleId: rule.id,
        ruleName: rule.name,
        timestamp: startTime,
        summary: executedSteps.join(' -> '),
        success: true,
      );
      _addLog(log);
      onLog?.call(log);
      return true;
    } catch (e) {
      failureMsg = e.toString().replaceAll('Exception: ', '');
      final log = AutomationExecutionLog(
        id: 'log_${DateTime.now().millisecondsSinceEpoch}',
        ruleId: rule.id,
        ruleName: rule.name,
        timestamp: startTime,
        summary: executedSteps.isNotEmpty
            ? '${executedSteps.join(" -> ")} [Failed: $failureMsg]'
            : 'Execution failed: $failureMsg',
        success: false,
        errorMessage: failureMsg,
      );
      _addLog(log);
      onLog?.call(log);
      return false;
    }
  }

  void _addLog(AutomationExecutionLog log) {
    executionLogs.insert(0, log);
    if (executionLogs.length > 100) {
      executionLogs.removeLast();
    }
  }

  /// Natural Language Rule Parser: Turns plain English sentences into working hardware rules!
  ///
  /// Examples:
  /// - "At 11:00 PM turn off Living Room Light and TV"
  /// - "At sunset turn on Porch Light to 80%"
  /// - "When TV turns on, set Light to 20% and wait 5s then turn off AC"
  /// - "When I leave home turn off all lights only on weekdays"
  /// - "At 07:00 AM turn on AC to 24 only when home"
  MultiConditionAutomationRule? parseNaturalLanguageToRule(
    String prompt,
    List<RealSmartDevice> availableDevices,
  ) {
    final lower = prompt.toLowerCase().trim();
    if (lower.isEmpty) return null;

    // 1. Determine Trigger
    SmartTrigger? trigger;
    String ruleName = 'Smart Routine';

    // Solar trigger check
    if (lower.contains('sunset')) {
      trigger = SmartTrigger(kind: TriggerKind.solarEvent, value: 'sunset');
      ruleName = 'Sunset Routine';
    } else if (lower.contains('sunrise')) {
      trigger = SmartTrigger(kind: TriggerKind.solarEvent, value: 'sunrise');
      ruleName = 'Sunrise Routine';
    }
    // Presence trigger check
    else if (lower.contains('leave home') || lower.contains('leaving home') || lower.contains('i leave')) {
      trigger = SmartTrigger(kind: TriggerKind.wifiPresence, value: 'leave_home');
      ruleName = 'Leaving Home Routine';
    } else if (lower.contains('arrive home') || lower.contains('arriving home') || lower.contains('i arrive') || lower.contains('come home')) {
      trigger = SmartTrigger(kind: TriggerKind.wifiPresence, value: 'arrive_home');
      ruleName = 'Welcome Home Routine';
    }
    // Time schedule trigger check (e.g., "11:00 pm", "7:30 am", "22:00", "7am", "11pm")
    else {
      final timeRegex = RegExp(r'\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b');
      final match = timeRegex.firstMatch(lower);
      if (match != null) {
        int hour = int.parse(match.group(1)!);
        int minute = match.group(2) != null ? int.parse(match.group(2)!) : 0;
        final meridiem = match.group(3);

        if (meridiem == 'pm' && hour < 12) hour += 12;
        if (meridiem == 'am' && hour == 12) hour = 0;

        final timeStr = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
        trigger = SmartTrigger(kind: TriggerKind.timeSchedule, value: timeStr);
        ruleName = 'Schedule at $timeStr';
      }
    }

    // Device state trigger check if not time/presence/solar (e.g. "when tv turns on", "when washer stops")
    if (trigger == null && lower.contains('when')) {
      for (final d in availableDevices) {
        if (lower.contains(d.name.toLowerCase()) || lower.contains(d.category.toLowerCase())) {
          final isTurnOn = lower.contains('turns on') || lower.contains('is on');
          trigger = SmartTrigger(
            kind: TriggerKind.deviceState,
            value: isTurnOn ? 'on' : 'off',
            sourceDeviceId: d.id,
            sourceDeviceName: d.name,
          );
          ruleName = 'When ${d.name} turns ${isTurnOn ? "ON" : "OFF"}';
          break;
        }
      }
    }

    // Default trigger fallback to 22:00 if no trigger detected
    trigger ??= SmartTrigger(kind: TriggerKind.timeSchedule, value: '22:00');

    // 2. Determine Preconditions
    final List<SmartPrecondition> preconditions = [];
    if (lower.contains('at night') || lower.contains('only at night')) {
      preconditions.add(SmartPrecondition(kind: PreconditionKind.onlyAtNight));
    }
    if (lower.contains('daytime') || lower.contains('during the day')) {
      preconditions.add(SmartPrecondition(kind: PreconditionKind.onlyDaytime));
    }
    if (lower.contains('when home') || lower.contains('only when home') || lower.contains('if at home')) {
      preconditions.add(SmartPrecondition(kind: PreconditionKind.onlyWhenHome));
    }
    if (lower.contains('weekdays') || lower.contains('weekday')) {
      preconditions.add(SmartPrecondition(kind: PreconditionKind.onlyWeekdays));
    }
    if (lower.contains('weekends') || lower.contains('weekend')) {
      preconditions.add(SmartPrecondition(kind: PreconditionKind.onlyWeekends));
    }

    // 3. Determine Actions
    final List<SmartActionStep> actions = [];

    // Check for delay (e.g., "wait 5s", "wait 10 seconds")
    int detectedDelay = 0;
    final delayMatch = RegExp(r'wait\s+(\d+)\s*(?:s|sec|seconds)?').firstMatch(lower);
    if (delayMatch != null) {
      detectedDelay = int.tryParse(delayMatch.group(1)!) ?? 0;
    }

    // Check for target level (e.g., "to 80%", "to 24 degrees", "to 24")
    double? detectedLevel;
    final levelMatch = RegExp(r'(?:to|at|set)\s+(\d{1,3})\s*(?:%|°c|deg|degrees)?').firstMatch(lower);
    if (levelMatch != null) {
      detectedLevel = double.tryParse(levelMatch.group(1)!);
    }

    final isOffCommand = lower.contains('turn off') || lower.contains('switch off') || lower.contains('shut down');

    // "Turn off all lights" or "turn on all lights"
    if (lower.contains('all lights') || lower.contains('everything')) {
      for (final d in availableDevices) {
        if (d.category == 'light' || lower.contains('everything')) {
          actions.add(
            SmartActionStep(
              targetDeviceId: d.id,
              targetDeviceName: d.name,
              turnOn: !isOffCommand,
              targetLevel: detectedLevel,
              delaySecondsBefore: actions.isEmpty ? 0 : detectedDelay,
            ),
          );
        }
      }
    } else {
      // Match specific devices by name or category
      for (final d in availableDevices) {
        final matchesName = lower.contains(d.name.toLowerCase());
        final matchesCat = lower.contains(d.category.toLowerCase()) ||
            (d.category == 'light' && (lower.contains('bulb') || lower.contains('lamp'))) ||
            (d.category == 'ac' && lower.contains('ac')) ||
            (d.category == 'tv' && lower.contains('tv')) ||
            (d.category == 'washer' && lower.contains('washer'));

        if (matchesName || matchesCat) {
          actions.add(
            SmartActionStep(
              targetDeviceId: d.id,
              targetDeviceName: d.name,
              turnOn: !isOffCommand,
              targetLevel: detectedLevel,
              delaySecondsBefore: actions.isEmpty ? 0 : detectedDelay,
            ),
          );
        }
      }
    }

    // Fallback: If no available devices matched, pick the first available device
    if (actions.isEmpty && availableDevices.isNotEmpty) {
      final first = availableDevices.first;
      actions.add(
        SmartActionStep(
          targetDeviceId: first.id,
          targetDeviceName: first.name,
          turnOn: !isOffCommand,
          targetLevel: detectedLevel,
          delaySecondsBefore: 0,
        ),
      );
    }

    if (actions.isEmpty) return null;

    final ruleId = 'rule_${DateTime.now().millisecondsSinceEpoch}';
    return MultiConditionAutomationRule(
      id: ruleId,
      name: ruleName,
      isEnabled: true,
      trigger: trigger,
      preconditions: preconditions,
      actions: actions,
    );
  }
}
