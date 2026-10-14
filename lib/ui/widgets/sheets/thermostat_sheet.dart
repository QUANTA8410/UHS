import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/device_model.dart';
import '../../../providers/home_state.dart';

class ThermostatSheet extends StatelessWidget {
  final ThermostatDevice device;

  const ThermostatSheet({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HomeState>();

    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.cyan.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.thermostat_rounded, color: Colors.cyan, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('LG DualCool & Google Nest • ${device.room}', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Switch(
                value: device.isPowered,
                activeThumbColor: Colors.cyan,
                onChanged: (val) => state.togglePower(device.id),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Live / Demo Status Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: device.isDummy ? Colors.amber.shade50 : Colors.cyan.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: device.isDummy ? Colors.amber.shade300 : Colors.cyan.shade300),
            ),
            child: Row(
              children: [
                Icon(
                  device.isDummy ? Icons.science_outlined : Icons.cloud_done_rounded,
                  size: 16,
                  color: device.isDummy ? Colors.orange : Colors.cyan.shade700,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    device.isDummy
                        ? 'Demo Preview Mode • Connect LG ThinQ Token to control real AC'
                        : 'Live LG ThinQ Cloud • Device ID: ${device.cloudDeviceId ?? device.id}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: device.isDummy ? Colors.brown : Colors.cyan.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Google Home Style Dial Card
          Center(
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.cyan.shade100.withValues(alpha: 0.4), Colors.cyan.shade50.withValues(alpha: 0.1)],
                ),
                border: Border.all(color: Colors.cyan.shade300, width: 3),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Indoor ${device.currentTempC.toStringAsFixed(1)}°C',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${device.targetTempC.toStringAsFixed(1)}°',
                    style: const TextStyle(fontSize: 46, fontWeight: FontWeight.bold, color: Colors.cyan),
                  ),
                  Text(
                    device.mode.name.toUpperCase(),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Stepper Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                iconSize: 22,
                icon: const Icon(Icons.remove),
                onPressed: () => state.updateThermostat(device.id, targetTemp: device.targetTempC - 0.5),
              ),
              const SizedBox(width: 32),
              IconButton.filledTonal(
                iconSize: 22,
                icon: const Icon(Icons.add),
                onPressed: () => state.updateThermostat(device.id, targetTemp: device.targetTempC + 0.5),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Thermostat Modes
          SegmentedButton<ThermostatMode>(
            segments: const [
              ButtonSegment(value: ThermostatMode.cool, label: Text('Cool')),
              ButtonSegment(value: ThermostatMode.heat, label: Text('Heat')),
              ButtonSegment(value: ThermostatMode.auto, label: Text('Auto')),
              ButtonSegment(value: ThermostatMode.eco, label: Text('Eco')),
            ],
            selected: {device.mode},
            onSelectionChanged: (set) => state.updateThermostat(device.id, mode: set.first),
          ),
          const SizedBox(height: 16),

          // LG DualCool Technologies (Jet Cool, Plasmaster Ionizer, Dual Vane Swing)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              FilterChip(
                avatar: const Icon(Icons.flash_on_rounded, size: 16, color: Colors.amber),
                label: const Text('LG Jet Cool (Turbo)'),
                selected: device.jetCoolActive,
                onSelected: (val) => state.updateLgAc(device.id, jetCool: val),
              ),
              FilterChip(
                avatar: const Icon(Icons.air_rounded, size: 16, color: Colors.teal),
                label: const Text('Plasmaster™ Ionizer'),
                selected: device.airCleanActive,
                onSelected: (val) => state.updateLgAc(device.id, airClean: val),
              ),
              FilterChip(
                avatar: const Icon(Icons.sync_alt_rounded, size: 16, color: Colors.blue),
                label: const Text('Dual Vane 4-Way Swing'),
                selected: device.vaneSwingActive,
                onSelected: (val) => state.updateLgAc(device.id, vaneSwing: val),
              ),
              Chip(
                avatar: const Icon(Icons.water_drop_outlined, size: 16, color: Colors.cyan),
                label: Text('${device.humidityPercent}% Humidity'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Fan Speed Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Fan Speed:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Auto', label: Text('Auto')),
                  ButtonSegment(value: 'Low', label: Text('Low')),
                  ButtonSegment(value: 'Med', label: Text('Med')),
                  ButtonSegment(value: 'High', label: Text('High')),
                ],
                selected: {device.fanSpeed},
                onSelectionChanged: (set) => state.updateLgAc(device.id, fanSpeed: set.first),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // LG AC Health & Filter Telemetry
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.cyan.shade50.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.cyan.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('Cleanable Filter', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Text('${device.filterLifePercent}% Life', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                  ],
                ),
                Container(height: 24, width: 1, color: Colors.grey.shade300),
                Column(
                  children: [
                    const Text('Today Consumption', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Text('${device.energyConsumedKwh.toStringAsFixed(1)} kWh', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.cyan)),
                  ],
                ),
                Container(height: 24, width: 1, color: Colors.grey.shade300),
                Column(
                  children: [
                    const Text('Refrigerant (R32)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 2),
                    const Text('Optimal (OK)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Remove AC Button
          Center(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Remove AC from Home'),
              onPressed: () {
                state.removeDevice(device.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Removed ${device.name}')),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}
}
