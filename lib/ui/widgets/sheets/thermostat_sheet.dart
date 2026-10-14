import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/device_model.dart';
import '../../../providers/home_state.dart';
import '../map3d/isometric_house_3d_widget.dart';

class ThermostatSheet extends StatelessWidget {
  final ThermostatDevice device;

  const ThermostatSheet({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HomeState>();

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Top: Zoomed-in 3D Room Preview with Live 3D Airflow Particles
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: 140,
                decoration: BoxDecoration(
                  color: const Color(0xFF0B132B),
                  border: Border.all(color: Colors.white12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Stack(
                  children: [
                    IsometricHouse3DWidget(
                      height: 140,
                      selectedRoomId: device.room.toLowerCase().contains('bed')
                          ? 'bedroom'
                          : 'living',
                      isInteractive: false,
                      showBadges: false,
                    ),
                    Positioned(
                      top: 8,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.air_rounded, size: 12, color: Color(0xFF00D4FF)),
                            const SizedBox(width: 4),
                            Text(
                              '${device.room} 3D Airflow Stream',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header: Device Title & Power Switch
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.cyan.shade900.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.thermostat_rounded, color: Colors.cyan, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(device.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text('LG DualCool & Google Nest • ${device.room}', style: const TextStyle(fontSize: 13, color: Colors.white60)),
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
            const SizedBox(height: 16),

            // Giant Temperature Readout (e.g. "23°C")
            Center(
              child: Column(
                children: [
                  const Text('TARGET TEMPERATURE', style: TextStyle(fontSize: 11, letterSpacing: 1.5, color: Colors.white54, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    '${device.targetTempC.toStringAsFixed(0)}°C',
                    style: const TextStyle(fontSize: 54, fontWeight: FontWeight.w900, color: Color(0xFF00D4FF), letterSpacing: -1.5),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Indoor: ${device.currentTempC.toStringAsFixed(1)}°C • ${device.humidityPercent}% Humidity',
                        style: const TextStyle(fontSize: 12, color: Colors.white60),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 16°..30° Gradient Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('16°C', style: TextStyle(color: Color(0xFF00D4FF), fontWeight: FontWeight.bold)),
                Text('${device.targetTempC.toStringAsFixed(1)}°C', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                const Text('30°C', style: TextStyle(color: Color(0xFFFF9F0A), fontWeight: FontWeight.bold)),
              ],
            ),
            Slider(
              value: device.targetTempC.clamp(16.0, 30.0),
              min: 16.0,
              max: 30.0,
              divisions: 28,
              activeColor: const Color(0xFF00D4FF),
              inactiveColor: Colors.white12,
              onChanged: (val) => state.updateThermostat(device.id, targetTemp: val),
            ),
            const SizedBox(height: 12),

            // Stepper Plus/Minus
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
            const SizedBox(height: 16),

            // 4 Bottom Control Cards:
            // Card 1: Mode (Cool / Heat / Dry / Fan / Auto)
            // Card 2: Fan Speed (Auto / Low / Med / High)
            // Card 3: Sleep / Eco Mode (Off / On)
            // Card 4: Airflow Swing (Vane Swing / Jet Cool / Ionizer)
            const Text('Climate Controls', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
            const SizedBox(height: 10),

            // Card 1: Modes
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mode:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white70)),
                  const SizedBox(height: 8),
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
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Card 2: Fan Speed
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Fan Speed:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white70)),
                  const SizedBox(height: 8),
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
            ),
            const SizedBox(height: 10),

            // Card 3 & 4: Special Technologies & Swing
            Wrap(
              spacing: 8,
              runSpacing: 8,
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
                FilterChip(
                  avatar: const Icon(Icons.eco_rounded, size: 16, color: Color(0xFF30D158)),
                  label: const Text('Eco Mode'),
                  selected: device.mode == ThermostatMode.eco,
                  onSelected: (val) => state.updateThermostat(
                    device.id,
                    mode: val ? ThermostatMode.eco : ThermostatMode.cool,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Filter Health & Telemetry
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.cyan.shade900.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text('Cleanable Filter', style: TextStyle(fontSize: 11, color: Colors.white60)),
                      const SizedBox(height: 2),
                      Text('${device.filterLifePercent}% Life', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.tealAccent)),
                    ],
                  ),
                  Container(height: 24, width: 1, color: Colors.white24),
                  Column(
                    children: [
                      const Text('Today Consumption', style: TextStyle(fontSize: 11, color: Colors.white60)),
                      const SizedBox(height: 2),
                      Text('${device.energyConsumedKwh.toStringAsFixed(1)} kWh', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                    ],
                  ),
                  Container(height: 24, width: 1, color: Colors.white24),
                  Column(
                    children: [
                      const Text('Refrigerant (R32)', style: TextStyle(fontSize: 11, color: Colors.white60)),
                      const SizedBox(height: 2),
                      const Text('Optimal (OK)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF30D158))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Remove Button
            Center(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
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
