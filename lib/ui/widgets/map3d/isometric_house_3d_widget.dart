import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../models/house_3d_twin_model.dart';
import '../../../providers/real_home_provider.dart';
import '../../../services/real_iot_controller.dart';
import '../../../theme/apple_glass_theme.dart';
import '../animations/universal_device_animations.dart';
import '../sheets/samsung_washer_sheet.dart';
import '../sheets/samsung_future_devices_sheet.dart';
import '../sheets/lg_future_appliances_sheet.dart';
import '../sheets/lg_thinq_ac_sheet.dart';

/// House Control stage background color matching Three.js scene background.
const Color kHouseControlStageBg = Color(0xFF0A0E1A);

/// Interactive True 3D Isometric Dollhouse Canvas with House Control Shaders,
/// Procedural Floors, Cutaway Architectural Walls, 3D Furniture, Volumetric Lights,
/// and Additive AC Airflow Streamers.
class IsometricHouse3DWidget extends StatefulWidget {
  final House3DTwinLayout? layout;
  final String selectedRoomId; // 'all', 'living', 'dining', 'kitchen', 'bedroom', 'bath'
  final ValueChanged<String>? onRoomSelected;
  final Function(Fixture3DNode fixture, RealSmartDevice? linkedDevice)? onFixtureTap;
  final Function(Fixture3DNode fixture, RealSmartDevice? linkedDevice)? onFixtureLongPress;
  final VoidCallback? onOpenBlueprintEditor;
  final bool isInteractive;
  final bool showBadges;
  final double height;

  const IsometricHouse3DWidget({
    super.key,
    this.layout,
    this.selectedRoomId = 'all',
    this.onRoomSelected,
    this.onFixtureTap,
    this.onFixtureLongPress,
    this.onOpenBlueprintEditor,
    this.isInteractive = true,
    this.showBadges = true,
    this.height = 360,
  });

  /// House Control authentic 8-color swatch palette from panel.js
  static const List<Color> kHouseControlSwatches = [
    Color(0xFFFF5A4F),
    Color(0xFFFF9A3C),
    Color(0xFFFFD84A),
    Color(0xFF5FE08A),
    Color(0xFF42D6E8),
    Color(0xFF4F8DFF),
    Color(0xFF8B5CFF),
    Color(0xFFFF5FC4),
  ];

  /// House Control AC mode colors from ac.js
  static const Map<String, Color> kHouseControlModeColors = {
    'cool': Color(0xFF4EA0FF),
    'heat': Color(0xFFFF9037),
    'dry': Color(0xFF3DD4BA),
    'fan': Color(0xFFB0BCCD),
    'auto': Color(0xFFB78AFF),
  };

  /// Kelvin temperature to RGB interpolation matching House Control lights.js
  static Color tempToColor(double kelvin) {
    final k = kelvin.clamp(2200.0, 6500.0);
    if (k <= 3000) {
      final t = (k - 2200) / (3000 - 2200);
      return Color.lerp(const Color(0xFFFF9438), const Color(0xFFFFBD7A), t)!;
    } else if (k <= 4200) {
      final t = (k - 3000) / (4200 - 3000);
      return Color.lerp(const Color(0xFFFFBD7A), const Color(0xFFFFE2C2), t)!;
    } else {
      final t = (k - 4200) / (6500 - 4200);
      return Color.lerp(const Color(0xFFFFE2C2), const Color(0xFFDFE9FF), t)!;
    }
  }

  @override
  State<IsometricHouse3DWidget> createState() => IsometricHouse3DWidgetState();
}

class IsometricHouse3DWidgetState extends State<IsometricHouse3DWidget>
    with TickerProviderStateMixin {
  late House3DTwinLayout _layout;

  // 3D Camera Angles matching House Control (azimuth 34 deg, elevation 47 deg)
  double _yaw = -0.59; // ~34 degrees
  double _pitch = 0.82; // ~47 degrees
  double _zoom = 1.0;
  double _baseZoom = 1.0;
  Offset _focus = const Offset(0.5, 0.5);

  // Animation Controllers
  late AnimationController _cameraAnimController;
  late Animation<double> _zoomAnim;
  late Animation<Offset> _focusAnim;

  // Continuous loop controller for AC airflow ribbons & breathing lights
  late AnimationController _flowController;

  @override
  void initState() {
    super.initState();
    _layout = widget.layout ?? House3DTwinLayout.defaultApartment();

    _cameraAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _zoomAnim = Tween<double>(begin: _zoom, end: _zoom).animate(
      CurvedAnimation(parent: _cameraAnimController, curve: Curves.easeOutCubic),
    );
    _focusAnim = Tween<Offset>(begin: _focus, end: _focus).animate(
      CurvedAnimation(parent: _cameraAnimController, curve: Curves.easeOutCubic),
    );

    _flowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    if (!WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      _flowController.repeat();
    } else {
      _flowController.value = 0.5;
    }

    _applyRoomFocus(widget.selectedRoomId, animate: false);
  }

  @override
  void didUpdateWidget(covariant IsometricHouse3DWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.layout != null && widget.layout != oldWidget.layout) {
      setState(() => _layout = widget.layout!);
    }
    if (widget.selectedRoomId != oldWidget.selectedRoomId) {
      _applyRoomFocus(widget.selectedRoomId, animate: true);
    }
  }

  @override
  void dispose() {
    _cameraAnimController.dispose();
    _flowController.dispose();
    super.dispose();
  }

  void _applyRoomFocus(String roomId, {bool animate = true}) {
    double targetZoom = 1.0;
    Offset targetFocus = const Offset(0.5, 0.5);

    if (roomId != 'all') {
      final room = _layout.rooms.firstWhere(
        (r) => r.id.toLowerCase() == roomId.toLowerCase(),
        orElse: () => _layout.rooms.first,
      );
      targetZoom = room.cameraZoom;
      targetFocus = room.cameraFocus;
    }

    if (!animate) {
      _zoom = targetZoom;
      _focus = targetFocus;
      return;
    }

    _zoomAnim = Tween<double>(begin: _zoom, end: targetZoom).animate(
      CurvedAnimation(parent: _cameraAnimController, curve: Curves.easeOutCubic),
    );
    _focusAnim = Tween<Offset>(begin: _focus, end: targetFocus).animate(
      CurvedAnimation(parent: _cameraAnimController, curve: Curves.easeOutCubic),
    );

    _cameraAnimController.forward(from: 0.0).then((_) {
      _zoom = targetZoom;
      _focus = targetFocus;
    });
  }

  void setCamera({double? yaw, double? pitch, double? zoom}) {
    HapticFeedback.selectionClick();
    setState(() {
      if (yaw != null) _yaw = yaw;
      if (pitch != null) _pitch = pitch;
      if (zoom != null) _zoom = zoom;
    });
  }

  void resetCamera() => _resetCamera();

  void _resetCamera() {
    HapticFeedback.lightImpact();
    setState(() {
      _yaw = -0.59;
      _pitch = 0.82;
      _zoom = 1.0;
      _focus = const Offset(0.5, 0.5);
    });
    widget.onRoomSelected?.call('all');
  }

  @override
  Widget build(BuildContext context) {
    RealHomeProvider? home;
    try {
      home = Provider.of<RealHomeProvider>(context, listen: true);
    } catch (_) {
      home = null;
    }
    final devices = home?.devices ?? const [];

    return LayoutBuilder(
      builder: (context, constraints) {
        final double renderW = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : 360.0;
        final double renderH = constraints.maxHeight.isFinite && constraints.maxHeight > 0
            ? constraints.maxHeight
            : (widget.height.isFinite && widget.height > 0 ? widget.height : 360.0);
        final renderSize = Size(renderW, renderH);

        return SizedBox(
          width: renderW,
          height: renderH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 3D Isometric Interactive Canvas with House Control background
              Container(
                width: renderW,
                height: renderH,
                color: kHouseControlStageBg,
              ),

              GestureDetector(
                onScaleStart: widget.isInteractive
                    ? (details) {
                        _baseZoom = _zoom;
                      }
                    : null,
                onScaleUpdate: widget.isInteractive
                    ? (details) {
                        setState(() {
                          if (details.pointerCount == 1) {
                            _yaw += details.focalPointDelta.dx * 0.008;
                            _pitch = (_pitch - details.focalPointDelta.dy * 0.008)
                                .clamp(0.20, 1.30);
                          } else if (details.pointerCount == 2) {
                            _zoom = (_baseZoom * details.scale).clamp(0.65, 2.80);
                          }
                        });
                      }
                    : null,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_cameraAnimController, _flowController]),
                  builder: (context, _) {
                    final curZoom = _cameraAnimController.isAnimating
                        ? _zoomAnim.value
                        : _zoom;
                    final curFocus = _cameraAnimController.isAnimating
                        ? _focusAnim.value
                        : _focus;

                    return CustomPaint(
                      size: renderSize,
                      painter: _IsometricDollhousePainter(
                        layout: _layout,
                        devices: devices,
                        yaw: _yaw,
                        pitch: _pitch,
                        zoom: curZoom,
                        focus: curFocus,
                        selectedRoomId: widget.selectedRoomId,
                        flowPhase: _flowController.value,
                      ),
                    );
                  },
                ),
              ),

              // Floating Badges in 3D Space (Overlay layer for tap targets)
              if (widget.showBadges)
                ..._buildInteractiveBadges(context, devices, renderSize, home),

              // Top Camera Controls Pill Bar
              Positioned(
                top: 12,
                right: 14,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.onOpenBlueprintEditor != null)
                      _buildControlPill(
                        icon: Icons.architecture_rounded,
                        tooltip: 'Edit 2D Floor Plan',
                        onTap: widget.onOpenBlueprintEditor!,
                      ),
                    const SizedBox(width: 8),
                    _buildControlPill(
                      icon: Icons.restart_alt_rounded,
                      tooltip: 'Reset Camera Orbit',
                      onTap: _resetCamera,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControlPill({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return GlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.all(8),
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.85)),
      ),
    );
  }

  List<Widget> _buildInteractiveBadges(
    BuildContext context,
    List<RealSmartDevice> devices,
    Size renderSize,
    RealHomeProvider? home,
  ) {
    final curZoom =
        _cameraAnimController.isAnimating ? _zoomAnim.value : _zoom;
    final curFocus =
        _cameraAnimController.isAnimating ? _focusAnim.value : _focus;

    final badges = <Widget>[];
    _layout.autoBindRealDevices(devices);

    for (final fix in _layout.fixtures) {
      final boundDev = _findBoundDevice(fix, devices);
      final isOn = boundDev?.isOn ?? false;

      // Project fixture position
      final screenPos = _projectIso(
        fix.x,
        fix.y,
        fix.zHeight,
        renderSize,
        yaw: _yaw,
        pitch: _pitch,
        zoom: curZoom,
        focus: curFocus,
      );

      // Filter badge if zoomed into another room
      if (widget.selectedRoomId != 'all' &&
          fix.roomId.toLowerCase() != widget.selectedRoomId.toLowerCase()) {
        continue;
      }

      badges.add(
        Positioned(
          left: screenPos.dx - 54,
          top: screenPos.dy - 34,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              if (boundDev != null) {
                final devId = boundDev.id.toLowerCase();
                final devName = boundDev.name.toLowerCase();
                final isLg = devId.contains('lg') || devName.contains('lg');

                if (isLg) {
                  if (devId.contains('washtower') || boundDev.category == 'washer') {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => LgFutureAppliancesSheet(initialDevice: boundDev, initialTabIndex: 0),
                    );
                  } else if (devId.contains('fridge') || boundDev.category == 'fridge' || devId.contains('instaview')) {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => LgFutureAppliancesSheet(initialDevice: boundDev, initialTabIndex: 1),
                    );
                  } else if (devId.contains('aerotower') || devId.contains('puricare') || boundDev.category.contains('purifier')) {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => LgFutureAppliancesSheet(initialDevice: boundDev, initialTabIndex: 2),
                    );
                  } else if (devId.contains('styler') || devId.contains('dish')) {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => LgFutureAppliancesSheet(initialDevice: boundDev, initialTabIndex: 3),
                    );
                  } else if (boundDev.category == 'ac') {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => LgThinqAcSheet(device: boundDev),
                    );
                  } else {
                    home?.toggleDevicePower(boundDev);
                  }
                } else if (boundDev.category == 'washer' || boundDev.id.contains('washer')) {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => SamsungWasherSheet(device: boundDev),
                  );
                } else if (boundDev.category == 'ac' && boundDev.windFreeEnabled) {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => SamsungFutureDevicesSheet(initialDevice: boundDev, initialTabIndex: 0),
                  );
                } else {
                  home?.toggleDevicePower(boundDev);
                }
              }
              widget.onFixtureTap?.call(fix, boundDev);
            },
            onLongPress: () {
              HapticFeedback.mediumImpact();
              if (boundDev != null) {
                if (boundDev.category == 'washer' || boundDev.id.contains('washer')) {
                  home?.toggleDevicePower(boundDev);
                } else if (boundDev.category == 'ac') {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => SamsungFutureDevicesSheet(initialDevice: boundDev, initialTabIndex: 0),
                  );
                }
              }
              widget.onFixtureLongPress?.call(fix, boundDev);
            },
            child: _buildBadgeContent(fix, boundDev, isOn),
          ),
        ),
      );
    }

    return badges;
  }

  Widget _buildBadgeContent(
      Fixture3DNode fix, RealSmartDevice? dev, bool isOn) {
    final tint = _getBadgeTint(fix, dev, isOn);
    final icon = _getBadgeIcon(fix, dev);

    String detailText = isOn ? 'ON' : 'OFF';
    bool isSamsungAppliance = false;
    bool isLgAppliance = false;

    if (dev != null) {
      final devId = dev.id.toLowerCase();
      final devName = dev.name.toLowerCase();
      final isLg = devId.contains('lg') || devName.contains('lg');

      if (isLg) {
        isLgAppliance = true;
        if (devId.contains('washtower')) {
          detailText = isOn ? 'WASHTOWER · ${dev.remainingMinutes}m' : 'WASHTOWER · OFF';
        } else if (devId.contains('aerotower')) {
          detailText = isOn ? 'AEROTOWER · Clean Booster' : 'AEROTOWER · OFF';
        } else if (devId.contains('instaview') || dev.category == 'fridge') {
          detailText = isOn ? 'INSTAVIEW · Craft Ice™' : 'FRIDGE · OFF';
        } else if (devId.contains('styler')) {
          detailText = isOn ? 'STYLER · TrueSteam®' : 'STYLER · OFF';
        } else if (dev.category == 'washer') {
          detailText = isOn ? 'LG WASHER · ${dev.remainingMinutes}m' : 'WASHER · OFF';
        } else if (isOn && dev.category == 'ac') {
          detailText = '${dev.primaryValue.round()}°C · AI Cool';
        }
      } else if (dev.category == 'washer' || fix.fixtureType.contains('washer')) {
        isSamsungAppliance = true;
        if (isOn) {
          final stage = dev.washerStage.toUpperCase();
          detailText = '$stage · ${dev.remainingMinutes}m';
        } else {
          detailText = 'WASHER · OFF';
        }
      } else if (isOn) {
        if (dev.category == 'light') {
          detailText = '${dev.primaryValue.round()}%';
        } else if (dev.category == 'ac') {
          final windFreeTag = dev.windFreeEnabled ? ' · WindFree™' : '';
          detailText = '${dev.primaryValue.round()}°C$windFreeTag';
        } else if (dev.category == 'tv') {
          detailText = dev.artModeEnabled ? 'Art Mode' : 'TV · ON';
        } else if (dev.category == 'fridge' || dev.category == 'refrigerator') {
          detailText = '${dev.fridgeTemp.round()}°C / ${dev.freezerTemp.round()}°C';
        }
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isOn
            ? (isSamsungAppliance
                ? const Color(0xFF0F1E36)
                : (isLgAppliance ? const Color(0xFF28101E) : tint.withValues(alpha: 0.85)))
            : const Color(0xCC111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOn
              ? (isSamsungAppliance
                  ? const Color(0xFF00E5FF)
                  : (isLgAppliance ? const Color(0xFFFF4081) : Colors.white))
              : Colors.white.withValues(alpha: 0.25),
          width: (isSamsungAppliance || isLgAppliance) && isOn ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isOn
                ? (isSamsungAppliance ? const Color(0xFF00E5FF).withValues(alpha: 0.4) : tint.withValues(alpha: 0.5))
                : Colors.black45,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            (isSamsungAppliance && isOn) ? Icons.sync_rounded : icon,
            size: 13,
            color: (isSamsungAppliance && isOn) ? const Color(0xFF00E5FF) : Colors.white,
          ),
          const SizedBox(width: 5),
          Text(
            detailText,
            style: TextStyle(
              color: (isSamsungAppliance && isOn) ? const Color(0xFF00E5FF) : Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  RealSmartDevice? _findBoundDevice(
      Fixture3DNode fixture, List<RealSmartDevice> devices) {
    if (fixture.linkedRealDeviceId != null) {
      try {
        return devices.firstWhere((d) => d.id == fixture.linkedRealDeviceId);
      } catch (_) {}
    }

    // Heuristic room + category match
    for (final d in devices) {
      final roomMatch = d.room.toLowerCase().contains(fixture.roomId.toLowerCase());
      if (roomMatch) {
        if (fixture.fixtureType.contains('light') && d.category == 'light') {
          return d;
        }
        if (fixture.fixtureType.contains('ac') && d.category == 'ac') {
          return d;
        }
        if (fixture.fixtureType.contains('washer') && d.category == 'washer') {
          return d;
        }
        if (fixture.fixtureType.contains('camera') && d.category == 'camera') {
          return d;
        }
        if (fixture.fixtureType.contains('tv') && d.category == 'tv') {
          return d;
        }
      }
    }
    return null;
  }

  Color _getBadgeTint(Fixture3DNode fix, RealSmartDevice? dev, bool isOn) {
    if (!isOn) return const Color(0xFF4B5563);
    if (dev != null) {
      final arch = UniversalCategoryClassifier.classify(dev);
      return UniversalCategoryClassifier.colorFor(arch);
    }
    if (fix.fixtureType.contains('light')) return const Color(0xFFFF9F0A);
    if (fix.fixtureType.contains('ac')) return const Color(0xFF00D4FF);
    if (fix.fixtureType.contains('camera')) return const Color(0xFF30D158);
    return const Color(0xFF0A84FF);
  }

  IconData _getBadgeIcon(Fixture3DNode fix, RealSmartDevice? dev) {
    if (dev != null) {
      final arch = UniversalCategoryClassifier.classify(dev);
      return UniversalCategoryClassifier.iconFor(arch);
    }
    if (fix.fixtureType.contains('light')) return Icons.lightbulb_rounded;
    if (fix.fixtureType.contains('ac')) return Icons.ac_unit_rounded;
    if (fix.fixtureType.contains('camera')) return Icons.videocam_rounded;
    if (fix.fixtureType.contains('washer')) return Icons.local_laundry_service_rounded;
    return Icons.power_settings_new_rounded;
  }

  static Offset _projectIso(
    double x,
    double y,
    double z,
    Size size, {
    required double yaw,
    required double pitch,
    required double zoom,
    required Offset focus,
  }) {
    const double scale = 290.0;
    const double wallHeightScale = 110.0;

    final safeWidth = size.width.isFinite && size.width > 0 ? size.width : 360.0;
    final safeHeight = size.height.isFinite && size.height > 0 ? size.height : 360.0;

    final cx = (x - focus.dx) * scale * zoom;
    final cy = (y - focus.dy) * scale * zoom;

    final rx = cx * math.cos(yaw) - cy * math.sin(yaw);
    final ry = cx * math.sin(yaw) + cy * math.cos(yaw);

    final screenX = safeWidth / 2 + (rx - ry) * math.cos(0.5236); // 30 deg
    final screenY = safeHeight / 2 +
        (rx + ry) * math.sin(0.5236) * pitch -
        (z * wallHeightScale * zoom);

    return Offset(screenX, screenY);
  }
}

/// Custom Painter executing True 3D Isometric Architectural Projection,
/// Cutaway Dollhouse Walls, 3D Furniture, and Volumetric Light Shaders.
class _IsometricDollhousePainter extends CustomPainter {
  final House3DTwinLayout layout;
  final List<RealSmartDevice> devices;
  final double yaw;
  final double pitch;
  final double zoom;
  final Offset focus;
  final String selectedRoomId;
  final double flowPhase;

  _IsometricDollhousePainter({
    required this.layout,
    required this.devices,
    required this.yaw,
    required this.pitch,
    required this.zoom,
    required this.focus,
    required this.selectedRoomId,
    required this.flowPhase,
  });

  Offset _project(double x, double y, double z, Size size) {
    return IsometricHouse3DWidgetState._projectIso(
      x,
      y,
      z,
      size,
      yaw: yaw,
      pitch: pitch,
      zoom: zoom,
      focus: focus,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 1. House Control Plinth Base & Ambient Floor Shadow
    _drawPlinthBase(canvas, size);

    // 2. Room Floor Polygons & Procedural Textures (Oak, Walnut, Stone, Tile)
    for (final room in layout.rooms) {
      _drawRoomFloor(canvas, size, room);
    }

    // 3. Volumetric Floor Light Pools & Cones (Kelvin temp to RGB)
    _drawVolumetricLightPools(canvas, size);

    // 4. House Control 3D Furniture Suite (Sofa, TV, Dining, Bed, Counter, Plants)
    for (final prop in layout.furniture) {
      _drawFurnitureProp(canvas, size, prop);
    }

    // 5. 3D Cutaway Dollhouse Walls, Openings & Window Glass
    _drawExtrudedWalls(canvas, size);

    // 6. Live 3D AC Airflow Particle Streamers (Additive Streaks with sway & gravity)
    _drawAcAirflowStreamers(canvas, size);
  }

  void _drawPlinthBase(Canvas canvas, Size size) {
    // Grounding Plinth under Building Footprint (#141927)
    final p1 = _project(-0.02, -0.02, 0.0, size);
    final p2 = _project(1.02, -0.02, 0.0, size);
    final p3 = _project(1.02, 1.02, 0.0, size);
    final p4 = _project(-0.02, 1.02, 0.0, size);

    final b1 = _project(-0.02, -0.02, -0.06, size);
    final b2 = _project(1.02, -0.02, -0.06, size);
    final b3 = _project(1.02, 1.02, -0.06, size);
    final b4 = _project(-0.02, 1.02, -0.06, size);

    // Ambient drop shadow beneath plinth
    final shadowPath = Path()
      ..moveTo(b1.dx, b1.dy + 8)
      ..lineTo(b2.dx, b2.dy + 8)
      ..lineTo(b3.dx, b3.dy + 8)
      ..lineTo(b4.dx, b4.dy + 8)
      ..close();

    canvas.drawPath(
      shadowPath,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.65)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
    );

    // Plinth Front Face
    final plinthFront = Path()
      ..moveTo(p4.dx, p4.dy)
      ..lineTo(p3.dx, p3.dy)
      ..lineTo(b3.dx, b3.dy)
      ..lineTo(b4.dx, b4.dy)
      ..close();
    canvas.drawPath(plinthFront, Paint()..color = const Color(0xFF0F131D));

    // Plinth Right Face
    final plinthRight = Path()
      ..moveTo(p3.dx, p3.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(b2.dx, b2.dy)
      ..lineTo(b3.dx, b3.dy)
      ..close();
    canvas.drawPath(plinthRight, Paint()..color = const Color(0xFF141927));

    // Plinth Top Slab
    final plinthTop = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..lineTo(p4.dx, p4.dy)
      ..close();
    canvas.drawPath(plinthTop, Paint()..color = const Color(0xFF1B2234));
  }

  void _drawRoomFloor(Canvas canvas, Size size, Room3DZone room) {
    final r = room.gridRect;
    final p1 = _project(r.left, r.top, 0.0, size);
    final p2 = _project(r.right, r.top, 0.0, size);
    final p3 = _project(r.right, r.bottom, 0.0, size);
    final p4 = _project(r.left, r.bottom, 0.0, size);

    final floorPath = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..lineTo(p4.dx, p4.dy)
      ..close();

    final isSelected = selectedRoomId != 'all' &&
        selectedRoomId.toLowerCase() == room.id.toLowerCase();

    // 1. Base floor tone
    final floorColor = room.floorType.color;
    canvas.drawPath(
      floorPath,
      Paint()
        ..color = isSelected ? floorColor : floorColor.withValues(alpha: 0.88)
        ..style = PaintingStyle.fill,
    );

    // 2. Procedural Floor Texture (Wood planks or Stone/Tile Grid)
    canvas.save();
    canvas.clipPath(floorPath);

    if (room.floorType == FloorMaterialType.oak || room.floorType == FloorMaterialType.walnut) {
      // Wood plank slats along the X-axis
      const int plankRows = 8;
      final stepY = (r.bottom - r.top) / plankRows;
      final plankLinePaint = Paint()
        ..color = room.floorType.groutColor
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke;

      for (int i = 1; i < plankRows; i++) {
        final py = r.top + i * stepY;
        final start = _project(r.left, py, 0.0, size);
        final end = _project(r.right, py, 0.0, size);
        canvas.drawLine(start, end, plankLinePaint);

        // Staggered vertical plank end seams
        final int verticalSeams = 4;
        final stepX = (r.right - r.left) / verticalSeams;
        final offsetX = (i % 2 == 0) ? stepX * 0.5 : 0.0;
        for (int j = 0; j <= verticalSeams; j++) {
          final px = (r.left + offsetX + j * stepX).clamp(r.left, r.right);
          final s1 = _project(px, py - stepY, 0.0, size);
          final s2 = _project(px, py, 0.0, size);
          canvas.drawLine(s1, s2, plankLinePaint);
        }
      }
    } else {
      // Ceramic Tile or Stone Grid with grout lines
      const int tileGrid = 6;
      final stepX = (r.right - r.left) / tileGrid;
      final stepY = (r.bottom - r.top) / tileGrid;
      final groutPaint = Paint()
        ..color = room.floorType.groutColor
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      for (int i = 1; i < tileGrid; i++) {
        final px = r.left + i * stepX;
        canvas.drawLine(_project(px, r.top, 0.0, size), _project(px, r.bottom, 0.0, size), groutPaint);
      }
      for (int j = 1; j < tileGrid; j++) {
        final py = r.top + j * stepY;
        canvas.drawLine(_project(r.left, py, 0.0, size), _project(r.right, py, 0.0, size), groutPaint);
      }
    }
    canvas.restore();

    // 3. Perimeter Architectural Border
    final borderPaint = Paint()
      ..color = isSelected
          ? const Color(0xFF0A84FF)
          : Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 2.2 : 1.0;

    canvas.drawPath(floorPath, borderPaint);
  }

  void _drawVolumetricLightPools(Canvas canvas, Size size) {
    for (final fix in layout.fixtures) {
      if (!fix.fixtureType.contains('light') &&
          fix.fixtureType != 'ceiling' &&
          fix.fixtureType != 'pendant' &&
          fix.fixtureType != 'spots' &&
          fix.fixtureType != 'floor' &&
          fix.fixtureType != 'table' &&
          fix.fixtureType != 'strip') {
        continue;
      }

      final dev = _findDeviceForFixture(fix);
      final isOn = dev?.isOn ?? true;
      if (!isOn) continue;

      final brightness = dev != null ? (dev.primaryValue / 100.0).clamp(0.25, 1.0) : 0.85;
      final lightColor = _getDeviceLightColor(fix, dev);

      // Floor center of light pool
      final poolCenter = _project(fix.x, fix.y, 0.0, size);
      final lightRadius = (75.0 * zoom * brightness).clamp(35.0, 160.0);

      // Multi-stop RadialGradient Light Pool on Room Floor matching House Control
      final gradient = RadialGradient(
        colors: [
          lightColor.withValues(alpha: 0.48 * brightness),
          lightColor.withValues(alpha: 0.22 * brightness),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      );

      final paint = Paint()
        ..shader = gradient.createShader(
          Rect.fromCircle(center: poolCenter, radius: lightRadius),
        );

      canvas.drawCircle(poolCenter, lightRadius, paint);

      // Translucent Volumetric Light Cone from Ceiling fixture down to Floor
      final fixtureTop = _project(fix.x, fix.y, fix.zHeight, size);
      final conePath = Path()
        ..moveTo(fixtureTop.dx, fixtureTop.dy)
        ..lineTo(poolCenter.dx - lightRadius * 0.75, poolCenter.dy)
        ..lineTo(poolCenter.dx + lightRadius * 0.75, poolCenter.dy)
        ..close();

      final conePaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lightColor.withValues(alpha: 0.32 * brightness),
            Colors.transparent,
          ],
        ).createShader(conePath.getBounds());

      canvas.drawPath(conePath, conePaint);
    }
  }

  void _drawExtrudedWalls(Canvas canvas, Size size) {
    const wallThick = 0.022;
    const fullHeight = 0.22; // Back and left walls (standing full)
    const curbHeight = 0.045; // Camera-side near walls cut down to curb

    final allWalls = <_WallSegment>[
      // Outer Boundary Back Wall (North: full height)
      _WallSegment(0.04, 0.04, 0.96, 0.04, fullHeight, wallThick),
      // Outer Boundary Left Wall (West: full height)
      _WallSegment(0.04, 0.04, 0.04, 0.96, fullHeight, wallThick, isWindow: true, windowStart: 0.65, windowEnd: 0.85),

      // Outer Boundary Front Cutaway Wall (South: low curb so interior is visible)
      _WallSegment(0.04, 0.96, 0.96, 0.96, curbHeight, wallThick),
      // Outer Boundary Right Wall (East: low curb)
      _WallSegment(0.96, 0.04, 0.96, 0.96, curbHeight, wallThick),

      // Interior Dividers (Cut low at 0.12 height with doorway gaps)
      // Horizontal corridor divider between Top (Bed/Bath/Kit) and Bottom (Living/Dining)
      _WallSegment(0.04, 0.46, 0.96, 0.46, 0.13, wallThick, hasDoorway: true, doorwayStart: 0.31, doorwayEnd: 0.40),
      // Divider between Bedroom and Bathroom
      _WallSegment(0.42, 0.04, 0.42, 0.46, 0.14, wallThick),
      // Divider between Bathroom and Kitchen
      _WallSegment(0.64, 0.04, 0.64, 0.46, 0.14, wallThick),
      // Divider between Living and Dining (with wide open archway)
      _WallSegment(0.62, 0.46, 0.62, 0.96, 0.13, wallThick, hasDoorway: true, doorwayStart: 0.54, doorwayEnd: 0.88),
    ];

    for (final wall in allWalls) {
      _paintWall(canvas, size, wall);
    }
  }

  void _paintWall(Canvas canvas, Size size, _WallSegment w) {
    if (w.hasDoorway && w.doorwayStart != null && w.doorwayEnd != null) {
      // Split into two segments leaving the doorway opening
      final isHorizontal = (w.y2 - w.y1).abs() < (w.x2 - w.x1).abs();
      if (isHorizontal) {
        _paintSolidWall(canvas, size, w.x1, w.y1, w.doorwayStart!, w.y2, w.height);
        _paintSolidWall(canvas, size, w.doorwayEnd!, w.y1, w.x2, w.y2, w.height);
      } else {
        _paintSolidWall(canvas, size, w.x1, w.y1, w.x2, w.doorwayStart!, w.height);
        _paintSolidWall(canvas, size, w.x1, w.doorwayEnd!, w.x2, w.y2, w.height);
      }
      return;
    }

    if (w.isWindow && w.windowStart != null && w.windowEnd != null) {
      // Window wall with sill, translucent glass, and frame
      _paintSolidWall(canvas, size, w.x1, w.y1, w.x2, w.windowStart!, w.height);
      _paintWindowWall(canvas, size, w.x1, w.windowStart!, w.x2, w.windowEnd!, w.height);
      _paintSolidWall(canvas, size, w.x1, w.windowEnd!, w.x2, w.y2, w.height);
      return;
    }

    _paintSolidWall(canvas, size, w.x1, w.y1, w.x2, w.y2, w.height);
  }

  void _paintSolidWall(
    Canvas canvas,
    Size size,
    double x1,
    double y1,
    double x2,
    double y2,
    double height,
  ) {
    final p1Base = _project(x1, y1, 0.0, size);
    final p2Base = _project(x2, y2, 0.0, size);
    final p1Top = _project(x1, y1, height, size);
    final p2Top = _project(x2, y2, height, size);

    // Wall Face (House Control Creamy Off-White Plaster #E7E3DB with directional light shading)
    final facePath = Path()
      ..moveTo(p1Base.dx, p1Base.dy)
      ..lineTo(p2Base.dx, p2Base.dy)
      ..lineTo(p2Top.dx, p2Top.dy)
      ..lineTo(p1Top.dx, p1Top.dy)
      ..close();

    final isHorizontal = (y2 - y1).abs() < (x2 - x1).abs();
    final faceColor = isHorizontal
        ? const Color(0xFFD6D1C7) // Left-facing directional shading
        : const Color(0xFFE7E3DB); // Front-facing plaster body

    canvas.drawPath(facePath, Paint()..color = faceColor);

    // Architectural Wall Top-Cap (House Control Slate Cap #262B3A)
    final capPath = Path()
      ..moveTo(p1Top.dx, p1Top.dy)
      ..lineTo(p2Top.dx, p2Top.dy)
      ..lineTo(p2Top.dx + 2, p2Top.dy - 3)
      ..lineTo(p1Top.dx + 2, p1Top.dy - 3)
      ..close();

    canvas.drawPath(capPath, Paint()..color = const Color(0xFF262B3A));
  }

  void _paintWindowWall(
    Canvas canvas,
    Size size,
    double x1,
    double y1,
    double x2,
    double y2,
    double height,
  ) {
    // Window sill below
    _paintSolidWall(canvas, size, x1, y1, x2, y2, 0.08);

    // Window Glass Pane (#9CC0FF at 25% opacity)
    final p1Sill = _project(x1, y1, 0.08, size);
    final p2Sill = _project(x2, y2, 0.08, size);
    final p1Head = _project(x1, y1, height - 0.02, size);
    final p2Head = _project(x2, y2, height - 0.02, size);

    final glassPath = Path()
      ..moveTo(p1Sill.dx, p1Sill.dy)
      ..lineTo(p2Sill.dx, p2Sill.dy)
      ..lineTo(p2Head.dx, p2Head.dy)
      ..lineTo(p1Head.dx, p1Head.dy)
      ..close();

    canvas.drawPath(
      glassPath,
      Paint()
        ..color = const Color(0x409CC0FF)
        ..style = PaintingStyle.fill,
    );

    // Window Mullions and Frame (#2C3142)
    final framePaint = Paint()
      ..color = const Color(0xFF2C3142)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    canvas.drawPath(glassPath, framePaint);
  }

  void _drawFurnitureProp(Canvas canvas, Size size, Furniture3DProp p) {
    final x = p.x;
    final y = p.y;
    final w = p.width;
    final d = p.depth;
    final h = p.height;

    switch (p.type) {
      case 'sofa':
        _drawSofa(canvas, size, x, y, w, d, h, p.colorHex);
        break;
      case 'armchair':
        _drawArmchair(canvas, size, x, y, w, d, h, p.colorHex);
        break;
      case 'tv':
      case 'tv_unit':
        _drawTvConsole(canvas, size, x, y, w, d, h);
        break;
      case 'diningSet':
      case 'dining_table':
        _drawDiningSet(canvas, size, x, y, w, d, h, p.chairs ?? 6);
        break;
      case 'coffeeTable':
      case 'coffee_table':
        _drawCoffeeTable(canvas, size, x, y, w, d, h);
        break;
      case 'island':
        _drawKitchenIsland(canvas, size, x, y, w, d, h);
        break;
      case 'kitchen':
      case 'kitchen_counter':
        _drawKitchenCounters(canvas, size, x, y, w, d, h);
        break;
      case 'fridge':
        _drawFridge(canvas, size, x, y, w, d, h);
        break;
      case 'bed':
        _drawBed(canvas, size, x, y, w, d, h, p.colorHex);
        break;
      case 'nightstand':
        _drawNightstand(canvas, size, x, y, w, d, h);
        break;
      case 'bathtub':
      case 'bath_tub':
        _drawBathtub(canvas, size, x, y, w, d, h);
        break;
      case 'vanity':
        _drawVanity(canvas, size, x, y, w, d, h);
        break;
      case 'toilet':
        _drawToilet(canvas, size, x, y, w, d, h);
        break;
      case 'rug':
        _drawRug(canvas, size, x, y, w, d, p.colorHex);
        break;
      case 'plant':
        _drawPlant(canvas, size, x, y, w, d, h);
        break;
      case 'desk':
        _drawDesk(canvas, size, x, y, w, d, h);
        break;
      case 'bookshelf':
        _drawBookshelf(canvas, size, x, y, w, d, h);
        break;
      case 'sideboard':
        _drawSideboard(canvas, size, x, y, w, d, h);
        break;
      default:
        _drawDefaultPrism(canvas, size, x, y, w, d, h, const Color(0xFF334155), const Color(0xFF1E293B));
        break;
    }
  }

  void _drawDesk(Canvas canvas, Size size, double x, double y, double w, double d, double h) {
    // Desktop slab (#8D735C)
    _drawPrism(canvas, size, x, y, w, d, h * 0.15, const Color(0xFF8D735C), const Color(0xFF6B533E));
    // Legs (#1E232E)
    _drawPrism(canvas, size, x + 0.005, y + 0.005, 0.015, 0.015, h * 0.85, const Color(0xFF1E232E), Colors.black);
    _drawPrism(canvas, size, x + w - 0.02, y + 0.005, 0.015, 0.015, h * 0.85, const Color(0xFF1E232E), Colors.black);
    _drawPrism(canvas, size, x + 0.005, y + d - 0.02, 0.015, 0.015, h * 0.85, const Color(0xFF1E232E), Colors.black);
    _drawPrism(canvas, size, x + w - 0.02, y + d - 0.02, 0.015, 0.015, h * 0.85, const Color(0xFF1E232E), Colors.black);
  }

  void _drawBookshelf(Canvas canvas, Size size, double x, double y, double w, double d, double h) {
    // Bookshelf Frame (#5A4535)
    _drawPrism(canvas, size, x, y, w, d, h, const Color(0xFF5A4535), const Color(0xFF3E2E22));
    // Shelves (#8A6D56)
    for (int i = 1; i <= 3; i++) {
      _drawPrism(canvas, size, x + 0.005, y + 0.005, w - 0.01, d - 0.005, 0.01, const Color(0xFF8A6D56), const Color(0xFF4A382A));
    }
  }

  void _drawSideboard(Canvas canvas, Size size, double x, double y, double w, double d, double h) {
    // Low credenza cabinet (#4A3B32)
    _drawPrism(canvas, size, x, y, w, d, h, const Color(0xFF4A3B32), const Color(0xFF2E241E));
    // Brass accents (#C5A059)
    _drawPrism(canvas, size, x + w * 0.25, y + d * 0.85, 0.02, 0.01, 0.01, const Color(0xFFC5A059), const Color(0xFF94753A));
    _drawPrism(canvas, size, x + w * 0.65, y + d * 0.85, 0.02, 0.01, 0.01, const Color(0xFFC5A059), const Color(0xFF94753A));
  }

  void _drawSofa(Canvas canvas, Size size, double x, double y, double w, double d, double h, String? colorHex) {
    final sofaColor = colorHex != null ? _parseColor(colorHex) : const Color(0xFF8B93A7);
    final darkBase = const Color(0xFF1E293B);

    // 1. Plinth Base
    _drawPrism(canvas, size, x, y, w, d, h * 0.15, const Color(0xFF1A202C), Colors.black);

    // 2. Main Cushions (Split 2-seater with stitch seam)
    final cushionH = h * 0.45;
    final halfW = (w - 0.04) / 2;
    _drawPrism(canvas, size, x + 0.02, y + 0.02, halfW - 0.005, d - 0.04, cushionH, sofaColor, darkBase);
    _drawPrism(canvas, size, x + 0.02 + halfW + 0.005, y + 0.02, halfW - 0.005, d - 0.04, cushionH, sofaColor, darkBase);

    // 3. Backrest with angled bevel
    _drawPrism(canvas, size, x + w * 0.72, y, w * 0.28, d, h, sofaColor, darkBase);

    // 4. Dual Armrests (Left & Right)
    _drawPrism(canvas, size, x, y, w * 0.72, 0.035, h * 0.75, sofaColor, darkBase);
    _drawPrism(canvas, size, x, y + d - 0.035, w * 0.72, 0.035, h * 0.75, sofaColor, darkBase);

    // 5. Decorative Throw Pillows (#D9B98A mustard & #38BDF8 cyan)
    _drawPrism(canvas, size, x + w * 0.58, y + 0.04, 0.04, 0.04, h * 0.85, const Color(0xFFD9B98A), const Color(0xFFB5935F));
    _drawPrism(canvas, size, x + w * 0.58, y + d - 0.08, 0.04, 0.04, h * 0.85, const Color(0xFF38BDF8), const Color(0xFF0284C7));
  }

  void _drawArmchair(Canvas canvas, Size size, double x, double y, double w, double d, double h, String? colorHex) {
    final leatherColor = colorHex != null ? _parseColor(colorHex) : const Color(0xFFC28A5A);
    _drawPrism(canvas, size, x, y, w, d, h * 0.65, leatherColor, const Color(0xFF8F5D34));
    _drawPrism(canvas, size, x + w * 0.75, y, w * 0.25, d, h, leatherColor, const Color(0xFF8F5D34));
  }

  void _drawTvConsole(Canvas canvas, Size size, double x, double y, double w, double d, double h) {
    // Dark wood credenza (#5A4334)
    _drawPrism(canvas, size, x, y, w, d, h * 0.45, const Color(0xFF5A4334), const Color(0xFF3A291E));
    // Soundbar (#1B1C21)
    _drawPrism(canvas, size, x + w * 0.2, y + d * 0.25, w * 0.6, d * 0.5, h * 0.55, const Color(0xFF1B1C21), Colors.black);
    // Glowing OLED Screen (#05070C emissive #27407A)
    final t1 = _project(x + w * 0.1, y, h * 0.55, size);
    final t2 = _project(x + w * 0.9, y, h * 0.55, size);
    final t3 = _project(x + w * 0.9, y, h * 1.35, size);
    final t4 = _project(x + w * 0.1, y, h * 1.35, size);

    final screenPath = Path()
      ..moveTo(t1.dx, t1.dy)
      ..lineTo(t2.dx, t2.dy)
      ..lineTo(t3.dx, t3.dy)
      ..lineTo(t4.dx, t4.dy)
      ..close();

    canvas.drawPath(screenPath, Paint()..color = const Color(0xFF0B101D));
    canvas.drawPath(
      screenPath,
      Paint()
        ..color = const Color(0xFF3D6BCE).withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawDiningSet(Canvas canvas, Size size, double x, double y, double w, double d, double h, int chairs) {
    // 1. Tabletop (#B48D63 Walnut)
    _drawPrism(canvas, size, x, y, w, d, h, const Color(0xFFB48D63), const Color(0xFF7D5936));

    // 2. Slender Black Metal Table Legs
    const legW = 0.012;
    _drawPrism(canvas, size, x + 0.01, y + 0.01, legW, legW, h * 0.95, const Color(0xFF1E2430), Colors.black);
    _drawPrism(canvas, size, x + w - legW - 0.01, y + 0.01, legW, legW, h * 0.95, const Color(0xFF1E2430), Colors.black);
    _drawPrism(canvas, size, x + 0.01, y + d - legW - 0.01, legW, legW, h * 0.95, const Color(0xFF1E2430), Colors.black);
    _drawPrism(canvas, size, x + w - legW - 0.01, y + d - legW - 0.01, legW, legW, h * 0.95, const Color(0xFF1E2430), Colors.black);

    // 3. Centerpiece ceramic bowl (#ECEAE5) & succulent
    _drawPrism(canvas, size, x + w * 0.42, y + d * 0.42, w * 0.16, d * 0.16, h + 0.025, const Color(0xFFECEAE5), const Color(0xFFD4D0C7));
    _drawPrism(canvas, size, x + w * 0.46, y + d * 0.46, w * 0.08, d * 0.08, h + 0.045, const Color(0xFF22C55E), const Color(0xFF15803D));

    // 4. Dining Chairs arranged on sides with seat and backrest slats
    // Left Chairs
    _drawPrism(canvas, size, x - 0.035, y + 0.02, 0.025, d * 0.38, h * 0.55, const Color(0xFF2B2E37), const Color(0xFF1B1C21));
    _drawPrism(canvas, size, x - 0.035, y + 0.02, 0.008, d * 0.38, h * 0.90, const Color(0xFF374151), const Color(0xFF1B1C21));
    // Right Chairs
    _drawPrism(canvas, size, x + w + 0.01, y + 0.02, 0.025, d * 0.38, h * 0.55, const Color(0xFF2B2E37), const Color(0xFF1B1C21));
    _drawPrism(canvas, size, x + w + 0.027, y + 0.02, 0.008, d * 0.38, h * 0.90, const Color(0xFF374151), const Color(0xFF1B1C21));
  }

  void _drawCoffeeTable(Canvas canvas, Size size, double x, double y, double w, double d, double h) {
    _drawPrism(canvas, size, x, y, w, d, h, const Color(0xFFA98459), const Color(0xFF725433));
    // Red book & white ceramic mug
    _drawPrism(canvas, size, x + w * 0.2, y + d * 0.2, 0.04, 0.03, h + 0.015, const Color(0xFFC9553F), const Color(0xFF8F3221));
    _drawPrism(canvas, size, x + w * 0.6, y + d * 0.5, 0.02, 0.02, h + 0.025, const Color(0xFFECEAE5), const Color(0xFFC5C2B8));
  }

  void _drawKitchenIsland(Canvas canvas, Size size, double x, double y, double w, double d, double h) {
    // 1. Dark Cabinet Base (#39424F)
    _drawPrism(canvas, size, x, y, w, d, h * 0.9, const Color(0xFF39424F), const Color(0xFF232B36));

    // 2. Polished White Marble Top with Waterfall Edge (#E9E7E2)
    _drawPrism(canvas, size, x - 0.01, y - 0.01, w + 0.02, d + 0.02, h, const Color(0xFFE9E7E2), const Color(0xFFD0CDC4));

    // 3. Undermount Dark Sink (#1E293B) & Metallic Faucet Spout
    _drawPrism(canvas, size, x + 0.02, y + d * 0.2, w * 0.35, d * 0.55, h - 0.01, const Color(0xFF1E293B), Colors.black);
    final f1 = _project(x + 0.03, y + d * 0.45, h + 0.01, size);
    final f2 = _project(x + 0.03, y + d * 0.45, h + 0.06, size);
    final f3 = _project(x + 0.08, y + d * 0.45, h + 0.05, size);
    final faucetPath = Path()..moveTo(f1.dx, f1.dy)..lineTo(f2.dx, f2.dy)..lineTo(f3.dx, f3.dy);
    canvas.drawPath(faucetPath, Paint()..color = const Color(0xFFCBD5E1)..style = PaintingStyle.stroke..strokeWidth = 2.0);

    // 4. Induction Cooktop Burner Rings (#0F172A)
    _drawPrism(canvas, size, x + w * 0.55, y + d * 0.25, w * 0.38, d * 0.5, h + 0.004, const Color(0xFF0F172A), Colors.black);

    // 5. Minimalist Bar Stools (#C28A5A wood top with metal legs)
    for (int i = 0; i < 3; i++) {
      final sx = x + (w / 3) * (i + 0.18);
      _drawPrism(canvas, size, sx, y + d + 0.02, 0.035, 0.035, h * 0.72, const Color(0xFFC28A5A), const Color(0xFF1B1C21));
    }
  }

  void _drawKitchenCounters(Canvas canvas, Size size, double x, double y, double w, double d, double h) {
    _drawPrism(canvas, size, x, y, w, d, h, const Color(0xFFE2E0D8), const Color(0xFF334155));
    // Cooktop / Sink detail
    _drawPrism(canvas, size, x + w * 0.3, y + d * 0.2, w * 0.35, d * 0.6, h + 0.005, const Color(0xFF1E293B), Colors.black);
  }

  void _drawFridge(Canvas canvas, Size size, double x, double y, double w, double d, double h) {
    // Stainless steel tall refrigerator (#9A9FA8)
    _drawPrism(canvas, size, x, y, w, d, h, const Color(0xFF9A9FA8), const Color(0xFF64748B));
    // Split door seam
    final d1 = _project(x + w * 0.5, y, h * 0.45, size);
    final d2 = _project(x + w * 0.5, y + d, h * 0.45, size);
    canvas.drawLine(d1, d2, Paint()..color = const Color(0xFF334155)..strokeWidth = 1.5);
  }

  void _drawBed(Canvas canvas, Size size, double x, double y, double w, double d, double h, String? colorHex) {
    final duvetColor = colorHex != null ? _parseColor(colorHex) : const Color(0xFF7F8FB5);
    // 1. Bed Frame Plinth
    _drawPrism(canvas, size, x, y, w, d, h * 0.35, const Color(0xFF1E293B), Colors.black);
    // 2. Headboard with fabric texture
    _drawPrism(canvas, size, x, y, w, 0.03, h * 1.5, const Color(0xFF334155), const Color(0xFF1E293B));
    // 3. Mattress & Duvet with folded quilt layer
    _drawPrism(canvas, size, x + 0.01, y + 0.03, w - 0.02, d - 0.04, h, duvetColor, const Color(0xFF516084));
    _drawPrism(canvas, size, x + 0.01, y + d * 0.45, w - 0.02, d * 0.51, h + 0.012, duvetColor.withValues(alpha: 0.9), const Color(0xFF334155));
    // 4. Dual Sleeping Pillows (#FFFFFF)
    _drawPrism(canvas, size, x + 0.025, y + 0.04, w * 0.42, 0.06, h + 0.035, Colors.white, const Color(0xFFCBD5E1));
    _drawPrism(canvas, size, x + w * 0.555, y + 0.04, w * 0.42, 0.06, h + 0.035, Colors.white, const Color(0xFFCBD5E1));
  }

  void _drawNightstand(Canvas canvas, Size size, double x, double y, double w, double d, double h) {
    _drawPrism(canvas, size, x, y, w, d, h, const Color(0xFFA98459), const Color(0xFF6B4D2F));
  }

  void _drawBathtub(Canvas canvas, Size size, double x, double y, double w, double d, double h) {
    // 1. Freestanding Porcelain Oval Tub Outer Hull (#F8FAFC)
    _drawPrism(canvas, size, x, y, w, d, h, const Color(0xFFF8FAFC), const Color(0xFFD4D8E2));
    // 2. Interior Basin with Water Reflection Gradient (#0284C7)
    _drawPrism(canvas, size, x + 0.015, y + 0.015, w - 0.03, d - 0.03, h - 0.015, const Color(0xFF0284C7), const Color(0xFF0369A1));
    // 3. Freestanding Chrome Spout Post
    final sp1 = _project(x + w * 0.5, y + 0.005, h, size);
    final sp2 = _project(x + w * 0.5, y + 0.005, h + 0.05, size);
    final sp3 = _project(x + w * 0.5, y + 0.025, h + 0.045, size);
    final spoutPath = Path()..moveTo(sp1.dx, sp1.dy)..lineTo(sp2.dx, sp2.dy)..lineTo(sp3.dx, sp3.dy);
    canvas.drawPath(spoutPath, Paint()..color = const Color(0xFFCBD5E1)..style = PaintingStyle.stroke..strokeWidth = 2.0);
  }

  void _drawVanity(Canvas canvas, Size size, double x, double y, double w, double d, double h) {
    _drawPrism(canvas, size, x, y, w, d, h, const Color(0xFFCBD5E1), const Color(0xFF475569));
  }

  void _drawToilet(Canvas canvas, Size size, double x, double y, double w, double d, double h) {
    _drawPrism(canvas, size, x, y, w, d * 0.4, h * 1.4, const Color(0xFFF8FAFC), const Color(0xFFCBD5E1));
    _drawPrism(canvas, size, x, y + d * 0.4, w, d * 0.6, h * 0.8, const Color(0xFFF8FAFC), const Color(0xFFCBD5E1));
  }

  void _drawRug(Canvas canvas, Size size, double x, double y, double w, double d, String? colorHex) {
    final rugColor = colorHex != null ? _parseColor(colorHex) : const Color(0xFF3B4A66);
    final p1 = _project(x, y, 0.005, size);
    final p2 = _project(x + w, y, 0.005, size);
    final p3 = _project(x + w, y + d, 0.005, size);
    final p4 = _project(x, y + d, 0.005, size);

    final path = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..lineTo(p4.dx, p4.dy)
      ..close();

    canvas.drawPath(path, Paint()..color = rugColor);
    // Soft inner border accent
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  void _drawPlant(Canvas canvas, Size size, double x, double y, double w, double d, double h) {
    // Terracotta pot
    _drawPrism(canvas, size, x, y, w, d, h * 0.4, const Color(0xFFC28A5A), const Color(0xFF8B542A));
    // Lush leafy foliage (#3E6B48)
    _drawPrism(canvas, size, x - 0.02, y - 0.02, w + 0.04, d + 0.04, h, const Color(0xFF3E6B48), const Color(0xFF26492F));
  }

  void _drawDefaultPrism(Canvas canvas, Size size, double x, double y, double w, double d, double h, Color topColor, Color sideColor) {
    _drawPrism(canvas, size, x, y, w, d, h, topColor, sideColor);
  }

  void _drawPrism(Canvas canvas, Size size, double x, double y, double w, double d, double h, Color topColor, Color sideColor) {
    final p3 = _project(x + w, y + d, 0.0, size);
    final p4 = _project(x, y + d, 0.0, size);

    final t1 = _project(x, y, h, size);
    final t2 = _project(x + w, y, h, size);
    final t3 = _project(x + w, y + d, h, size);
    final t4 = _project(x, y + d, h, size);

    // Front Face
    final frontPath = Path()
      ..moveTo(p4.dx, p4.dy)
      ..lineTo(p3.dx, p3.dy)
      ..lineTo(t3.dx, t3.dy)
      ..lineTo(t4.dx, t4.dy)
      ..close();
    canvas.drawPath(frontPath, Paint()..color = sideColor);

    // Top Face
    final topPath = Path()
      ..moveTo(t1.dx, t1.dy)
      ..lineTo(t2.dx, t2.dy)
      ..lineTo(t3.dx, t3.dy)
      ..lineTo(t4.dx, t4.dy)
      ..close();
    canvas.drawPath(topPath, Paint()..color = topColor);
  }

  void _drawAcAirflowStreamers(Canvas canvas, Size size) {
    for (final fix in layout.fixtures) {
      if (fix.fixtureType != 'wall_ac') continue;

      final dev = _findDeviceForFixture(fix);
      final isAcOn = dev?.isOn ?? true;
      if (!isAcOn) continue;

      final attrs = dev?.liveAttributes ?? {};
      final mode = attrs['mode']?.toString().toLowerCase() ?? 'cool';
      final fan = attrs['fan']?.toString().toLowerCase() ?? attrs['windStrength']?.toString().toLowerCase() ?? 'auto';
      final bool swingV = attrs['swingVertical'] ?? attrs['upDown'] ?? true;
      final bool swingH = attrs['swingHorizontal'] ?? attrs['leftRight'] ?? false;

      // Authentic House Control & LG ThinQ AC Mode Color Palette
      final Color flowColor;
      switch (mode) {
        case 'heat':
          flowColor = const Color(0xFFFF8C3A);
          break;
        case 'dry':
          flowColor = const Color(0xFF29B6A0);
          break;
        case 'fan':
          flowColor = const Color(0xFFCFDCFF);
          break;
        case 'ai':
        case 'auto':
          flowColor = const Color(0xFFA855F7);
          break;
        case 'jet':
          flowColor = const Color(0xFF00E5FF);
          break;
        case 'cool':
        default:
          flowColor = const Color(0xFF38BDF8);
          break;
      }

      // Wind speed multiplier & streak density
      final double speedMult;
      final int streakCount;
      if (mode == 'jet' || fan == 'turbo' || fan == '8') {
        speedMult = 1.8;
        streakCount = 20;
      } else if (fan == 'high' || fan == '6') {
        speedMult = 1.4;
        streakCount = 16;
      } else if (fan == 'low' || fan == '2') {
        speedMult = 0.7;
        streakCount = 8;
      } else {
        speedMult = 1.0;
        streakCount = 12;
      }

      final acPos = _project(fix.x, fix.y, fix.zHeight, size);

      // 1. AC Wall Chassis (#F8FAFC) with glowing LED & louver grille
      _drawPrism(canvas, size, fix.x - 0.045, fix.y - 0.02, 0.09, 0.03, fix.zHeight + 0.032, const Color(0xFFF8FAFC), const Color(0xFFCBD5E1));
      canvas.drawCircle(acPos, 3.2, Paint()..color = flowColor);

      // Louver vent line
      final v1 = _project(fix.x - 0.035, fix.y + 0.008, fix.zHeight - 0.005, size);
      final v2 = _project(fix.x + 0.035, fix.y + 0.008, fix.zHeight - 0.005, size);
      canvas.drawLine(v1, v2, Paint()..color = const Color(0xFF334155)..strokeWidth = 1.5);

      // 2. Volumetric Dynamic Airflow Streamer Ribbons (three/ac.js)
      for (int i = 0; i < streakCount; i++) {
        final phase = (flowPhase * speedMult + (i * 0.618034)) % 1.0;

        // Vane oscillation dynamics
        final double swingOffsetH = swingH ? math.sin(flowPhase * math.pi * 3 + (i * 0.4)) * 0.04 : 0.0;
        final double swingOffsetV = swingV ? math.cos(flowPhase * math.pi * 2.5 + (i * 0.3)) * 0.03 : 0.0;

        final spreadX = ((((i * 0.381966) % 1.0) * 2 - 1) * (0.05 + 0.07 * phase)) + swingOffsetH;
        final sway = math.sin(flowPhase * math.pi * 2 + (i * 2.399)) * 0.018 * phase;
        final reachY = (0.24 * phase) * (mode == 'jet' ? 1.25 : 1.0);

        final target = _project(
          fix.x + spreadX + sway,
          fix.y + reachY,
          (fix.zHeight - (0.16 * phase * phase) + swingOffsetV).clamp(0.04, 1.0),
          size,
        );

        final ctrl = _project(
          fix.x + spreadX * 0.5,
          fix.y + reachY * 0.5,
          fix.zHeight - 0.07 + (swingOffsetV * 0.5),
          size,
        );

        final flowPath = Path()
          ..moveTo(acPos.dx, acPos.dy)
          ..quadraticBezierTo(ctrl.dx, ctrl.dy, target.dx, target.dy);

        final fade = math.pow(math.sin(math.pi * phase), 0.65) * 1.15;

        final streamerPaint = Paint()
          ..color = flowColor.withValues(alpha: (0.60 * fade).clamp(0.04, 0.85))
          ..style = PaintingStyle.stroke
          ..strokeWidth = (2.6 - (phase * 1.5)) * (mode == 'jet' ? 1.3 : 1.0)
          ..strokeCap = StrokeCap.round;

        canvas.drawPath(flowPath, streamerPaint);

        // 3. Volumetric Micro-Droplet Floating Particles (three/ac.js particle simulation)
        if (i % 2 == 0) {
          final particleT = (phase + 0.2) % 1.0;
          final particlePos = _project(
            fix.x + spreadX * particleT + sway * 0.8,
            fix.y + reachY * particleT,
            (fix.zHeight - (0.12 * particleT * particleT)).clamp(0.04, 1.0),
            size,
          );

          final particleAlpha = (0.8 * math.sin(math.pi * particleT)).clamp(0.0, 0.9);
          canvas.drawCircle(
            particlePos,
            1.8 * (1.0 - particleT * 0.5),
            Paint()
              ..color = flowColor.withValues(alpha: particleAlpha)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
          );
        }
      }
    }
  }

  RealSmartDevice? _findDeviceForFixture(Fixture3DNode fixture) {
    if (fixture.linkedRealDeviceId != null) {
      try {
        return devices.firstWhere((d) => d.id == fixture.linkedRealDeviceId);
      } catch (_) {}
    }
    return null;
  }

  Color _getDeviceLightColor(Fixture3DNode fix, RealSmartDevice? dev) {
    if (dev != null && dev.liveAttributes.containsKey('colorHex')) {
      try {
        return _parseColor(dev.liveAttributes['colorHex'].toString());
      } catch (_) {}
    }
    if (fix.colorHex != null) {
      return _parseColor(fix.colorHex!);
    }
    // Kelvin temperature conversion
    final kelvin = dev?.liveAttributes['temp'] as num? ?? fix.kelvinTemp ?? 3000.0;
    return tempToColor(kelvin.toDouble());
  }

  static Color tempToColor(double kelvin) {
    final k = kelvin.clamp(2200.0, 6500.0);
    if (k <= 3000) {
      final t = (k - 2200) / (3000 - 2200);
      return Color.lerp(const Color(0xFFFF9438), const Color(0xFFFFBD7A), t)!;
    } else if (k <= 4200) {
      final t = (k - 3000) / (4200 - 3000);
      return Color.lerp(const Color(0xFFFFBD7A), const Color(0xFFFFE2C2), t)!;
    } else {
      final t = (k - 4200) / (6500 - 4200);
      return Color.lerp(const Color(0xFFFFE2C2), const Color(0xFFDFE9FF), t)!;
    }
  }

  static Color _parseColor(String hex) {
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    }
    return const Color(0xFFFFD54F);
  }

  @override
  bool shouldRepaint(covariant _IsometricDollhousePainter old) {
    return old.yaw != yaw ||
        old.pitch != pitch ||
        old.zoom != zoom ||
        old.focus != focus ||
        old.selectedRoomId != selectedRoomId ||
        old.flowPhase != flowPhase ||
        old.devices != devices ||
        old.layout != layout;
  }
}

class _WallSegment {
  final double x1, y1, x2, y2, height, thickness;
  final bool hasDoorway;
  final double? doorwayStart;
  final double? doorwayEnd;
  final bool isWindow;
  final double? windowStart;
  final double? windowEnd;

  _WallSegment(
    this.x1,
    this.y1,
    this.x2,
    this.y2,
    this.height,
    this.thickness, {
    this.hasDoorway = false,
    this.doorwayStart,
    this.doorwayEnd,
    this.isWindow = false,
    this.windowStart,
    this.windowEnd,
  });
}
