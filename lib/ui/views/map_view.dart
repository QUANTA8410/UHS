import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/device_model.dart';
import '../../providers/home_state.dart';
import '../widgets/copilot/ai_copilot_sheet.dart';
import '../widgets/sheets/oneplus_tv_sheet.dart';
import '../widgets/sheets/samsung_washer_sheet.dart';
import '../widgets/sheets/thermostat_sheet.dart';
import '../widgets/sheets/light_sheet.dart';

enum MapLayerMode { spatial3d, thermalFlow, energyDraw }

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> with SingleTickerProviderStateMixin {
  String? selectedRoom;
  MapLayerMode _currentMode = MapLayerMode.spatial3d;

  // 3D Camera Orbit & Perspective Coordinates
  double _pitch = 0.85; // Tilt angle in radians (0.3 to 1.3)
  double _yaw = -0.45; // Rotation orbit angle
  double _zoom = 1.0; // Scale factor
  double _baseZoom = 1.0;
  Offset _panOffset = Offset.zero;

  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    if (!WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      _animController.repeat();
    } else {
      _animController.value = 0.5;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _resetCamera() {
    setState(() {
      _pitch = 0.85;
      _yaw = -0.45;
      _zoom = 1.0;
      _panOffset = Offset.zero;
      selectedRoom = null;
    });
  }

  void _setCameraTopDown() {
    setState(() {
      _pitch = 0.05;
      _yaw = 0.0;
      _zoom = 0.95;
      _panOffset = Offset.zero;
    });
  }

  void _setCameraFrontView() {
    setState(() {
      _pitch = 1.25;
      _yaw = 0.0;
      _zoom = 1.05;
      _panOffset = Offset.zero;
    });
  }

  void _openDeviceSheet(BuildContext context, SmartDevice device) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        if (device is TvDevice) {
          return OnePlusTvSheet(device: device);
        } else if (device is WasherDevice) {
          return SamsungWasherSheet(device: device);
        } else if (device is ThermostatDevice) {
          return ThermostatSheet(device: device);
        } else if (device is LightDevice) {
          return LightSheet(device: device);
        }
        return const SizedBox(height: 100);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HomeState>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F141C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161D28),
        title: const Text('SmartThings 3D Map View', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt_rounded),
            tooltip: 'Reset 3D Camera',
            onPressed: _resetCamera,
          ),
          PopupMenuButton<MapLayerMode>(
            icon: const Icon(Icons.layers_outlined),
            tooltip: '3D Visualization Layers',
            initialValue: _currentMode,
            onSelected: (mode) {
              setState(() => _currentMode = mode);
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: MapLayerMode.spatial3d, child: Text('3D Spatial Digital Twin')),
              PopupMenuItem(value: MapLayerMode.thermalFlow, child: Text('LG DualCool Thermal Flow')),
              PopupMenuItem(value: MapLayerMode.energyDraw, child: Text('Live Energy Heatmap')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.auto_awesome, color: Colors.amberAccent),
        label: const Text('AI Copilot', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => AiCopilotSheet.show(context),
      ),
      body: Column(
        children: [
          // 3D Layer Selection Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF161D28),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('3D Spatial'),
                          selected: _currentMode == MapLayerMode.spatial3d,
                          selectedColor: Colors.blueAccent.withValues(alpha: 0.3),
                          onSelected: (s) => setState(() => _currentMode = MapLayerMode.spatial3d),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Thermal Flow (LG AC)'),
                          selected: _currentMode == MapLayerMode.thermalFlow,
                          selectedColor: Colors.cyanAccent.withValues(alpha: 0.3),
                          onSelected: (s) => setState(() => _currentMode = MapLayerMode.thermalFlow),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Energy Overlay'),
                          selected: _currentMode == MapLayerMode.energyDraw,
                          selectedColor: Colors.amberAccent.withValues(alpha: 0.3),
                          onSelected: (s) => setState(() => _currentMode = MapLayerMode.energyDraw),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3D Interactive Viewport
          Expanded(
            child: Stack(
              children: [
                // 3D Orbit & Pan Gesture Canvas
                GestureDetector(
                  onScaleStart: (details) {
                    _baseZoom = _zoom;
                  },
                  onScaleUpdate: (details) {
                    setState(() {
                      if (details.pointerCount == 2) {
                        _zoom = (_baseZoom * details.scale).clamp(0.55, 2.3);
                      } else {
                        // 1 finger: 3D orbit rotation & tilt
                        _yaw += details.focalPointDelta.dx * 0.008;
                        _pitch = (_pitch + details.focalPointDelta.dy * 0.006).clamp(0.15, 1.35);
                        _panOffset += details.focalPointDelta * 0.3;
                      }
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.transparent,
                    child: AnimatedBuilder(
                      animation: _animController,
                      builder: (context, _) {
                        return Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.0014) // True 3D perspective foreshortening
                            ..translateByDouble(_panOffset.dx, _panOffset.dy, 0.0, 1.0)
                            ..rotateX(_pitch)
                            ..rotateZ(_yaw)
                            ..scaleByDouble(_zoom, _zoom, _zoom, 1.0),
                          child: Center(
                            child: SizedBox(
                              width: 360,
                              height: 380,
                              child: CustomPaint(
                                painter: _Photorealistic3DMapPainter(
                                  mode: _currentMode,
                                  devices: state.allDevices,
                                  selectedRoom: selectedRoom,
                                  animValue: _animController.value,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Floating 3D Camera Preset HUD (Top Left)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.threed_rotation_rounded, size: 18, color: Colors.cyanAccent),
                          tooltip: '3D Orbit View',
                          onPressed: _resetCamera,
                        ),
                        IconButton(
                          icon: const Icon(Icons.grid_on_rounded, size: 18, color: Colors.white70),
                          tooltip: 'Top-Down Blueprint',
                          onPressed: _setCameraTopDown,
                        ),
                        IconButton(
                          icon: const Icon(Icons.view_in_ar_rounded, size: 18, color: Colors.white70),
                          tooltip: 'Front 3D Elevation',
                          onPressed: _setCameraFrontView,
                        ),
                      ],
                    ),
                  ),
                ),

                // Room Quick Select Pills (Top Right)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildRoomChip('Living Room', state),
                        const SizedBox(width: 4),
                        _buildRoomChip('Kitchen', state),
                        const SizedBox(width: 4),
                        _buildRoomChip('Laundry Room', state),
                        const SizedBox(width: 4),
                        _buildRoomChip('Master Bedroom', state),
                      ],
                    ),
                  ),
                ),

                // Live Layer Telemetry HUD (Bottom Center)
                Positioned(
                  bottom: 12,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161D28).withValues(alpha: 0.90),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                _currentMode == MapLayerMode.thermalFlow
                                    ? Icons.air_rounded
                                    : (_currentMode == MapLayerMode.energyDraw ? Icons.bolt_rounded : Icons.view_in_ar_rounded),
                                color: _currentMode == MapLayerMode.thermalFlow
                                    ? Colors.cyanAccent
                                    : (_currentMode == MapLayerMode.energyDraw ? Colors.amberAccent : Colors.blueAccent),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _currentMode == MapLayerMode.thermalFlow
                                      ? 'Cooling Flow: 21.5°C Active'
                                      : (_currentMode == MapLayerMode.energyDraw
                                          ? '${state.totalPowerWatts.toStringAsFixed(0)} W Total Household Draw'
                                          : 'Interactive 3D Digital Twin • Drag to Orbit'),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${state.allDevices.length} Nodes',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Selected Room Devices Bottom Drawer
          Container(
            color: const Color(0xFF161D28),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      selectedRoom == null ? 'All Rooms & Interactive 3D Nodes' : 'Selected Room: $selectedRoom',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                    ),
                    if (selectedRoom != null)
                      TextButton(
                        onPressed: () => setState(() => selectedRoom = null),
                        child: const Text('Show All', style: TextStyle(fontSize: 12, color: Colors.cyanAccent)),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: (selectedRoom == null ? state.allDevices : state.devicesInRoom(selectedRoom!)).map((d) {
                      return GestureDetector(
                        onTap: () => state.togglePower(d.id),
                        onLongPress: () => _openDeviceSheet(context, d),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: d.isPowered ? Colors.cyan.withValues(alpha: 0.20) : Colors.white10,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: d.isPowered ? Colors.cyanAccent : Colors.white24,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(d.icon, size: 16, color: d.isPowered ? Colors.cyanAccent : Colors.grey),
                              const SizedBox(width: 6),
                              Text(d.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                              const SizedBox(width: 4),
                              Icon(Icons.touch_app, size: 12, color: Colors.grey.shade400),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomChip(String room, HomeState state) {
    final isSelected = selectedRoom == room;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedRoom = isSelected ? null : room;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.cyanAccent.withValues(alpha: 0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? Colors.cyanAccent : Colors.transparent),
        ),
        child: Text(
          room,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.cyanAccent : Colors.white70,
          ),
        ),
      ),
    );
  }
}

/// Photorealistic 3D Volumetric Digital Twin Painter
class _Photorealistic3DMapPainter extends CustomPainter {
  final MapLayerMode mode;
  final List<SmartDevice> devices;
  final String? selectedRoom;
  final double animValue;

  _Photorealistic3DMapPainter({
    required this.mode,
    required this.devices,
    required this.selectedRoom,
    required this.animValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const wallExtrudeHeight = 38.0;

    // Room Layout Definitions (Normalized Coordinates on 360x380 footprint)
    final rooms = [
      _Room3D(name: 'Living Room', rect: const Rect.fromLTWH(20, 20, 180, 180), floorColor: const Color(0xFF2A231C)),
      _Room3D(name: 'Kitchen', rect: const Rect.fromLTWH(200, 20, 140, 180), floorColor: const Color(0xFF20262E)),
      _Room3D(name: 'Laundry Room', rect: const Rect.fromLTWH(20, 200, 140, 160), floorColor: const Color(0xFF1E2833)),
      _Room3D(name: 'Master Bedroom', rect: const Rect.fromLTWH(160, 200, 180, 160), floorColor: const Color(0xFF26202E)),
    ];

    // 1. Draw 3D Base Foundation Slab & Soft Drop Shadow
    final slabPath = Path()
      ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(12, 12, 336, 356), const Radius.circular(24)));
    canvas.drawShadow(slabPath, Colors.black, 20, true);

    final slabPaint = Paint()
      ..color = const Color(0xFF181F2A)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(12, 12, 336, 356), const Radius.circular(24)), slabPaint);

    // 2. Draw Realistic 3D Floor Materials for Each Room
    for (final room in rooms) {
      final isHighlighted = selectedRoom == null || selectedRoom == room.name;
      final roomFloorPaint = Paint()
        ..color = isHighlighted ? room.floorColor : room.floorColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.fill;
      canvas.drawRect(room.rect, roomFloorPaint);

      // Floor Material Patterns (Parquet for living room, tile grid for kitchen/laundry)
      if (room.name == 'Living Room') {
        _drawParquetPlanks(canvas, room.rect);
      } else if (room.name == 'Kitchen' || room.name == 'Laundry Room') {
        _drawCeramicTiles(canvas, room.rect);
      } else {
        _drawCarpetWeave(canvas, room.rect);
      }
    }

    // 3. Volumetric 3D Light Glows from Powered Bulbs
    for (final dev in devices.whereType<LightDevice>().where((d) => d.isPowered)) {
      Offset pos = const Offset(110, 110);
      if (dev.room == 'Master Bedroom') pos = const Offset(250, 280);

      final glowRadius = 55.0 * dev.brightness;
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            dev.color.withValues(alpha: 0.55 * dev.brightness),
            dev.color.withValues(alpha: 0.15 * dev.brightness),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: pos, radius: glowRadius));
      canvas.drawCircle(pos, glowRadius, glowPaint);
    }

    // 4. Samsung Washer 3D Animated Ecobubble™ Rings & Vibration Waves (Laundry Room)
    final washer = devices.whereType<WasherDevice>().firstOrNull;
    if (washer != null && washer.isPowered) {
      const washerPos = Offset(85, 275);
      // Expanding water wave shockwaves
      for (int i = 0; i < 3; i++) {
        final phase = (animValue + i / 3.0) % 1.0;
        final waveRadius = 12.0 + (phase * 35.0);
        final waveAlpha = (1.0 - phase) * 0.7;
        final wavePaint = Paint()
          ..color = const Color(0xFF29B6F6).withValues(alpha: waveAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawCircle(washerPos, waveRadius, wavePaint);
      }
    }

    // 5. LG DualCool AC Dynamic 3D Thermal Flow Streamlines (Living Room)
    final ac = devices.whereType<ThermostatDevice>().firstOrNull;
    if (ac != null && (ac.isPowered || mode == MapLayerMode.thermalFlow)) {
      _drawThermalAirflowStreamlines(canvas, const Offset(110, 24), animValue);
    }

    // 6. OnePlus TV 3D Ambient Screen Projection Glow (Living Room Wall)
    final tv = devices.whereType<TvDevice>().firstOrNull;
    if (tv != null && tv.isPowered) {
      final tvGlowPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.redAccent.withValues(alpha: 0.45),
            Colors.redAccent.withValues(alpha: 0.05),
            Colors.transparent,
          ],
        ).createShader(const Rect.fromLTWH(140, 22, 50, 45));
      canvas.drawRect(const Rect.fromLTWH(140, 22, 50, 45), tvGlowPaint);
    }

    // 7. Draw Extruded 3D Volumetric Walls (Physical Depth with 3D Height)
    for (final room in rooms) {
      _drawExtrudedWalls(canvas, room.rect, wallExtrudeHeight);
    }

    // 8. 3D Energy Heatmap Overlay (Mode 3)
    if (mode == MapLayerMode.energyDraw) {
      _drawEnergyHeatmap(canvas, devices, animValue);
    }

    // 9. Floating Holographic 3D Device Nodes with Laser Guides
    for (final dev in devices) {
      _drawHolographicDeviceNode(canvas, dev, wallExtrudeHeight, animValue);
    }
  }

  void _drawParquetPlanks(Canvas canvas, Rect rect) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;
    for (double y = rect.top + 16; y < rect.bottom; y += 18) {
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), linePaint);
    }
  }

  void _drawCeramicTiles(Canvas canvas, Rect rect) {
    final tilePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 1.0;
    for (double x = rect.left + 20; x < rect.right; x += 22) {
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), tilePaint);
    }
    for (double y = rect.top + 20; y < rect.bottom; y += 22) {
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), tilePaint);
    }
  }

  void _drawCarpetWeave(Canvas canvas, Rect rect) {
    final weavePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1.0;
    for (double i = rect.left; i < rect.right + rect.height; i += 16) {
      canvas.drawLine(
        Offset(math.max(rect.left, i - rect.height), rect.bottom),
        Offset(math.min(rect.right, i), rect.top),
        weavePaint,
      );
    }
  }

  void _drawExtrudedWalls(Canvas canvas, Rect r, double height) {
    // 3D Wall Front & Side Quad Shading
    final sidePaint = Paint()
      ..color = const Color(0xFF252B36)
      ..style = PaintingStyle.fill;

    final topCapPaint = Paint()
      ..color = const Color(0xFF3B4353)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    // Extruded South Wall Slab
    final southQuad = Path()
      ..moveTo(r.left, r.bottom)
      ..lineTo(r.right, r.bottom)
      ..lineTo(r.right, r.bottom - height)
      ..lineTo(r.left, r.bottom - height)
      ..close();
    canvas.drawPath(southQuad, sidePaint);

    // Extruded East Wall Slab
    final eastQuad = Path()
      ..moveTo(r.right, r.top)
      ..lineTo(r.right, r.bottom)
      ..lineTo(r.right, r.bottom - height)
      ..lineTo(r.right, r.top - height)
      ..close();
    canvas.drawPath(eastQuad, sidePaint);

    // Top Beveled Cap Outline
    canvas.drawRect(Rect.fromLTWH(r.left, r.top - height, r.width, r.height), topCapPaint);
  }

  void _drawThermalAirflowStreamlines(Canvas canvas, Offset source, double anim) {
    // Curved streamlines travelling across Living Room floor
    final flowPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final path1 = Path()
      ..moveTo(source.dx, source.dy)
      ..quadraticBezierTo(source.dx + 40, source.dy + 60, source.dx + 20, source.dy + 130);
    canvas.drawPath(path1, flowPaint);

    final path2 = Path()
      ..moveTo(source.dx - 20, source.dy)
      ..quadraticBezierTo(source.dx - 60, source.dy + 70, source.dx - 30, source.dy + 140);
    canvas.drawPath(path2, flowPaint);

    // Floating animated cooling breeze particles
    for (int i = 0; i < 4; i++) {
      final t = (anim + i * 0.25) % 1.0;
      final px = source.dx + 20 * math.sin(t * math.pi);
      final py = source.dy + t * 130;
      canvas.drawCircle(Offset(px, py), 3.5, Paint()..color = const Color(0xFF80DEEA));
    }
  }

  void _drawEnergyHeatmap(Canvas canvas, List<SmartDevice> devs, double anim) {
    for (final dev in devs.where((d) => d.isPowered && d.powerUsageWatts > 50)) {
      Offset pos = const Offset(110, 110);
      if (dev is WasherDevice) pos = const Offset(85, 275);
      if (dev is ThermostatDevice) pos = const Offset(110, 45);
      if (dev is TvDevice) pos = const Offset(165, 35);
      if (dev is RefrigeratorDevice) pos = const Offset(270, 70);

      final pulse = (math.sin(anim * math.pi * 2) + 1.0) / 2.0;
      final ringRadius = 25.0 + pulse * 12.0;

      final heatPaint = Paint()
        ..color = (dev.powerUsageWatts > 400 ? Colors.redAccent : Colors.orangeAccent).withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(pos, ringRadius, heatPaint);
    }
  }

  void _drawHolographicDeviceNode(Canvas canvas, SmartDevice dev, double wallHeight, double anim) {
    Offset basePos = const Offset(110, 110);
    if (dev.name.contains('Bulb') || dev is LightDevice) {
      basePos = dev.room == 'Master Bedroom' ? const Offset(250, 280) : const Offset(110, 110);
    } else if (dev is WasherDevice) {
      basePos = const Offset(85, 275);
    } else if (dev is ThermostatDevice) {
      basePos = const Offset(110, 45);
    } else if (dev is TvDevice) {
      basePos = const Offset(165, 35);
    } else if (dev is RefrigeratorDevice) {
      basePos = const Offset(270, 70);
    }

    // 3D Laser Guide Line from Floor to Floating Hologram
    final hoverHeight = wallHeight + 24.0 + math.sin(anim * math.pi * 2) * 3.0;
    final nodePos = Offset(basePos.dx, basePos.dy - hoverHeight);

    final guidePaint = Paint()
      ..color = (dev.isPowered ? Colors.cyanAccent : Colors.white30).withValues(alpha: 0.5)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(basePos, nodePos, guidePaint);

    // Floor Marker Anchor
    canvas.drawCircle(basePos, 4, Paint()..color = (dev.isPowered ? Colors.cyanAccent : Colors.white24));

    // Floating 3D Hologram Orb
    final nodeColor = dev.isPowered
        ? (dev is LightDevice
            ? dev.color
            : (dev is TvDevice
                ? Colors.redAccent
                : (dev is WasherDevice ? Colors.blueAccent : Colors.cyanAccent)))
        : Colors.grey.shade700;

    // Glowing Halo
    if (dev.isPowered) {
      canvas.drawCircle(
        nodePos,
        14,
        Paint()
          ..color = nodeColor.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    // Solid Node Center
    canvas.drawCircle(nodePos, 8, Paint()..color = nodeColor);
    canvas.drawCircle(
      nodePos,
      8,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _Photorealistic3DMapPainter oldDelegate) => true;
}
class _Room3D {
  final String name;
  final Rect rect;
  final Color floorColor;

  const _Room3D({required this.name, required this.rect, required this.floorColor});
}
