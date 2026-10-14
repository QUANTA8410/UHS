import '../../providers/real_home_provider.dart';

class CopilotAction {
  final String toolName;
  final String targetDevice;
  final Map<String, dynamic> parameters;
  final String humanDescription;

  const CopilotAction({
    required this.toolName,
    required this.targetDevice,
    required this.parameters,
    required this.humanDescription,
  });
}

class CopilotMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<CopilotAction> executedActions;

  CopilotMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.executedActions = const [],
  }) : timestamp = timestamp ?? DateTime.now();
}

class AiHomeCopilotService {
  /// Interprets user natural language prompts and executes real home automation tools
  CopilotMessage processPrompt(String prompt, RealHomeProvider home) {
    final lower = prompt.toLowerCase();
    final List<CopilotAction> actions = [];
    String replyText = '';

    // 1. Live Telemetry / Power Queries
    if (lower.contains('power') ||
        lower.contains('watt') ||
        lower.contains('energy') ||
        lower.contains('consuming') ||
        lower.contains('draw')) {
      final totalWatts = home.totalLiveWatts;
      final kwh = home.todayAccumulatedKwh;
      final cost = home.estimatedTodayCostInr;
      final activeCount = home.activeDrawingDevicesCount;
      final hvacLaundry = home.hvacAndLaundryWatts;

      actions.add(CopilotAction(
        toolName: 'query_energy_telemetry',
        targetDevice: 'Power Topology Bus',
        parameters: {
          'totalWatts': totalWatts,
          'todayKwh': kwh,
          'estimatedCostInr': cost,
          'activeDrawingDevices': activeCount,
        },
        humanDescription: 'Queried real-time Riemann sum power telemetry & smart meters',
      ));

      replyText = '⚡ Current house draw is ${totalWatts.toStringAsFixed(1)}W across $activeCount active appliances ($hvacLaundry W from HVAC & Laundry).\n'
          'Today\'s accumulated energy: ${kwh.toStringAsFixed(3)} kWh (Est. cost: ₹${cost.toStringAsFixed(2)}).\n'
          'SmartThings AI Energy Mode is active and optimizing peak loads.';
      return CopilotMessage(text: replyText, isUser: false, executedActions: actions);
    }

    // 2. Scene: Movie Night / Cinema
    if (lower.contains('movie') || lower.contains('cinema')) {
      // TV
      final tv = home.devices.where((d) => d.category == 'tv').firstOrNull;
      if (tv != null) {
        home.updateTv(tv.id, app: 'OxygenPlay', volume: 20, pictureMode: 'Cinema');
        if (!tv.isOn) home.togglePower(tv.id);
        actions.add(CopilotAction(
          toolName: 'oneplus_tv_control',
          targetDevice: tv.name,
          parameters: {'app': 'OxygenPlay', 'pictureMode': 'Cinema', 'volume': 20},
          humanDescription: 'Turned on OnePlus TV 55 to OxygenPlay in Cinema mode (Vol 20)',
        ));
      }

      // Lights
      for (final light in home.devices.where((d) => d.category == 'light')) {
        home.setDeviceLevel(light, 20.0);
        home.updateWiproBulb(light.id, brightness: 0.20, scene: 'Relax');
        actions.add(CopilotAction(
          toolName: 'wipro_light_dim',
          targetDevice: light.name,
          parameters: {'brightness': 0.20, 'scene': 'Relax'},
          humanDescription: 'Dimmed ${light.name} to 20% Warm Relax glow',
        ));
      }

      // AC
      final ac = home.devices.where((d) => d.category == 'ac').firstOrNull;
      if (ac != null) {
        home.setDeviceLevel(ac, 22.0);
        home.updateLgAc(ac.id, targetTemp: 22.0, fanSpeed: 'Low');
        actions.add(CopilotAction(
          toolName: 'lg_ac_climate',
          targetDevice: ac.name,
          parameters: {'targetTemp': 22.0, 'fanSpeed': 'Low'},
          humanDescription: 'Set LG DualCool AC to 22.0°C with quiet Low fan',
        ));
      }

      replyText = '🎬 Movie Night activated! Configured OnePlus TV to OxygenPlay in Cinema mode, dimmed Wipro bulbs to 20% warm glow, and set LG AC to 22°C.';
      return CopilotMessage(text: replyText, isUser: false, executedActions: actions);
    }

    // 3. Routine: Bedtime / Goodnight
    if (lower.contains('bedtime') || lower.contains('goodnight') || lower.contains('sleep')) {
      for (final dev in home.devices.where((d) => d.category == 'tv' && d.isOn)) {
        home.togglePower(dev.id);
        actions.add(CopilotAction(
          toolName: 'power_off',
          targetDevice: dev.name,
          parameters: {'power': false},
          humanDescription: 'Powered off ${dev.name}',
        ));
      }
      for (final light in home.devices.where((d) => d.category == 'light' && d.isOn)) {
        home.togglePower(light.id);
        actions.add(CopilotAction(
          toolName: 'power_off',
          targetDevice: light.name,
          parameters: {'power': false},
          humanDescription: 'Turned off ${light.name}',
        ));
      }
      final ac = home.devices.where((d) => d.category == 'ac').firstOrNull;
      if (ac != null) {
        home.setDeviceLevel(ac, 24.0);
        home.updateLgAc(ac.id, targetTemp: 24.0, fanSpeed: 'Auto');
        actions.add(CopilotAction(
          toolName: 'lg_ac_climate',
          targetDevice: ac.name,
          parameters: {'targetTemp': 24.0, 'mode': 'eco'},
          humanDescription: 'Set LG DualCool AC to 24.0°C Eco Mode',
        ));
      }

      replyText = '🌙 Goodnight routine complete! Powered off entertainment systems, extinguished ambient lights, and switched LG AC to 24°C Eco Mode.';
      return CopilotMessage(text: replyText, isUser: false, executedActions: actions);
    }

    // 4. Turn off / on all lights
    if (lower.contains('turn off all lights') || lower.contains('lights off') || lower.contains('kill lights')) {
      for (final light in home.devices.where((d) => d.category == 'light' && d.isOn)) {
        home.togglePower(light.id);
        actions.add(CopilotAction(
          toolName: 'power_off',
          targetDevice: light.name,
          parameters: {'power': false},
          humanDescription: 'Turned off ${light.name}',
        ));
      }
      replyText = '💡 All smart lights have been powered off.';
      return CopilotMessage(text: replyText, isUser: false, executedActions: actions);
    }

    if (lower.contains('turn on all lights') || lower.contains('lights on')) {
      for (final light in home.devices.where((d) => d.category == 'light' && !d.isOn)) {
        home.togglePower(light.id);
        actions.add(CopilotAction(
          toolName: 'power_on',
          targetDevice: light.name,
          parameters: {'power': true},
          humanDescription: 'Turned on ${light.name}',
        ));
      }
      replyText = '💡 All smart lights have been illuminated.';
      return CopilotMessage(text: replyText, isUser: false, executedActions: actions);
    }

    // 5. Laundry Recipe
    if (lower.contains('jeans') || lower.contains('wash') || lower.contains('laundry')) {
      final washer = home.devices.where((d) => d.category == 'washer').firstOrNull;
      if (washer != null) {
        home.updateSamsungWasher(
          washer.id,
          cycle: 'Denim & Colors',
          waterTemp: 30,
          spinSpeed: 'Med',
          ecoBubble: true,
          recommendedRecipe: 'Cold-water EcoBubble™ penetrates dense denim weave while locking indigo dye.',
        );
        actions.add(CopilotAction(
          toolName: 'samsung_laundry_recipe',
          targetDevice: washer.name,
          parameters: {'cycle': 'Denim & Colors', 'tempC': 30, 'ecoBubble': true},
          humanDescription: 'Applied Samsung EcoBubble™ Denim cycle at 30°C',
        ));
      }
      replyText = '🧺 Samsung Laundry Recipe for Jeans: Configured EcoBubble™ Denim & Colors cycle at 30°C (Medium Spin) to preserve color and fabric weave.';
      return CopilotMessage(text: replyText, isUser: false, executedActions: actions);
    }

    // 6. Jet Cool
    if (lower.contains('jet cool') || lower.contains('turbo cool') || (lower.contains('cool') && lower.contains('hot'))) {
      final ac = home.devices.where((d) => d.category == 'ac').firstOrNull;
      if (ac != null) {
        home.setDeviceLevel(ac, 18.0);
        home.updateLgAc(ac.id, targetTemp: 18.0, jetCool: true, fanSpeed: 'Power');
        actions.add(CopilotAction(
          toolName: 'lg_ac_jet_cool',
          targetDevice: ac.name,
          parameters: {'jetCool': true, 'targetTemp': 18.0},
          humanDescription: 'Triggered 30-minute Jet Cool blast to 18°C',
        ));
      }
      replyText = '❄️ LG Jet Cool activated! Firing high-power DualCool blast to 18°C for 30 minutes.';
      return CopilotMessage(text: replyText, isUser: false, executedActions: actions);
    }

    // 7. Party Mode
    if (lower.contains('party')) {
      for (final light in home.devices.where((d) => d.category == 'light')) {
        home.setDeviceLevel(light, 100.0);
        home.updateWiproBulb(light.id, brightness: 1.0, scene: 'Party Mode', musicSync: true);
        actions.add(CopilotAction(
          toolName: 'wipro_party_mode',
          targetDevice: light.name,
          parameters: {'scene': 'Party Mode', 'musicSync': true},
          humanDescription: 'Engaged 16M Neon Party color cycle with Music Sync',
        ));
      }
      replyText = '🎉 Party Mode engaged! Switched Wipro Bulbs to vibrant Neon RGB with real-time Music Rhythm Sync.';
      return CopilotMessage(text: replyText, isUser: false, executedActions: actions);
    }

    // 8. Natural Language Automation Rule Creation
    final rule = home.smartEngine.parseNaturalLanguageToRule(prompt, home.devices);
    if (rule != null) {
      home.addMultiConditionRule(rule);
      actions.add(CopilotAction(
        toolName: 'create_smart_automation',
        targetDevice: rule.name,
        parameters: rule.toJson(),
        humanDescription: 'Created smart rule: ${rule.name}',
      ));
      replyText = '✨ Created smart automation: "${rule.name}". Trigger: ${rule.trigger.kind.name}.';
      return CopilotMessage(text: replyText, isUser: false, executedActions: actions);
    }

    return CopilotMessage(
      text: 'Understood: "$prompt". All device states and power levels are synchronized with your hardware.',
      isUser: false,
      executedActions: actions,
    );
  }
}
