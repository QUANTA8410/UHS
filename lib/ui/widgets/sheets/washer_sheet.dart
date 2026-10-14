import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/device_model.dart';
import '../../../providers/home_state.dart';
import 'appliance_cycle_store_sheet.dart';
import '../dialogs/smart_diagnosis_dialog.dart';
import 'samsung_washer_sheet.dart';

class WasherSheet extends StatelessWidget {
  final WasherDevice device;

  const WasherSheet({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    if (device.brand.contains('Samsung')) {
      return SamsungWasherSheet(device: device);
    }

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
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.local_laundry_service_rounded, color: Colors.green, size: 28),
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
                      'LG ThinQ AI DirectDrive • ${device.room}',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Switch(
                value: device.isPowered,
                activeThumbColor: Colors.green,
                onChanged: (val) => state.togglePower(device.id),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Cycle Progress Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      device.selectedCycle,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      device.isPowered ? '${device.remainingMinutes} min left' : 'Idle',
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: device.isPowered ? 0.65 : 0.0,
                  backgroundColor: Colors.grey.shade300,
                  color: Colors.green,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('Wash', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    Text('Rinse', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green)),
                    Text('Spin', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // LG ThinQ Cycle Selector Chips
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Wash Cycles (LG ThinQ UP)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              TextButton.icon(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    builder: (ctx) => ApplianceCycleStoreSheet(washer: device),
                  );
                },
                icon: const Icon(Icons.add_shopping_cart, size: 16),
                label: const Text('Cycle Store', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: state.availableWashCycles.map((recipe) {
                final isSelected = device.selectedCycle == recipe.name;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(recipe.name),
                    selected: isSelected,
                    selectedColor: Colors.green.shade100,
                    onSelected: (selected) {
                      if (selected) {
                        state.updateWasher(
                          device.id,
                          cycle: recipe.name,
                          waterTemp: recipe.defaultTempC,
                          spinSpeed: recipe.defaultSpinSpeed,
                        );
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Granular Wash Modifiers
          Row(
            children: [
              Expanded(
                child: _buildModifierDropdown(
                  title: 'Water Temp',
                  value: '${device.waterTempC}°C',
                  options: ['Cold', '30°C', '40°C', '60°C', '95°C'],
                  onChanged: (val) {
                    final temp = int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), '')) ?? 40;
                    state.updateWasher(device.id, waterTemp: temp);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildModifierDropdown(
                  title: 'Spin Speed',
                  value: device.spinSpeed,
                  options: ['No Spin', 'Low', 'Med', 'High', 'Max'],
                  onChanged: (val) => state.updateWasher(device.id, spinSpeed: val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Toggles: Steam & TurboWash
          Row(
            children: [
              Expanded(
                child: FilterChip(
                  label: const Text('Steam Allergy Care'),
                  selected: device.steamEnabled,
                  onSelected: (val) => state.updateWasher(device.id, steam: val),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilterChip(
                  label: const Text('TurboWash™'),
                  selected: device.turboWashEnabled,
                  onSelected: (val) => state.updateWasher(device.id, turboWash: val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Smart Diagnosis action
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.health_and_safety_outlined, color: Colors.blue),
            label: const Text('Run LG Smart Diagnosis™ (Wi-Fi)'),
            onPressed: () {
              SmartDiagnosisDialog.show(context, device);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildModifierDropdown({
    required String title,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          DropdownButton<String>(
            isExpanded: true,
            value: options.contains(value) ? value : options.first,
            underline: const SizedBox(),
            items: options.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}
