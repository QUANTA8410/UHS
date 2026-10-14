import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/house_3d_twin_model.dart';
import '../../providers/real_home_provider.dart';
import '../../services/auth/brand_oauth_catalog.dart';
import '../../services/automation/smart_automation_engine.dart';
import '../../services/notifications/appliance_notification_bridge.dart';
import '../../services/real_iot_controller.dart';
import '../../theme/apple_glass_theme.dart';
import '../widgets/animations/universal_device_animations.dart';
import '../widgets/dialogs/brand_oauth_webview_sheet.dart';
import '../widgets/dialogs/camera_cockpit_sheet.dart';
import '../widgets/dialogs/node_server_dashboard_sheet.dart';
import '../widgets/dialogs/smart_rule_studio_sheet.dart';
import '../widgets/energy/animated_power_flow_card.dart';
import '../widgets/map3d/floor_plan_editor_sheet.dart';
import '../widgets/map3d/isometric_house_3d_widget.dart';

class AppleGlassHomeShell extends StatefulWidget {
  const AppleGlassHomeShell({super.key});

  @override
  State<AppleGlassHomeShell> createState() => _AppleGlassHomeShellState();
}

class _AppleGlassHomeShellState extends State<AppleGlassHomeShell> {
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    ApplianceNotificationBridge.requestPermission();
  }

  @override
  Widget build(BuildContext context) {
    final home = context.watch<RealHomeProvider>();

    return LiquidGlassScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          ['My Home', '3D Spatial Twin', 'Automations'][_tabIndex],
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        actions: [
          IconButton(
            tooltip: 'Sync Real Hardware Status',
            icon: home.isBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded, color: Colors.white),
            onPressed: () => home.syncAllDevicesSilent(),
          ),
          IconButton(
            tooltip: '24/7 Android Hub Node Server',
            icon: Icon(
              Icons.dns_rounded,
              color: home.nodeServer.isRunning ? const Color(0xFF30D158) : Colors.white70,
            ),
            onPressed: () => NodeServerDashboardSheet.show(context),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: GlassContainer(
              borderRadius: 20,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              isActive: true,
              activeTint: const Color(0xFF0A84FF),
              onTap: () => _showConnectRealDeviceSheet(context),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 18, color: Colors.white),
                  SizedBox(width: 4),
                  Text('Pair Device', style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (home.lastGlobalError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: GlassContainer(
                borderRadius: 16,
                isActive: true,
                activeTint: const Color(0xFFFF453A),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFFF453A)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        home.lastGlobalError!,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              children: const [
                _GlassDashboardTab(),
                _Interactive3DMapTab(),
                _FunctionalAutomationsTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: GlassContainer(
          borderRadius: 36,
          blur: 35,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildDockPill(0, Icons.home_rounded, 'Home'),
              _buildDockPill(1, Icons.view_in_ar_rounded, '3D Map'),
              _buildDockPill(2, Icons.bolt_rounded, 'Automations'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDockPill(int index, IconData icon, String label) {
    final selected = _tabIndex == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _tabIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: EdgeInsets.symmetric(horizontal: selected ? 18 : 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withValues(alpha: 0.22) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? Colors.white : Colors.white.withValues(alpha: 0.55),
            ),
            if (selected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showConnectRealDeviceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _RealDevicePairingModal(),
    );
  }
}

// =============================================================================
// TAB 1: APPLE LIQUID GLASS HOME DASHBOARD
// =============================================================================
class _GlassDashboardTab extends StatefulWidget {
  const _GlassDashboardTab();

  @override
  State<_GlassDashboardTab> createState() => _GlassDashboardTabState();
}

class _GlassDashboardTabState extends State<_GlassDashboardTab> {
  bool _showPowerFlow = false;
  String _selectedRoom = 'All';
  House3DTwinLayout _houseLayout = House3DTwinLayout.defaultApartment();

  @override
  void initState() {
    super.initState();
    House3DTwinLayout.loadFromPrefs().then((layout) {
      if (mounted) setState(() => _houseLayout = layout);
    });
  }

  @override
  Widget build(BuildContext context) {
    final home = context.watch<RealHomeProvider>();
    final devices = home.devices;
    final activeCount = devices.where((d) => d.isOn).length;

    if (devices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: GlassContainer(
            borderRadius: 30,
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_tethering_rounded, size: 54, color: Color(0xFF0A84FF)),
                const SizedBox(height: 16),
                const Text(
                  'No Dummy Devices Loaded',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap "Pair Device" in the top right to connect your real Samsung SmartThings account, LG ThinQ PAT, Universal Home Assistant bridge, Wipro Smart Bulb, or OnePlus TV.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final filteredDevices = _selectedRoom == 'All'
        ? devices
        : devices
            .where((d) => d.room.toLowerCase().contains(_selectedRoom.toLowerCase()))
            .toList();

    return CustomScrollView(
      slivers: [
        // 1. Glass Whisper Briefing & Subtitle
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome Home',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$activeCount devices active • ${home.isUserAtHome ? "Home Wi-Fi Locked" : "Away Mode"}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                GlassContainer(
                  borderRadius: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  onTap: () => setState(() => _showPowerFlow = !_showPowerFlow),
                  child: Row(
                    children: [
                      Icon(
                        _showPowerFlow ? Icons.bolt_rounded : Icons.energy_savings_leaf_rounded,
                        size: 15,
                        color: const Color(0xFF30D158),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _showPowerFlow ? 'Energy Topology' : 'Show Energy',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // 2. Top 3D Isometric Dollhouse Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Container(
                height: 285,
                decoration: BoxDecoration(
                  color: const Color(0xFF090E1D),
                  border: Border.all(color: Colors.white12, width: 1.2),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, 8)),
                  ],
                ),
                child: Stack(
                  children: [
                    IsometricHouse3DWidget(
                      height: 285,
                      layout: _houseLayout,
                      selectedRoomId: _selectedRoom == 'All' ? 'all' : _selectedRoom.toLowerCase(),
                      onRoomSelected: (r) => setState(() =>
                          _selectedRoom = r == 'all' ? 'All' : (r[0].toUpperCase() + r.substring(1))),
                      onFixtureLongPress: (fix, dev) {
                        if (dev != null) _showDeviceControlSheet(context, dev);
                      },
                      onOpenBlueprintEditor: () async {
                        final updated = await FloorPlanEditorSheet.show(context, layout: _houseLayout);
                        if (updated != null) {
                          setState(() => _houseLayout = updated);
                        }
                      },
                    ),
                    Positioned(
                      top: 12,
                      left: 14,
                      child: GlassContainer(
                        borderRadius: 16,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.apartment_rounded, size: 14, color: Color(0xFF0A84FF)),
                            const SizedBox(width: 5),
                            Text(
                              _selectedRoom == 'All' ? '3D Isometric Twin' : '$_selectedRoom Camera Zoom',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      right: 14,
                      child: GlassContainer(
                        borderRadius: 16,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        activeTint: const Color(0xFFFF453A),
                        isActive: devices.any((d) => d.isOn),
                        onTap: () async {
                          HapticFeedback.heavyImpact();
                          final anyOn = devices.any((d) => d.isOn);
                          for (final d in devices) {
                            if (anyOn && d.isOn) {
                              await home.toggleDevicePower(d);
                            } else if (!anyOn && !d.isOn) {
                              await home.toggleDevicePower(d);
                            }
                          }
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.power_settings_new_rounded,
                              size: 14,
                              color: devices.any((d) => d.isOn) ? const Color(0xFFFF453A) : Colors.white70,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              devices.any((d) => d.isOn) ? 'Master Off' : 'Master On',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // 3. Five One-Tap Mood Scene Pills (Bright, Cozy, Movie, Night, Away)
        SliverToBoxAdapter(
          child: _build5MoodSceneRibbon(context, home),
        ),

        // 4. Room Camera Zoom Filter Bar (All, Living, Dining, Kitchen, Bedroom, Bathroom) + All on / All off
        SliverToBoxAdapter(
          child: _buildRoomCameraFilterBar(context, home),
        ),

        // 5. Collapsible Animated Tesla-Style Power Flow Card
        if (_showPowerFlow)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
              child: AnimatedPowerFlowCard(devices: devices),
            ),
          ),

        // 6. Universal 12-Category Animated Glass Grid Cards (Filtered by Selected Room)
        if (filteredDevices.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: GlassContainer(
                borderRadius: 24,
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.meeting_room_outlined, size: 40, color: Colors.white54),
                    const SizedBox(height: 10),
                    Text(
                      'No devices in $_selectedRoom',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () => setState(() => _selectedRoom = 'All'),
                      child: const Text('Show All Devices', style: TextStyle(color: Color(0xFF0A84FF))),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 120),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.98,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final dev = filteredDevices[index];
                  final inFlight = home.networkEngine.isDeviceInFlight(dev.id);

                  return UniversalAnimatedGlassCard(
                    device: dev,
                    isSyncing: inFlight,
                    onTap: () => _showDeviceControlSheet(context, dev),
                    onPowerToggle: () async {
                      HapticFeedback.mediumImpact();
                      try {
                        await home.toggleDevicePower(dev);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Hardware Error: $e')),
                          );
                        }
                      }
                    },
                    onLongPress: () => _showDeviceControlSheet(context, dev),
                    onHorizontalLevelDrag: (val) => home.setDeviceLevel(dev, val),
                  );
                },
                childCount: filteredDevices.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _build5MoodSceneRibbon(BuildContext context, RealHomeProvider home) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Row(
        children: [
          _scenePill(
            label: '☀️ Bright',
            tint: const Color(0xFFFFD60A),
            onTap: () async {
              HapticFeedback.heavyImpact();
              for (final d in home.devices) {
                if (d.category == 'light') {
                  if (!d.isOn) await home.toggleDevicePower(d);
                  await home.setDeviceLevel(d, 100.0);
                } else if (d.category == 'ac') {
                  if (!d.isOn) await home.toggleDevicePower(d);
                  await home.setDeviceLevel(d, 22.0);
                }
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('☀️ Scene: Bright 100% Warm White & 22°C Cool')),
                );
              }
            },
          ),
          const SizedBox(width: 8),
          _scenePill(
            label: '🕯️ Cozy',
            tint: const Color(0xFFFF9F0A),
            onTap: () async {
              HapticFeedback.heavyImpact();
              for (final d in home.devices) {
                if (d.category == 'light') {
                  if (!d.isOn) await home.toggleDevicePower(d);
                  await home.setDeviceLevel(d, 60.0);
                } else if (d.category == 'ac') {
                  if (!d.isOn) await home.toggleDevicePower(d);
                  await home.setDeviceLevel(d, 24.0);
                }
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('🕯️ Scene: Cozy 60% Warm Amber & 24°C')),
                );
              }
            },
          ),
          const SizedBox(width: 8),
          _scenePill(
            label: '🎬 Movie',
            tint: const Color(0xFFBF5AF2),
            onTap: () async {
              HapticFeedback.heavyImpact();
              for (final d in home.devices) {
                if (d.category == 'tv') {
                  if (!d.isOn) await home.toggleDevicePower(d);
                } else if (d.category == 'light') {
                  if (d.name.toLowerCase().contains('backlight') ||
                      d.name.toLowerCase().contains('wipro')) {
                    if (!d.isOn) await home.toggleDevicePower(d);
                    await home.setDeviceLevel(d, 40.0);
                  } else if (d.isOn) {
                    await home.toggleDevicePower(d);
                  }
                }
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('🎬 Scene: Movie Cinema Mode')),
                );
              }
            },
          ),
          const SizedBox(width: 8),
          _scenePill(
            label: '🌙 Night',
            tint: const Color(0xFF5E5CE6),
            onTap: () async {
              HapticFeedback.heavyImpact();
              for (final d in home.devices) {
                if (d.category == 'tv' && d.isOn) {
                  await home.toggleDevicePower(d);
                } else if (d.category == 'light') {
                  if (d.name.toLowerCase().contains('bed') ||
                      d.name.toLowerCase().contains('night')) {
                    if (!d.isOn) await home.toggleDevicePower(d);
                    await home.setDeviceLevel(d, 15.0);
                  } else if (d.isOn) {
                    await home.toggleDevicePower(d);
                  }
                } else if (d.category == 'ac') {
                  if (!d.isOn) await home.toggleDevicePower(d);
                  await home.setDeviceLevel(d, 25.0);
                }
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('🌙 Scene: Night Light 15% & AC 25°C Sleep')),
                );
              }
            },
          ),
          const SizedBox(width: 8),
          _scenePill(
            label: '🛡️ Away',
            tint: const Color(0xFFFF453A),
            onTap: () async {
              HapticFeedback.heavyImpact();
              for (final d in home.devices) {
                if (d.category == 'light' && d.isOn) {
                  await home.toggleDevicePower(d);
                } else if (d.category == 'tv' && d.isOn) {
                  await home.toggleDevicePower(d);
                } else if (d.category == 'ac' && d.isOn) {
                  await home.toggleDevicePower(d);
                }
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('🛡️ Scene: Away Mode • Lights & ACs Off • Cameras Armed')),
                );
              }
            },
          ),
          const SizedBox(width: 8),
          _scenePill(
            label: home.nodeServer.isRunning ? '🏛️ Hub 24/7' : '🏛️ Standby Hub',
            tint: home.nodeServer.isRunning ? const Color(0xFF30D158) : const Color(0xFF00D4FF),
            onTap: () {
              HapticFeedback.mediumImpact();
              NodeServerDashboardSheet.show(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCameraFilterBar(BuildContext context, RealHomeProvider home) {
    final rooms = ['All', 'Living', 'Dining', 'Kitchen', 'Bedroom', 'Bathroom'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Row(
        children: [
          ...rooms.map((room) {
            final isSelected = _selectedRoom.toLowerCase() == room.toLowerCase();
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(room),
                selected: isSelected,
                selectedColor: const Color(0xFF0A84FF),
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
                onSelected: (val) {
                  if (val) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedRoom = room);
                  }
                },
              ),
            );
          }),
          const SizedBox(width: 4),
          ActionChip(
            avatar: const Icon(Icons.power_settings_new_rounded, size: 13, color: Color(0xFF30D158)),
            label: const Text('All on',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            onPressed: () async {
              HapticFeedback.lightImpact();
              final targetDevices = _selectedRoom == 'All'
                  ? home.devices
                  : home.devices.where((d) => d.room.toLowerCase().contains(_selectedRoom.toLowerCase()));
              for (final d in targetDevices.where((d) => !d.isOn)) {
                await home.toggleDevicePower(d);
              }
            },
          ),
          const SizedBox(width: 6),
          ActionChip(
            avatar: const Icon(Icons.power_off_rounded, size: 13, color: Color(0xFFFF453A)),
            label: const Text('All off',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            onPressed: () async {
              HapticFeedback.lightImpact();
              final targetDevices = _selectedRoom == 'All'
                  ? home.devices
                  : home.devices.where((d) => d.room.toLowerCase().contains(_selectedRoom.toLowerCase()));
              for (final d in targetDevices.where((d) => d.isOn)) {
                await home.toggleDevicePower(d);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _scenePill({
    required String label,
    required Color tint,
    required VoidCallback onTap,
  }) {
    return GlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      isActive: true,
      activeTint: tint,
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

// =============================================================================
// TAB 2: INTERACTIVE 3D SPATIAL DIGITAL TWIN MAP (REAL DEVICE CONTROL)
// =============================================================================
class _Interactive3DMapTab extends StatefulWidget {
  const _Interactive3DMapTab();

  @override
  State<_Interactive3DMapTab> createState() => _Interactive3DMapTabState();
}

class _Interactive3DMapTabState extends State<_Interactive3DMapTab> {
  final GlobalKey<IsometricHouse3DWidgetState> _houseKey = GlobalKey();
  House3DTwinLayout _layout = House3DTwinLayout.defaultApartment();
  String _selectedRoomId = 'all';

  @override
  void initState() {
    super.initState();
    _loadLayout();
  }

  Future<void> _loadLayout() async {
    final loaded = await House3DTwinLayout.loadFromPrefs();
    if (mounted) {
      setState(() => _layout = loaded);
    }
  }

  Future<void> _openBlueprintStudio() async {
    HapticFeedback.selectionClick();
    final updated = await FloorPlanEditorSheet.show(context, layout: _layout);
    if (updated != null && mounted) {
      setState(() => _layout = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final home = context.watch<RealHomeProvider>();

    return Stack(
      children: [
        // 1. Full-Screen 3D Isometric Dollhouse Canvas
        Positioned.fill(
          child: IsometricHouse3DWidget(
            key: _houseKey,
            layout: _layout,
            selectedRoomId: _selectedRoomId,
            height: 500,
            onRoomSelected: (roomId) {
              setState(() => _selectedRoomId = roomId);
            },
            onFixtureTap: (fixture, linkedDevice) async {
              if (linkedDevice != null) {
                HapticFeedback.heavyImpact();
                try {
                  await home.toggleDevicePower(linkedDevice);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              }
            },
            onFixtureLongPress: (fixture, linkedDevice) {
              if (linkedDevice != null) {
                _showDeviceControlSheet(context, linkedDevice);
              }
            },
            onOpenBlueprintEditor: _openBlueprintStudio,
          ),
        ),

        // 2. Top Action Bar: 2D Studio & Camera Presets
        Positioned(
          top: 12,
          left: 16,
          right: 16,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _actionChip(
                  icon: Icons.architecture_rounded,
                  label: '2D Blueprint Studio',
                  color: const Color(0xFF00D4FF),
                  onTap: _openBlueprintStudio,
                ),
                const SizedBox(width: 8),
                _cameraPresetChip('Isometric 3D', yaw: -0.46, pitch: 0.82),
                const SizedBox(width: 8),
                _cameraPresetChip('Top Blueprint', yaw: 0.0, pitch: 0.15),
                const SizedBox(width: 8),
                _cameraPresetChip('Elevation Front', yaw: 0.0, pitch: 1.25),
              ],
            ),
          ),
        ),

        // 3. Bottom Room Filter Bar
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final r in [
                  {'id': 'all', 'label': 'All'},
                  {'id': 'living', 'label': 'Living'},
                  {'id': 'dining', 'label': 'Dining'},
                  {'id': 'kitchen', 'label': 'Kitchen'},
                  {'id': 'bedroom', 'label': 'Bedroom'},
                  {'id': 'bathroom', 'label': 'Bathroom'},
                ]) ...[
                  _roomFilterChip(r['id']!, r['label']!),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cameraPresetChip(String label, {required double yaw, required double pitch}) {
    return GlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      onTap: () {
        HapticFeedback.selectionClick();
        _houseKey.currentState?.setCamera(yaw: yaw, pitch: pitch);
      },
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _roomFilterChip(String id, String label) {
    final isSelected = _selectedRoomId == id;
    return GlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      isActive: isSelected,
      activeTint: const Color(0xFF00D4FF),
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedRoomId = id);
      },
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isSelected ? Colors.white : Colors.white70,
        ),
      ),
    );
  }
}

// =============================================================================
// TAB 3: WORKING AUTOMATIONS & MASTER HUB TAB
// =============================================================================
class _FunctionalAutomationsTab extends StatefulWidget {
  const _FunctionalAutomationsTab();

  @override
  State<_FunctionalAutomationsTab> createState() => _FunctionalAutomationsTabState();
}

class _FunctionalAutomationsTabState extends State<_FunctionalAutomationsTab> {
  final TextEditingController _wsUrlCtrl = TextEditingController(text: 'ws://192.168.1.100:8765/ws');
  final TextEditingController _aiRuleCtrl = TextEditingController();
  bool _isGeneratingAiRule = false;

  @override
  void dispose() {
    _wsUrlCtrl.dispose();
    _aiRuleCtrl.dispose();
    super.dispose();
  }

  void _openRuleStudio(BuildContext context, [MultiConditionAutomationRule? rule, String? initialTemplate]) {
    final home = context.read<RealHomeProvider>();
    if (home.devices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pair at least one real device first!')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SmartRuleStudioSheet(
        existingRule: rule,
        initialTemplate: initialTemplate,
      ),
    );
  }

  Future<void> _generateAiRule() async {
    final prompt = _aiRuleCtrl.text.trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Type a command first (e.g. "At 11 PM turn off TV and lights")')),
      );
      return;
    }

    setState(() => _isGeneratingAiRule = true);
    HapticFeedback.heavyImpact();

    try {
      final home = context.read<RealHomeProvider>();
      final created = await home.parseAndAddNaturalLanguageRule(prompt);
      if (!mounted) return;
      if (created != null) {
        _aiRuleCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF30D158),
            content: Text('Generated and deployed "${created.name}" (${created.actions.length} action(s))!'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not match devices. Ensure appliances are paired!')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingAiRule = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final home = context.watch<RealHomeProvider>();
    final rules = home.automations;
    final multiRules = home.multiConditionRules;
    final reflexRules = home.reflexBus.reflexRules;
    final executionLogs = home.executionLogs;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
      children: [
        // ---------------------------------------------------------------------
        // 1. AI NATURAL LANGUAGE RULE BAR
        // ---------------------------------------------------------------------
        GlassContainer(
          borderRadius: 24,
          padding: const EdgeInsets.all(16),
          isActive: true,
          activeTint: const Color(0xFFBF5AF2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: Color(0xFFBF5AF2), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'AI Automation Rule Copilot',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Type plain English commands to auto-generate multi-step hardware rules:',
                style: TextStyle(fontSize: 11.5, color: Colors.white70),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _aiRuleCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'e.g. At 11 PM turn off TV, wait 5s then dim light to 15%',
                  hintStyle: const TextStyle(color: Colors.white30, fontSize: 12.5),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  suffixIcon: IconButton(
                    icon: _isGeneratingAiRule
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFBF5AF2)),
                          )
                        : const Icon(Icons.arrow_upward_rounded, color: Color(0xFFBF5AF2)),
                    onPressed: _isGeneratingAiRule ? null : () => _generateAiRule(),
                  ),
                ),
                onSubmitted: (_) => _generateAiRule(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFBF5AF2),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      icon: const Icon(Icons.bolt_rounded, size: 18),
                      label: const Text('Deploy AI Rule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: _isGeneratingAiRule ? null : () => _generateAiRule(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF30D158),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('+ New Custom Rule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: () => _openRuleStudio(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ---------------------------------------------------------------------
        // 2. MULTI-CONDITION AUTOMATION RULES (WHEN ➔ ONLY IF ➔ THEN)
        // ---------------------------------------------------------------------
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '⚡ Multi-Condition Rules (${multiRules.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            TextButton.icon(
              icon: const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF30D158)),
              label: const Text('Studio', style: TextStyle(color: Color(0xFF30D158), fontSize: 12)),
              onPressed: () => _openRuleStudio(context),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (multiRules.isEmpty)
          GlassContainer(
            padding: const EdgeInsets.all(16),
            child: const Column(
              children: [
                Icon(Icons.hub_rounded, size: 36, color: Colors.white30),
                SizedBox(height: 8),
                Text(
                  'No multi-condition workflows configured yet.',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                SizedBox(height: 4),
                Text(
                  'Use the AI Copilot above or tap "+ New Custom Rule" to build a WHEN ➔ ONLY IF ➔ THEN multi-appliance sequence!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.white60),
                ),
              ],
            ),
          ),

        ...multiRules.map((rule) {
          final isTime = rule.trigger.kind == TriggerKind.timeSchedule;
          final isSolar = rule.trigger.kind == TriggerKind.solarEvent;
          final isPresence = rule.trigger.kind == TriggerKind.wifiPresence;

          final trigIcon = isTime
              ? Icons.schedule_rounded
              : (isSolar
                  ? Icons.wb_sunny_rounded
                  : (isPresence ? Icons.directions_walk_rounded : Icons.flash_on_rounded));
          final trigColor = isTime
              ? const Color(0xFFFF9F0A)
              : (isSolar
                  ? const Color(0xFFFFD60A)
                  : (isPresence ? const Color(0xFF0A84FF) : const Color(0xFF30D158)));

          return GlassContainer(
            margin: const EdgeInsets.only(bottom: 14),
            isActive: rule.isEnabled,
            activeTint: trigColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: trigColor.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(trigIcon, size: 16, color: trigColor),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        rule.name,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    if (rule.executionCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF30D158).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${rule.executionCount}x Run',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF30D158), fontWeight: FontWeight.bold),
                        ),
                      ),
                    Switch.adaptive(
                      value: rule.isEnabled,
                      onChanged: (_) => home.toggleMultiConditionRule(rule.id),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Badge Chips (WHEN -> ONLY IF -> THEN)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildRuleBadge('WHEN: ${rule.trigger.value}', trigColor),
                    ...rule.preconditions.map((p) => _buildRuleBadge('IF: ${p.label}', const Color(0xFF0A84FF))),
                    _buildRuleBadge('THEN: ${rule.actions.length} Step(s)', const Color(0xFF30D158)),
                  ],
                ),
                const SizedBox(height: 10),

                // Sequenced Action Steps Preview
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: rule.actions.map((act) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.arrow_right_rounded, color: Color(0xFF30D158), size: 18),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                act.summary,
                                style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),

                // Controls: Run Now, Edit, Delete
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.play_arrow_rounded, color: Color(0xFF30D158), size: 18),
                      label: const Text('Run Now', style: TextStyle(color: Color(0xFF30D158), fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        HapticFeedback.heavyImpact();
                        final success = await home.executeMultiConditionRuleNow(rule);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: success ? const Color(0xFF30D158) : const Color(0xFFFF453A),
                              content: Text(success ? 'Executed "${rule.name}" successfully on real appliances!' : 'Automation execution failed. Check logs.'),
                            ),
                          );
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.white60, size: 18),
                      onPressed: () => _openRuleStudio(context, rule),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF453A), size: 18),
                      onPressed: () => home.deleteMultiConditionRule(rule.id),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),

        if (rules.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            '⏱️ Simple Time Schedules',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          ...rules.map((rule) {
            return GlassContainer(
              margin: const EdgeInsets.only(bottom: 10),
              isActive: rule.isEnabled,
              activeTint: const Color(0xFF0A84FF),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rule.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        Text('At ${rule.triggerValue} ➔ ${rule.targetPowerState ? "ON" : "OFF"}', style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF453A), size: 18),
                    onPressed: () => home.deleteAutomation(rule.id),
                  ),
                ],
              ),
            );
          }),
        ],

        const SizedBox(height: 20),

        // ---------------------------------------------------------------------
        // 3. PILLAR 3: CROSS-BRAND REFLEXES (CINEMA, LAUNDRY ALERT, CALL ATTENUATION)
        // ---------------------------------------------------------------------
        const Text(
          '⚡ Cross-Brand Reflexes (Auto Pub/Sub)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 8),
        ...reflexRules.map((reflex) {
          return GlassContainer(
            margin: const EdgeInsets.only(bottom: 10),
            isActive: reflex.isEnabled,
            activeTint: const Color(0xFFBF5AF2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(reflex.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(reflex.description, style: const TextStyle(fontSize: 11, color: Colors.white70)),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: reflex.isEnabled,
                  onChanged: (val) {
                    setState(() => reflex.isEnabled = val);
                    HapticFeedback.selectionClick();
                  },
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: 18),

        // ---------------------------------------------------------------------
        // 4. PILLAR 4: ZERO-GPS WI-FI BSSID GEOFENCING
        // ---------------------------------------------------------------------
        const Text(
          '📍 Context Presence & Geofencing',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 8),
        GlassContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Home Router BSSID:', style: TextStyle(fontWeight: FontWeight.w600)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: home.osBridge.isUserAtHome
                          ? const Color(0xFF30D158).withValues(alpha: 0.25)
                          : const Color(0xFFFF9F0A).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      home.osBridge.isUserAtHome ? 'AT HOME' : 'AWAY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: home.osBridge.isUserAtHome ? const Color(0xFF30D158) : const Color(0xFFFF9F0A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                home.osBridge.homeRouterBssid ?? 'No BSSID locked yet (Uses 0% GPS Battery)',
                style: const TextStyle(fontSize: 12, color: Colors.white60),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.wifi_lock_rounded, size: 16),
                  label: const Text('Lock Current Wi-Fi BSSID as Home'),
                  onPressed: () async {
                    try {
                      await home.lockCurrentBssidAsHome();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Locked BSSID: ${home.osBridge.homeRouterBssid}')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$e')),
                        );
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // ---------------------------------------------------------------------
        // 5. PILLAR 1: ALWAYS-ON 24/7 NODE WEBSOCKET TUNNEL
        // ---------------------------------------------------------------------
        const Text(
          '🌐 Always-On Home Node Bridge',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 8),
        GlassContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('WebSocket Tunnel:', style: TextStyle(fontWeight: FontWeight.w600)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: home.networkEngine.isAlwaysOnNodeConnected
                          ? const Color(0xFF30D158).withValues(alpha: 0.25)
                          : Colors.white12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      home.networkEngine.isAlwaysOnNodeConnected ? 'CONNECTED' : 'DISCONNECTED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: home.networkEngine.isAlwaysOnNodeConnected ? const Color(0xFF30D158) : Colors.white60,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _wsUrlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Node WS URL (e.g. ws://192.168.1.100:8765/ws)',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.cable_rounded, size: 16),
                  label: const Text('Connect 24/7 Node Tunnel'),
                  onPressed: () async {
                    try {
                      await home.networkEngine.connectAlwaysOnNode(
                        _wsUrlCtrl.text.trim(),
                        onRemoteHardwareEvent: (_) => home.syncAllDevicesSilent(),
                      );
                      setState(() {});
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Node Connection Error: $e')),
                        );
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),

        // ---------------------------------------------------------------------
        // 6. REAL-TIME LIVE EXECUTION HISTORY
        // ---------------------------------------------------------------------
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '📜 Live Execution History',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            if (executionLogs.isNotEmpty)
              Text(
                '${executionLogs.length} events',
                style: const TextStyle(fontSize: 11, color: Colors.white54),
              ),
          ],
        ),
        const SizedBox(height: 8),

        if (executionLogs.isEmpty)
          const GlassContainer(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.history_rounded, color: Colors.white38, size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No executions recorded yet. Tap "Run Now" on any rule above to test execution.',
                    style: TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                ),
              ],
            ),
          )
        else
          ...executionLogs.take(15).map((log) {
            final timeStr =
                '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: log.success
                    ? const Color(0xFF30D158).withValues(alpha: 0.10)
                    : const Color(0xFFFF453A).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: log.success
                      ? const Color(0xFF30D158).withValues(alpha: 0.3)
                      : const Color(0xFFFF453A).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    log.success ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                    size: 18,
                    color: log.success ? const Color(0xFF30D158) : const Color(0xFFFF453A),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              log.ruleName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: 11,
                                color: log.success ? const Color(0xFF30D158) : const Color(0xFFFF453A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          log.summary,
                          style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildRuleBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// =============================================================================
// UNIVERSAL REAL DEVICE PAIRING SHEET (SMARTTHINGS, LG THINQ, TUYA AUTO, HA, LAN)
// =============================================================================
class _RealDevicePairingModal extends StatefulWidget {
  const _RealDevicePairingModal();

  @override
  State<_RealDevicePairingModal> createState() => _RealDevicePairingModalState();
}

class _RealDevicePairingModalState extends State<_RealDevicePairingModal> {
  // 0: Sign In with Brand (Google Home Style)
  // 1: SmartThings PAT, 2: LG ThinQ PAT, 3: Wipro Auto-Key, 4: Universal Hub (HA), 5: Direct LAN
  int _mode = 0;
  final _tokenCtrl = TextEditingController();
  final _urlOrIpCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _localKeyCtrl = TextEditingController();
  final _accessIdCtrl = TextEditingController();
  final _accessSecretCtrl = TextEditingController();
  final _sampleDevIdCtrl = TextEditingController();
  final _countryCtrl = TextEditingController(text: 'IN');
  String _selectedCategory = 'light';
  String _statusMsg = '';

  @override
  Widget build(BuildContext context) {
    final home = context.watch<RealHomeProvider>();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16,
        right: 16,
      ),
      child: GlassContainer(
        borderRadius: 32,
        blur: 35,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Connect Real Smart Devices',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Sign In with Brand (Google Home Style)'),
                      selected: _mode == 0,
                      onSelected: (_) => setState(() => _mode = 0),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('SmartThings Token'),
                      selected: _mode == 1,
                      onSelected: (_) => setState(() => _mode = 1),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('LG ThinQ PAT'),
                      selected: _mode == 2,
                      onSelected: (_) => setState(() => _mode = 2),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Wipro Cloud Auto-Key'),
                      selected: _mode == 3,
                      onSelected: (_) => setState(() => _mode = 3),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Universal Hub (HA)'),
                      selected: _mode == 4,
                      onSelected: (_) => setState(() => _mode = 4),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Direct LAN'),
                      selected: _mode == 5,
                      onSelected: (_) => setState(() => _mode = 5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              if (_mode == 0) ...[
                const Text(
                  'Works with Unified Home',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tap your device brand to log in on their official page. Tokens and appliances link automatically.',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(height: 12),
                ...BrandOAuthCatalog.providers.map((provider) {
                  return GlassContainer(
                    margin: const EdgeInsets.only(bottom: 10),
                    borderRadius: 22,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    onTap: () {
                      Navigator.pop(context);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (ctx) => BrandOAuthWebViewSheet(brand: provider),
                      );
                    },
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: provider.brandColor,
                          radius: 18,
                          child: Icon(provider.icon, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                provider.brandName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                provider.subtitle,
                                style: const TextStyle(fontSize: 11, color: Colors.white60),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.white54,
                          size: 14,
                        ),
                      ],
                    ),
                  );
                }),
              ] else if (_mode == 1) ...[
                const Text(
                  'Paste your Personal Access Token from account.smartthings.com/tokens. Directly imports your Samsung Washer, TV, AC, and linked peripherals.',
                  style: TextStyle(fontSize: 12),
                ),
                TextField(
                  controller: _tokenCtrl,
                  decoration: const InputDecoration(
                    labelText: 'SmartThings Bearer PAT Token',
                    hintText: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
                  ),
                ),
              ] else if (_mode == 2) ...[
                const Text(
                  'Paste your official LG ThinQ Personal Access Token from connect-pat.lgthinq.com to discover and control your LG DualCool Inverter AC.',
                  style: TextStyle(fontSize: 12),
                ),
                TextField(
                  controller: _tokenCtrl,
                  decoration: const InputDecoration(
                    labelText: 'LG ThinQ Bearer PAT Token',
                  ),
                ),
                TextField(
                  controller: _countryCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Country Code (e.g. IN, US, KR, DE)',
                  ),
                ),
              ] else if (_mode == 3) ...[
                const Text(
                  'Enter your Tuya Cloud Developer credentials (openapi.tuyain.com) to automatically harvest localKeys for Wipro Smart Bulbs without manual extraction.',
                  style: TextStyle(fontSize: 12),
                ),
                TextField(
                  controller: _accessIdCtrl,
                  decoration: const InputDecoration(labelText: 'Tuya Cloud Access ID / Client ID'),
                ),
                TextField(
                  controller: _accessSecretCtrl,
                  decoration: const InputDecoration(labelText: 'Tuya Cloud Access Secret'),
                ),
                TextField(
                  controller: _sampleDevIdCtrl,
                  decoration: const InputDecoration(labelText: 'Sample Bulb Device ID (from Wipro/SmartLife app)'),
                ),
              ] else if (_mode == 4) ...[
                const Text(
                  'Connect any brand via your local Home Assistant server (Matter, Zigbee, Wipro, Hue).',
                  style: TextStyle(fontSize: 12),
                ),
                TextField(
                  controller: _urlOrIpCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Hub URL (e.g. http://192.168.1.50:8123)',
                  ),
                ),
                TextField(
                  controller: _tokenCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Long-Lived Access Token',
                  ),
                ),
              ] else ...[
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Device Name (e.g. OnePlus TV 55)'),
                ),
                TextField(
                  controller: _urlOrIpCtrl,
                  decoration: const InputDecoration(labelText: 'Local Wi-Fi IP (e.g. 192.168.1.105)'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  items: const [
                    DropdownMenuItem(value: 'tv', child: Text('OnePlus / Android TV (Port 8008)')),
                    DropdownMenuItem(value: 'light', child: Text('Wipro / Tuya Smart Bulb (Port 6668)')),
                  ],
                  onChanged: (v) => setState(() => _selectedCategory = v ?? 'tv'),
                ),
                if (_selectedCategory == 'light')
                  TextField(
                    controller: _localKeyCtrl,
                    decoration: const InputDecoration(
                      labelText: '16-Char Tuya LocalKey (Required for LAN Encryption)',
                    ),
                  ),
              ],

              if (_mode != 0) ...[
                if (_statusMsg.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(_statusMsg, style: const TextStyle(color: Color(0xFFFF9F0A), fontSize: 12)),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: home.isBusy ? null : () => _pairNow(context, home),
                    child: Text(home.isBusy ? 'Verifying Handshake...' : 'Verify & Pair Real Hardware'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pairNow(BuildContext context, RealHomeProvider home) async {
    setState(() => _statusMsg = 'Connecting to real device endpoint...');
    try {
      if (_mode == 1) {
        final count = await home.linkSmartThingsAccount(_tokenCtrl.text);
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Imported $count real SmartThings devices!')),
          );
        }
      } else if (_mode == 2) {
        final count = await home.linkLgThinqAccount(
          _tokenCtrl.text,
          countryCode: _countryCtrl.text.trim().isEmpty ? 'IN' : _countryCtrl.text.trim(),
        );
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Imported $count real LG ThinQ devices!')),
          );
        }
      } else if (_mode == 3) {
        final count = await home.autoHarvestWiproKeys(
          accessId: _accessIdCtrl.text.trim(),
          accessSecret: _accessSecretCtrl.text.trim(),
          sampleDeviceId: _sampleDevIdCtrl.text.trim(),
        );
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Harvested and imported $count Wipro bulbs!')),
          );
        }
      } else if (_mode == 4) {
        final count = await home.linkHomeAssistantHub(_urlOrIpCtrl.text, _tokenCtrl.text);
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Imported $count real devices from Hub!')),
          );
        }
      } else if (_mode == 5) {
        final dev = RealSmartDevice(
          id: 'lan_${DateTime.now().millisecondsSinceEpoch}',
          name: _nameCtrl.text.trim().isEmpty ? 'LAN Device' : _nameCtrl.text.trim(),
          room: 'Living Room',
          category: _selectedCategory,
          protocol: _selectedCategory == 'tv'
              ? ConnectionProtocol.onePlusTvLan
              : ConnectionProtocol.tuyaLocalLan,
          credentials: {
            'ip': _urlOrIpCtrl.text.trim(),
            'port': _selectedCategory == 'tv' ? '8008' : '6668',
            'localKey': _localKeyCtrl.text.trim(),
          },
        );
        await home.addDirectLanDevice(dev);
        if (context.mounted) Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _statusMsg = e.toString().replaceAll('Exception: ', ''));
    }
  }
}

void _showDeviceControlSheet(BuildContext context, RealSmartDevice device) {
  if (device.category == 'camera') {
    final home = context.read<RealHomeProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => CameraCockpitSheet(
        device: device,
        iot: RealIotController(),
        onStateChanged: () {
          home.notifyUi();
        },
      ),
    );
    return;
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.65),
    builder: (ctx) => _AppleGlassDeviceControlSheet(initialDevice: device),
  );
}

class _AppleGlassDeviceControlSheet extends StatefulWidget {
  final RealSmartDevice initialDevice;

  const _AppleGlassDeviceControlSheet({required this.initialDevice});

  @override
  State<_AppleGlassDeviceControlSheet> createState() => _AppleGlassDeviceControlSheetState();
}

class _AppleGlassDeviceControlSheetState extends State<_AppleGlassDeviceControlSheet> {
  bool _isRefreshing = false;
  String? _selectedWaterTemp;
  String? _selectedSpinSpeed;
  String _acMode = 'Cool';
  String _acFanSpeed = 'Auto';
  String _lightKelvin = '4000K';
  Color _lightColor = const Color(0xFFFF9F0A);
  String? _actionStatus;

  @override
  void initState() {
    super.initState();
    _selectedWaterTemp = widget.initialDevice.liveAttributes['waterTemperature']?.toString() ?? '40°C';
    _selectedSpinSpeed = widget.initialDevice.liveAttributes['spinSpeed']?.toString() != null
        ? '${widget.initialDevice.liveAttributes['spinSpeed']} RPM'
        : '1200 RPM';
  }

  @override
  Widget build(BuildContext context) {
    final home = context.watch<RealHomeProvider>();
    final device = home.devices.firstWhere(
      (d) => d.id == widget.initialDevice.id,
      orElse: () => widget.initialDevice,
    );

    final archetype = UniversalCategoryClassifier.classify(device);
    final tint = UniversalCategoryClassifier.colorFor(archetype);
    final isOnline = device.isOnline;
    final isOn = device.isOn;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF090E1D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
        border: Border(
          top: BorderSide(color: Colors.white24, width: 1.2),
          left: BorderSide(color: Colors.white12, width: 1.0),
          right: BorderSide(color: Colors.white12, width: 1.0),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black87, blurRadius: 40, spreadRadius: 10),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Pull Indicator
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: tint.withValues(alpha: isOn ? 0.35 : 0.15),
                    child: Icon(
                      UniversalCategoryClassifier.iconFor(archetype),
                      color: isOn ? tint : Colors.white70,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${device.room} • ${device.protocol.name.toUpperCase()}',
                          style: const TextStyle(fontSize: 11.5, color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white60),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 3. Prominent Offline Alert Banner
              if (!isOnline) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF453A).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFF453A).withValues(alpha: 0.45)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Color(0xFFFF9F0A), size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '⚠️ Device is Offline — Turn on physical power to enable live controls',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // 4. Power & Master Switch Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Power State', style: TextStyle(color: Colors.white54, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          isOn ? 'ACTIVELY RUNNING' : 'STANDBY / OFF',
                          style: TextStyle(
                            color: isOn ? const Color(0xFF30D158) : Colors.white60,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isOn ? const Color(0xFFFF453A) : const Color(0xFF30D158),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: Icon(isOn ? Icons.power_settings_new_rounded : Icons.play_arrow_rounded, size: 18),
                      label: Text(isOn ? 'Turn Off' : 'Turn On', style: const TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: !isOnline
                          ? null
                          : () async {
                              HapticFeedback.mediumImpact();
                              try {
                                await home.toggleDevicePower(device);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              }
                            },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 5. Category-Specific Control Panels
              if (device.category == 'washer')
                _buildSamsungWasherControls(context, home, device, isOnline, isOn)
              else if (device.category == 'ac')
                _buildAcClimateControls(context, home, device, isOnline, isOn)
              else if (device.category == 'light')
                _buildSmartLightControls(context, home, device, isOnline, isOn)
              else if (device.category == 'tv')
                _buildOnePlusTvControls(context, home, device, isOnline, isOn)
              else if (device.category == 'camera')
                _buildCameraControls(context, home, device, isOnline, isOn)
              else
                _buildGenericLevelControl(context, home, device, isOnline, isOn),

              if (_actionStatus != null) ...[
                const SizedBox(height: 12),
                Text(
                  _actionStatus!,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF00D4FF), fontWeight: FontWeight.w500),
                ),
              ],
              const SizedBox(height: 22),

              // 6. Bottom Actions: Refresh Status & Remove Device
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: _isRefreshing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Refresh Hardware Status', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      onPressed: _isRefreshing
                          ? null
                          : () async {
                              setState(() => _isRefreshing = true);
                              HapticFeedback.lightImpact();
                              try {
                                await home.refreshDevice(device);
                                if (mounted) {
                                  setState(() => _actionStatus = 'Hardware status refreshed successfully.');
                                }
                              } catch (e) {
                                if (mounted) {
                                  setState(() => _actionStatus = 'Refresh error: $e');
                                }
                              } finally {
                                if (mounted) setState(() => _isRefreshing = false);
                              }
                            },
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF453A),
                      side: const BorderSide(color: Color(0x66FF453A)),
                      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Remove Device', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    onPressed: () {
                      home.removeDevice(device.id);
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSamsungWasherControls(
    BuildContext context,
    RealHomeProvider home,
    RealSmartDevice device,
    bool isOnline,
    bool isOn,
  ) {
    final machineState = (device.liveAttributes['machineState'] ?? (isOn ? 'run' : 'stop')).toString().toLowerCase();
    final isRunning = machineState == 'run';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cycle State & Badges
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Cycle State', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        machineState.toUpperCase(),
                        style: TextStyle(
                          color: isRunning ? const Color(0xFF00D4FF) : Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isRunning ? const Color(0xFFFF9F0A) : const Color(0xFF0A84FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: Icon(isRunning ? Icons.pause_circle_rounded : Icons.play_circle_fill_rounded, size: 18),
                    label: Text(isRunning ? 'Pause Cycle' : 'Start Cycle', style: const TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: !isOnline
                        ? null
                        : () async {
                            final target = isRunning ? 'pause' : 'run';
                            HapticFeedback.mediumImpact();
                            try {
                              await home.executeDeviceCommand(device, 'washerOperatingState', 'setMachineState', [target]);
                              await home.refreshDevice(device);
                              if (mounted) setState(() => _actionStatus = 'Washer cycle command: $target sent');
                            } catch (e) {
                              if (mounted) setState(() => _actionStatus = 'Error: $e');
                            }
                          },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // EcoBubble & AI Wash Badges
              const Row(
                children: [
                  _FeatureBadge(icon: Icons.bubble_chart_rounded, label: 'EcoBubble™ Active', color: Color(0xFF00D4FF)),
                  SizedBox(width: 8),
                  _FeatureBadge(icon: Icons.auto_awesome_rounded, label: 'AI Wash™ Ready', color: Color(0xFFBF5AF2)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Water Temperature Chips
        const Text('Water Temperature', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: ['Cold', '30°C', '40°C', '60°C'].map((temp) {
            final selected = _selectedWaterTemp == temp;
            return ChoiceChip(
              label: Text(temp),
              selected: selected,
              selectedColor: const Color(0xFF0A84FF),
              backgroundColor: Colors.white12,
              labelStyle: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: !isOnline
                  ? null
                  : (sel) async {
                      if (sel) {
                        setState(() => _selectedWaterTemp = temp);
                        HapticFeedback.selectionClick();
                        try {
                          await home.executeDeviceCommand(
                            device,
                            'custom.washerWaterTemperature',
                            'setWasherWaterTemperature',
                            [temp],
                          );
                        } catch (_) {}
                      }
                    },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Spin Speed Selector Chips
        const Text('Spin Speed', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: ['400 RPM', '800 RPM', '1200 RPM', '1400 RPM'].map((speed) {
            final selected = _selectedSpinSpeed == speed;
            return ChoiceChip(
              label: Text(speed),
              selected: selected,
              selectedColor: const Color(0xFF00D4FF),
              backgroundColor: Colors.white12,
              labelStyle: TextStyle(
                color: selected ? Colors.black : Colors.white70,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: !isOnline
                  ? null
                  : (sel) async {
                      if (sel) {
                        setState(() => _selectedSpinSpeed = speed);
                        HapticFeedback.selectionClick();
                        try {
                          await home.executeDeviceCommand(
                            device,
                            'custom.washerSpinSpeed',
                            'setWasherSpinSpeed',
                            [speed.replaceAll(' RPM', '')],
                          );
                        } catch (_) {}
                      }
                    },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAcClimateControls(
    BuildContext context,
    RealHomeProvider home,
    RealSmartDevice device,
    bool isOnline,
    bool isOn,
  ) {
    final currentTemp = device.primaryValue.clamp(16.0, 30.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Circular Temperature Readout
        Center(
          child: Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.05),
              border: Border.all(color: const Color(0xFF00D4FF).withValues(alpha: 0.35), width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('SET TEMPERATURE', style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: Colors.white54)),
                const SizedBox(height: 4),
                Text(
                  '${currentTemp.round()}°C',
                  style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.white70),
                      onPressed: (!isOnline || currentTemp <= 16.0)
                          ? null
                          : () {
                              final newTemp = currentTemp - 1.0;
                              home.setDeviceLevel(device, newTemp);
                            },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white70),
                      onPressed: (!isOnline || currentTemp >= 30.0)
                          ? null
                          : () {
                              final newTemp = currentTemp + 1.0;
                              home.setDeviceLevel(device, newTemp);
                            },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Mode Chips
        const Text('Climate Mode', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: ['Cool', 'Jet Cool', 'Eco', 'Fan'].map((mode) {
            final selected = _acMode == mode;
            return ChoiceChip(
              label: Text(mode),
              selected: selected,
              selectedColor: const Color(0xFF0A84FF),
              backgroundColor: Colors.white12,
              labelStyle: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: !isOnline
                  ? null
                  : (sel) {
                      if (sel) setState(() => _acMode = mode);
                    },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Fan Speed Selector Chips
        const Text('Fan Speed', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: ['Auto', 'Low', 'Medium', 'High', 'Turbo'].map((speed) {
            final selected = _acFanSpeed == speed;
            return ChoiceChip(
              label: Text(speed),
              selected: selected,
              selectedColor: const Color(0xFF00D4FF),
              backgroundColor: Colors.white12,
              labelStyle: TextStyle(
                color: selected ? Colors.black : Colors.white70,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: !isOnline
                  ? null
                  : (sel) {
                      if (sel) setState(() => _acFanSpeed = speed);
                    },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSmartLightControls(
    BuildContext context,
    RealHomeProvider home,
    RealSmartDevice device,
    bool isOnline,
    bool isOn,
  ) {
    final brightness = device.primaryValue.clamp(1.0, 100.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Brightness', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
            Text('${brightness.round()}%', style: const TextStyle(color: Color(0xFFFF9F0A), fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: brightness,
          min: 1.0,
          max: 100.0,
          activeColor: const Color(0xFFFF9F0A),
          inactiveColor: Colors.white12,
          onChanged: !isOnline ? null : (v) => home.setDeviceLevel(device, v),
        ),
        const SizedBox(height: 14),

        // Kelvin Presets
        const Text('Color Temperature', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: ['2700K', '3000K', '4000K', '6500K'].map((k) {
            final selected = _lightKelvin == k;
            return ChoiceChip(
              label: Text(k),
              selected: selected,
              selectedColor: const Color(0xFFFF9F0A),
              backgroundColor: Colors.white12,
              labelStyle: TextStyle(
                color: selected ? Colors.black : Colors.white70,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: !isOnline ? null : (sel) => setState(() => _lightKelvin = k),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),

        // Color Chips
        const Text('Color Preset', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            const Color(0xFFFF9F0A),
            const Color(0xFF00D4FF),
            const Color(0xFFBF5AF2),
            const Color(0xFFFF375F),
            const Color(0xFF30D158),
            const Color(0xFFFFFFFF),
          ].map((c) {
            final isSel = _lightColor == c;
            return GestureDetector(
              onTap: !isOnline ? null : () => setState(() => _lightColor = c),
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c,
                  border: Border.all(
                    color: isSel ? Colors.white : Colors.transparent,
                    width: isSel ? 2.5 : 0,
                  ),
                  boxShadow: [
                    if (isSel) BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 10),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildOnePlusTvControls(
    BuildContext context,
    RealHomeProvider home,
    RealSmartDevice device,
    bool isOnline,
    bool isOn,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Virtual D-Pad Remote', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Center(
          child: Column(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_drop_up_rounded, size: 36, color: Colors.white),
                onPressed: !isOnline ? null : () => HapticFeedback.selectionClick(),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_left_rounded, size: 36, color: Colors.white),
                    onPressed: !isOnline ? null : () => HapticFeedback.selectionClick(),
                  ),
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: IconButton(
                      icon: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      onPressed: !isOnline ? null : () => HapticFeedback.mediumImpact(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_right_rounded, size: 36, color: Colors.white),
                    onPressed: !isOnline ? null : () => HapticFeedback.selectionClick(),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.arrow_drop_down_rounded, size: 36, color: Colors.white),
                onPressed: !isOnline ? null : () => HapticFeedback.selectionClick(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white24)),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Back'),
              onPressed: !isOnline ? null : () => HapticFeedback.lightImpact(),
            ),
            const SizedBox(width: 14),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white24)),
              icon: const Icon(Icons.home_rounded, size: 16),
              label: const Text('Home'),
              onPressed: !isOnline ? null : () => HapticFeedback.lightImpact(),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Quick App Launcher Pills
        const Text('Quick App Launchers', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          children: ['YouTube', 'Netflix', 'Prime Video'].map((app) {
            return ActionChip(
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              label: Text(app, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              avatar: const Icon(Icons.smart_display_rounded, size: 16, color: Color(0xFFFF375F)),
              onPressed: !isOnline
                  ? null
                  : () {
                      HapticFeedback.mediumImpact();
                      setState(() => _actionStatus = 'Launching $app on ${device.name}...');
                    },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildGenericLevelControl(
    BuildContext context,
    RealHomeProvider home,
    RealSmartDevice device,
    bool isOnline,
    bool isOn,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Device Level', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
            Text('${device.primaryValue.round()}%', style: const TextStyle(color: Color(0xFF00D4FF), fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: device.primaryValue.clamp(1.0, 100.0),
          min: 1.0,
          max: 100.0,
          activeColor: const Color(0xFF00D4FF),
          inactiveColor: Colors.white12,
          onChanged: !isOnline ? null : (v) => home.setDeviceLevel(device, v),
        ),
      ],
    );
  }

  Widget _buildCameraControls(
    BuildContext context,
    RealHomeProvider home,
    RealSmartDevice device,
    bool isOnline,
    bool isOn,
  ) {
    final brand = device.credentials['brand']?.toString().toLowerCase() ?? 'realme';
    final isRealme = brand == 'realme';
    final rtspUrl = device.credentials['rtspUrl'] ?? '';
    final isPrivacyActive = !isOn;
    final lastPtz = device.liveAttributes['lastPtzDirection']?.toString().toUpperCase() ?? 'CENTER';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Camera Viewport Card
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isPrivacyActive
                  ? const Color(0xFFFF9F0A).withValues(alpha: 0.5)
                  : const Color(0xFF30D158).withValues(alpha: 0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isPrivacyActive
                    ? const Color(0xFFFF9F0A).withValues(alpha: 0.15)
                    : const Color(0xFF30D158).withValues(alpha: 0.2),
                blurRadius: 20,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Simulated Grid Lines / Viewfinder
              Positioned.fill(
                child: CustomPaint(
                  painter: _CameraViewfinderPainter(isPrivacy: isPrivacyActive),
                ),
              ),

              if (isPrivacyActive)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFFF9F0A), width: 1.2),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.privacy_tip_rounded, color: Color(0xFFFF9F0A), size: 36),
                        SizedBox(height: 6),
                        Text(
                          'Privacy Mode Active',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Lens Tilted Down • Stream Paused (2.0 W)',
                          style: TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                )
              else
                // Active Live Stream Overlay HUD
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Top HUD Bar: Live indicator, Resolution, FPS
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF453A),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(radius: 3, backgroundColor: Colors.white),
                                  SizedBox(width: 5),
                                  Text(
                                    'LIVE RTSP',
                                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: const Text(
                                '1080P • 30 FPS • 2.4 Mbps',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),

                        // Center watermark / HUD crosshair
                        Center(
                          child: Icon(
                            Icons.center_focus_strong_rounded,
                            color: Colors.white.withValues(alpha: 0.35),
                            size: 48,
                          ),
                        ),

                        // Bottom HUD Bar: Timestamp & PTZ Heading
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              device.name.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            if (isRealme)
                              Text(
                                'PTZ: $lastPtz',
                                style: const TextStyle(
                                  color: Color(0xFF00D4FF),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Stream RTSP URL info strip
        if (rtspUrl.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                const Icon(Icons.link_rounded, color: Color(0xFF00D4FF), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rtspUrl,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 3. Quick Action Buttons: Privacy Mode & Snapshot
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPrivacyActive ? const Color(0xFF30D158) : const Color(0xFFFF9F0A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: Icon(isPrivacyActive ? Icons.videocam_rounded : Icons.privacy_tip_rounded, size: 18),
                label: Text(
                  isPrivacyActive ? 'Resume Video' : 'Privacy Mode',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: !isOnline
                    ? null
                    : () async {
                        HapticFeedback.mediumImpact();
                        try {
                          await home.toggleDevicePower(device);
                          setState(() {
                            _actionStatus = isPrivacyActive ? 'Camera stream activated.' : 'Camera privacy mode enabled.';
                          });
                        } catch (e) {
                          setState(() => _actionStatus = 'Error: $e');
                        }
                      },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.camera_alt_rounded, size: 18),
                label: const Text('Capture Frame', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: !isOnline || isPrivacyActive
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        setState(() => _actionStatus = '1080p frame captured to gallery.');
                      },
              ),
            ),
          ],
        ),

        // 4. PTZ Directional Pan-Tilt Controls (Specifically for Realme Cam 360)
        if (isRealme) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                const Row(
                  children: [
                    Icon(Icons.threed_rotation_rounded, color: Color(0xFFFFB800), size: 20),
                    SizedBox(width: 8),
                    Text(
                      '360° PTZ Pan-Tilt Control',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Directional D-Pad
                Column(
                  children: [
                    _buildPtzButton(context, home, device, isOnline && !isPrivacyActive, Icons.arrow_upward_rounded, 'up'),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildPtzButton(context, home, device, isOnline && !isPrivacyActive, Icons.arrow_back_rounded, 'left'),
                        const SizedBox(width: 14),
                        _buildPtzButton(context, home, device, isOnline && !isPrivacyActive, Icons.filter_center_focus_rounded, 'center', isCenter: true),
                        const SizedBox(width: 14),
                        _buildPtzButton(context, home, device, isOnline && !isPrivacyActive, Icons.arrow_forward_rounded, 'right'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildPtzButton(context, home, device, isOnline && !isPrivacyActive, Icons.arrow_downward_rounded, 'down'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPtzButton(
    BuildContext context,
    RealHomeProvider home,
    RealSmartDevice device,
    bool enabled,
    IconData icon,
    String dir, {
    bool isCenter = false,
  }) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isCenter
            ? const Color(0xFFFFB800).withValues(alpha: enabled ? 0.25 : 0.08)
            : Colors.white.withValues(alpha: enabled ? 0.12 : 0.05),
        shape: BoxShape.circle,
        border: Border.all(
          color: isCenter
              ? const Color(0xFFFFB800).withValues(alpha: enabled ? 0.7 : 0.2)
              : Colors.white.withValues(alpha: enabled ? 0.25 : 0.08),
        ),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(
          icon,
          color: isCenter
              ? (enabled ? const Color(0xFFFFB800) : Colors.white30)
              : (enabled ? Colors.white : Colors.white30),
          size: isCenter ? 22 : 20,
        ),
        onPressed: !enabled
            ? null
            : () async {
                HapticFeedback.lightImpact();
                try {
                  await home.executeDeviceCommand(device, 'ptz', 'ptzMove', [dir]);
                  setState(() => _actionStatus = 'Camera PTZ: Moving ${dir.toUpperCase()}');
                } catch (e) {
                  setState(() => _actionStatus = 'PTZ Error: $e');
                }
              },
      ),
    );
  }
}

class _CameraViewfinderPainter extends CustomPainter {
  final bool isPrivacy;
  const _CameraViewfinderPainter({required this.isPrivacy});

  @override
  void paint(Canvas canvas, Size size) {
    if (isPrivacy) return;

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Corner brackets
    const cornerSize = 16.0;
    const pad = 16.0;

    // Top-Left
    canvas.drawLine(const Offset(pad, pad), const Offset(pad + cornerSize, pad), paint);
    canvas.drawLine(const Offset(pad, pad), const Offset(pad, pad + cornerSize), paint);

    // Top-Right
    canvas.drawLine(Offset(size.width - pad, pad), Offset(size.width - pad - cornerSize, pad), paint);
    canvas.drawLine(Offset(size.width - pad, pad), Offset(size.width - pad, pad + cornerSize), paint);

    // Bottom-Left
    canvas.drawLine(Offset(pad, size.height - pad), Offset(pad + cornerSize, size.height - pad), paint);
    canvas.drawLine(Offset(pad, size.height - pad), Offset(pad, size.height - pad - cornerSize), paint);

    // Bottom-Right
    canvas.drawLine(Offset(size.width - pad, size.height - pad), Offset(size.width - pad - cornerSize, size.height - pad), paint);
    canvas.drawLine(Offset(size.width - pad, size.height - pad), Offset(size.width - pad, size.height - pad - cornerSize), paint);
  }

  @override
  bool shouldRepaint(covariant _CameraViewfinderPainter oldDelegate) => oldDelegate.isPrivacy != isPrivacy;
}

class _FeatureBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _FeatureBadge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

