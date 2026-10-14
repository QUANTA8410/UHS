import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/device_model.dart';
import '../../../providers/home_state.dart';

class LightSheet extends StatelessWidget {
  final LightDevice device;

  const LightSheet({super.key, required this.device});

  static const List<Map<String, dynamic>> _colorPalette = [
    {'name': 'Warm Amber', 'color': Color(0xFFFFD54F), 'temp': 3000},
    {'name': 'Candle Glow', 'color': Color(0xFFFFB74D), 'temp': 2700},
    {'name': 'Cool White', 'color': Color(0xFFE0F7FA), 'temp': 6500},
    {'name': 'Sunset Coral', 'color': Color(0xFFFF7043), 'temp': 3200},
    {'name': 'Lavender', 'color': Color(0xFFBA68C8), 'temp': 4000},
    {'name': 'Sky Blue', 'color': Color(0xFF4FC3F7), 'temp': 5000},
    {'name': 'Emerald', 'color': Color(0xFF81C784), 'temp': 4500},
    {'name': 'Neon Party', 'color': Color(0xFFE91E63), 'temp': 4000},
  ];

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header: Wipro Smart Bulb
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: device.color.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.lightbulb_rounded, color: device.color, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(device.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Wipro Smart', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
                          ),
                          const SizedBox(width: 6),
                          Text('${device.colorTempKelvin}K • ${device.room}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: device.isPowered,
                  activeThumbColor: Colors.amber,
                  onChanged: (val) => state.togglePower(device.id),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Live / Demo Status Indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: device.isDummy ? Colors.amber.shade50 : Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: device.isDummy ? Colors.amber.shade300 : Colors.green.shade300),
              ),
              child: Row(
                children: [
                  Icon(
                    device.isDummy ? Icons.science_outlined : Icons.wifi_rounded,
                    size: 16,
                    color: device.isDummy ? Colors.orange : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      device.isDummy
                          ? 'Demo Preview Mode • Connect Bulb IP / Tuya Key to control real bulb'
                          : 'Live Wi-Fi Bulb • ${device.host ?? "LAN Connected"}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: device.isDummy ? Colors.brown : Colors.green.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Brightness Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Brightness', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text('${(device.brightness * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            Slider(
              value: device.brightness,
              activeColor: device.color,
              onChanged: (val) => state.updateWiproBulb(device.id, brightness: val),
            ),
            const SizedBox(height: 12),

            // CCT Color Temperature Kelvin Slider (Warm White to Cool Daylight)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tunable White (CCT)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(
                  '${device.colorTempKelvin}K (${device.colorTempKelvin < 3200 ? "Warm" : device.colorTempKelvin > 5000 ? "Cool" : "Neutral"})',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            Slider(
              value: device.colorTempKelvin.toDouble(),
              min: 2700,
              max: 6500,
              divisions: 38,
              activeColor: Colors.orangeAccent,
              inactiveColor: Colors.blue.shade100,
              onChanged: (val) {
                final int k = val.round();
                state.updateWiproBulb(device.id, colorTempKelvin: k);
              },
            ),
            const SizedBox(height: 14),

            // 16 Million Colors RGB Palette
            const Text('16M Colors (RGB Palette)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _colorPalette.map((item) {
                  final Color c = item['color'] as Color;
                  final isSelected = device.color.toARGB32() == c.toARGB32();
                  return GestureDetector(
                    onTap: () {
                      state.updateWiproBulb(
                        device.id,
                        color: c,
                        colorTempKelvin: item['temp'] as int,
                        scene: item['name'] as String,
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.black87 : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: c,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // Wipro Smart Preset Scenes
            const Text('Smart Scenes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildSceneChip(context, state, 'Reading', 4000, 0.90, const Color(0xFFFFECB3)),
                _buildSceneChip(context, state, 'Relax', 2700, 0.50, const Color(0xFFFFCC80)),
                _buildSceneChip(context, state, 'Night Light', 2700, 0.15, const Color(0xFFFFAB91)),
                _buildSceneChip(context, state, 'Focus Work', 6500, 1.0, const Color(0xFFB2EBF2)),
                _buildSceneChip(context, state, 'Party Mode', 4500, 1.0, const Color(0xFFF48FB1)),
              ],
            ),
            const SizedBox(height: 16),

            // Music Sync Toggle
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Music Rhythm Sync', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              subtitle: const Text('Pulsates light colors dynamically to room audio / microphone', style: TextStyle(fontSize: 11)),
              value: device.musicSyncActive,
              activeThumbColor: Colors.amber,
              onChanged: (val) => state.updateWiproBulb(device.id, musicSync: val),
            ),
            const SizedBox(height: 16),

            // Remove Light Button
            Center(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Remove Bulb from Home'),
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

  Widget _buildSceneChip(
    BuildContext context,
    HomeState state,
    String name,
    int kelvin,
    double brightness,
    Color color,
  ) {
    final isSelected = device.activeScene == name;
    return ChoiceChip(
      label: Text(name),
      selected: isSelected,
      selectedColor: color.withValues(alpha: 0.6),
      onSelected: (selected) {
        if (selected) {
          state.updateWiproBulb(
            device.id,
            scene: name,
            brightness: brightness,
            colorTempKelvin: kelvin,
            color: color,
          );
        }
      },
    );
  }
}
