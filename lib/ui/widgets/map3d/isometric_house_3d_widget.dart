import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../models/house_3d_twin_model.dart';
import '../../../providers/real_home_provider.dart';
import '../../../services/real_iot_controller.dart';
import '../../../theme/apple_glass_theme.dart';
import '../animations/universal_device_animations.dart';

/// Interactive True 3D Isometric Dollhouse Canvas with Volumetric Light Pools,
/// 3D Wall Airflow Shaders, and Real Device Controls.
class IsometricHouse3DWidget extends StatefulWidget {
  final House3DTwinLayout? layout;
  final String selectedRoomId; // 'all', 'living', 'dining', 'kitchen', 'bedroom', 'bathroom'
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

  @override
  State<IsometricHouse3DWidget> createState() => IsometricHouse3DWidgetState();
}

class IsometricHouse3DWidgetState extends State<IsometricHouse3DWidget>
    with TickerProviderStateMixin {
  late House3DTwinLayout _layout;

  // 3D Camera Angles
  double _yaw = -0.46; // Radians
  double _pitch = 0.82; // Radians
  double _zoom = 1.0;
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
      _yaw = -0.46;
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
              // 3D Isometric Interactive Canvas
              GestureDetector(
                onScaleUpdate: widget.isInteractive
                    ? (details) {
                        setState(() {
                          if (details.pointerCount == 1) {
                            _yaw += details.focalPointDelta.dx * 0.008;
                            _pitch = (_pitch - details.focalPointDelta.dy * 0.008)
                                .clamp(0.20, 1.30);
                          } else if (details.pointerCount == 2) {
                            _zoom = (_zoom * details.scale).clamp(0.70, 2.80);
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
          left: screenPos.dx - 48,
          top: screenPos.dy - 32,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              if (boundDev != null) {
                home?.toggleDevicePower(boundDev);
              }
              widget.onFixtureTap?.call(fix, boundDev);
            },
            onLongPress: () {
              HapticFeedback.mediumImpact();
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
    if (dev != null && isOn) {
      if (dev.category == 'light') {
        detailText = '${dev.primaryValue.round()}%';
      } else if (dev.category == 'ac') {
        detailText = '${dev.primaryValue.round()}°C';
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isOn ? tint.withValues(alpha: 0.85) : const Color(0xCC111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOn ? Colors.white : Colors.white.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isOn ? tint.withValues(alpha: 0.5) : Colors.black45,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            detailText,
            style: const TextStyle(
              color: Colors.white,
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
    // 1. Ambient Drop Shadow under Building Footprint
    _drawAmbientFloorShadow(canvas, size);

    // 2. Room Floor Polygons & Textures
    for (final room in layout.rooms) {
      _drawRoomFloor(canvas, size, room);
    }

    // 3. Volumetric Floor Light Pools & Cones
    _drawVolumetricLightPools(canvas, size);

    // 4. 3D Furniture Prisms (Bed, Sofa, Dining, Counters, Tub)
    for (final prop in layout.furniture) {
      _drawFurnitureProp(canvas, size, prop);
    }

    // 5. 3D Cutaway Dollhouse Walls & Doorways
    _drawExtrudedWalls(canvas, size);

    // 6. Live 3D AC Airflow Streamer Ribbons
    _drawAcAirflowStreamers(canvas, size);
  }

  void _drawAmbientFloorShadow(Canvas canvas, Size size) {
    final p1 = _project(-0.02, -0.02, 0.0, size);
    final p2 = _project(1.02, -0.02, 0.0, size);
    final p3 = _project(1.02, 1.02, 0.0, size);
    final p4 = _project(-0.02, 1.02, 0.0, size);

    final path = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..lineTo(p4.dx, p4.dy)
      ..close();

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);

    canvas.drawPath(path, shadowPaint);
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

    final floorPaint = Paint()
      ..color = isSelected
          ? room.floorColor.withValues(alpha: 0.95)
          : room.floorColor.withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;

    canvas.drawPath(floorPath, floorPaint);

    // Subtle Architectural Floor Grout / Plank Lines
    final borderPaint = Paint()
      ..color = isSelected
          ? const Color(0xFF0A84FF).withValues(alpha: 0.70)
          : Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 2.0 : 0.8;

    canvas.drawPath(floorPath, borderPaint);
  }

  void _drawVolumetricLightPools(Canvas canvas, Size size) {
    for (final fix in layout.fixtures) {
      if (!fix.fixtureType.contains('light')) continue;

      final dev = _findDeviceForFixture(fix);
      final isOn = dev?.isOn ?? true;
      if (!isOn) continue;

      final brightness = dev != null ? (dev.primaryValue / 100.0).clamp(0.25, 1.0) : 0.8;
      final lightColor = _getDeviceLightColor(dev);

      // Floor center of light pool
      final poolCenter = _project(fix.x, fix.y, 0.0, size);
      final lightRadius = (75.0 * zoom * brightness).clamp(35.0, 150.0);

      // Multi-stop RadialGradient Light Pool on Room Floor
      final gradient = RadialGradient(
        colors: [
          lightColor.withValues(alpha: 0.45 * brightness),
          lightColor.withValues(alpha: 0.20 * brightness),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      );

      final paint = Paint()
        ..shader = gradient.createShader(
          Rect.fromCircle(center: poolCenter, radius: lightRadius),
        );

      canvas.drawCircle(poolCenter, lightRadius, paint);

      // Translucent Volumetric Light Cone from Ceiling fixture to Floor
      final fixtureTop = _project(fix.x, fix.y, fix.zHeight, size);
      final conePath = Path()
        ..moveTo(fixtureTop.dx, fixtureTop.dy)
        ..lineTo(poolCenter.dx - lightRadius * 0.7, poolCenter.dy)
        ..lineTo(poolCenter.dx + lightRadius * 0.7, poolCenter.dy)
        ..close();

      final conePaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lightColor.withValues(alpha: 0.30 * brightness),
            Colors.transparent,
          ],
        ).createShader(conePath.getBounds());

      canvas.drawPath(conePath, conePaint);
    }
  }

  void _drawExtrudedWalls(Canvas canvas, Size size) {
    const wallThick = 0.022;
    const fullHeight = 0.22; // Back walls
    const sillHeight = 0.06; // Front cutaway walls

    final allWalls = <_WallSegment>[
      // Outer Boundary Back Walls (Full height)
      _WallSegment(0.0, 0.0, 1.0, 0.0, fullHeight, wallThick),
      _WallSegment(0.0, 0.0, 0.0, 1.0, fullHeight, wallThick),

      // Outer Boundary Front Cutaway Walls (Low sill height so view is never blocked)
      _WallSegment(1.0, 0.0, 1.0, 1.0, sillHeight, wallThick),
      _WallSegment(0.0, 1.0, 1.0, 1.0, sillHeight, wallThick),

      // Interior Dividers
      // Horizontal corridor divider between Top (Bed/Bath/Kit) and Bottom (Living/Dining)
      _WallSegment(0.06, 0.46, 0.94, 0.46, 0.16, wallThick, hasDoorway: true),
      // Vertical divider between Bedroom and Bathroom
      _WallSegment(0.44, 0.06, 0.44, 0.46, 0.18, wallThick),
      // Vertical divider between Bathroom and Kitchen
      _WallSegment(0.68, 0.06, 0.68, 0.46, 0.18, wallThick),
      // Vertical divider between Living and Dining
      _WallSegment(0.54, 0.46, 0.54, 0.94, 0.14, wallThick, hasDoorway: true),
    ];

    for (final wall in allWalls) {
      _paintWall(canvas, size, wall);
    }
  }

  void _paintWall(Canvas canvas, Size size, _WallSegment w) {
    final p1Base = _project(w.x1, w.y1, 0.0, size);
    final p2Base = _project(w.x2, w.y2, 0.0, size);
    final p1Top = _project(w.x1, w.y1, w.height, size);
    final p2Top = _project(w.x2, w.y2, w.height, size);

    // Front/Side Face
    final facePath = Path()
      ..moveTo(p1Base.dx, p1Base.dy)
      ..lineTo(p2Base.dx, p2Base.dy)
      ..lineTo(p2Top.dx, p2Top.dy)
      ..lineTo(p1Top.dx, p1Top.dy)
      ..close();

    final isHorizontal = (w.y2 - w.y1).abs() < (w.x2 - w.x1).abs();
    final faceColor = isHorizontal
        ? const Color(0xFF273549) // Medium shadow
        : const Color(0xFF1B2432); // Deep shadow

    canvas.drawPath(facePath, Paint()..color = faceColor);

    // Architectural Wall Top-Cap (Lighter Highlight)
    final capPath = Path()
      ..moveTo(p1Top.dx, p1Top.dy)
      ..lineTo(p2Top.dx, p2Top.dy)
      ..lineTo(p2Top.dx + 2, p2Top.dy - 3)
      ..lineTo(p1Top.dx + 2, p1Top.dy - 3)
      ..close();

    canvas.drawPath(capPath, Paint()..color = const Color(0xFF64748B));
  }

  void _drawFurnitureProp(Canvas canvas, Size size, Furniture3DProp p) {
    final x = p.x;
    final y = p.y;
    final w = p.width;
    final d = p.depth;
    final h = p.height;

    Color topColor = const Color(0xFF334155);
    Color sideColor = const Color(0xFF1E293B);

    switch (p.type) {
      case 'bed':
        topColor = const Color(0xFFE2E8F0); // Crisp linen
        sideColor = const Color(0xFF475569);
        break;
      case 'sofa':
        topColor = const Color(0xFF2C3E50);
        sideColor = const Color(0xFF1A252F);
        break;
      case 'dining_table':
        topColor = const Color(0xFF4E342E); // Deep mahogany
        sideColor = const Color(0xFF3E2723);
        break;
      case 'kitchen_counter':
        topColor = const Color(0xFFCBD5E1); // Polished quartz
        sideColor = const Color(0xFF334155);
        break;
      case 'bath_tub':
        topColor = const Color(0xFFF8FAFC); // Ceramic white
        sideColor = const Color(0xFF0284C7);
        break;
      case 'rug':
        topColor = const Color(0xFF475569).withValues(alpha: 0.6);
        sideColor = Colors.transparent;
        break;
      default:
        break;
    }

    // 3D Prism Faces
    final p3 = _project(x + w, y + d, 0.0, size);
    final p4 = _project(x, y + d, 0.0, size);

    final t1 = _project(x, y, h, size);
    final t2 = _project(x + w, y, h, size);
    final t3 = _project(x + w, y + d, h, size);
    final t4 = _project(x, y + d, h, size);

    // Left/Front Face
    final sidePath = Path()
      ..moveTo(p4.dx, p4.dy)
      ..lineTo(p3.dx, p3.dy)
      ..lineTo(t3.dx, t3.dy)
      ..lineTo(t4.dx, t4.dy)
      ..close();
    canvas.drawPath(sidePath, Paint()..color = sideColor);

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

      final temp = dev?.primaryValue ?? 22.0;
      final isCool = temp <= 23.0;
      final flowColor = isCool ? const Color(0xFF00D4FF) : const Color(0xFFFF9F0A);

      final acPos = _project(fix.x, fix.y, fix.zHeight, size);

      // Draw 3 animated flowing bezier streamers extending from AC
      for (int i = 0; i < 3; i++) {
        final phaseOffset = (flowPhase + (i * 0.33)) % 1.0;
        final spreadX = (i - 1) * 0.06;
        final reachY = 0.18 + (phaseOffset * 0.08);

        final target = _project(fix.x + spreadX, fix.y + reachY, 0.25, size);
        final ctrl = _project(
          fix.x + spreadX * 0.5,
          fix.y + reachY * 0.5,
          fix.zHeight - 0.25 + (math.sin(flowPhase * math.pi * 2 + i) * 0.05),
          size,
        );

        final flowPath = Path()
          ..moveTo(acPos.dx, acPos.dy)
          ..quadraticBezierTo(ctrl.dx, ctrl.dy, target.dx, target.dy);

        final streamerPaint = Paint()
          ..color = flowColor.withValues(alpha: (0.45 * (1.0 - phaseOffset)).clamp(0.05, 0.6))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4 - (phaseOffset * 1.2)
          ..strokeCap = StrokeCap.round;

        canvas.drawPath(flowPath, streamerPaint);
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

  Color _getDeviceLightColor(RealSmartDevice? dev) {
    if (dev != null && dev.liveAttributes.containsKey('colorHex')) {
      try {
        final hexStr = dev.liveAttributes['colorHex'].toString().replaceAll('#', '');
        return Color(int.parse('FF$hexStr', radix: 16));
      } catch (_) {}
    }
    return const Color(0xFFFFD54F); // Warm Amber
  }

  @override
  bool shouldRepaint(covariant _IsometricDollhousePainter old) {
    return old.yaw != yaw ||
        old.pitch != pitch ||
        old.zoom != zoom ||
        old.focus != focus ||
        old.selectedRoomId != selectedRoomId ||
        old.flowPhase != flowPhase ||
        old.devices != devices;
  }
}

class _WallSegment {
  final double x1, y1, x2, y2, height, thickness;
  final bool hasDoorway;

  _WallSegment(
    this.x1,
    this.y1,
    this.x2,
    this.y2,
    this.height,
    this.thickness, {
    this.hasDoorway = false,
  });
}
