import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/device_model.dart';
import '../../../providers/home_state.dart';
import '../../../services/smartthings/smartthings_laundry_service.dart';

class SamsungWasherSheet extends StatefulWidget {
  final WasherDevice device;

  const SamsungWasherSheet({super.key, required this.device});

  @override
  State<SamsungWasherSheet> createState() => _SamsungWasherSheetState();
}

class _SamsungWasherSheetState extends State<SamsungWasherSheet> {
  final Set<GarmentType> _selectedGarments = {GarmentType.shirtsDaily};

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HomeState>();
    final washer = widget.device;
    final homeCare = state.laundryService.checkHomeCareStatus(
      drumCleanCount: washer.drumCleanCount,
      detergentPercent: washer.detergentLevelPercent,
      softenerPercent: washer.softenerLevelPercent,
    );

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

            // Header: Samsung SmartThings
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.local_laundry_service_rounded, color: Colors.blueAccent, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        washer.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('SmartThings', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
                          ),
                          const SizedBox(width: 6),
                          Text('AI Ecobubble™ • ${washer.room}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: washer.isPowered,
                  activeThumbColor: Colors.blueAccent,
                  onChanged: (val) => state.togglePower(washer.id),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Live / Demo Status Indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: washer.isDummy ? Colors.amber.shade50 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: washer.isDummy ? Colors.amber.shade300 : Colors.blue.shade300),
              ),
              child: Row(
                children: [
                  Icon(
                    washer.isDummy ? Icons.science_outlined : Icons.cloud_done_rounded,
                    size: 16,
                    color: washer.isDummy ? Colors.orange : Colors.blueAccent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      washer.isDummy
                          ? 'Demo Preview Mode • Connect Samsung PAT to control real washer'
                          : 'Live SmartThings Cloud • Device ID: ${washer.cloudDeviceId ?? washer.id}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: washer.isDummy ? Colors.brown : Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Live Cycle Status Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(washer.selectedCycle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(
                            washer.stage == WasherStage.wash
                                ? 'EcoBubble™ active • Sensing fabric weight'
                                : washer.statusSummary,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                      Text(
                        washer.isPowered ? '${washer.remainingMinutes} min left' : 'Idle',
                        style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: washer.isPowered ? 0.60 : 0.0,
                    backgroundColor: Colors.grey.shade300,
                    color: Colors.blueAccent,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Samsung Auto Dispenser System (Detergent & Softener)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Auto Dispense System (SmartThings)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Icon(
                        (homeCare['detergentLow'] as bool || homeCare['softenerLow'] as bool)
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline,
                        size: 18,
                        color: (homeCare['detergentLow'] as bool) ? Colors.amber.shade800 : Colors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Liquid Detergent', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                Text('${washer.detergentLevelPercent}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: washer.detergentLevelPercent / 100.0,
                              color: Colors.blueAccent,
                              backgroundColor: Colors.blue.shade100,
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Fabric Softener', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                Text('${washer.softenerLevelPercent}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: washer.softenerLevelPercent / 100.0,
                              color: Colors.teal,
                              backgroundColor: Colors.teal.shade100,
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // SmartThings Laundry Recipe Assistant
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.purple.shade50.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.auto_awesome, color: Colors.purple, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'SmartThings Laundry Recipe',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Select what you are washing to calculate optimal cycle parameters:',
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildGarmentFilterChip(GarmentType.shirtsDaily, 'Shirts & Daily'),
                      _buildGarmentFilterChip(GarmentType.jeansDenim, 'Jeans & Denim'),
                      _buildGarmentFilterChip(GarmentType.gymActivewear, 'Gym Activewear'),
                      _buildGarmentFilterChip(GarmentType.delicates, 'Delicates / Silk'),
                      _buildGarmentFilterChip(GarmentType.towels, 'Towels & Bedding'),
                      _buildGarmentFilterChip(GarmentType.babyWear, 'Baby Clothes'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(38),
                    ),
                    icon: const Icon(Icons.recommend_rounded, size: 16),
                    label: const Text('Apply Smart Recipe'),
                    onPressed: () {
                      final recipe = state.laundryService.recommendRecipe(_selectedGarments);
                      state.updateSamsungWasher(
                        washer.id,
                        cycle: recipe.recommendedCycle,
                        waterTemp: recipe.recommendedTempC,
                        spinSpeed: recipe.recommendedSpin,
                        ecoBubble: recipe.enableEcoBubble,
                        recommendedRecipe: recipe.advice,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Applied recipe: ${recipe.recommendedCycle} (${recipe.advice})')),
                      );
                    },
                  ),
                  if (washer.recommendedLaundryRecipe != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'AI Advice: ${washer.recommendedLaundryRecipe}',
                      style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.purple.shade900),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Samsung Specific Technology Toggles
            const Text('Samsung Technologies', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilterChip(
                    avatar: const Icon(Icons.bubble_chart_outlined, size: 16),
                    label: const Text('EcoBubble™'),
                    selected: washer.ecoBubbleEnabled,
                    onSelected: (val) => state.updateSamsungWasher(washer.id, ecoBubble: val),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilterChip(
                    avatar: const Icon(Icons.flash_on_rounded, size: 16),
                    label: const Text('SuperSpeed'),
                    selected: washer.superSpeedEnabled,
                    onSelected: (val) => state.updateSamsungWasher(washer.id, superSpeed: val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilterChip(
                    avatar: const Icon(Icons.psychology_outlined, size: 16),
                    label: const Text('AI Wash (Sensors)'),
                    selected: washer.aiWashEnabled,
                    onSelected: (val) => state.updateSamsungWasher(washer.id, aiWash: val),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilterChip(
                    avatar: Icon(
                      washer.addWashDoorLocked ? Icons.lock_outline : Icons.lock_open,
                      size: 16,
                    ),
                    label: Text(washer.addWashDoorLocked ? 'AddWash Door' : 'AddWash Open'),
                    selected: !washer.addWashDoorLocked,
                    onSelected: (val) => state.updateSamsungWasher(washer.id, addWashDoorLocked: !val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // SmartThings Home Care (Drum Clean+ Counter)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cleaning_services_rounded, color: Colors.teal),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Self Clean+ / Drum Clean Tracker', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Text(
                          '${washer.drumCleanCount}/40 cycles completed since last sanitization',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      state.updateSamsungWasher(washer.id, cycle: 'Drum Clean+ (70°C)');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Switched to Drum Clean+ cycle')),
                      );
                    },
                    child: const Text('Clean Now', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Remove Washer Button
            Center(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Remove Washer from Home'),
                onPressed: () {
                  state.removeDevice(washer.id);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Removed ${washer.name}')),
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

  Widget _buildGarmentFilterChip(GarmentType type, String label) {
    final isSelected = _selectedGarments.contains(type);
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedGarments.add(type);
          } else if (_selectedGarments.length > 1) {
            _selectedGarments.remove(type);
          }
        });
      },
    );
  }
}
