import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/real_home_provider.dart';
import '../../../services/real_iot_controller.dart';
import '../dialogs/smart_diagnosis_dialog.dart';
import 'samsung_washer_sheet.dart';

/// LG ThinQ™ Smart Appliance Ecosystem & Next-Gen Control Sheet (`LgFutureAppliancesSheet`).
///
/// Reverse-engineered directly from LG ThinQ (`LG ThinQ.apk` / `com.lgeha.nuts`):
/// - Tab 0: LG WashTower™ & AI DD™ Washer / Dryer (Center Control™, TurboWash™ 360, ezDispense™, Smart Pairing™)
/// - Tab 1: LG InstaView™ Refrigerator (Knock-twice tinted glass, Craft Ice™ spherical 50mm, DoorCooling+™, LinearCooling™)
/// - Tab 2: LG PuriCare™ AeroTower (Clean Booster™ 55° pop-up fan, 3 Airflow Modes, PM1.0 Laser Halo, UVnano™)
/// - Tab 3: LG Styler® Steam Closet & QuadWash™ Dishwasher (Moving Hanger™ 200 RPM, TrueSteam®, Pants Crease Care, ThinQ UP™)
class LgFutureAppliancesSheet extends StatefulWidget {
  final RealSmartDevice? initialDevice;
  final int initialTabIndex; // 0: WashTower, 1: InstaView, 2: AeroTower, 3: Styler & Dishes

  const LgFutureAppliancesSheet({
    super.key,
    this.initialDevice,
    this.initialTabIndex = 0,
  });

  @override
  State<LgFutureAppliancesSheet> createState() => _LgFutureAppliancesSheetState();
}

class _LgFutureAppliancesSheetState extends State<LgFutureAppliancesSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Local state for InstaView double-knock animation
  bool _isGlassIlluminated = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _triggerDoubleKnock() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isGlassIlluminated = !_isGlassIlluminated;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D1527),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          const SizedBox(height: 14),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFA50034).withValues(alpha: 0.22), // LG Burgundy Red
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFFFF4081),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'LG ThinQ™ Appliance Studio',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'ThinQ UP™ · WashTower · InstaView · AeroTower · Styler',
                      style: TextStyle(fontSize: 11, color: Colors.white60),
                    ),
                  ],
                ),
              ),
              if (widget.initialDevice != null &&
                  (widget.initialDevice!.category == 'washer' ||
                      widget.initialDevice!.id.toLowerCase().contains('washer')))
                IconButton(
                  tooltip: 'Samsung Ecobubble™ View',
                  icon: const Icon(Icons.swap_horiz_rounded, color: Color(0xFFFF4081)),
                  onPressed: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      barrierColor: Colors.black.withValues(alpha: 0.65),
                      builder: (ctx) => SamsungWasherSheet(device: widget.initialDevice!),
                    );
                  },
                ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white60),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tab Bar Selector
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: const Color(0xFFA50034),
                borderRadius: BorderRadius.circular(20),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: 'WashTower'),
                Tab(text: 'InstaView'),
                Tab(text: 'AeroTower'),
                Tab(text: 'Styler & Dish'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Tab View Content
          Flexible(
            child: SizedBox(
              height: 520,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildWashTowerTab(context),
                  _buildInstaViewFridgeTab(context),
                  _buildAeroTowerTab(context),
                  _buildStylerAndDishwasherTab(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 0: LG WashTower™ (AI DD™ Washer & DUAL Inverter Heat Pump Dryer)
  // =========================================================================
  Widget _buildWashTowerTab(BuildContext context) {
    final state = context.watch<RealHomeProvider>();
    final dev = state.devices
            .where((d) =>
                d.id.contains('washtower') ||
                d.id.contains('washer') ||
                d.category == 'washer')
            .firstOrNull ??
        widget.initialDevice;

    final isPowered = dev?.isOn ?? true;
    final stage = dev?.washerStage ?? 'rinse';
    final remainingMin = dev?.remainingMinutes ?? 24;
    final isTurboWash = dev?.turboWash360Enabled ?? true;
    final detLevel = dev?.ezDispenseDetergentPercent ?? 82;
    final softLevel = dev?.ezDispenseSoftenerPercent ?? 68;
    final isSmartPairing = dev?.smartPairingActive ?? true;
    final dryMin = dev?.dryerRemainingMinutes ?? 34;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Center Control Stacked Hero Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF161F38),
                  const Color(0xFFA50034).withValues(alpha: 0.25),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_laundry_service_rounded,
                            color: Color(0xFFFF4081), size: 22),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'LG WashTower™ Center Control',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                            Text(
                              'Integrated Dual Drum Laundry Suite',
                              style: TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Switch(
                      value: isPowered,
                      activeColor: const Color(0xFFFF4081),
                      onChanged: (v) {
                        if (dev != null) state.toggleDevicePower(dev);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Lower Drum (Washer) & Upper Drum (Dryer) Status Chips
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('WASHER (BOTTOM)',
                                style: TextStyle(
                                    color: Colors.pinkAccent,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(
                              isPowered ? '${stage.toUpperCase()} · $remainingMin min' : 'STANDBY',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('DRYER (TOP)',
                                style: TextStyle(
                                    color: Colors.amberAccent,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(
                              isSmartPairing ? 'PRE-HEATING · $dryMin min' : 'STANDBY',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // TurboWash™ 360 Feature Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.speed_rounded, color: Colors.cyanAccent, size: 20),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'TurboWash™ 360 Jets',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                            Text(
                              '4 Directional Multi-Nozzles (39 min normal cycle)',
                              style: TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Switch(
                      value: isTurboWash,
                      activeColor: Colors.cyanAccent,
                      onChanged: (val) {
                        if (dev != null) {
                          state.updateLgWashTower(dev.id, turboWash360: val);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 4-Way Jet Visualizer
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(4, (index) {
                      return Row(
                        children: [
                          Icon(
                            Icons.water_drop_rounded,
                            size: 16,
                            color: isTurboWash
                                ? Colors.cyanAccent
                                : Colors.white24,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Jet ${index + 1}',
                            style: TextStyle(
                              fontSize: 10,
                              color: isTurboWash ? Colors.white70 : Colors.white24,
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ezDispense™ Fluid Reservoir Gauges
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'ezDispense™ Auto Dosing Tanks',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                    Text(
                      'AI Load Sensed',
                      style: TextStyle(color: Colors.greenAccent, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Detergent Bar
                Row(
                  children: [
                    const SizedBox(
                      width: 80,
                      child: Text('Detergent',
                          style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: detLevel / 100.0,
                          backgroundColor: Colors.white10,
                          color: Colors.blueAccent,
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('$detLevel%',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 8),

                // Softener Bar
                Row(
                  children: [
                    const SizedBox(
                      width: 80,
                      child: Text('Softener',
                          style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: softLevel / 100.0,
                          backgroundColor: Colors.white10,
                          color: Colors.purpleAccent,
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('$softLevel%',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Smart Pairing™ Course Transfer Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF162544),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.sync_alt_rounded, color: Colors.lightBlueAccent, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Smart Pairing™ Auto Cycle Transfer',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                      Text(
                        'Washer transmits fabric telemetry to pre-set matching dry cycle',
                        style: TextStyle(color: Colors.white60, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isSmartPairing,
                  activeColor: Colors.lightBlueAccent,
                  onChanged: (val) {
                    if (dev != null) {
                      state.updateLgWashTower(dev.id, smartPairing: val);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 1: LG InstaView™ Refrigerator & Craft Ice™
  // =========================================================================
  Widget _buildInstaViewFridgeTab(BuildContext context) {
    final state = context.watch<RealHomeProvider>();
    final dev = state.devices
            .where((d) =>
                d.id.contains('fridge') ||
                d.id.contains('refrigerator') ||
                d.category == 'fridge')
            .firstOrNull ??
        widget.initialDevice;

    final isCraftIce = dev?.craftIceEnabled ?? true;
    final isExpressFreeze = dev?.expressFreezeActive ?? false;
    final isExpressCool = dev?.expressCoolActive ?? false;
    final fridgeTemp = dev?.fridgeTemp ?? 3.0;
    final freezerTemp = dev?.freezerTemp ?? -19.0;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // InstaView Tinted Glass Interactive Panel (Knock Twice)
          GestureDetector(
            onTap: _triggerDoubleKnock,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isGlassIlluminated
                    ? const Color(0xFF1E2D4A)
                    : const Color(0xFF0A0F1D),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: _isGlassIlluminated
                      ? Colors.amberAccent.withValues(alpha: 0.6)
                      : Colors.white24,
                  width: 1.5,
                ),
                boxShadow: _isGlassIlluminated
                    ? [
                        BoxShadow(
                          color: Colors.amberAccent.withValues(alpha: 0.25),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isGlassIlluminated
                                ? Icons.lightbulb_rounded
                                : Icons.touch_app_rounded,
                            color: _isGlassIlluminated
                                ? Colors.amberAccent
                                : Colors.cyanAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isGlassIlluminated
                                ? 'InstaView™ Illuminated (Glass Transparent)'
                                : 'InstaView™ Tinted Glass (Knock Twice)',
                            style: TextStyle(
                              color: _isGlassIlluminated
                                  ? Colors.amberAccent
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _isGlassIlluminated ? 'TRANSPARENT' : 'TINTED',
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 9,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Interior items revealed when glass illuminates
                  if (_isGlassIlluminated)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: const [
                          _FridgeItemTag(icon: Icons.local_drink_rounded, label: 'Beverages', count: '6 Cans'),
                          _FridgeItemTag(icon: Icons.egg_rounded, label: 'Fresh Milk', count: '100% Full'),
                          _FridgeItemTag(icon: Icons.apple_rounded, label: 'Crisper', count: 'Fresh'),
                        ],
                      ),
                    )
                  else
                    Container(
                      height: 50,
                      alignment: Alignment.center,
                      child: const Text(
                        'Tap here or knock twice to illuminate inside without opening the door',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Craft Ice™ Spherical Ice Maker
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.cyanAccent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.circle_rounded, color: Colors.cyanAccent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Craft Ice™ Dual Maker',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                      Text(
                        'Slow-melting 50mm spherical ice balls (3-6/day)',
                        style: TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isCraftIce,
                  activeColor: Colors.cyanAccent,
                  onChanged: (val) {
                    if (dev != null) {
                      state.updateLgFridge(dev.id, craftIce: val);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // LinearCooling™ & DoorCooling+™ Controls
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Fridge Compartment',
                          style: TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                        Text(
                          '${fridgeTemp.round()}°C (LinearCooling™ ±0.5°)',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Text('Express Cool',
                            style: TextStyle(color: Colors.white70, fontSize: 11)),
                        const SizedBox(width: 6),
                        Switch(
                          value: isExpressCool,
                          activeColor: Colors.lightBlueAccent,
                          onChanged: (v) {
                            if (dev != null) {
                              state.updateLgFridge(dev.id, expressCool: v);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(color: Colors.white12, height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Freezer Compartment',
                          style: TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                        Text(
                          '${freezerTemp.round()}°C',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Text('Express Freeze',
                            style: TextStyle(color: Colors.white70, fontSize: 11)),
                        const SizedBox(width: 6),
                        Switch(
                          value: isExpressFreeze,
                          activeColor: Colors.blueAccent,
                          onChanged: (v) {
                            if (dev != null) {
                              state.updateLgFridge(dev.id, expressFreeze: v);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 2: LG PuriCare™ AeroTower (Clean Booster & 360° Airflow)
  // =========================================================================
  Widget _buildAeroTowerTab(BuildContext context) {
    final state = context.watch<RealHomeProvider>();
    final dev = state.devices
            .where((d) =>
                d.id.contains('aerotower') ||
                d.id.contains('puricare') ||
                d.category.contains('purifier'))
            .firstOrNull ??
        widget.initialDevice;

    final isPowered = dev?.isOn ?? true;
    final tiltAngle = dev?.cleanBoosterTiltAngle ?? 55;
    final airflowMode = dev?.aeroTowerAirflowMode ?? 'Wide';
    final isUvNano = dev?.uvNanoEnabled ?? true;
    final pm1 = dev?.pm1LaserIndex ?? 9;

    Color haloColor;
    String haloLabel;
    if (pm1 <= 12) {
      haloColor = Colors.blueAccent;
      haloLabel = 'Good (Blue)';
    } else if (pm1 <= 35) {
      haloColor = Colors.greenAccent;
      haloLabel = 'Normal (Green)';
    } else if (pm1 <= 55) {
      haloColor = Colors.orangeAccent;
      haloLabel = 'Unhealthy (Yellow)';
    } else {
      haloColor = Colors.redAccent;
      haloLabel = 'Very Unhealthy (Red)';
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PM1.0 Laser Air Quality Halo Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF131D33),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: haloColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: haloColor, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: haloColor.withValues(alpha: 0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$pm1',
                    style: TextStyle(
                      color: haloColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'PM1.0 Laser Sensor: $haloLabel',
                            style: TextStyle(
                              color: haloColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const Text(
                        'Real-time particulate detection (μg/m³)',
                        style: TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isPowered,
                  activeColor: haloColor,
                  onChanged: (v) {
                    if (dev != null) state.toggleDevicePower(dev);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Clean Booster™ 55° Pop-Up Fan Controls
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Clean Booster™ Pop-up Fan',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                    Text(
                      'Tilt: $tiltAngle°',
                      style: const TextStyle(
                          color: Colors.cyanAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Motorized booster rises and projects clean air up to 7.5 meters',
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
                Slider(
                  value: tiltAngle.toDouble(),
                  min: 0,
                  max: 55,
                  divisions: 11,
                  activeColor: Colors.cyanAccent,
                  inactiveColor: Colors.white12,
                  onChanged: (val) {
                    if (dev != null) {
                      state.updateLgAeroTower(dev.id, cleanBoosterTilt: val.round());
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3-Way Airflow Engine Selector (Direct, Wide, Diffusion)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AeroTower Airflow Dispersion Mode',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
                const SizedBox(height: 10),
                Row(
                  children: ['Direct', 'Wide', 'Diffusion'].map((mode) {
                    final isSel = airflowMode == mode;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(mode, style: const TextStyle(fontSize: 11)),
                          selected: isSel,
                          selectedColor: const Color(0xFFA50034),
                          backgroundColor: Colors.white10,
                          labelStyle: TextStyle(
                            color: isSel ? Colors.white : Colors.white60,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (val) {
                            if (val && dev != null) {
                              state.updateLgAeroTower(dev.id, airflowMode: mode);
                            }
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // UVnano™ Blade Sterilization
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_rounded, color: Colors.purpleAccent, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'UVnano™ Fan Blade Sterilization',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                      Text(
                        'Eliminates 99.99% of bacteria on internal fan blades',
                        style: TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isUvNano,
                  activeColor: Colors.purpleAccent,
                  onChanged: (val) {
                    if (dev != null) {
                      state.updateLgAeroTower(dev.id, uvNano: val);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 3: LG Styler® Steam Closet & QuadWash™ Dishwasher
  // =========================================================================
  Widget _buildStylerAndDishwasherTab(BuildContext context) {
    final state = context.watch<RealHomeProvider>();
    final stylerDev = state.devices
            .where((d) => d.id.contains('styler') || d.category == 'styler')
            .firstOrNull ??
        widget.initialDevice;

    final movingHangerRpm = stylerDev?.movingHangerRpm ?? 180;
    final isTrueSteam = stylerDev?.trueSteamActive ?? true;
    final isPantsCrease = stylerDev?.pantsCreaseCare ?? true;
    final isUpdateAvail = stylerDev?.thinqUpUpdateAvailable ?? true;
    final updateFeatureName = stylerDev?.thinqUpFeatureName ?? 'Pet Care Cycle & Gentle Dry Wave';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LG Styler Moving Hanger™ Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.dry_cleaning_rounded, color: Colors.orangeAccent, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'LG Styler® Moving Hanger™',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                      ],
                    ),
                    Text(
                      '$movingHangerRpm RPM',
                      style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Mechanical oscillation shaking dust, smoke, and pollen from fabrics',
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
                Slider(
                  value: movingHangerRpm.toDouble(),
                  min: 0,
                  max: 200,
                  divisions: 10,
                  activeColor: Colors.orangeAccent,
                  inactiveColor: Colors.white12,
                  onChanged: (val) {
                    if (stylerDev != null) {
                      state.updateLgStyler(stylerDev.id, movingHangerRpm: val.round());
                    }
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('TrueSteam®',
                            style: TextStyle(color: Colors.white70, fontSize: 11)),
                        const SizedBox(width: 4),
                        Switch(
                          value: isTrueSteam,
                          activeColor: Colors.orangeAccent,
                          onChanged: (v) {
                            if (stylerDev != null) {
                              state.updateLgStyler(stylerDev.id, trueSteam: v);
                            }
                          },
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Text('Pants Crease Care',
                            style: TextStyle(color: Colors.white70, fontSize: 11)),
                        const SizedBox(width: 4),
                        Switch(
                          value: isPantsCrease,
                          activeColor: Colors.amberAccent,
                          onChanged: (v) {
                            if (stylerDev != null) {
                              state.updateLgStyler(stylerDev.id, pantsCrease: v);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // LG QuadWash™ Dishwasher Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.countertops_rounded, color: Colors.tealAccent, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'LG QuadWash™ Steam Dishwasher',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  '4 Multi-Motion spray arms with Dual Zone variable wash intensity',
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('Auto Door Open Drying',
                        style: TextStyle(color: Colors.white70, fontSize: 11)),
                    Text('READY',
                        style: TextStyle(
                            color: Colors.tealAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // LG ThinQ UP™ Upgrade Center Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1E1B4B),
                  const Color(0xFFA50034).withValues(alpha: 0.3),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.system_update_rounded, color: Colors.pinkAccent, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'LG ThinQ UP™ Upgrade Center',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.pinkAccent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isUpdateAvail ? 'NEW' : 'UPDATED',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  isUpdateAvail
                      ? 'Downloadable Feature: $updateFeatureName'
                      : 'Appliance running latest ThinQ UP firmware package',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(height: 10),
                if (isUpdateAvail)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFA50034),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Install ThinQ UP Feature'),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        if (stylerDev != null) {
                          state.triggerLgThinqUp(
                            stylerDev.id,
                            installedFeature: updateFeatureName,
                          );
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // LG Smart Diagnosis™ 3.0 Launch Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.health_and_safety_rounded, color: Colors.blueAccent),
              label: const Text('Run LG Smart Diagnosis™ 3.0'),
              onPressed: () {
                if (stylerDev != null) {
                  SmartDiagnosisDialog.show(context, stylerDev);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FridgeItemTag extends StatelessWidget {
  final IconData icon;
  final String label;
  final String count;

  const _FridgeItemTag({
    required this.icon,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.amberAccent, size: 24),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        Text(count, style: const TextStyle(color: Colors.white54, fontSize: 9)),
      ],
    );
  }
}
