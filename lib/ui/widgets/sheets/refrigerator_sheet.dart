import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/device_model.dart';
import '../../../providers/home_state.dart';

class RefrigeratorSheet extends StatelessWidget {
  final RefrigeratorDevice device;

  const RefrigeratorSheet({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HomeState>();

    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.kitchen_rounded, color: Colors.teal, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'LG InstaView™ & SmartThings • ${device.room}',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Dual Compartment Temperature Cards
          Row(
            children: [
              Expanded(
                child: _buildTempCard(
                  title: 'Fridge Compartment',
                  temp: '${device.fridgeTempC.toInt()}°C',
                  onMinus: () => state.updateRefrigerator(device.id, fridgeTemp: (device.fridgeTempC - 1).clamp(1.0, 7.0)),
                  onPlus: () => state.updateRefrigerator(device.id, fridgeTemp: (device.fridgeTempC + 1).clamp(1.0, 7.0)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTempCard(
                  title: 'Freezer Compartment',
                  temp: '${device.freezerTempC.toInt()}°C',
                  onMinus: () => state.updateRefrigerator(device.id, freezerTemp: (device.freezerTempC - 1).clamp(-23.0, -15.0)),
                  onPlus: () => state.updateRefrigerator(device.id, freezerTemp: (device.freezerTempC + 1).clamp(-23.0, -15.0)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // LG Craft Ice™ Control (Signature Feature)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.ac_unit_rounded, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('LG Craft Ice™ Maker', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                    Text(
                      device.craftIceMode == CraftIceMode.off ? 'Off' : '${device.craftIceMode == CraftIceMode.threePerDay ? "3" : "6"} Balls/Day',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SegmentedButton<CraftIceMode>(
                  segments: const [
                    ButtonSegment(value: CraftIceMode.off, label: Text('Off')),
                    ButtonSegment(value: CraftIceMode.threePerDay, label: Text('3 Ice Balls')),
                    ButtonSegment(value: CraftIceMode.sixPerDay, label: Text('6 Ice Balls')),
                  ],
                  selected: {device.craftIceMode},
                  onSelectionChanged: (set) => state.updateRefrigerator(device.id, craftIce: set.first),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Express Freeze & Maintenance
          Row(
            children: [
              Expanded(
                child: FilterChip(
                  label: const Text('Express Freeze'),
                  selected: device.expressFreeze,
                  onSelected: (val) => state.updateRefrigerator(device.id, expressFreeze: val),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Chip(
                  avatar: const Icon(Icons.water_drop_outlined, size: 16, color: Colors.blue),
                  label: Text('Filter: ${device.waterFilterLifePercent}% Life'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTempCard({
    required String title,
    required String temp,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 8),
          Text(temp, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                iconSize: 18,
                icon: const Icon(Icons.remove),
                onPressed: onMinus,
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                iconSize: 18,
                icon: const Icon(Icons.add),
                onPressed: onPlus,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
