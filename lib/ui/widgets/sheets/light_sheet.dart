import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../models/device_model.dart';
import '../../../providers/home_state.dart';
import '../map3d/isometric_house_3d_widget.dart';

class LightSheet extends StatefulWidget {
  final LightDevice device;

  const LightSheet({super.key, required this.device});

  @override
  State<LightSheet> createState() => _LightSheetState();
}

class _LightSheetState extends State<LightSheet> {
  static const List<Color> _videoPresetDots = [
    Color(0xFFFF3A3C),
    Color(0xFFFF9500),
    Color(0xFFFFCC00),
    Color(0xFF34C759),
    Color(0xFF00C7BE),
    Color(0xFF007AFF),
    Color(0xFFAF52DE),
  ];

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

  double _hsvHue = 35.0; // 0..360

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HomeState>();
    final device = widget.device;
    final brightnessPercent = (device.brightness * 100).round();

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

            // Top: Zoomed-in 3D Room Isometric Preview
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
                          : device.room.toLowerCase().contains('bath')
                              ? 'bathroom'
                              : device.room.toLowerCase().contains('kit')
                                  ? 'kitchen'
                                  : device.room.toLowerCase().contains('din')
                                      ? 'dining'
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
                        child: Text(
                          '${device.room} 3D View',
                          style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
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
                      Text(device.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade900.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Wipro Smart', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
                          ),
                          const SizedBox(width: 6),
                          Text('${device.colorTempKelvin}K • ${device.room}', style: const TextStyle(fontSize: 12, color: Colors.white60)),
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
            const SizedBox(height: 16),

            // Giant Brightness Readout (e.g. "86%")
            Center(
              child: Column(
                children: [
                  const Text('BRIGHTNESS LEVEL', style: TextStyle(fontSize: 11, letterSpacing: 1.5, color: Colors.white54, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    '$brightnessPercent%',
                    style: TextStyle(
                      fontSize: 54,
                      fontWeight: FontWeight.w900,
                      color: device.isPowered ? (device.color == Colors.black ? Colors.white : device.color) : Colors.white38,
                      letterSpacing: -1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Horizontal Brightness Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Brightness', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                Text('$brightnessPercent%', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF9F0A))),
              ],
            ),
            Slider(
              value: device.brightness,
              activeColor: device.color,
              inactiveColor: Colors.white12,
              onChanged: (val) => state.updateWiproBulb(device.id, brightness: val),
            ),
            const SizedBox(height: 14),

            // Video Preset Color Dots
            const Text('Spectrum Presets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white70)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _videoPresetDots.map((c) {
                final isSelected = device.color.toARGB32() == c.toARGB32();
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    state.updateWiproBulb(device.id, color: c);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 2.2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 17,
                      backgroundColor: c,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // 2D HSV Rainbow Color Picker Bar
            const Text('2D HSV Rainbow Spectrum', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white70)),
            const SizedBox(height: 8),
            GestureDetector(
              onHorizontalDragUpdate: (details) {
                final box = context.findRenderObject() as RenderBox?;
                if (box == null) return;
                setState(() {
                  _hsvHue = (_hsvHue + (details.primaryDelta! / 200.0) * 360.0).clamp(0.0, 360.0);
                });
                final newColor = HSVColor.fromAHSV(1.0, _hsvHue, 0.85, 1.0).toColor();
                state.updateWiproBulb(device.id, color: newColor);
              },
              child: Container(
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFF0000),
                      Color(0xFFFFFF00),
                      Color(0xFF00FF00),
                      Color(0xFF00FFFF),
                      Color(0xFF0000FF),
                      Color(0xFFFF00FF),
                      Color(0xFFFF0000),
                    ],
                  ),
                  border: Border.all(color: Colors.white24),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // CCT Color Temperature Kelvin Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tunable White (CCT)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                Text(
                  '${device.colorTempKelvin}K (${device.colorTempKelvin < 3200 ? "Warm" : device.colorTempKelvin > 5000 ? "Cool" : "Neutral"})',
                  style: const TextStyle(fontSize: 12, color: Colors.white60),
                ),
              ],
            ),
            Slider(
              value: device.colorTempKelvin.toDouble(),
              min: 2700,
              max: 6500,
              divisions: 38,
              activeColor: Colors.orangeAccent,
              inactiveColor: Colors.white12,
              onChanged: (val) {
                final int k = val.round();
                state.updateWiproBulb(device.id, colorTempKelvin: k);
              },
            ),
            const SizedBox(height: 14),

            // 16 Million Colors RGB Palette
            const Text('16M Colors (RGB Palette)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
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
                          color: isSelected ? Colors.white : Colors.transparent,
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
            const Text('Smart Scenes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
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
            Material(
              color: Colors.transparent,
              child: SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Music Rhythm Sync', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white)),
                subtitle: const Text('Pulsates light colors dynamically to room audio / microphone', style: TextStyle(fontSize: 11, color: Colors.white54)),
                value: device.musicSyncActive,
                activeThumbColor: Colors.amber,
                onChanged: (val) => state.updateWiproBulb(device.id, musicSync: val),
              ),
            ),
            const SizedBox(height: 16),

            // Remove Light Button
            Center(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
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
    final isSelected = widget.device.activeScene == name;
    return ChoiceChip(
      label: Text(name),
      selected: isSelected,
      selectedColor: color.withValues(alpha: 0.6),
      onSelected: (selected) {
        if (selected) {
          state.updateWiproBulb(
            widget.device.id,
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
