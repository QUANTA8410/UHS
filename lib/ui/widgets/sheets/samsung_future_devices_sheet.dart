import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/real_home_provider.dart';
import '../../../services/real_iot_controller.dart';
import 'lg_thinq_ac_sheet.dart';

/// Interactive SmartKit Sheet for Future Samsung Ecosystem Appliances
/// Reverse-engineered from SmartThings APK:
/// 1. WindFree™ AC (com.samsung.android.plugin.airconditioner.v3)
/// 2. Family Hub Refrigerator (com.samsung.android.plugin.refrigerator.v2)
/// 3. The Frame / Smart TV (com.samsung.android.plugin.tv.v3)
class SamsungFutureDevicesSheet extends StatefulWidget {
  final RealSmartDevice? initialDevice;
  final int initialTabIndex; // 0: AC, 1: Fridge, 2: The Frame TV

  const SamsungFutureDevicesSheet({
    super.key,
    this.initialDevice,
    this.initialTabIndex = 0,
  });

  @override
  State<SamsungFutureDevicesSheet> createState() =>
      _SamsungFutureDevicesSheetState();
}

class _SamsungFutureDevicesSheetState extends State<SamsungFutureDevicesSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
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
                  color: Colors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.devices_other_rounded,
                    color: Colors.cyanAccent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Samsung SmartKit™ Device Studio',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Future Ecosystem Devices & Next-Gen Controls',
                      style: TextStyle(fontSize: 11, color: Colors.white60),
                    ),
                  ],
                ),
              ),
              if (widget.initialDevice != null)
                IconButton(
                  tooltip: 'LG ThinQ™ AC View',
                  icon: const Icon(Icons.swap_horiz_rounded, color: Colors.cyanAccent),
                  onPressed: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      barrierColor: Colors.black.withValues(alpha: 0.65),
                      builder: (ctx) => LgThinqAcSheet(device: widget.initialDevice!),
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

          // Device Tab Selector
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.blueAccent,
                borderRadius: BorderRadius.circular(20),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: 'WindFree™ AC'),
                Tab(text: 'Family Hub Fridge'),
                Tab(text: 'The Frame TV'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Tab Content
          Flexible(
            child: SizedBox(
              height: 520,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildWindFreeAcTab(context),
                  _buildFamilyHubFridgeTab(context),
                  _buildTheFrameTvTab(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 1: Samsung WindFree™ AC
  // =========================================================================
  Widget _buildWindFreeAcTab(BuildContext context) {
    final state = context.watch<RealHomeProvider>();
    final acDevice = state.devices
            .where((d) =>
                d.category.toLowerCase().contains('ac') ||
                d.category.toLowerCase().contains('climate'))
            .firstOrNull ??
        widget.initialDevice;

    final isWindFree = acDevice?.windFreeEnabled ?? true;
    final isGoodSleep = acDevice?.goodSleepActive ?? false;
    final pm1 = acDevice?.pm1AirQuality ?? 11;
    final isAiEnergy = acDevice?.aiEnergyMode ?? true;
    final currentTemp = acDevice?.primaryValue ?? 23.0;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Louver vs 23,000 Micro-hole Dispersion Stage
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF131D33),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isWindFree ? Colors.cyanAccent.withValues(alpha: 0.4) : Colors.white10,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isWindFree
                                  ? Icons.grain_rounded
                                  : Icons.air_rounded,
                              color: isWindFree ? Colors.cyanAccent : Colors.lightBlueAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isWindFree
                                  ? 'WindFree™ Still Air Cooling'
                                  : 'High-Velocity Directional Louver',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          isWindFree
                            ? 'Dispersing through 23,000 micro-holes (<0.15 m/s)'
                            : 'Standard motorized louver open',
                          style: const TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                      ],
                    ),
                    Switch(
                      value: isWindFree,
                      activeColor: Colors.cyanAccent,
                      onChanged: (val) {
                        if (acDevice != null) {
                          state.updateSamsungAc(acDevice.id, windFree: val);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Animated Micro-hole Mesh Graphic
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 52,
                    width: double.infinity,
                    color: const Color(0xFF090E1A),
                    child: CustomPaint(
                      painter: _WindFreeMeshPainter(isWindFree: isWindFree),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Temperature & GoodSleep Thermal Curve
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
                    Text(
                      'Cooling Setpoint: ${currentTemp.round()}°C',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                    Row(
                      children: [
                        IconButton.filledTonal(
                          iconSize: 16,
                          icon: const Icon(Icons.remove_rounded),
                          onPressed: () {
                            if (acDevice != null) {
                              state.setDevicePrimaryValue(
                                  acDevice.id, (currentTemp - 1).clamp(16.0, 30.0));
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          iconSize: 16,
                          icon: const Icon(Icons.add_rounded),
                          onPressed: () {
                            if (acDevice != null) {
                              state.setDevicePrimaryValue(
                                  acDevice.id, (currentTemp + 1).clamp(16.0, 30.0));
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(color: Colors.white12, height: 20),

                // GoodSleep 3-Stage Nocturnal Thermal Curve
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.bedtime_rounded,
                            color: Colors.purpleAccent, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'GoodSleep™ AI Nocturnal Curve',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                      ],
                    ),
                    Switch(
                      value: isGoodSleep,
                      activeColor: Colors.purpleAccent,
                      onChanged: (val) {
                        if (acDevice != null) {
                          state.updateSamsungAc(acDevice.id, goodSleep: val);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildSleepStage(
                        '1. Falling Asleep', '22°C Deep induction', Colors.blue),
                    const SizedBox(width: 6),
                    _buildSleepStage(
                        '2. Sound Sleep', '24°C Restful comfort', Colors.purple),
                    const SizedBox(width: 6),
                    _buildSleepStage(
                        '3. Wake-up', '25°C Fresh breeze', Colors.teal),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // PM1.0 Laser Air Quality Halo & AI Energy Mode
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getPmColor(pm1).withValues(alpha: 0.2),
                          border: Border.all(color: _getPmColor(pm1), width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$pm1',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getPmColor(pm1),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('PM1.0 Laser Halo',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11)),
                          Text(
                            _getPmLabel(pm1),
                            style: TextStyle(
                                color: _getPmColor(pm1), fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('AI Energy Mode',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11)),
                          Text('Frequency throttle',
                              style: TextStyle(
                                  color: Colors.white60, fontSize: 10)),
                        ],
                      ),
                      Switch(
                        value: isAiEnergy,
                        activeColor: Colors.greenAccent,
                        onChanged: (val) {
                          if (acDevice != null) {
                            state.updateSamsungAc(acDevice.id, aiEnergyMode: val);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSleepStage(String stage, String desc, MaterialColor color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: color.shade900.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.shade400.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(stage,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color.shade200)),
            const SizedBox(height: 2),
            Text(desc,
                style: const TextStyle(fontSize: 8, color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Color _getPmColor(int pm1) {
    if (pm1 <= 15) return Colors.blueAccent;
    if (pm1 <= 35) return Colors.greenAccent;
    if (pm1 <= 75) return Colors.amberAccent;
    return Colors.redAccent;
  }

  String _getPmLabel(int pm1) {
    if (pm1 <= 15) return 'Clean Air';
    if (pm1 <= 35) return 'Moderate';
    if (pm1 <= 75) return 'Unhealthy';
    return 'Hazardous';
  }

  // =========================================================================
  // TAB 2: Samsung Family Hub Refrigerator
  // =========================================================================
  Widget _buildFamilyHubFridgeTab(BuildContext context) {
    final state = context.watch<RealHomeProvider>();
    final fridgeDevice = state.devices
            .where((d) =>
                d.category.toLowerCase().contains('fridge') ||
                d.category.toLowerCase().contains('refrigerat'))
            .firstOrNull ??
        widget.initialDevice;

    final fridgeTemp = fridgeDevice?.fridgeTemp ?? 3.0;
    final freezerTemp = fridgeDevice?.freezerTemp ?? -19.0;
    final flexMode = fridgeDevice?.flexZoneMode ?? 'Beverage';
    final isPowerCool = fridgeDevice?.powerCool ?? false;
    final isPowerFreeze = fridgeDevice?.powerFreeze ?? false;
    final isIceBites = fridgeDevice?.iceBitesEnabled ?? true;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // View Inside Camera Card with Food Expiration Tags
          Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.camera_indoor_rounded,
                          color: Colors.white38, size: 36),
                      SizedBox(height: 6),
                      Text(
                        'Family Hub View Inside™ Camera',
                        style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                      Text('Auto snapshot taken on door close',
                          style: TextStyle(color: Colors.white38, fontSize: 10)),
                    ],
                  ),
                ),
                // Expiration Tag Overlays
                Positioned(
                  left: 20,
                  top: 20,
                  child: _buildFoodTag('🥛 Whole Milk', '2d left', Colors.amber),
                ),
                Positioned(
                  right: 24,
                  top: 30,
                  child: _buildFoodTag('🍓 Fresh Berries', 'Fresh', Colors.green),
                ),
                Positioned(
                  left: 40,
                  bottom: 20,
                  child: _buildFoodTag('🥚 Organic Eggs', '6d left', Colors.cyan),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Independent 3-Zone Cooling Controls
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Triple Cooling Independent Zones',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildTempZone(
                      label: 'Fridge',
                      val: '${fridgeTemp.round()}°C',
                      range: '1°C ~ 7°C',
                      onMinus: () {
                        if (fridgeDevice != null) {
                          state.updateSamsungFridge(fridgeDevice.id,
                              fridgeTemp: (fridgeTemp - 1).clamp(1.0, 7.0));
                        }
                      },
                      onPlus: () {
                        if (fridgeDevice != null) {
                          state.updateSamsungFridge(fridgeDevice.id,
                              fridgeTemp: (fridgeTemp + 1).clamp(1.0, 7.0));
                        }
                      },
                    ),
                    const SizedBox(width: 10),
                    _buildTempZone(
                      label: 'Freezer',
                      val: '${freezerTemp.round()}°C',
                      range: '-23°C ~ -15°C',
                      onMinus: () {
                        if (fridgeDevice != null) {
                          state.updateSamsungFridge(fridgeDevice.id,
                              freezerTemp: (freezerTemp - 1).clamp(-23.0, -15.0));
                        }
                      },
                      onPlus: () {
                        if (fridgeDevice != null) {
                          state.updateSamsungFridge(fridgeDevice.id,
                              freezerTemp: (freezerTemp + 1).clamp(-23.0, -15.0));
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // FlexZone Mode Selector
                const Text('FlexZone™ / CoolSelect+ Drawer',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    _buildFlexChip('Beverage 4°C', flexMode == 'Beverage', () {
                      if (fridgeDevice != null) {
                        state.updateSamsungFridge(fridgeDevice.id, flexZoneMode: 'Beverage');
                      }
                    }),
                    _buildFlexChip('Deli/Meat 2°C', flexMode == 'Deli', () {
                      if (fridgeDevice != null) {
                        state.updateSamsungFridge(fridgeDevice.id, flexZoneMode: 'Deli');
                      }
                    }),
                    _buildFlexChip('Fish -1°C', flexMode == 'Fish', () {
                      if (fridgeDevice != null) {
                        state.updateSamsungFridge(fridgeDevice.id, flexZoneMode: 'Fish');
                      }
                    }),
                    _buildFlexChip('Wine 5°C', flexMode == 'Wine', () {
                      if (fridgeDevice != null) {
                        state.updateSamsungFridge(fridgeDevice.id, flexZoneMode: 'Wine');
                      }
                    }),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Turbo Cool & Ice Maker Toggles
          Row(
            children: [
              Expanded(
                child: FilterChip(
                  avatar: const Icon(Icons.flash_on_rounded, size: 16),
                  label: const Text('Power Cool'),
                  selected: isPowerCool,
                  onSelected: (val) {
                    if (fridgeDevice != null) {
                      state.updateSamsungFridge(fridgeDevice.id, powerCool: val);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilterChip(
                  avatar: const Icon(Icons.ac_unit_rounded, size: 16),
                  label: const Text('Power Freeze'),
                  selected: isPowerFreeze,
                  onSelected: (val) {
                    if (fridgeDevice != null) {
                      state.updateSamsungFridge(fridgeDevice.id, powerFreeze: val);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilterChip(
                  avatar: const Icon(Icons.icecream_rounded, size: 16),
                  label: Text(isIceBites ? 'Ice Bites™' : 'Cubed Ice'),
                  selected: isIceBites,
                  onSelected: (val) {
                    if (fridgeDevice != null) {
                      state.updateSamsungFridge(fridgeDevice.id, iceBites: val);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFoodTag(String name, String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name,
              style: const TextStyle(
                  color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(status,
                style: TextStyle(
                    color: color, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTempZone({
    required String label,
    required String val,
    required String range,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(val,
                style: const TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            Text(range,
                style: const TextStyle(color: Colors.white38, fontSize: 9)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  iconSize: 14,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: const Icon(Icons.remove),
                  onPressed: onMinus,
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  iconSize: 14,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: const Icon(Icons.add),
                  onPressed: onPlus,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlexChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? Colors.teal : Colors.white10,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.white60,
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 3: Samsung Smart TV & The Frame
  // =========================================================================
  Widget _buildTheFrameTvTab(BuildContext context) {
    final state = context.watch<RealHomeProvider>();
    final tvDevice = state.devices
            .where((d) =>
                d.category.toLowerCase().contains('tv') ||
                d.category.toLowerCase().contains('display'))
            .firstOrNull ??
        widget.initialDevice;

    final isArtMode = tvDevice?.artModeEnabled ?? true;
    final isLightSync = tvDevice?.lightSyncEnabled ?? true;
    final currentArtwork = tvDevice?.selectedArtwork ?? 'Starry Night';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Art Mode Hero Showcase
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isArtMode ? Colors.amberAccent.withValues(alpha: 0.5) : Colors.white10,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.brush_rounded,
                            color: Colors.amberAccent, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'The Frame Art Mode',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: isArtMode,
                      activeColor: Colors.amberAccent,
                      onChanged: (val) {
                        if (tvDevice != null) {
                          state.updateSamsungTv(tvDevice.id, artMode: val);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Simulated Frame Canvas
                Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2416),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF8B6B38), width: 6),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.palette_rounded,
                            color: Colors.amber, size: 32),
                        const SizedBox(height: 6),
                        Text(
                          currentArtwork,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const Text(
                          'Matte Display • Ambient Photodiode Matched',
                          style: TextStyle(color: Colors.white60, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Artwork Picker
                Wrap(
                  spacing: 6,
                  children: [
                    _buildArtChip('Starry Night', currentArtwork == 'Starry Night', () {
                      if (tvDevice != null) {
                        state.updateSamsungTv(tvDevice.id, selectedArtwork: 'Starry Night');
                      }
                    }),
                    _buildArtChip('Water Lilies', currentArtwork == 'Water Lilies', () {
                      if (tvDevice != null) {
                        state.updateSamsungTv(tvDevice.id, selectedArtwork: 'Water Lilies');
                      }
                    }),
                    _buildArtChip('The Great Wave', currentArtwork == 'The Great Wave', () {
                      if (tvDevice != null) {
                        state.updateSamsungTv(tvDevice.id, selectedArtwork: 'The Great Wave');
                      }
                    }),
                    _buildArtChip('Sunset Impression', currentArtwork == 'Sunset Impression', () {
                      if (tvDevice != null) {
                        state.updateSamsungTv(tvDevice.id, selectedArtwork: 'Sunset Impression');
                      }
                    }),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Ambient Light Sync (SmartkitVD lightsync)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_awesome_motion_rounded,
                      color: Colors.purpleAccent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Ambient Light Sync (lightsync)',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                      Text(
                        'Streams edge video color gradients to room RGB lighting fixtures',
                        style: TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isLightSync,
                  activeColor: Colors.purpleAccent,
                  onChanged: (val) {
                    if (tvDevice != null) {
                      state.updateSamsungTv(tvDevice.id, lightSync: val);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Local Matter & Thread Hub Controller (libCHIPController.so)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: const [
                Icon(Icons.hub_rounded, color: Colors.blueAccent, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Built-in SmartThings & Matter Hub',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                      Text(
                        'libCHIPController.so • Local Thread Border Router Active',
                        style: TextStyle(color: Colors.cyanAccent, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? Colors.amber : Colors.white10,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.black : Colors.white60,
          ),
        ),
      ),
    );
  }
}

/// CustomPainter for the WindFree 23,000 Micro-hole Matrix
class _WindFreeMeshPainter extends CustomPainter {
  final bool isWindFree;

  _WindFreeMeshPainter({required this.isWindFree});

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = isWindFree
          ? Colors.cyanAccent.withValues(alpha: 0.45)
          : Colors.white12
      ..style = PaintingStyle.fill;

    // Draw dense micro-dot grid
    const spacing = 8.0;
    for (double y = 6; y < size.height - 4; y += spacing) {
      for (double x = 8; x < size.width - 6; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WindFreeMeshPainter oldDelegate) {
    return oldDelegate.isWindFree != isWindFree;
  }
}
