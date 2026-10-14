import 'package:flutter/material.dart';
import '../../providers/home_state.dart';
import '../../models/device_model.dart';

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
  /// Interprets user natural language prompts and executes home automation tools
  CopilotMessage processPrompt(String prompt, HomeState state) {
    final lower = prompt.toLowerCase();
    final List<CopilotAction> actions = [];
    String replyText = '';

    // Routine: Movie Night
    if (lower.contains('movie') || lower.contains('cinema')) {
      // 1. OnePlus TV: turn on, launch OxygenPlay
      final tv = state.allDevices.whereType<TvDevice>().firstOrNull;
      if (tv != null) {
        state.updateTv(tv.id, app: 'OxygenPlay', volume: 20, pictureMode: 'Cinema');
        if (!tv.isPowered) state.togglePower(tv.id);
        actions.add(CopilotAction(
          toolName: 'oneplus_tv_control',
          targetDevice: tv.name,
          parameters: {'app': 'OxygenPlay', 'pictureMode': 'Cinema', 'volume': 20},
          humanDescription: 'Turned on OnePlus TV 55 to OxygenPlay in Cinema mode (Vol 20)',
        ));
      }

      // 2. Wipro Lights: dim to 20% in warm amber/relax
      for (final light in state.allDevices.whereType<LightDevice>()) {
        state.updateWiproBulb(
          light.id,
          brightness: 0.20,
          color: const Color(0xFFFFB74D),
          colorTempKelvin: 2700,
          scene: 'Relax',
        );
        actions.add(CopilotAction(
          toolName: 'wipro_light_dim',
          targetDevice: light.name,
          parameters: {'brightness': 0.20, 'scene': 'Relax'},
          humanDescription: 'Dimmed ${light.name} to 20% Warm Relax glow',
        ));
      }

      // 3. LG AC: set quiet cool 22°C
      final ac = state.allDevices.whereType<ThermostatDevice>().firstOrNull;
      if (ac != null) {
        state.updateLgAc(ac.id, targetTemp: 22.0, fanSpeed: 'Low');
        actions.add(CopilotAction(
          toolName: 'lg_ac_climate',
          targetDevice: ac.name,
          parameters: {'targetTemp': 22.0, 'fanSpeed': 'Low'},
          humanDescription: 'Set LG DualCool AC to 22.0°C with quiet Low fan',
        ));
      }

      replyText = '🎬 Movie Night activated! Configured OnePlus TV to OxygenPlay in Cinema mode, dimmed Wipro bulbs to 20% warm glow, and set LG AC to 22°C.';
    }

    // Routine: Bedtime / Goodnight
    else if (lower.contains('bedtime') || lower.contains('goodnight') || lower.contains('sleep')) {
      // Turn off TV
      final tv = state.allDevices.whereType<TvDevice>().firstOrNull;
      if (tv != null && tv.isPowered) {
        state.togglePower(tv.id);
        actions.add(CopilotAction(
          toolName: 'power_off',
          targetDevice: tv.name,
          parameters: {'power': false},
          humanDescription: 'Powered off OnePlus TV',
        ));
      }

      // Turn off living room lights, bedroom light to Night Light 10%
      for (final light in state.allDevices.whereType<LightDevice>()) {
        if (light.room == 'Living Room') {
          if (light.isPowered) state.togglePower(light.id);
          actions.add(CopilotAction(
            toolName: 'power_off',
            targetDevice: light.name,
            parameters: {'power': false},
            humanDescription: 'Turned off ${light.name}',
          ));
        } else {
          state.updateWiproBulb(
            light.id,
            brightness: 0.10,
            colorTempKelvin: 2700,
            scene: 'Night Light',
          );
          actions.add(CopilotAction(
            toolName: 'night_mode',
            targetDevice: light.name,
            parameters: {'brightness': 0.10, 'scene': 'Night Light'},
            humanDescription: 'Set ${light.name} to 10% Night Light',
          ));
        }
      }

      // Set AC to 24°C Eco
      final ac = state.allDevices.whereType<ThermostatDevice>().firstOrNull;
      if (ac != null) {
        state.updateLgAc(ac.id, targetTemp: 24.0, mode: ThermostatMode.eco, fanSpeed: 'Auto');
        actions.add(CopilotAction(
          toolName: 'lg_ac_eco',
          targetDevice: ac.name,
          parameters: {'targetTemp': 24.0, 'mode': 'eco'},
          humanDescription: 'Set LG AC to 24.0°C Eco night mode',
        ));
      }

      replyText = '🌙 Goodnight routine complete. Powered down Living Room lights & OnePlus TV, configured bedroom night light, and engaged LG DualCool Eco mode at 24°C.';
    }

    // Washer Status & Recipe query
    else if (lower.contains('washer') ||
        lower.contains('washing') ||
        lower.contains('laundry') ||
        lower.contains('wash') ||
        lower.contains('jeans') ||
        lower.contains('denim')) {
      final washer = state.allDevices.whereType<WasherDevice>().firstOrNull;
      if (washer != null) {
        if (lower.contains('jeans') || lower.contains('denim')) {
          state.updateSamsungWasher(
            washer.id,
            cycle: 'Denim & Colors',
            ecoBubble: true,
            waterTemp: 30,
            spinSpeed: 'Med',
          );
          actions.add(CopilotAction(
            toolName: 'smartthings_recipe',
            targetDevice: washer.name,
            parameters: {'cycle': 'Denim & Colors', 'ecoBubble': true},
            humanDescription: 'Applied Samsung EcoBubble™ Denim & Colors recipe',
          ));
          replyText = '👖 Applied Samsung Laundry Recipe for Jeans! Cold-water EcoBubble™ engaged at 30°C to protect fabric fibers and dye.';
        } else if (lower.contains('gym') || lower.contains('workout') || lower.contains('activewear')) {
          state.updateSamsungWasher(
            washer.id,
            cycle: 'Activewear SuperSpeed',
            superSpeed: true,
            waterTemp: 30,
          );
          actions.add(CopilotAction(
            toolName: 'smartthings_recipe',
            targetDevice: washer.name,
            parameters: {'cycle': 'Activewear SuperSpeed'},
            humanDescription: 'Applied Samsung SuperSpeed 39 Activewear cycle',
          ));
          replyText = '🏃 Applied Samsung SuperSpeed Activewear wash! Q-Bubble spray will sanitize synthetic workout wear in 39 minutes.';
        } else {
          replyText = '🧺 Samsung AI Ecobubble™ Washer is currently ${washer.isPowered ? "Running (${washer.remainingMinutes} min left in ${washer.selectedCycle})" : "Ready"}. Auto Dispenser: Detergent at ${washer.detergentLevelPercent}%, Softener at ${washer.softenerLevelPercent}%. EcoBubble™ is active.';
        }
      } else {
        replyText = 'No washing machine found in home network.';
      }
    }

    // LG AC Controls
    else if (lower.contains('ac') ||
        lower.contains('air conditioner') ||
        lower.contains('cooling') ||
        lower.contains('jet cool') ||
        lower.contains('cool') ||
        lower.contains('hot') ||
        lower.contains('temp')) {
      final ac = state.allDevices.whereType<ThermostatDevice>().firstOrNull;
      if (ac != null) {
        if (lower.contains('jet cool') || lower.contains('turbo') || lower.contains('fast cool')) {
          state.updateLgAc(ac.id, jetCool: true, targetTemp: 18.0);
          actions.add(CopilotAction(
            toolName: 'lg_jet_cool',
            targetDevice: ac.name,
            parameters: {'jetCool': true, 'targetTemp': 18.0},
            humanDescription: 'Triggered LG Jet Cool 30-minute high-power cooling',
          ));
          replyText = '❄️ LG Jet Cool activated! DualCool compressor running at peak frequency to cool room rapidly to 18°C.';
        } else if (lower.contains('ionizer') || lower.contains('purif')) {
          state.updateLgAc(ac.id, airClean: !ac.airCleanActive);
          actions.add(CopilotAction(
            toolName: 'lg_plasmaster_ionizer',
            targetDevice: ac.name,
            parameters: {'airClean': !ac.airCleanActive},
            humanDescription: 'Toggled LG Plasmaster™ Ionizer+ air purification',
          ));
          replyText = '🍃 LG Plasmaster™ Ionizer+ is now active, sterilizing indoor air and neutralizing fine allergens.';
        } else {
          // Parse temperature request like "22" or "20"
          final match = RegExp(r'\b([1-2][0-9])\b').firstMatch(lower);
          if (match != null) {
            final double t = double.parse(match.group(1)!);
            state.updateLgAc(ac.id, targetTemp: t);
            actions.add(CopilotAction(
              toolName: 'set_ac_temperature',
              targetDevice: ac.name,
              parameters: {'targetTemp': t},
              humanDescription: 'Adjusted LG DualCool AC to $t°C',
            ));
            replyText = '🌡️ Adjusted LG DualCool AC target temperature to $t°C.';
          } else {
            replyText = '🌡️ LG DualCool AC is ${ac.isPowered ? "cooling to ${ac.targetTempC}°C (Indoor: ${ac.currentTempC}°C, Humidity: ${ac.humidityPercent}%)" : "powered off"}.';
          }
        }
      }
    }

    // Wipro Lights Controls
    else if (lower.contains('light') || lower.contains('bulb') || lower.contains('color')) {
      final lights = state.allDevices.whereType<LightDevice>().toList();
      if (lower.contains('party')) {
        for (final l in lights) {
          state.updateWiproBulb(l.id, scene: 'Party Mode', color: const Color(0xFFE91E63), brightness: 1.0, musicSync: true);
        }
        actions.add(CopilotAction(
          toolName: 'wipro_party_mode',
          targetDevice: 'All Wipro Bulbs',
          parameters: {'scene': 'Party Mode', 'musicSync': true},
          humanDescription: 'Enabled Wipro 16M Neon Party color cycle with Music Sync',
        ));
        replyText = '🎉 Party Mode engaged on all Wipro Smart Bulbs with vibrant neon hues and Music Sync!';
      } else if (lower.contains('read')) {
        for (final l in lights) {
          state.updateWiproBulb(l.id, scene: 'Reading', colorTempKelvin: 4000, brightness: 0.90);
        }
        actions.add(CopilotAction(
          toolName: 'wipro_cct_tune',
          targetDevice: 'All Wipro Bulbs',
          parameters: {'kelvin': 4000, 'brightness': 0.90},
          humanDescription: 'Adjusted Wipro Bulbs to 4000K Neutral White reading light',
        ));
        replyText = '📖 Wipro Smart Bulbs tuned to 4000K Neutral White at 90% brightness for optimal eye reading comfort.';
      } else {
        replyText = '💡 Controlled ${lights.length} Wipro Smart Bulbs. You can set them to Reading, Relax, Party, or specify color temperatures from 2700K to 6500K.';
      }
    }

    // Energy & Tariff query
    else if (lower.contains('energy') || lower.contains('power') || lower.contains('bill') || lower.contains('tariff')) {
      final prediction = state.energyPrediction;
      replyText = '⚡ Current house draw is ${state.totalPowerWatts.toStringAsFixed(0)} W (\$${prediction.hourlyCostNow.toStringAsFixed(3)}/hr). Currently on ${prediction.isCurrentlyPeakHour ? "PEAK TARIFF (\$0.38/kWh)" : "OFF-PEAK TARIFF (\$0.14/kWh)"}. SmartThings AI Energy Mode is estimated to save \$${prediction.monthlySavingsWithAiMode.toStringAsFixed(2)}/month and avoid ${prediction.carbonAvoidedKgPerMonth.toStringAsFixed(1)} kg CO₂.';
    }

    // Default Fallback
    else {
      replyText = '🤖 Antigravity Home Copilot: I can coordinate your Samsung Ecobubble Washer, LG DualCool AC, Wipro Smart Bulbs, and OnePlus TV. Try asking: "Movie night scene", "Set AC to 21 degrees", "Recommend cycle for jeans", or "Check energy draw".';
    }

    return CopilotMessage(
      text: replyText,
      isUser: false,
      executedActions: actions,
    );
  }
}
