import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../models/house_3d_twin_model.dart';
import '../../../providers/real_home_provider.dart';
import '../animations/universal_device_animations.dart';
import 'isometric_house_3d_widget.dart';

/// 2D Blueprint Floor Plan Editor & Real Device Hardware Linker Sheet.
/// Matches House Control's editor.js:
/// - 5cm (0.05m) metric snap-to-grid for fixtures and furniture.
/// - Room Inspector for renaming, resizing, and changing floor materials (oak, walnut, tile, stone).
/// - Draggable fixtures & furniture props with real-time coordinate readouts.
/// - Live 3D isometric mini preview updating instantly.
/// - Undo / Redo history stack.
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

  // History stacks matching editor.js undo/redo
  final List<String> _undoStack = [];
  final List<String> _redoStack = [];

  // Currently selected entity for inspection
  String? _selectedRoomId;
  String? _selectedFixtureId;
  String? _selectedFurnitureId;

  // Coordinate readout for active drag
  String? _dragCoordinatesHud;

  @override
  void initState() {
    super.initState();
    // Deep clone working layout
    _workingLayout = House3DTwinLayout.fromJson(widget.initialLayout.toJson());
  }

  void _snapshot() {
    _undoStack.add(jsonEncode(_workingLayout.toJson()));
    if (_undoStack.length > 50) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    HapticFeedback.lightImpact();
    _redoStack.add(jsonEncode(_workingLayout.toJson()));
    final lastJson = _undoStack.removeLast();
    setState(() {
      _workingLayout = House3DTwinLayout.fromJson(jsonDecode(lastJson));
      _dragCoordinatesHud = null;
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    HapticFeedback.lightImpact();
    _undoStack.add(jsonEncode(_workingLayout.toJson()));
    final nextJson = _redoStack.removeLast();
    setState(() {
      _workingLayout = House3DTwinLayout.fromJson(jsonDecode(nextJson));
      _dragCoordinatesHud = null;
    });
  }

  /// Snaps a normalized coordinate (0.0..1.0) to 5cm (0.05m) intervals on real 10m scale
  double _snapTo5cm(double normalized, [double totalMeters = 10.0]) {
    final meters = normalized * totalMeters;
    final snappedMeters = (meters / 0.05).round() * 0.05;
    return (snappedMeters / totalMeters).clamp(0.04, 0.96);
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

  // MARK: - Room Inspector Modal (matching editor.js Room section)

  void _openRoomInspector(Room3DZone room) {
    HapticFeedback.mediumImpact();
    setState(() => _selectedRoomId = room.id);

    final nameController = TextEditingController(text: room.name);
    FloorMaterialType selectedFloor = room.floorType;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final widthMeters = (room.gridRect.width * 10.4).toStringAsFixed(2);
          final depthMeters = (room.gridRect.height * 8.2).toStringAsFixed(2);

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Room Inspector: ${room.name}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$widthMeters × $depthMeters m',
                          style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Room Name Field
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Room Name',
                      labelStyle: const TextStyle(color: Colors.white60),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      suffixIcon: const Icon(Icons.edit_rounded, color: Colors.white54, size: 18),
                    ),
                    onChanged: (val) {
                      _snapshot();
                      setState(() {
                        final idx = _workingLayout.rooms.indexWhere((r) => r.id == room.id);
                        if (idx >= 0) {
                          _workingLayout.rooms[idx] = _workingLayout.rooms[idx].copyWith(name: val);
                        }
                      });
                    },
                  ),

                  const SizedBox(height: 18),

                  // Floor Material Selector (oak, walnut, tile, stone)
                  const Text('Floor Material & Finish', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildFloorMaterialOption(
                        label: 'Oak Wood',
                        icon: '🌳',
                        color: const Color(0xFF4A3D2E),
                        type: FloorMaterialType.oak,
                        selected: selectedFloor == FloorMaterialType.oak,
                        onTap: () {
                          _snapshot();
                          setModalState(() => selectedFloor = FloorMaterialType.oak);
                          setState(() {
                            final idx = _workingLayout.rooms.indexWhere((r) => r.id == room.id);
                            if (idx >= 0) {
                              _workingLayout.rooms[idx] = _workingLayout.rooms[idx].copyWith(
                                floorType: FloorMaterialType.oak,
                                floorColor: FloorMaterialType.oak.color,
                              );
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildFloorMaterialOption(
                        label: 'Walnut',
                        icon: '🪵',
                        color: const Color(0xFF3C2F28),
                        type: FloorMaterialType.walnut,
                        selected: selectedFloor == FloorMaterialType.walnut,
                        onTap: () {
                          _snapshot();
                          setModalState(() => selectedFloor = FloorMaterialType.walnut);
                          setState(() {
                            final idx = _workingLayout.rooms.indexWhere((r) => r.id == room.id);
                            if (idx >= 0) {
                              _workingLayout.rooms[idx] = _workingLayout.rooms[idx].copyWith(
                                floorType: FloorMaterialType.walnut,
                                floorColor: FloorMaterialType.walnut.color,
                              );
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildFloorMaterialOption(
                        label: 'Ceramic Tile',
                        icon: '🧱',
                        color: const Color(0xFF39424B),
                        type: FloorMaterialType.tile,
                        selected: selectedFloor == FloorMaterialType.tile,
                        onTap: () {
                          _snapshot();
                          setModalState(() => selectedFloor = FloorMaterialType.tile);
                          setState(() {
                            final idx = _workingLayout.rooms.indexWhere((r) => r.id == room.id);
                            if (idx >= 0) {
                              _workingLayout.rooms[idx] = _workingLayout.rooms[idx].copyWith(
                                floorType: FloorMaterialType.tile,
                                floorColor: FloorMaterialType.tile.color,
                              );
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildFloorMaterialOption(
                        label: 'Stone',
                        icon: '🪨',
                        color: const Color(0xFF30353C),
                        type: FloorMaterialType.stone,
                        selected: selectedFloor == FloorMaterialType.stone,
                        onTap: () {
                          _snapshot();
                          setModalState(() => selectedFloor = FloorMaterialType.stone);
                          setState(() {
                            final idx = _workingLayout.rooms.indexWhere((r) => r.id == room.id);
                            if (idx >= 0) {
                              _workingLayout.rooms[idx] = _workingLayout.rooms[idx].copyWith(
                                floorType: FloorMaterialType.stone,
                                floorColor: FloorMaterialType.stone.color,
                              );
                            }
                          });
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Delete room option
                  Center(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF453A)),
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      label: const Text('Delete Room and Contents'),
                      onPressed: () {
                        _snapshot();
                        setState(() {
                          _workingLayout.rooms.removeWhere((r) => r.id == room.id);
                          _workingLayout.fixtures.removeWhere((f) => f.roomId == room.id);
                          _workingLayout.furniture.removeWhere((f) => f.roomId == room.id);
                        });
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFloorMaterialOption({
    required String label,
    required String icon,
    required Color color,
    required FloorMaterialType type,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? const Color(0xFF0A84FF) : Colors.white24,
              width: selected ? 2.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // MARK: - Device Hardware Linker

  void _openDeviceLinkPicker(Fixture3DNode fixture) {
    HapticFeedback.mediumImpact();
    setState(() => _selectedFixtureId = fixture.id);
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
                            _snapshot();
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
                          _snapshot();
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

  // MARK: - Furniture Inspector & Rotation

  void _openFurnitureInspector(Furniture3DProp item) {
    HapticFeedback.lightImpact();
    setState(() => _selectedFurnitureId = item.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF161D2B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              'Furniture: ${item.type.toUpperCase()}',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Position: X ${(item.x * 10).toStringAsFixed(2)}m, Y ${(item.y * 10).toStringAsFixed(2)}m • Rotation ${item.rotationDeg.toInt()}°',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A84FF)),
                  icon: const Icon(Icons.rotate_right_rounded, size: 18),
                  label: const Text('Rotate 90°'),
                  onPressed: () {
                    _snapshot();
                    setState(() {
                      item.rotationDeg = (item.rotationDeg + 90) % 360;
                    });
                    Navigator.pop(ctx);
                  },
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF453A)),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Remove'),
                  onPressed: () {
                    _snapshot();
                    setState(() {
                      _workingLayout.furniture.removeWhere((f) => f.id == item.id);
                    });
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addNewFixture(String type) {
    _snapshot();
    HapticFeedback.lightImpact();
    setState(() {
      final newId = 'fix_${DateTime.now().millisecondsSinceEpoch}';
      final label = type == 'wall_ac'
          ? 'Wall AC'
          : type == 'ceiling_light'
              ? 'Ceiling Light'
              : type == 'table_lamp'
                  ? 'Table Lamp'
                  : type == 'strip_light'
                      ? 'LED Strip'
                      : 'Smart Node';
      _workingLayout.fixtures.add(
        Fixture3DNode(
          id: newId,
          label: label,
          fixtureType: type,
          roomId: _workingLayout.rooms.firstOrNull?.id ?? 'living',
          x: 0.5,
          y: 0.5,
          zHeight: type == 'wall_ac' ? 0.80 : 0.95,
        ),
      );
    });
  }

  void _addNewFurniture(String type) {
    _snapshot();
    HapticFeedback.lightImpact();
    setState(() {
      final newId = 'furn_${DateTime.now().millisecondsSinceEpoch}';
      _workingLayout.furniture.add(
        Furniture3DProp(
          id: newId,
          type: type,
          roomId: _workingLayout.rooms.firstOrNull?.id ?? 'living',
          x: 0.5,
          y: 0.5,
          width: 0.12,
          depth: 0.08,
          height: 0.4,
          rotationDeg: 0,
        ),
      );
    });
  }

  void _showAddDialog() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Add to Floor Plan', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildAddItemChip('Ceiling Light', Icons.lightbulb_rounded, () => _addNewFixture('ceiling_light')),
                _buildAddItemChip('Table Lamp', Icons.table_restaurant_rounded, () => _addNewFixture('table_lamp')),
                _buildAddItemChip('Wall AC', Icons.ac_unit_rounded, () => _addNewFixture('wall_ac')),
                _buildAddItemChip('Sofa', Icons.weekend_rounded, () => _addNewFurniture('sofa')),
                _buildAddItemChip('Coffee Table', Icons.table_bar_rounded, () => _addNewFurniture('coffeeTable')),
                _buildAddItemChip('Dining Set', Icons.dining_rounded, () => _addNewFurniture('diningSet')),
                _buildAddItemChip('Bed', Icons.bed_rounded, () => _addNewFurniture('bed')),
                _buildAddItemChip('Desk Suite', Icons.desk_rounded, () => _addNewFurniture('desk')),
                _buildAddItemChip('Bookshelf', Icons.shelves, () => _addNewFurniture('bookshelf')),
                _buildAddItemChip('TV Media', Icons.tv_rounded, () => _addNewFurniture('tv')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddItemChip(String label, IconData icon, VoidCallback onAdd) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: const Color(0xFF38BDF8)),
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: Colors.white.withValues(alpha: 0.08),
      side: const BorderSide(color: Colors.white12),
      onPressed: () {
        Navigator.pop(context);
        onAdd();
      },
    );
  }

  void _showPresetSelector() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select House Control Blueprint',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Switch between authentic metric architectural floor plans from House Control.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0x3300D4FF),
                      child: Icon(Icons.home_work_rounded, color: Color(0xFF00D4FF)),
                    ),
                    title: const Text('Authentic 5-Room Home', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Living, Dining, Kitchen, Bedroom, Bathroom (home.json)', style: TextStyle(color: Colors.white60, fontSize: 12)),
                    onTap: () {
                      _snapshot();
                      setState(() => _workingLayout = House3DTwinLayout.defaultApartment());
                      Navigator.pop(ctx);
                    },
                  ),
                  const Divider(color: Colors.white12),
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0x33BF5AF2),
                      child: Icon(Icons.apartment_rounded, color: Color(0xFFBF5AF2)),
                    ),
                    title: const Text('Studio Apartment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Studio, Bathroom, Hallway with AC & desk suite (studio.json)', style: TextStyle(color: Colors.white60, fontSize: 12)),
                    onTap: () {
                      _snapshot();
                      setState(() => _workingLayout = House3DTwinLayout.studioApartment());
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showJsonDialog() {
    HapticFeedback.selectionClick();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(_workingLayout.toJson());
    final textController = TextEditingController(text: jsonStr);
    String? errorMsg;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Color(0xFF161D2B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'House Control Blueprint JSON',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: Color(0xFF38BDF8), size: 20),
                    tooltip: 'Copy JSON',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: textController.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Blueprint JSON copied to clipboard!')),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Export, backup, or paste authentic House Control home.json schemas.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 12),
              if (errorMsg != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(errorMsg!, style: const TextStyle(color: Color(0xFFFF453A), fontSize: 12)),
                ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D121D),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: textController,
                    maxLines: null,
                    expands: true,
                    style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF93C5FD), fontSize: 11),
                    decoration: const InputDecoration(border: InputBorder.none),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A84FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      try {
                        final parsed = jsonDecode(textController.text);
                        if (parsed is Map<String, dynamic>) {
                          _snapshot();
                          final newLayout = parsed.containsKey('rooms') &&
                                  parsed['rooms'] is List &&
                                  (parsed['rooms'] as List).isNotEmpty &&
                                  (parsed['rooms'] as List)[0] is Map &&
                                  ((parsed['rooms'] as List)[0] as Map).containsKey('rect')
                              ? House3DTwinLayout.fromHouseControlJson(parsed)
                              : House3DTwinLayout.fromJson(parsed);
                          setState(() {
                            _workingLayout = newLayout;
                          });
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Blueprint successfully loaded from JSON!'),
                              backgroundColor: Color(0xFF30D158),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() {
                          errorMsg = 'JSON Error: $e';
                        });
                      }
                    },
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Import & Apply'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.94,
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
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 12),

          // Header with Undo/Redo & Save
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '2D Blueprint Editor',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        _dragCoordinatesHud ?? '5cm snap-to-grid • Tap room for Inspector',
                        style: TextStyle(
                          color: _dragCoordinatesHud != null ? const Color(0xFF38BDF8) : Colors.white60,
                          fontSize: 12,
                          fontWeight: _dragCoordinatesHud != null ? FontWeight.bold : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Undo',
                      icon: Icon(Icons.undo_rounded, color: _undoStack.isNotEmpty ? Colors.white : Colors.white24, size: 20),
                      onPressed: _undoStack.isNotEmpty ? _undo : null,
                    ),
                    IconButton(
                      tooltip: 'Redo',
                      icon: Icon(Icons.redo_rounded, color: _redoStack.isNotEmpty ? Colors.white : Colors.white24, size: 20),
                      onPressed: _redoStack.isNotEmpty ? _redo : null,
                    ),
                    IconButton(
                      tooltip: 'Blueprint JSON Schema',
                      icon: const Icon(Icons.data_object_rounded, color: Color(0xFF38BDF8), size: 20),
                      onPressed: _showJsonDialog,
                    ),
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
                  height: 150,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B132B),
                    border: Border.all(color: Colors.white12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Stack(
                    children: [
                      IsometricHouse3DWidget(
                        height: 150,
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

          // 2D Architectural Blueprint Canvas with 5cm Snap Grid
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
                          GestureDetector(
                            onTapUp: (details) {
                              final clickX = details.localPosition.dx / canvasSize.width;
                              final clickY = details.localPosition.dy / canvasSize.height;
                              for (final room in _workingLayout.rooms) {
                                if (room.gridRect.contains(Offset(clickX, clickY))) {
                                  _openRoomInspector(room);
                                  return;
                                }
                              }
                            },
                            child: CustomPaint(
                              size: canvasSize,
                              painter: _Blueprint2DPainter(
                                layout: _workingLayout,
                                selectedRoomId: _selectedRoomId,
                              ),
                            ),
                          ),

                          // Draggable Furniture Nodes
                          ..._workingLayout.furniture.map((furn) {
                            final screenX = furn.x * canvasSize.width;
                            final screenY = furn.y * canvasSize.height;

                            return Positioned(
                              left: screenX - 16,
                              top: screenY - 16,
                              child: GestureDetector(
                                onPanStart: (_) => _snapshot(),
                                onPanUpdate: (details) {
                                  setState(() {
                                    final rawX = (furn.x + details.delta.dx / canvasSize.width).clamp(0.04, 0.96);
                                    final rawY = (furn.y + details.delta.dy / canvasSize.height).clamp(0.04, 0.96);
                                    // 5cm Snap
                                    furn.x = _snapTo5cm(rawX, 10.4);
                                    furn.y = _snapTo5cm(rawY, 8.2);
                                    _dragCoordinatesHud = 'Furniture: ${(furn.x * 10.4).toStringAsFixed(2)}m, ${(furn.y * 8.2).toStringAsFixed(2)}m (5cm snap)';
                                  });
                                },
                                onPanEnd: (_) => setState(() => _dragCoordinatesHud = null),
                                onTap: () => _openFurnitureInspector(furn),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF334155),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _selectedFurnitureId == furn.id ? const Color(0xFF38BDF8) : Colors.white38,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Icon(
                                    furn.type == 'bed'
                                        ? Icons.bed_rounded
                                        : furn.type == 'desk'
                                            ? Icons.desk_rounded
                                            : furn.type == 'tv'
                                                ? Icons.tv_rounded
                                                : Icons.weekend_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            );
                          }),

                          // Draggable Fixture Nodes
                          ..._workingLayout.fixtures.map((fix) {
                            final screenX = fix.x * canvasSize.width;
                            final screenY = fix.y * canvasSize.height;
                            final isLinked = fix.linkedRealDeviceId != null;

                            return Positioned(
                              left: screenX - 22,
                              top: screenY - 22,
                              child: GestureDetector(
                                onPanStart: (_) => _snapshot(),
                                onPanUpdate: (details) {
                                  setState(() {
                                    final rawX = (fix.x + details.delta.dx / canvasSize.width).clamp(0.04, 0.96);
                                    final rawY = (fix.y + details.delta.dy / canvasSize.height).clamp(0.04, 0.96);
                                    // 5cm Snap
                                    fix.x = _snapTo5cm(rawX, 10.4);
                                    fix.y = _snapTo5cm(rawY, 8.2);
                                    _dragCoordinatesHud = '${fix.label}: ${(fix.x * 10.4).toStringAsFixed(2)}m, ${(fix.y * 8.2).toStringAsFixed(2)}m (5cm snap)';
                                  });
                                },
                                onPanEnd: (_) => setState(() => _dragCoordinatesHud = null),
                                onTap: () => _openDeviceLinkPicker(fix),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isLinked ? const Color(0xFF0A84FF) : const Color(0xFF334155),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _selectedFixtureId == fix.id
                                              ? const Color(0xFF00D4FF)
                                              : (isLinked ? const Color(0xFF60A5FA) : Colors.white54),
                                          width: _selectedFixtureId == fix.id ? 2.5 : 1.8,
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
                                            : fix.fixtureType == 'table_lamp'
                                                ? Icons.table_restaurant_rounded
                                                : fix.fixtureType == 'camera'
                                                    ? Icons.videocam_rounded
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

          // Bottom Quick Add & Template Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAddButton(Icons.auto_stories_rounded, 'Templates', _showPresetSelector),
                _buildAddButton(Icons.add_circle_outline_rounded, 'Add Fixture', _showAddDialog),
                _buildAddButton(Icons.restore_rounded, 'Reset Default', () {
                  _snapshot();
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: const Color(0xFF60A5FA)),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// Custom Painter for 2D Architectural Blueprint Grid & Dimension Annotations.
class _Blueprint2DPainter extends CustomPainter {
  final House3DTwinLayout layout;
  final String? selectedRoomId;

  _Blueprint2DPainter({required this.layout, this.selectedRoomId});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Blueprint Grid Lines (5cm subgrid + 1m major grid)
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

    final selectedRoomBorderPaint = Paint()
      ..color = const Color(0xFF00D4FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    for (final room in layout.rooms) {
      final r = Rect.fromLTWH(
        room.gridRect.left * size.width,
        room.gridRect.top * size.height,
        room.gridRect.width * size.width,
        room.gridRect.height * size.height,
      );

      final isSelected = selectedRoomId == room.id;

      // Fill room with procedural floor material color
      final roomFillPaint = Paint()
        ..color = room.floorType.color.withValues(alpha: 0.55)
        ..style = PaintingStyle.fill;
      canvas.drawRect(r, roomFillPaint);

      // Border
      canvas.drawRect(r, isSelected ? selectedRoomBorderPaint : roomBorderPaint);

      // Dimension Text Labels (e.g. "Living (OAK) • 4.8 x 4.6 m")
      final textSpan = TextSpan(
        text: '${room.name} (${room.floorType.name.toUpperCase()})\n${(room.gridRect.width * 10.4).toStringAsFixed(1)}m × ${(room.gridRect.height * 8.2).toStringAsFixed(1)}m',
        style: TextStyle(
          color: isSelected ? const Color(0xFF67E8F9) : const Color(0xFF93C5FD),
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

    // 3. Openings (Doors, Windows, and Open Passages)
    for (final op in layout.openings) {
      final p1 = Offset(op.from.dx * size.width, op.from.dy * size.height);
      final p2 = Offset(op.to.dx * size.width, op.to.dy * size.height);

      if (op.type == 'door') {
        canvas.drawLine(
          p1,
          p2,
          Paint()
            ..color = const Color(0xFF34D399) // Emerald door marker
            ..strokeWidth = 3.0
            ..strokeCap = StrokeCap.round,
        );
      } else if (op.type == 'window') {
        canvas.drawLine(
          p1,
          p2,
          Paint()
            ..color = const Color(0xFF38BDF8) // Cyan window marker
            ..strokeWidth = 3.0
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Blueprint2DPainter old) =>
      old.layout != layout || old.selectedRoomId != selectedRoomId;
}
