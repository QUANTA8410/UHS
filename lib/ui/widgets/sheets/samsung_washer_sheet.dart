import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/real_home_provider.dart';
import '../../../services/real_iot_controller.dart';
import '../../../services/smartthings/smartthings_laundry_service.dart';
import 'lg_future_appliances_sheet.dart';

class SamsungWasherSheet extends StatefulWidget {
  final RealSmartDevice device;

  const SamsungWasherSheet({super.key, required this.device});

  @override
  State<SamsungWasherSheet> createState() => _SamsungWasherSheetState();
}

class _SamsungWasherSheetState extends State<SamsungWasherSheet>
    with SingleTickerProviderStateMixin {
  final Set<GarmentType> _selectedGarments = {GarmentType.shirtsDaily};
  late AnimationController _foamAnimController;

  @override
  void initState() {
    super.initState();
    _foamAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _foamAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RealHomeProvider>();
    final washer = state.devices.firstWhere(
      (d) => d.id == widget.device.id,
      orElse: () => widget.device,
    );
    final homeCare = state.laundryService.checkHomeCareStatus(
      drumCleanCount: washer.drumCleanCount,
      detergentPercent: washer.detergentLevelPercent,
      softenerPercent: washer.softenerLevelPercent,
    );

    return Theme(
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF007AFF),
          surface: Colors.white,
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
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
                  child: const Icon(Icons.local_laundry_service_rounded,
                      color: Colors.blueAccent, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        washer.name,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('SmartThings',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue)),
                          ),
                          const SizedBox(width: 6),
                          Text('AI Ecobubble™ • ${washer.room}',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'LG WashTower™ View',
                  icon: const Icon(Icons.swap_horiz_rounded, color: Colors.blueAccent),
                  onPressed: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      barrierColor: Colors.black.withValues(alpha: 0.65),
                      builder: (ctx) => LgFutureAppliancesSheet(
                        initialDevice: washer,
                        initialTabIndex: 0,
                      ),
                    );
                  },
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
                border: Border.all(
                    color: washer.isDummy
                        ? Colors.amber.shade300
                        : Colors.blue.shade300),
              ),
              child: Row(
                children: [
                  Icon(
                    washer.isDummy
                        ? Icons.science_outlined
                        : Icons.cloud_done_rounded,
                    size: 16,
                    color: washer.isDummy ? Colors.orange : Colors.blueAccent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      washer.isDummy
                          ? 'Demo Preview Mode • Connect Samsung PAT to control real washer'
                          : 'Live SmartThings Cloud • Device ID: ${washer.cloudDeviceId}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: washer.isDummy
                            ? Colors.brown
                            : Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 1. Real-Time Cycle Dial (washerOperatingState)
            _buildCircularHeroDial(context, state, washer),
            const SizedBox(height: 18),

            // 2. AI Ecobubble™ & Foam Simulation
            _buildEcobubbleFoamSection(context, state, washer),
            const SizedBox(height: 18),

            // 3. HomeCare Wizard Auto-Dispenser Gauges
            _buildHomeCareDispenserGauges(context, state, washer, homeCare),
            const SizedBox(height: 18),

            // 4. SmartThings Fabric Recipe Assistant
            _buildFabricRecipeSection(context, state, washer),
            const SizedBox(height: 18),

            // 5. Auto Cycle Link (Smart Forwarding to Dryer)
            _buildAutoCycleLinkCard(context, state, washer),
            const SizedBox(height: 18),

            // 6. Samsung Specific Technology Toggles
            const Text('Samsung Technologies',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilterChip(
                    avatar: const Icon(Icons.bubble_chart_outlined, size: 16),
                    label: const Text('EcoBubble™'),
                    selected: washer.ecoBubbleEnabled,
                    onSelected: (val) =>
                        state.updateSamsungWasher(washer.id, ecoBubble: val),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilterChip(
                    avatar: const Icon(Icons.flash_on_rounded, size: 16),
                    label: const Text('SuperSpeed'),
                    selected: washer.superSpeedEnabled,
                    onSelected: (val) =>
                        state.updateSamsungWasher(washer.id, superSpeed: val),
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
                    onSelected: (val) =>
                        state.updateSamsungWasher(washer.id, aiWash: val),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilterChip(
                    avatar: Icon(
                      washer.addWashDoorLocked
                          ? Icons.lock_outline
                          : Icons.lock_open,
                      size: 16,
                    ),
                    label: Text(washer.addWashDoorLocked
                        ? 'AddWash Door'
                        : 'AddWash Open'),
                    selected: !washer.addWashDoorLocked,
                    onSelected: (val) => state.updateSamsungWasher(washer.id,
                        addWashDoorLocked: !val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Self Clean+ / Drum Clean Tracker
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
                        const Text('Self Clean+ / Drum Clean Tracker',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12)),
                        Text(
                          '${washer.drumCleanCount}/40 cycles completed since last sanitization',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      state.updateSamsungWasher(
                        washer.id,
                        cycle: 'Drum Clean+ (70°C)',
                        drumCleanCount: 0,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Switched to Drum Clean+ cycle • Reset counter')),
                      );
                    },
                    child:
                        const Text('Clean Now', style: TextStyle(fontSize: 12)),
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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
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
    ),
  );
}

  // 1. Real-Time Cycle Dial (washerOperatingState)
  Widget _buildCircularHeroDial(
      BuildContext context, RealHomeProvider state, RealSmartDevice washer) {
    final isRunning = washer.isPowered;
    final currentStage = washer.washerStage.toLowerCase();
    final remainingMin = washer.remainingMinutes;

    // Determine progress 0.0 - 1.0 based on stage
    double progress = 0.0;
    if (isRunning) {
      if (currentStage == 'wash' || currentStage == 'weightsensing') {
        progress = 0.35;
      } else if (currentStage == 'rinse') {
        progress = 0.68;
      } else if (currentStage == 'spin') {
        progress = 0.92;
      } else {
        progress = 0.50;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withValues(alpha: isRunning ? 0.25 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Segmented Progress Dial with Chronometer
          SizedBox(
            width: 190,
            height: 190,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(190, 190),
                  painter: _WasherSegmentedDialPainter(
                    progress: progress,
                    activeStage: currentStage,
                    isRunning: isRunning,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isRunning ? '$remainingMin min' : 'Idle',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isRunning
                            ? Colors.cyanAccent.withValues(alpha: 0.2)
                            : Colors.white12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isRunning ? currentStage.toUpperCase() : 'OFF',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isRunning ? Colors.cyanAccent : Colors.white60,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      washer.selectedCycle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Stage Chips (Wash -> Rinse -> Spin)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStageChip(
                label: 'Wash',
                isActive: isRunning && (currentStage == 'wash' || currentStage == 'weightsensing'),
                onTap: () => state.updateSamsungWasher(washer.id, stage: 'wash'),
              ),
              const SizedBox(width: 8),
              _buildStageChip(
                label: 'Rinse',
                isActive: isRunning && currentStage == 'rinse',
                onTap: () => state.updateSamsungWasher(washer.id, stage: 'rinse'),
              ),
              const SizedBox(width: 8),
              _buildStageChip(
                label: 'Spin',
                isActive: isRunning && currentStage == 'spin',
                onTap: () => state.updateSamsungWasher(washer.id, stage: 'spin'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Control Actions: Pause / Resume / Stop
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: isRunning ? Colors.blueAccent : Colors.teal,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: Icon(
                    isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 18,
                  ),
                  label: Text(isRunning ? 'Pause Cycle' : 'Start Cycle'),
                  onPressed: () => state.togglePower(washer.id),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white30),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.stop_rounded, size: 18),
                label: const Text('Cancel'),
                onPressed: () {
                  state.updateSamsungWasher(
                    washer.id,
                    stage: 'idle',
                    remainingMinutes: 0,
                  );
                  if (washer.isOn) state.togglePower(washer.id);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStageChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.cyanAccent : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive) ...[
              const Icon(Icons.sync_rounded, size: 12, color: Colors.black),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.black : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 2. AI Ecobubble™ & Foam Simulation
  Widget _buildEcobubbleFoamSection(
      BuildContext context, RealHomeProvider state, RealSmartDevice washer) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1E36),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.bubble_chart_rounded, color: Colors.cyanAccent, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'AI Ecobubble™ Active Foam',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.white),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.cyan.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('~70% Energy Saved',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.cyanAccent)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Generates rich cleansing bubbles in cold water that penetrate fabric 40x faster than traditional dissolved detergent.',
            style: TextStyle(fontSize: 11, color: Colors.white70),
          ),
          const SizedBox(height: 10),

          // Foam Bubble Wave Animation
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 44,
              width: double.infinity,
              child: AnimatedBuilder(
                animation: _foamAnimController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _EcobubbleFoamPainter(
                      phase: _foamAnimController.value,
                      isActive: washer.ecoBubbleEnabled && washer.isPowered,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                washer.ecoBubbleEnabled ? 'Bubble Soak: Active' : 'Bubble Soak: Off',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: washer.ecoBubbleEnabled ? Colors.cyanAccent : Colors.white38,
                ),
              ),
              Switch(
                value: washer.ecoBubbleEnabled,
                activeColor: Colors.cyanAccent,
                onChanged: (val) =>
                    state.updateSamsungWasher(washer.id, ecoBubble: val),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 3. HomeCare Wizard Auto-Dispenser Gauges
  Widget _buildHomeCareDispenserGauges(BuildContext context,
      RealHomeProvider state, RealSmartDevice washer, Map<String, dynamic> homeCare) {
    final detLow = homeCare['detergentLow'] as bool;
    final softLow = homeCare['softenerLow'] as bool;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.inventory_2_rounded,
                      color: Colors.blueAccent, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Auto Dispenser System (HomeCare Wizard)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              Icon(
                (detLow || softLow)
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_rounded,
                size: 18,
                color: (detLow || softLow) ? Colors.amber.shade800 : Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Liquid Detergent',
                            style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text('${washer.detergentLevelPercent}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: detLow ? Colors.orange.shade800 : Colors.black,
                            )),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: washer.detergentLevelPercent / 100.0,
                      color: detLow ? Colors.amber.shade700 : Colors.blueAccent,
                      backgroundColor: Colors.blue.shade100,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    if (detLow)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('Refill recommended',
                            style: TextStyle(
                                fontSize: 9,
                                color: Colors.orange.shade900,
                                fontWeight: FontWeight.bold)),
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
                        const Text('Fabric Softener',
                            style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text('${washer.softenerLevelPercent}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: softLow ? Colors.orange.shade800 : Colors.black,
                            )),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: washer.softenerLevelPercent / 100.0,
                      color: softLow ? Colors.amber.shade700 : Colors.teal,
                      backgroundColor: Colors.teal.shade100,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    if (softLow)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('Refill recommended',
                            style: TextStyle(
                                fontSize: 9,
                                color: Colors.orange.shade900,
                                fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 4. Fabric Recipe Engine
  Widget _buildFabricRecipeSection(
      BuildContext context, RealHomeProvider state, RealSmartDevice washer) {
    return Container(
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
              final recipe =
                  state.laundryService.recommendRecipe(_selectedGarments);
              state.updateSamsungWasher(
                washer.id,
                cycle: recipe.recommendedCycle,
                waterTemp: recipe.recommendedTempC,
                waterTempStr: '${recipe.recommendedTempC}°C',
                spinSpeed: recipe.recommendedSpin,
                ecoBubble: recipe.enableEcoBubble,
                recommendedRecipe: recipe.advice,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        'Applied recipe: ${recipe.recommendedCycle} (${recipe.advice})')),
              );
            },
          ),
          if (washer.recommendedLaundryRecipe != null) ...[
            const SizedBox(height: 8),
            Text(
              'AI Advice: ${washer.recommendedLaundryRecipe}',
              style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Colors.purple.shade900),
            ),
          ],
        ],
      ),
    );
  }

  // 5. Auto Cycle Link (Smart Forwarding to Dryer)
  Widget _buildAutoCycleLinkCard(
      BuildContext context, RealHomeProvider state, RealSmartDevice washer) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.indigo.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.indigo.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.sync_alt_rounded,
                color: Colors.indigo, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Auto Cycle Link (Smart Forwarding)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  'Automatically syncs wash load profile to Samsung Dryer to preheat & select dry course',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          Switch(
            value: washer.autoCycleLinkEnabled,
            activeColor: Colors.indigo,
            onChanged: (val) =>
                state.updateSamsungWasher(washer.id, autoCycleLink: val),
          ),
        ],
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

/// CustomPainter for the Circular Segmented Hero Dial
class _WasherSegmentedDialPainter extends CustomPainter {
  final double progress;
  final String activeStage;
  final bool isRunning;

  _WasherSegmentedDialPainter({
    required this.progress,
    required this.activeStage,
    required this.isRunning,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 14;

    // Background Track
    final bgPaint = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    if (!isRunning) return;

    // Glowing Gradient Progress Arc
    final rect = Rect.fromCircle(center: center, radius: radius);
    final gradient = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: 3 * math.pi / 2,
      colors: const [
        Color(0xFF00E5FF),
        Color(0xFF2979FF),
        Color(0xFF7C4DFF),
      ],
      transform: const GradientRotation(-math.pi / 2),
    );

    final activePaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress.clamp(0.02, 1.0);
    canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, activePaint);

    // Glowing Lead Bead
    final beadAngle = -math.pi / 2 + sweepAngle;
    final beadPos = Offset(
      center.dx + radius * math.cos(beadAngle),
      center.dy + radius * math.sin(beadAngle),
    );

    final glowPaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(beadPos, 8, glowPaint);

    final whiteBead = Paint()..color = Colors.white;
    canvas.drawCircle(beadPos, 5, whiteBead);
  }

  @override
  bool shouldRepaint(covariant _WasherSegmentedDialPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeStage != activeStage ||
        oldDelegate.isRunning != isRunning;
  }
}

/// CustomPainter for AI Ecobubble™ active foam simulation
class _EcobubbleFoamPainter extends CustomPainter {
  final double phase;
  final bool isActive;

  _EcobubbleFoamPainter({required this.phase, required this.isActive});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF0A1526);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    if (!isActive) {
      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'Ecobubble foam generator standby',
          style: TextStyle(color: Colors.white24, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2),
      );
      return;
    }

    // Draw floating bubbles
    final bubblePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.cyanAccent.withValues(alpha: 0.6);

    final bubbleFill = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.cyan.withValues(alpha: 0.2);

    final numBubbles = 18;
    for (int i = 0; i < numBubbles; i++) {
      final xRatio = (i / numBubbles + phase * 0.4) % 1.0;
      final x = xRatio * size.width;
      final y = size.height * 0.7 -
          math.sin((phase * 2 * math.pi) + i) * (size.height * 0.35);
      final r = 4.0 + (i % 5) * 1.5;

      canvas.drawCircle(Offset(x, y), r, bubbleFill);
      canvas.drawCircle(Offset(x, y), r, bubblePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _EcobubbleFoamPainter oldDelegate) {
    return oldDelegate.phase != phase || oldDelegate.isActive != isActive;
  }
}
