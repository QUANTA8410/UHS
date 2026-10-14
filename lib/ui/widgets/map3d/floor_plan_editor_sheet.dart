import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../models/house_3d_twin_model.dart';
import '../../../providers/real_home_provider.dart';
import '../animations/universal_device_animations.dart';
import 'isometric_house_3d_widget.dart';

/// 2D Blueprint Floor Plan Editor & Real Device Hardware Linker Sheet.
class FloorPlanEditorSheet extends StatefulWidget {
  final House3DTwinLayout initialLayout;
  final ValueChanged<House3DTwinLayout>? onLayoutSaved;

  const FloorPlanEditorSheet({
    super.key,
    required this.initialLayout,
    this.onLayoutSaved,
  });

  static Future<House3DTwinLayout?> show(
    BuildContext context, {
    required House3DTwinLayout layout,
  }) {
    return showModalBottomSheet<House3DTwinLayout>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FloorPlanEditorSheet(initialLayout: layout),
    );
  }

  @override
  State<FloorPlanEditorSheet> createState() => _FloorPlanEditorSheetState();
}

class _FloorPlanEditorSheetState extends State<FloorPlanEditorSheet> {
  late House3DTwinLayout _workingLayout;
  bool _showMiniPreview = true;

  @override
  void initState() {
    super.initState();
    // Deep clone working layout
    _workingLayout = House3DTwinLayout.fromJson(widget.initialLayout.toJson());
  }

  void _saveAndApply() async {
    HapticFeedback.heavyImpact();
    await _workingLayout.saveToPrefs();
    widget.onLayoutSaved?.call(_workingLayout);
    if (mounted) {
      Navigator.of(context).pop(_workingLayout);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Blueprint layout and device links saved successfully!'),
          backgroundColor: Color(0xFF30D158),
        ),
      );
    }
  }

  void _openDeviceLinkPicker(Fixture3DNode fixture) {
    HapticFeedback.mediumImpact();
    final home = context.read<RealHomeProvider>();
    final devices = home.devices;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF161D2B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Link "${fixture.label}" to Real Hardware',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Select a paired physical device to control when tapping this 3D node.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              if (devices.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No paired devices found. Pair a device from the Home tab first.',
                      style: TextStyle(color: Colors.white60),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: devices.length + 1,
                    separatorBuilder: (context, index) => const Divider(color: Colors.white12, height: 1),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return ListTile(
                          leading: const Icon(Icons.link_off_rounded, color: Colors.white60),
                          title: const Text('Unlink (Visual Node Only)', style: TextStyle(color: Colors.white)),
                          onTap: () {
                            setState(() {
                              fixture.linkedRealDeviceId = null;
                            });
                            Navigator.pop(ctx);
                          },
                        );
                      }
                      final dev = devices[index - 1];
                      final isSelected = fixture.linkedRealDeviceId == dev.id;
                      final arch = UniversalCategoryClassifier.classify(dev);
                      final icon = UniversalCategoryClassifier.iconFor(arch);
                      final tint = UniversalCategoryClassifier.colorFor(arch);

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: tint.withValues(alpha: 0.20),
                          child: Icon(icon, color: tint, size: 20),
                        ),
                        title: Text(
                          dev.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${dev.room} • ${dev.protocol.name}',
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: Color(0xFF30D158))
                            : null,
                        onTap: () {
                          setState(() {
                            fixture.linkedRealDeviceId = dev.id;
                            fixture.label = dev.name;
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _addNewFixture(String type) {
    HapticFeedback.lightImpact();
    setState(() {
      final newId = 'fix_${DateTime.now().millisecondsSinceEpoch}';
      final label = type == 'wall_ac'
          ? 'Wall AC'
          : type == 'ceiling_light'
              ? 'Ceiling Light'
              : type == 'camera'
                  ? '360 Cam'
                  : 'Smart Fixture';
      _workingLayout.fixtures.add(
        Fixture3DNode(
          id: newId,
          label: label,
          fixtureType: type,
          roomId: 'living',
          x: 0.25,
          y: 0.70,
          zHeight: type == 'wall_ac' ? 0.80 : 0.95,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '2D Blueprint Editor',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Drag fixtures & link to real appliances',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: _showMiniPreview ? 'Hide 3D Preview' : 'Show 3D Preview',
                      icon: Icon(
                        _showMiniPreview ? Icons.view_in_ar_rounded : Icons.view_in_ar_outlined,
                        color: const Color(0xFF0A84FF),
                      ),
                      onPressed: () => setState(() => _showMiniPreview = !_showMiniPreview),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A84FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _saveAndApply,
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Save & Apply', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Mini 3D Preview (Top Collapsible Drawer)
          if (_showMiniPreview)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B132B),
                    border: Border.all(color: Colors.white12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Stack(
                    children: [
                      IsometricHouse3DWidget(
                        height: 160,
                        layout: _workingLayout,
                        isInteractive: false,
                        showBadges: false,
                      ),
                      Positioned(
                        top: 8,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome_rounded, size: 12, color: Color(0xFF38BDF8)),
                              SizedBox(width: 4),
                              Text('Live 3D Isometric Preview', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 2D Architectural Blueprint Canvas
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B1528), // Blueprint Deep Navy
                    border: Border.all(color: const Color(0xFF1E3A8A), width: 1.5),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
                      return Stack(
                        children: [
                          // Custom Architectural Grid & Room Polygons
                          CustomPaint(
                            size: canvasSize,
                            painter: _Blueprint2DPainter(layout: _workingLayout),
                          ),

                          // Draggable Fixture Nodes
                          ..._workingLayout.fixtures.map((fix) {
                            final screenX = fix.x * canvasSize.width;
                            final screenY = fix.y * canvasSize.height;

                            final isLinked = fix.linkedRealDeviceId != null;

                            return Positioned(
                              left: screenX - 22,
                              top: screenY - 22,
                              child: GestureDetector(
                                onPanUpdate: (details) {
                                  setState(() {
                                    fix.x = (fix.x + details.delta.dx / canvasSize.width).clamp(0.04, 0.96);
                                    fix.y = (fix.y + details.delta.dy / canvasSize.height).clamp(0.04, 0.96);
                                  });
                                },
                                onTap: () => _openDeviceLinkPicker(fix),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isLinked
                                            ? const Color(0xFF0A84FF)
                                            : const Color(0xFF334155),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isLinked ? const Color(0xFF60A5FA) : Colors.white54,
                                          width: 1.8,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: isLinked ? const Color(0xFF0A84FF).withValues(alpha: 0.6) : Colors.black45,
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        fix.fixtureType == 'wall_ac'
                                            ? Icons.ac_unit_rounded
                                            : fix.fixtureType == 'camera'
                                                ? Icons.videocam_rounded
                                                : fix.fixtureType == 'washer'
                                                    ? Icons.local_laundry_service_rounded
                                                    : Icons.lightbulb_rounded,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black87,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        fix.label,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          // Bottom Quick Add Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAddButton(Icons.lightbulb_outline_rounded, 'Add Light', () => _addNewFixture('ceiling_light')),
                _buildAddButton(Icons.ac_unit_rounded, 'Add AC', () => _addNewFixture('wall_ac')),
                _buildAddButton(Icons.videocam_outlined, 'Add Camera', () => _addNewFixture('camera')),
                _buildAddButton(Icons.restore_rounded, 'Reset Default', () {
                  HapticFeedback.mediumImpact();
                  setState(() {
                    _workingLayout = House3DTwinLayout.defaultApartment();
                  });
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF60A5FA)),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// Custom Painter for 2D Architectural Blueprint Grid & Dimension Annotations.
class _Blueprint2DPainter extends CustomPainter {
  final House3DTwinLayout layout;

  _Blueprint2DPainter({required this.layout});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Blueprint Grid Lines
    final gridPaint = Paint()
      ..color = const Color(0xFF1E3A8A).withValues(alpha: 0.25)
      ..strokeWidth = 0.8;

    const step = 20.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 2. Room Rectangles & Dimension Annotations
    final roomBorderPaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final roomFillPaint = Paint()
      ..color = const Color(0xFF1E293B).withValues(alpha: 0.40)
      ..style = PaintingStyle.fill;

    for (final room in layout.rooms) {
      final r = Rect.fromLTWH(
        room.gridRect.left * size.width,
        room.gridRect.top * size.height,
        room.gridRect.width * size.width,
        room.gridRect.height * size.height,
      );

      // Fill room
      canvas.drawRect(r, roomFillPaint);
      // Border
      canvas.drawRect(r, roomBorderPaint);

      // Dimension Text Labels (e.g. "Living • 4.8 x 4.6 m")
      final textSpan = TextSpan(
        text: '${room.name}\n${(room.gridRect.width * 10).toStringAsFixed(1)}m × ${(room.gridRect.height * 10).toStringAsFixed(1)}m',
        style: const TextStyle(
          color: Color(0xFF93C5FD),
          fontSize: 10,
          fontWeight: FontWeight.bold,
          height: 1.2,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          r.center.dx - (textPainter.width / 2),
          r.center.dy - (textPainter.height / 2),
        ),
      );
    }

    // 3. Dashed Doorway Arcs
    final arcPaint = Paint()
      ..color = const Color(0xFF60A5FA).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Doorway living to dining
    final doorCenter = Offset(0.54 * size.width, 0.70 * size.height);
    canvas.drawArc(
      Rect.fromCircle(center: doorCenter, radius: 18),
      0,
      math.pi / 2,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _Blueprint2DPainter old) => old.layout != layout;
}
