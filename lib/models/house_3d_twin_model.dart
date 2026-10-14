import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a distinct room zone within the 3D isometric house.
class Room3DZone {
  final String id;
  final String name;
  final Rect gridRect; // Normalized 0.0..1.0 house footprint coordinates
  final Color floorColor;
  final double cameraZoom; // e.g. 1.85 for room focus, 1.0 for entire house
  final Offset cameraFocus; // Normalized 0.0..1.0 center of focus

  const Room3DZone({
    required this.id,
    required this.name,
    required this.gridRect,
    required this.floorColor,
    this.cameraZoom = 1.85,
    required this.cameraFocus,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'rect': [gridRect.left, gridRect.top, gridRect.width, gridRect.height],
        'color': floorColor.toARGB32(),
        'cameraZoom': cameraZoom,
        'cameraFocus': [cameraFocus.dx, cameraFocus.dy],
      };

  factory Room3DZone.fromJson(Map<String, dynamic> json) {
    final rectList = (json['rect'] as List?)?.map((e) => (e as num).toDouble()).toList() ??
        [0.0, 0.0, 0.5, 0.5];
    final focusList = (json['cameraFocus'] as List?)?.map((e) => (e as num).toDouble()).toList() ??
        [0.25, 0.25];

    return Room3DZone(
      id: json['id'] as String? ?? 'living',
      name: json['name'] as String? ?? 'Living',
      gridRect: Rect.fromLTWH(rectList[0], rectList[1], rectList[2], rectList[3]),
      floorColor: Color(json['color'] as int? ?? 0xFF2A221E),
      cameraZoom: (json['cameraZoom'] as num?)?.toDouble() ?? 1.85,
      cameraFocus: Offset(focusList[0], focusList[1]),
    );
  }

  Room3DZone copyWith({
    String? id,
    String? name,
    Rect? gridRect,
    Color? floorColor,
    double? cameraZoom,
    Offset? cameraFocus,
  }) {
    return Room3DZone(
      id: id ?? this.id,
      name: name ?? this.name,
      gridRect: gridRect ?? this.gridRect,
      floorColor: floorColor ?? this.floorColor,
      cameraZoom: cameraZoom ?? this.cameraZoom,
      cameraFocus: cameraFocus ?? this.cameraFocus,
    );
  }
}

/// Represents an interactive light, appliance, or sensor fixture in 3D space.
class Fixture3DNode {
  final String id;
  String label;
  String fixtureType; // 'ceiling_light', 'floor_lamp', 'tv_backlight', 'wall_ac', 'washer', 'camera'
  String roomId;
  double x; // 0.0..1.0 relative to house footprint
  double y; // 0.0..1.0 relative to house footprint
  double zHeight; // 0.0 (floor) to 1.0 (ceiling)
  String? linkedRealDeviceId; // Dynamically bound to RealSmartDevice.id in RealHomeProvider

  Fixture3DNode({
    required this.id,
    required this.label,
    required this.fixtureType,
    required this.roomId,
    required this.x,
    required this.y,
    this.zHeight = 0.85,
    this.linkedRealDeviceId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'fixtureType': fixtureType,
        'roomId': roomId,
        'x': x,
        'y': y,
        'zHeight': zHeight,
        if (linkedRealDeviceId != null) 'linkedRealDeviceId': linkedRealDeviceId,
      };

  factory Fixture3DNode.fromJson(Map<String, dynamic> json) {
    return Fixture3DNode(
      id: json['id'] as String? ?? UniqueKey().toString(),
      label: json['label'] as String? ?? 'Fixture',
      fixtureType: json['fixtureType'] as String? ?? 'ceiling_light',
      roomId: json['roomId'] as String? ?? 'living',
      x: (json['x'] as num?)?.toDouble() ?? 0.5,
      y: (json['y'] as num?)?.toDouble() ?? 0.5,
      zHeight: (json['zHeight'] as num?)?.toDouble() ?? 0.85,
      linkedRealDeviceId: json['linkedRealDeviceId'] as String?,
    );
  }

  Fixture3DNode copyWith({
    String? id,
    String? label,
    String? fixtureType,
    String? roomId,
    double? x,
    double? y,
    double? zHeight,
    String? linkedRealDeviceId,
  }) {
    return Fixture3DNode(
      id: id ?? this.id,
      label: label ?? this.label,
      fixtureType: fixtureType ?? this.fixtureType,
      roomId: roomId ?? this.roomId,
      x: x ?? this.x,
      y: y ?? this.y,
      zHeight: zHeight ?? this.zHeight,
      linkedRealDeviceId: linkedRealDeviceId ?? this.linkedRealDeviceId,
    );
  }
}

/// Represents an extruded architectural furniture element.
class Furniture3DProp {
  final String id;
  final String type; // 'sofa', 'bed', 'dining_table', 'tv_unit', 'kitchen_counter', 'rug', 'bath_tub', 'coffee_table'
  final String roomId;
  double x;
  double y;
  double width;
  double depth;
  double height;
  double rotationDeg;

  Furniture3DProp({
    required this.id,
    required this.type,
    required this.roomId,
    required this.x,
    required this.y,
    required this.width,
    required this.depth,
    required this.height,
    this.rotationDeg = 0.0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'roomId': roomId,
        'x': x,
        'y': y,
        'width': width,
        'depth': depth,
        'height': height,
        'rotationDeg': rotationDeg,
      };

  factory Furniture3DProp.fromJson(Map<String, dynamic> json) {
    return Furniture3DProp(
      id: json['id'] as String? ?? UniqueKey().toString(),
      type: json['type'] as String? ?? 'sofa',
      roomId: json['roomId'] as String? ?? 'living',
      x: (json['x'] as num?)?.toDouble() ?? 0.2,
      y: (json['y'] as num?)?.toDouble() ?? 0.2,
      width: (json['width'] as num?)?.toDouble() ?? 0.1,
      depth: (json['depth'] as num?)?.toDouble() ?? 0.1,
      height: (json['height'] as num?)?.toDouble() ?? 0.08,
      rotationDeg: (json['rotationDeg'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// The complete 5-Room Apartment 3D Dollhouse and Blueprint state.
class House3DTwinLayout {
  final List<Room3DZone> rooms;
  final List<Fixture3DNode> fixtures;
  final List<Furniture3DProp> furniture;

  static const String prefsKey = 'house_3d_twin_layout_v1';

  House3DTwinLayout({
    required this.rooms,
    required this.fixtures,
    required this.furniture,
  });

  /// Creates the default 5-room layout matching the video:
  /// - Bedroom (top-left)
  /// - Bathroom (top-center)
  /// - Kitchen (top-right)
  /// - Living (bottom-left)
  /// - Dining (bottom-right)
  factory House3DTwinLayout.defaultApartment() {
    final rooms = [
      const Room3DZone(
        id: 'bedroom',
        name: 'Bedroom',
        gridRect: Rect.fromLTWH(0.06, 0.06, 0.38, 0.40),
        floorColor: Color(0xFF231D24), // Cozy parquet
        cameraZoom: 1.85,
        cameraFocus: Offset(0.25, 0.26),
      ),
      const Room3DZone(
        id: 'bathroom',
        name: 'Bathroom',
        gridRect: Rect.fromLTWH(0.46, 0.06, 0.22, 0.34),
        floorColor: Color(0xFF1E262B), // Slate tile
        cameraZoom: 2.10,
        cameraFocus: Offset(0.57, 0.23),
      ),
      const Room3DZone(
        id: 'kitchen',
        name: 'Kitchen',
        gridRect: Rect.fromLTWH(0.70, 0.06, 0.24, 0.40),
        floorColor: Color(0xFF20232A), // Dark stone
        cameraZoom: 1.95,
        cameraFocus: Offset(0.82, 0.26),
      ),
      const Room3DZone(
        id: 'living',
        name: 'Living',
        gridRect: Rect.fromLTWH(0.06, 0.48, 0.48, 0.46),
        floorColor: Color(0xFF2E241E), // Warm oak wood
        cameraZoom: 1.75,
        cameraFocus: Offset(0.30, 0.71),
      ),
      const Room3DZone(
        id: 'dining',
        name: 'Dining',
        gridRect: Rect.fromLTWH(0.56, 0.48, 0.38, 0.46),
        floorColor: Color(0xFF26201B), // Natural wood
        cameraZoom: 1.85,
        cameraFocus: Offset(0.75, 0.71),
      ),
    ];

    final fixtures = [
      // Living Room
      Fixture3DNode(
        id: 'living_ceiling',
        label: 'Ceiling Light',
        fixtureType: 'ceiling_light',
        roomId: 'living',
        x: 0.30,
        y: 0.70,
        zHeight: 0.95,
      ),
      Fixture3DNode(
        id: 'living_floor_lamp',
        label: 'Floor Lamp',
        fixtureType: 'floor_lamp',
        roomId: 'living',
        x: 0.12,
        y: 0.86,
        zHeight: 0.50,
      ),
      Fixture3DNode(
        id: 'living_tv_backlight',
        label: 'TV Backlight',
        fixtureType: 'tv_backlight',
        roomId: 'living',
        x: 0.10,
        y: 0.60,
        zHeight: 0.45,
      ),
      Fixture3DNode(
        id: 'living_ac',
        label: 'Living AC',
        fixtureType: 'wall_ac',
        roomId: 'living',
        x: 0.48,
        y: 0.52,
        zHeight: 0.80,
      ),
      Fixture3DNode(
        id: 'living_camera',
        label: '360 Cam',
        fixtureType: 'camera',
        roomId: 'living',
        x: 0.50,
        y: 0.88,
        zHeight: 0.88,
      ),

      // Bedroom
      Fixture3DNode(
        id: 'bedroom_ceiling',
        label: 'Ceiling Light',
        fixtureType: 'ceiling_light',
        roomId: 'bedroom',
        x: 0.25,
        y: 0.25,
        zHeight: 0.95,
      ),
      Fixture3DNode(
        id: 'bedroom_bedside_lamp',
        label: 'Bedside Lamp',
        fixtureType: 'floor_lamp',
        roomId: 'bedroom',
        x: 0.10,
        y: 0.12,
        zHeight: 0.38,
      ),
      Fixture3DNode(
        id: 'bedroom_ac',
        label: 'Bedroom AC',
        fixtureType: 'wall_ac',
        roomId: 'bedroom',
        x: 0.40,
        y: 0.10,
        zHeight: 0.80,
      ),

      // Dining Room
      Fixture3DNode(
        id: 'dining_pendant',
        label: 'Dining Pendant',
        fixtureType: 'ceiling_light',
        roomId: 'dining',
        x: 0.75,
        y: 0.70,
        zHeight: 0.78,
      ),

      // Kitchen
      Fixture3DNode(
        id: 'kitchen_spots',
        label: 'Kitchen Spots',
        fixtureType: 'ceiling_light',
        roomId: 'kitchen',
        x: 0.82,
        y: 0.25,
        zHeight: 0.95,
      ),
      Fixture3DNode(
        id: 'kitchen_washer',
        label: 'Ecobubble Washer',
        fixtureType: 'washer',
        roomId: 'kitchen',
        x: 0.88,
        y: 0.12,
        zHeight: 0.25,
      ),

      // Bathroom
      Fixture3DNode(
        id: 'bathroom_light',
        label: 'Vanity Mirror',
        fixtureType: 'ceiling_light',
        roomId: 'bathroom',
        x: 0.57,
        y: 0.18,
        zHeight: 0.90,
      ),
    ];

    final furniture = [
      // Bedroom: Bed + Rug
      Furniture3DProp(
        id: 'bed_master',
        type: 'bed',
        roomId: 'bedroom',
        x: 0.14,
        y: 0.12,
        width: 0.18,
        depth: 0.20,
        height: 0.14,
      ),
      Furniture3DProp(
        id: 'rug_bedroom',
        type: 'rug',
        roomId: 'bedroom',
        x: 0.12,
        y: 0.28,
        width: 0.20,
        depth: 0.14,
        height: 0.01,
      ),

      // Living Room: L-Sofa + Rug + Coffee Table + TV Unit
      Furniture3DProp(
        id: 'sofa_living',
        type: 'sofa',
        roomId: 'living',
        x: 0.18,
        y: 0.72,
        width: 0.22,
        depth: 0.16,
        height: 0.12,
      ),
      Furniture3DProp(
        id: 'rug_living',
        type: 'rug',
        roomId: 'living',
        x: 0.18,
        y: 0.60,
        width: 0.22,
        depth: 0.18,
        height: 0.01,
      ),
      Furniture3DProp(
        id: 'coffee_table_living',
        type: 'coffee_table',
        roomId: 'living',
        x: 0.24,
        y: 0.64,
        width: 0.10,
        depth: 0.07,
        height: 0.06,
      ),
      Furniture3DProp(
        id: 'tv_unit_living',
        type: 'tv_unit',
        roomId: 'living',
        x: 0.08,
        y: 0.52,
        width: 0.04,
        depth: 0.18,
        height: 0.10,
      ),

      // Dining: Dining Table
      Furniture3DProp(
        id: 'dining_table',
        type: 'dining_table',
        roomId: 'dining',
        x: 0.68,
        y: 0.64,
        width: 0.16,
        depth: 0.14,
        height: 0.11,
      ),

      // Kitchen: Counter
      Furniture3DProp(
        id: 'kitchen_counter',
        type: 'kitchen_counter',
        roomId: 'kitchen',
        x: 0.76,
        y: 0.10,
        width: 0.15,
        depth: 0.12,
        height: 0.12,
      ),

      // Bathroom: Tub
      Furniture3DProp(
        id: 'bath_tub',
        type: 'bath_tub',
        roomId: 'bathroom',
        x: 0.50,
        y: 0.10,
        width: 0.14,
        depth: 0.10,
        height: 0.11,
      ),
    ];

    return House3DTwinLayout(
      rooms: rooms,
      fixtures: fixtures,
      furniture: furniture,
    );
  }

  Map<String, dynamic> toJson() => {
        'rooms': rooms.map((r) => r.toJson()).toList(),
        'fixtures': fixtures.map((f) => f.toJson()).toList(),
        'furniture': furniture.map((p) => p.toJson()).toList(),
      };

  factory House3DTwinLayout.fromJson(Map<String, dynamic> json) {
    final rawRooms = json['rooms'] as List? ?? [];
    final rawFixtures = json['fixtures'] as List? ?? [];
    final rawFurniture = json['furniture'] as List? ?? [];

    return House3DTwinLayout(
      rooms: rawRooms.map((r) => Room3DZone.fromJson(r as Map<String, dynamic>)).toList(),
      fixtures: rawFixtures.map((f) => Fixture3DNode.fromJson(f as Map<String, dynamic>)).toList(),
      furniture: rawFurniture.map((p) => Furniture3DProp.fromJson(p as Map<String, dynamic>)).toList(),
    );
  }

  Future<void> saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, jsonEncode(toJson()));
  }

  static Future<House3DTwinLayout> loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        return House3DTwinLayout.fromJson(decoded);
      }
    } catch (_) {
      // Fallback on parse failure
    }
    return House3DTwinLayout.defaultApartment();
  }
}
