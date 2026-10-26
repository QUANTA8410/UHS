import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Architectural floor material types matching House Control Three.js procedural floors.
enum FloorMaterialType {
  oak,
  walnut,
  tile,
  stone;

  Color get color {
    switch (this) {
      case FloorMaterialType.oak:
        return const Color(0xFFC7A47C); // Warm oak wood planks
      case FloorMaterialType.walnut:
        return const Color(0xFF94705A); // Deep walnut parquet planks
      case FloorMaterialType.tile:
        return const Color(0xFFD5DADE); // Architectural ceramic tile
      case FloorMaterialType.stone:
        return const Color(0xFFA2A7AE); // Slate stone tile
    }
  }

  Color get groutColor {
    switch (this) {
      case FloorMaterialType.oak:
        return const Color(0x33281A10);
      case FloorMaterialType.walnut:
        return const Color(0x331B120B);
      case FloorMaterialType.tile:
        return const Color(0xFFAAB0B8);
      case FloorMaterialType.stone:
        return const Color(0xFF7C828B);
    }
  }

  static FloorMaterialType fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'walnut':
        return FloorMaterialType.walnut;
      case 'tile':
        return FloorMaterialType.tile;
      case 'stone':
        return FloorMaterialType.stone;
      case 'oak':
      default:
        return FloorMaterialType.oak;
    }
  }
}

/// Represents an architectural opening in a wall (door, window, open archway).
class Opening3D {
  final String type; // 'door', 'window', 'open'
  final Offset from;
  final Offset to;
  final double sill;
  final double head;

  const Opening3D({
    required this.type,
    required this.from,
    required this.to,
    this.sill = 0.0,
    this.head = 2.2,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'from': [from.dx, from.dy],
        'to': [to.dx, to.dy],
        'sill': sill,
        'head': head,
      };

  factory Opening3D.fromJson(Map<String, dynamic> json) {
    final fromList = (json['from'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [0.0, 0.0];
    final toList = (json['to'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [0.0, 0.0];
    return Opening3D(
      type: json['type'] as String? ?? 'door',
      from: Offset(fromList[0], fromList[1]),
      to: Offset(toList[0], toList[1]),
      sill: (json['sill'] as num?)?.toDouble() ?? 0.0,
      head: (json['head'] as num?)?.toDouble() ?? 2.2,
    );
  }
}

/// Represents a distinct room zone within the 3D isometric house.
class Room3DZone {
  final String id;
  final String name;
  final Rect gridRect; // Normalized 0.0..1.0 house footprint coordinates
  final Color floorColor;
  final FloorMaterialType floorType;
  final double cameraZoom; // e.g. 1.85 for room focus, 1.0 for entire house
  final Offset cameraFocus; // Normalized 0.0..1.0 center of focus

  const Room3DZone({
    required this.id,
    required this.name,
    required this.gridRect,
    required this.floorColor,
    this.floorType = FloorMaterialType.oak,
    this.cameraZoom = 1.85,
    required this.cameraFocus,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'rect': [gridRect.left, gridRect.top, gridRect.width, gridRect.height],
        'color': floorColor.toARGB32(),
        'floor': floorType.name,
        'cameraZoom': cameraZoom,
        'cameraFocus': [cameraFocus.dx, cameraFocus.dy],
      };

  factory Room3DZone.fromJson(Map<String, dynamic> json) {
    final rectList = (json['rect'] as List?)?.map((e) => (e as num).toDouble()).toList() ??
        [0.0, 0.0, 0.5, 0.5];
    final focusList = (json['cameraFocus'] as List?)?.map((e) => (e as num).toDouble()).toList() ??
        [0.25, 0.25];
    final floorType = FloorMaterialType.fromString(json['floor'] as String?);

    return Room3DZone(
      id: json['id'] as String? ?? 'living',
      name: json['name'] as String? ?? 'Living',
      gridRect: Rect.fromLTWH(rectList[0], rectList[1], rectList[2], rectList[3]),
      floorColor: json['color'] != null ? Color(json['color'] as int) : floorType.color,
      floorType: floorType,
      cameraZoom: (json['cameraZoom'] as num?)?.toDouble() ?? 1.85,
      cameraFocus: Offset(focusList[0], focusList[1]),
    );
  }

  Room3DZone copyWith({
    String? id,
    String? name,
    Rect? gridRect,
    Color? floorColor,
    FloorMaterialType? floorType,
    double? cameraZoom,
    Offset? cameraFocus,
  }) {
    return Room3DZone(
      id: id ?? this.id,
      name: name ?? this.name,
      gridRect: gridRect ?? this.gridRect,
      floorColor: floorColor ?? this.floorColor,
      floorType: floorType ?? this.floorType,
      cameraZoom: cameraZoom ?? this.cameraZoom,
      cameraFocus: cameraFocus ?? this.cameraFocus,
    );
  }
}

/// Represents an interactive light, appliance, or sensor fixture in 3D space.
class Fixture3DNode {
  final String id;
  String label;
  String fixtureType; // 'ceiling', 'floor', 'strip', 'pendant', 'spots', 'table', 'wall_ac', 'washer', 'camera'
  String roomId;
  double x; // 0.0..1.0 relative to house footprint
  double y; // 0.0..1.0 relative to house footprint
  double zHeight; // 0.0 (floor) to 1.0 (ceiling)
  String? linkedRealDeviceId; // Dynamically bound to RealSmartDevice.id in RealHomeProvider
  List<String> capabilities;
  String? wall; // 'west', 'north', 'east', 'south'
  String? colorHex;
  double? length;
  double? intensity;
  double? kelvinTemp;

  Fixture3DNode({
    required this.id,
    required this.label,
    required this.fixtureType,
    required this.roomId,
    required this.x,
    required this.y,
    this.zHeight = 0.85,
    this.linkedRealDeviceId,
    this.capabilities = const ['brightness'],
    this.wall,
    this.colorHex,
    this.length,
    this.intensity,
    this.kelvinTemp = 3000.0,
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
        'capabilities': capabilities,
        if (wall != null) 'wall': wall,
        if (colorHex != null) 'colorHex': colorHex,
        if (length != null) 'length': length,
        if (intensity != null) 'intensity': intensity,
        if (kelvinTemp != null) 'kelvinTemp': kelvinTemp,
      };

  factory Fixture3DNode.fromJson(Map<String, dynamic> json) {
    return Fixture3DNode(
      id: json['id'] as String? ?? UniqueKey().toString(),
      label: json['label'] as String? ?? 'Fixture',
      fixtureType: json['fixtureType'] as String? ?? 'ceiling',
      roomId: json['roomId'] as String? ?? 'living',
      x: (json['x'] as num?)?.toDouble() ?? 0.5,
      y: (json['y'] as num?)?.toDouble() ?? 0.5,
      zHeight: (json['zHeight'] as num?)?.toDouble() ?? 0.85,
      linkedRealDeviceId: json['linkedRealDeviceId'] as String?,
      capabilities: (json['capabilities'] as List?)?.map((e) => e.toString()).toList() ?? const ['brightness'],
      wall: json['wall'] as String?,
      colorHex: json['colorHex'] as String?,
      length: (json['length'] as num?)?.toDouble(),
      intensity: (json['intensity'] as num?)?.toDouble(),
      kelvinTemp: (json['kelvinTemp'] as num?)?.toDouble() ?? 3000.0,
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
    List<String>? capabilities,
    String? wall,
    String? colorHex,
    double? length,
    double? intensity,
    double? kelvinTemp,
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
      capabilities: capabilities ?? this.capabilities,
      wall: wall ?? this.wall,
      colorHex: colorHex ?? this.colorHex,
      length: length ?? this.length,
      intensity: intensity ?? this.intensity,
      kelvinTemp: kelvinTemp ?? this.kelvinTemp,
    );
  }
}

/// Represents an extruded architectural furniture element matching House Control.
class Furniture3DProp {
  final String id;
  final String type; // 'sofa', 'armchair', 'coffeeTable', 'tv', 'sideboard', 'diningSet', 'island', 'kitchen', 'fridge', 'bed', 'nightstand', 'dresser', 'vanity', 'bathtub', 'toilet', 'rug', 'plant'
  final String roomId;
  double x;
  double y;
  double width;
  double depth;
  double height;
  double rotationDeg;
  String? colorHex;
  int? chairs;
  int? stools;
  bool? isUpper;

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
    this.colorHex,
    this.chairs,
    this.stools,
    this.isUpper,
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
        if (colorHex != null) 'colorHex': colorHex,
        if (chairs != null) 'chairs': chairs,
        if (stools != null) 'stools': stools,
        if (isUpper != null) 'isUpper': isUpper,
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
      colorHex: json['colorHex'] as String?,
      chairs: json['chairs'] as int?,
      stools: json['stools'] as int?,
      isUpper: json['isUpper'] as bool?,
    );
  }
}

/// Represents a smart home scene preset matching House Control.
class HouseScene3D {
  final String id;
  final String name;
  final String icon;
  final Map<String, dynamic> lights;
  final Map<String, dynamic> acs;

  const HouseScene3D({
    required this.id,
    required this.name,
    required this.icon,
    this.lights = const {},
    this.acs = const {},
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'lights': lights,
        'acs': acs,
      };

  factory HouseScene3D.fromJson(Map<String, dynamic> json) => HouseScene3D(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Scene',
        icon: json['icon'] as String? ?? 'sun',
        lights: (json['lights'] as Map?)?.cast<String, dynamic>() ?? const {},
        acs: (json['acs'] as Map?)?.cast<String, dynamic>() ?? const {},
      );

  static List<HouseScene3D> defaultScenes() => const [
        HouseScene3D(
          id: 'bright',
          name: 'Bright',
          icon: 'sun',
          lights: {
            '*': {'on': true, 'brightness': 1.0, 'temp': 4200}
          },
        ),
        HouseScene3D(
          id: 'cozy',
          name: 'Cozy',
          icon: 'sofa',
          lights: {
            '*': {'on': false},
            'living.floor': {'on': true},
            'living.tv': {'on': true, 'brightness': 0.7, 'color': '#ff7a3c'},
            'dining.pendant': {'on': true, 'brightness': 0.45, 'temp': 2400},
            'kitchen.strip': {'on': true, 'brightness': 0.6, 'temp': 2700},
            'bedroom.left': {'on': true},
            'bedroom.right': {'on': true},
          },
        ),
        HouseScene3D(
          id: 'movie',
          name: 'Movie',
          icon: 'film',
          lights: {
            '*': {'on': false},
            'living.tv': {'on': true, 'brightness': 0.9, 'color': '#6a4cff'},
            'kitchen.strip': {'on': true, 'brightness': 0.2, 'temp': 2400},
          },
        ),
        HouseScene3D(
          id: 'night',
          name: 'Night',
          icon: 'moon',
          lights: {
            '*': {'on': false},
            'bedroom.left': {'on': true},
            'bath.mirror': {'on': true, 'brightness': 0.25, 'temp': 2300},
          },
          acs: {
            'bedroom.ac': {'sleep': true}
          },
        ),
        HouseScene3D(
          id: 'away',
          name: 'Away',
          icon: 'door',
          lights: {
            '*': {'on': false}
          },
          acs: {
            '*': {'on': false}
          },
        ),
      ];
}

/// The complete Apartment 3D Dollhouse and Blueprint state, aligned with House Control.
class House3DTwinLayout {
  final String name;
  final double wallHeight;
  final double interiorWallHeight;
  final double outdoorTemp;
  final double cameraAzimuth;
  final double cameraElevation;
  final List<Room3DZone> rooms;
  final List<Opening3D> openings;
  final List<Fixture3DNode> fixtures;
  final List<Furniture3DProp> furniture;
  final List<HouseScene3D> scenes;

  static const String prefsKey = 'house_3d_twin_layout_v1';

  House3DTwinLayout({
    this.name = 'Home',
    this.wallHeight = 2.6,
    this.interiorWallHeight = 1.25,
    this.outdoorTemp = 29.0,
    this.cameraAzimuth = 34.0,
    this.cameraElevation = 47.0,
    required this.rooms,
    this.openings = const [],
    required this.fixtures,
    required this.furniture,
    this.scenes = const [],
  });

  /// Creates the authentic 5-Room Home layout from House Control:
  /// Living, Dining, Kitchen, Bedroom, Bathroom with procedural floors,
  /// doors, windows, AC units, and complete furniture suite.
  factory House3DTwinLayout.defaultApartment() {
    final rooms = [
      const Room3DZone(
        id: 'bedroom',
        name: 'Bedroom',
        gridRect: Rect.fromLTWH(0.04, 0.04, 0.38, 0.42),
        floorColor: Color(0xFF94705A), // Walnut wood
        floorType: FloorMaterialType.walnut,
        cameraZoom: 1.85,
        cameraFocus: Offset(0.23, 0.25),
      ),
      const Room3DZone(
        id: 'bath',
        name: 'Bathroom',
        gridRect: Rect.fromLTWH(0.44, 0.04, 0.20, 0.42),
        floorColor: Color(0xFFD5DADE), // Ceramic tile
        floorType: FloorMaterialType.tile,
        cameraZoom: 2.10,
        cameraFocus: Offset(0.54, 0.25),
      ),
      const Room3DZone(
        id: 'kitchen',
        name: 'Kitchen',
        gridRect: Rect.fromLTWH(0.66, 0.04, 0.30, 0.42),
        floorColor: Color(0xFFA2A7AE), // Slate stone
        floorType: FloorMaterialType.stone,
        cameraZoom: 1.95,
        cameraFocus: Offset(0.81, 0.25),
      ),
      const Room3DZone(
        id: 'living',
        name: 'Living',
        gridRect: Rect.fromLTWH(0.04, 0.48, 0.58, 0.48),
        floorColor: Color(0xFFC7A47C), // Warm oak wood
        floorType: FloorMaterialType.oak,
        cameraZoom: 1.75,
        cameraFocus: Offset(0.33, 0.72),
      ),
      const Room3DZone(
        id: 'dining',
        name: 'Dining',
        gridRect: Rect.fromLTWH(0.64, 0.48, 0.32, 0.48),
        floorColor: Color(0xFFC7A47C), // Warm oak wood
        floorType: FloorMaterialType.oak,
        cameraZoom: 1.85,
        cameraFocus: Offset(0.80, 0.72),
      ),
    ];

    final openings = [
      // Doors
      const Opening3D(type: 'door', from: Offset(0.31, 0.46), to: Offset(0.40, 0.46)),
      const Opening3D(type: 'door', from: Offset(0.47, 0.46), to: Offset(0.55, 0.46)),
      // Open archways
      const Opening3D(type: 'open', from: Offset(0.64, 0.54), to: Offset(0.64, 0.90)),
      const Opening3D(type: 'open', from: Offset(0.70, 0.46), to: Offset(0.96, 0.46)),
      // Windows
      const Opening3D(type: 'window', from: Offset(0.04, 0.15), to: Offset(0.04, 0.35), sill: 0.85, head: 2.2),
      const Opening3D(type: 'window', from: Offset(0.04, 0.65), to: Offset(0.04, 0.85), sill: 0.85, head: 2.2),
      const Opening3D(type: 'window', from: Offset(0.12, 0.04), to: Offset(0.30, 0.04), sill: 1.50, head: 2.2),
    ];

    final fixtures = [
      // Living Room
      Fixture3DNode(
        id: 'living.main',
        label: 'Ceiling Light',
        fixtureType: 'ceiling',
        roomId: 'living',
        x: 0.30,
        y: 0.72,
        zHeight: 0.95,
        capabilities: ['brightness', 'temp'],
        kelvinTemp: 4200,
      ),
      Fixture3DNode(
        id: 'living.floor',
        label: 'Floor Lamp',
        fixtureType: 'floor',
        roomId: 'living',
        x: 0.10,
        y: 0.54,
        zHeight: 0.55,
        capabilities: ['brightness'],
        kelvinTemp: 2700,
      ),
      Fixture3DNode(
        id: 'living.tv',
        label: 'TV Backlight',
        fixtureType: 'strip',
        roomId: 'living',
        x: 0.06,
        y: 0.72,
        zHeight: 0.45,
        colorHex: '#7B5CFF',
        capabilities: ['brightness', 'color'],
      ),
      Fixture3DNode(
        id: 'living.ac',
        label: 'Living AC',
        fixtureType: 'wall_ac',
        roomId: 'living',
        wall: 'west',
        x: 0.04,
        y: 0.58,
        zHeight: 0.82,
      ),
      Fixture3DNode(
        id: 'living.camera',
        label: '360 Cam',
        fixtureType: 'camera',
        roomId: 'living',
        x: 0.58,
        y: 0.92,
        zHeight: 0.88,
      ),

      // Dining Room
      Fixture3DNode(
        id: 'dining.pendant',
        label: 'Dining Pendant',
        fixtureType: 'pendant',
        roomId: 'dining',
        x: 0.80,
        y: 0.72,
        zHeight: 0.75,
        capabilities: ['brightness', 'temp'],
        kelvinTemp: 2700,
      ),

      // Kitchen
      Fixture3DNode(
        id: 'kitchen.spots',
        label: 'Kitchen Spots',
        fixtureType: 'spots',
        roomId: 'kitchen',
        x: 0.80,
        y: 0.24,
        zHeight: 0.95,
        capabilities: ['brightness'],
        kelvinTemp: 4000,
      ),
      Fixture3DNode(
        id: 'kitchen.strip',
        label: 'Counter Strip',
        fixtureType: 'strip',
        roomId: 'kitchen',
        x: 0.78,
        y: 0.07,
        zHeight: 0.55,
        colorHex: '#FFE2C2',
        capabilities: ['brightness', 'temp'],
        kelvinTemp: 3000,
      ),
      Fixture3DNode(
        id: 'kitchen.washer',
        label: 'Ecobubble Washer',
        fixtureType: 'washer',
        roomId: 'kitchen',
        x: 0.92,
        y: 0.10,
        zHeight: 0.28,
      ),

      // Bedroom
      Fixture3DNode(
        id: 'bedroom.main',
        label: 'Bedroom Ceiling',
        fixtureType: 'ceiling',
        roomId: 'bedroom',
        x: 0.23,
        y: 0.26,
        zHeight: 0.95,
        capabilities: ['brightness', 'temp'],
        kelvinTemp: 3000,
      ),
      Fixture3DNode(
        id: 'bedroom.left',
        label: 'Bedside Left',
        fixtureType: 'table',
        roomId: 'bedroom',
        x: 0.12,
        y: 0.10,
        zHeight: 0.40,
        kelvinTemp: 2400,
      ),
      Fixture3DNode(
        id: 'bedroom.right',
        label: 'Bedside Right',
        fixtureType: 'table',
        roomId: 'bedroom',
        x: 0.34,
        y: 0.10,
        zHeight: 0.40,
        kelvinTemp: 2400,
      ),
      Fixture3DNode(
        id: 'bedroom.ac',
        label: 'Bedroom AC',
        fixtureType: 'wall_ac',
        roomId: 'bedroom',
        wall: 'north',
        x: 0.32,
        y: 0.04,
        zHeight: 0.82,
      ),

      // Bathroom
      Fixture3DNode(
        id: 'bath.main',
        label: 'Bath Ceiling',
        fixtureType: 'ceiling',
        roomId: 'bath',
        x: 0.54,
        y: 0.24,
        zHeight: 0.95,
        capabilities: ['brightness'],
      ),
      Fixture3DNode(
        id: 'bath.mirror',
        label: 'Mirror Light',
        fixtureType: 'strip',
        roomId: 'bath',
        x: 0.51,
        y: 0.06,
        zHeight: 0.70,
        capabilities: ['brightness', 'temp'],
        kelvinTemp: 3500,
      ),
    ];

    final furniture = [
      // Living Room
      Furniture3DProp(
        id: 'rug.living',
        type: 'rug',
        roomId: 'living',
        x: 0.14,
        y: 0.62,
        width: 0.32,
        depth: 0.26,
        height: 0.01,
        colorHex: '#3B4A66',
      ),
      Furniture3DProp(
        id: 'sofa.living',
        type: 'sofa',
        roomId: 'living',
        x: 0.36,
        y: 0.66,
        width: 0.16,
        depth: 0.24,
        height: 0.12,
        colorHex: '#8B93A7',
        rotationDeg: -90,
      ),
      Furniture3DProp(
        id: 'armchair.living',
        type: 'armchair',
        roomId: 'living',
        x: 0.20,
        y: 0.54,
        width: 0.10,
        depth: 0.10,
        height: 0.11,
        colorHex: '#C28A5A',
        rotationDeg: 12,
      ),
      Furniture3DProp(
        id: 'coffeeTable.living',
        type: 'coffeeTable',
        roomId: 'living',
        x: 0.24,
        y: 0.70,
        width: 0.12,
        depth: 0.08,
        height: 0.05,
      ),
      Furniture3DProp(
        id: 'tv.living',
        type: 'tv',
        roomId: 'living',
        x: 0.06,
        y: 0.65,
        width: 0.05,
        depth: 0.18,
        height: 0.14,
        rotationDeg: 90,
      ),
      Furniture3DProp(
        id: 'plant.living',
        type: 'plant',
        roomId: 'living',
        x: 0.08,
        y: 0.90,
        width: 0.08,
        depth: 0.08,
        height: 0.16,
      ),
      Furniture3DProp(
        id: 'sideboard.living',
        type: 'sideboard',
        roomId: 'living',
        x: 0.48,
        y: 0.92,
        width: 0.16,
        depth: 0.06,
        height: 0.10,
      ),

      // Dining Room
      Furniture3DProp(
        id: 'diningSet.dining',
        type: 'diningSet',
        roomId: 'dining',
        x: 0.72,
        y: 0.68,
        width: 0.18,
        depth: 0.14,
        height: 0.11,
        chairs: 6,
      ),
      Furniture3DProp(
        id: 'island.dining',
        type: 'island',
        roomId: 'dining',
        x: 0.72,
        y: 0.48,
        width: 0.20,
        depth: 0.08,
        height: 0.13,
        stools: 3,
      ),

      // Kitchen
      Furniture3DProp(
        id: 'kitchen.counter',
        type: 'kitchen',
        roomId: 'kitchen',
        x: 0.76,
        y: 0.06,
        width: 0.20,
        depth: 0.08,
        height: 0.12,
        isUpper: true,
      ),
      Furniture3DProp(
        id: 'fridge.kitchen',
        type: 'fridge',
        roomId: 'kitchen',
        x: 0.92,
        y: 0.06,
        width: 0.07,
        depth: 0.07,
        height: 0.22,
      ),

      // Bedroom
      Furniture3DProp(
        id: 'bed.bedroom',
        type: 'bed',
        roomId: 'bedroom',
        x: 0.16,
        y: 0.14,
        width: 0.18,
        depth: 0.20,
        height: 0.13,
        colorHex: '#7F8FB5',
      ),
      Furniture3DProp(
        id: 'nightstand.left',
        type: 'nightstand',
        roomId: 'bedroom',
        x: 0.08,
        y: 0.08,
        width: 0.06,
        depth: 0.06,
        height: 0.07,
      ),
      Furniture3DProp(
        id: 'nightstand.right',
        type: 'nightstand',
        roomId: 'bedroom',
        x: 0.34,
        y: 0.08,
        width: 0.06,
        depth: 0.06,
        height: 0.07,
      ),
      Furniture3DProp(
        id: 'rug.bedroom',
        type: 'rug',
        roomId: 'bedroom',
        x: 0.14,
        y: 0.26,
        width: 0.22,
        depth: 0.16,
        height: 0.01,
        colorHex: '#6A5A52',
      ),

      // Bathroom
      Furniture3DProp(
        id: 'bathtub.bath',
        type: 'bathtub',
        roomId: 'bath',
        x: 0.56,
        y: 0.14,
        width: 0.08,
        depth: 0.16,
        height: 0.10,
        rotationDeg: 90,
      ),
      Furniture3DProp(
        id: 'vanity.bath',
        type: 'vanity',
        roomId: 'bath',
        x: 0.48,
        y: 0.06,
        width: 0.10,
        depth: 0.06,
        height: 0.12,
      ),
      Furniture3DProp(
        id: 'toilet.bath',
        type: 'toilet',
        roomId: 'bath',
        x: 0.46,
        y: 0.26,
        width: 0.06,
        depth: 0.08,
        height: 0.09,
        rotationDeg: 90,
      ),
    ];

    return House3DTwinLayout(
      name: 'Home',
      wallHeight: 2.6,
      interiorWallHeight: 1.25,
      outdoorTemp: 29.0,
      cameraAzimuth: 34.0,
      cameraElevation: 47.0,
      rooms: rooms,
      openings: openings,
      fixtures: fixtures,
      furniture: furniture,
      scenes: HouseScene3D.defaultScenes(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'wallHeight': wallHeight,
        'interiorWallHeight': interiorWallHeight,
        'outdoorTemp': outdoorTemp,
        'camera': {'azimuth': cameraAzimuth, 'elevation': cameraElevation},
        'rooms': rooms.map((r) => r.toJson()).toList(),
        'openings': openings.map((o) => o.toJson()).toList(),
        'fixtures': fixtures.map((f) => f.toJson()).toList(),
        'furniture': furniture.map((p) => p.toJson()).toList(),
        'scenes': scenes.map((s) => s.toJson()).toList(),
      };

  factory House3DTwinLayout.fromJson(Map<String, dynamic> json) {
    final rawRooms = json['rooms'] as List? ?? [];
    final rawOpenings = json['openings'] as List? ?? [];
    final rawFixtures = json['fixtures'] as List? ?? [];
    final rawFurniture = json['furniture'] as List? ?? [];
    final rawScenes = json['scenes'] as List? ?? [];

    final cameraMap = json['camera'] as Map<String, dynamic>?;

    return House3DTwinLayout(
      name: json['name'] as String? ?? 'Home',
      wallHeight: (json['wallHeight'] as num?)?.toDouble() ?? 2.6,
      interiorWallHeight: (json['interiorWallHeight'] as num?)?.toDouble() ?? 1.25,
      outdoorTemp: (json['outdoorTemp'] as num?)?.toDouble() ?? 29.0,
      cameraAzimuth: (cameraMap?['azimuth'] as num?)?.toDouble() ?? 34.0,
      cameraElevation: (cameraMap?['elevation'] as num?)?.toDouble() ?? 47.0,
      rooms: rawRooms.map((r) => Room3DZone.fromJson(r as Map<String, dynamic>)).toList(),
      openings: rawOpenings.map((o) => Opening3D.fromJson(o as Map<String, dynamic>)).toList(),
      fixtures: rawFixtures.map((f) => Fixture3DNode.fromJson(f as Map<String, dynamic>)).toList(),
      furniture: rawFurniture.map((p) => Furniture3DProp.fromJson(p as Map<String, dynamic>)).toList(),
      scenes: rawScenes.isNotEmpty
          ? rawScenes.map((s) => HouseScene3D.fromJson(s as Map<String, dynamic>)).toList()
          : HouseScene3D.defaultScenes(),
    );
  }

  /// Parses House Control's native world-metric JSON format directly (`home.json`, `studio.json`).
  factory House3DTwinLayout.fromHouseControlJson(Map<String, dynamic> json) {
    final rawRooms = json['rooms'] as List? ?? [];
    double minX = 0, minZ = 0, maxX = 10.4, maxZ = 8.2;

    for (final r in rawRooms) {
      final rect = (r['rect'] as List?)?.map((e) => (e as num).toDouble()).toList();
      if (rect != null && rect.length >= 4) {
        if (rect[0] < minX) minX = rect[0];
        if (rect[1] < minZ) minZ = rect[1];
        if (rect[0] + rect[2] > maxX) maxX = rect[0] + rect[2];
        if (rect[1] + rect[3] > maxZ) maxZ = rect[1] + rect[3];
      }
    }

    final spanX = (maxX - minX > 0) ? (maxX - minX) : 10.4;
    final spanZ = (maxZ - minZ > 0) ? (maxZ - minZ) : 8.2;

    double normX(double x) => 0.04 + ((x - minX) / spanX) * 0.92;
    double normZ(double z) => 0.04 + ((z - minZ) / spanZ) * 0.92;
    double normW(double w) => (w / spanX) * 0.92;
    double normD(double d) => (d / spanZ) * 0.92;

    final parsedRooms = rawRooms.map((r) {
      final rect = (r['rect'] as List).map((e) => (e as num).toDouble()).toList();
      final floorType = FloorMaterialType.fromString(r['floor'] as String?);
      final rx = normX(rect[0]);
      final rz = normZ(rect[1]);
      final rw = normW(rect[2]);
      final rd = normD(rect[3]);

      return Room3DZone(
        id: r['id'] as String? ?? 'room',
        name: r['name'] as String? ?? 'Room',
        gridRect: Rect.fromLTWH(rx, rz, rw, rd),
        floorColor: floorType.color,
        floorType: floorType,
        cameraZoom: 1.85,
        cameraFocus: Offset(rx + rw / 2, rz + rd / 2),
      );
    }).toList();

    // Parse Openings
    final rawOpenings = json['openings'] as List? ?? [];
    final List<Opening3D> parsedOpenings = rawOpenings.isNotEmpty
        ? rawOpenings.map<Opening3D>((o) {
            final from = (o['from'] as List).map((e) => (e as num).toDouble()).toList();
            final to = (o['to'] as List).map((e) => (e as num).toDouble()).toList();
            return Opening3D(
              type: o['type'] as String? ?? 'door',
              from: Offset(normX(from[0]), normZ(from[1])),
              to: Offset(normX(to[0]), normZ(to[1])),
              sill: (o['sill'] as num?)?.toDouble() ?? 0.0,
              head: (o['head'] as num?)?.toDouble() ?? 2.1,
            );
          }).toList()
        : House3DTwinLayout.defaultApartment().openings;

    // Parse Furniture
    final rawFurniture = json['furniture'] as List? ?? [];
    final List<Furniture3DProp> parsedFurniture = rawFurniture.isNotEmpty
        ? rawFurniture.map((f) {
            final pos = (f['pos'] as List).map((e) => (e as num).toDouble()).toList();
            final size = (f['size'] as List?)?.map((e) => (e as num).toDouble()).toList();
            final fx = normX(pos[0]);
            final fz = normZ(pos[1]);

            String propRoom = 'living';
            for (final room in parsedRooms) {
              if (room.gridRect.contains(Offset(fx, fz))) {
                propRoom = room.id;
                break;
              }
            }

            final propType = f['type'] as String? ?? 'cube';
            double w = 0.12;
            double d = 0.10;
            double h = 0.08;

            if (size != null && size.length >= 2) {
              w = normW(size[0]);
              d = normD(size[1]);
            } else if (f['width'] != null) {
              w = normW((f['width'] as num).toDouble());
              d = w * 0.75;
            }

            if (f['height'] != null) {
              h = ((f['height'] as num).toDouble() / 2.6) * 0.35;
            } else if (propType == 'rug') {
              h = 0.005;
            } else if (propType == 'bed') {
              h = 0.10;
            } else if (propType == 'sofa') {
              h = 0.12;
            } else if (propType == 'plant') {
              h = 0.15;
            } else if (propType == 'bookshelf') {
              h = 0.22;
            }

            return Furniture3DProp(
              id: 'prop_${pos[0]}_${pos[1]}',
              type: propType,
              roomId: propRoom,
              x: fx,
              y: fz,
              width: w,
              depth: d,
              height: h,
              rotationDeg: (f['rot'] as num?)?.toDouble() ?? 0.0,
              colorHex: f['color'] as String?,
              chairs: (f['chairs'] as num?)?.toInt(),
              stools: (f['stools'] as num?)?.toInt(),
              isUpper: f['upper'] as bool? ?? false,
            );
          }).toList()
        : House3DTwinLayout.defaultApartment().furniture;

    // Parse Fixtures (Lights and ACs)
    final rawLights = json['lights'] as List? ?? [];
    final rawAcs = json['acs'] as List? ?? [];
    final List<Fixture3DNode> parsedFixtures = [];
    final wallHeight = (json['wallHeight'] as num?)?.toDouble() ?? 2.6;

    for (final l in rawLights) {
      final pos = (l['pos'] as List).map((e) => (e as num).toDouble()).toList();
      final y = (l['y'] as num?)?.toDouble() ?? 2.0;
      final caps = (l['capabilities'] as List?)?.map((e) => e.toString()).toList();
      parsedFixtures.add(
        Fixture3DNode(
          id: l['id'] as String? ?? 'light_${parsedFixtures.length}',
          label: l['name'] as String? ?? 'Light',
          fixtureType: 'ceiling_light',
          roomId: l['room'] as String? ?? 'living',
          x: normX(pos[0]),
          y: normZ(pos[1]),
          zHeight: (y / wallHeight).clamp(0.1, 1.0),
          capabilities: caps ?? const ['brightness'],
          colorHex: l['color'] as String?,
          intensity: (l['intensity'] as num?)?.toDouble(),
        ),
      );
    }

    for (final a in rawAcs) {
      final pos = (a['pos'] as List).map((e) => (e as num).toDouble()).toList();
      final y = (a['y'] as num?)?.toDouble() ?? 2.2;
      parsedFixtures.add(
        Fixture3DNode(
          id: a['id'] as String? ?? 'ac_${parsedFixtures.length}',
          label: a['name'] as String? ?? 'AC',
          fixtureType: 'wall_ac',
          roomId: a['room'] as String? ?? 'living',
          x: normX(pos[0]),
          y: normZ(pos[1]),
          zHeight: (y / wallHeight).clamp(0.1, 1.0),
          wall: a['wall'] as String?,
        ),
      );
    }

    // Parse Scenes
    final rawScenes = json['scenes'] as List? ?? [];
    final List<HouseScene3D> parsedScenes = rawScenes.isNotEmpty
        ? rawScenes.map((s) => HouseScene3D.fromJson(s as Map<String, dynamic>)).toList()
        : HouseScene3D.defaultScenes();

    final cameraMap = json['camera'] as Map<String, dynamic>?;

    return House3DTwinLayout(
      name: json['name'] as String? ?? 'House Control Home',
      wallHeight: wallHeight,
      interiorWallHeight: (json['interiorWallHeight'] as num?)?.toDouble() ?? 1.25,
      outdoorTemp: (json['outdoorTemp'] as num?)?.toDouble() ?? 29.0,
      cameraAzimuth: (cameraMap?['azimuth'] as num?)?.toDouble() ?? 34.0,
      cameraElevation: (cameraMap?['elevation'] as num?)?.toDouble() ?? 47.0,
      rooms: parsedRooms,
      fixtures: parsedFixtures.isNotEmpty ? parsedFixtures : House3DTwinLayout.defaultApartment().fixtures,
      furniture: parsedFurniture,
      openings: parsedOpenings,
      scenes: parsedScenes,
    );
  }

  /// Authentic House Control Studio Apartment Plan (`studio.json`)
  static final Map<String, dynamic> studioJsonMap = {
    "version": 1,
    "name": "Studio",
    "wallHeight": 2.7,
    "interiorWallHeight": 1.25,
    "camera": {"azimuth": 30, "elevation": 50},
    "outdoorTemp": 31,
    "rooms": [
      {"id": "main", "name": "Studio", "rect": [0, 0, 6.2, 4.8], "floor": "walnut"},
      {"id": "bath", "name": "Bathroom", "rect": [6.2, 0, 2.2, 2.6], "floor": "tile"},
      {"id": "hall", "name": "Hall", "rect": [6.2, 2.6, 2.2, 2.2], "floor": "stone"}
    ],
    "openings": [
      {"type": "door", "from": [6.2, 3.2], "to": [6.2, 4.1]},
      {"type": "door", "from": [6.9, 2.6], "to": [7.7, 2.6]},
      {"type": "window", "from": [0, 1.2], "to": [0, 3.6]},
      {"type": "window", "from": [2.6, 0], "to": [4.2, 0]}
    ],
    "furniture": [
      {"type": "rug", "pos": [2.2, 3.2], "size": [2.6, 1.9], "color": "#5b4a6e"},
      {"type": "bed", "pos": [1.2, 1.25], "width": 1.6, "color": "#b98a7a"},
      {"type": "nightstand", "pos": [2.45, 0.4]},
      {"type": "sofa", "pos": [2.2, 4.25], "rot": 180, "width": 2.1, "color": "#6f8f86"},
      {"type": "coffeeTable", "pos": [2.2, 3.1]},
      {"type": "desk", "pos": [4.9, 0.5], "width": 1.4},
      {"type": "bookshelf", "pos": [0.28, 4.2], "rot": 90, "width": 0.9, "height": 1.9},
      {"type": "kitchen", "pos": [4.6, 4.38], "rot": 180, "width": 2.4, "upper": false},
      {"type": "plant", "pos": [5.75, 2.4], "height": 1.3},
      {"type": "vanity", "pos": [7.3, 0.38], "width": 0.9},
      {"type": "toilet", "pos": [6.6, 1.7], "rot": 90},
      {"type": "sideboard", "pos": [8.1, 3.7], "rot": -90, "width": 1.1}
    ],
    "lights": [
      {"id": "main.ceiling", "name": "Ceiling", "room": "main", "type": "pendant", "pos": [3.1, 2.6], "y": 2.0, "capabilities": ["brightness", "temp"]},
      {"id": "main.bed", "name": "Bedside", "room": "main", "type": "table", "pos": [2.45, 0.4], "y": 0.5},
      {"id": "main.desk", "name": "Desk lamp", "room": "main", "type": "table", "pos": [5.4, 0.35], "y": 0.76},
      {"id": "main.shelf", "name": "Shelf glow", "room": "main", "type": "strip", "pos": [0.14, 4.2], "y": 1.95, "rot": 90, "length": 0.9, "capabilities": ["brightness", "color"], "color": "#ff5fc4"},
      {"id": "bath.ceiling", "name": "Ceiling", "room": "bath", "type": "ceiling", "pos": [7.3, 1.4], "capabilities": ["brightness"]},
      {"id": "hall.ceiling", "name": "Ceiling", "room": "hall", "type": "spots", "pos": [7.3, 3.7], "rot": 90}
    ],
    "acs": [
      {"id": "main.ac", "name": "Studio AC", "room": "main", "wall": "north", "pos": [1.2, 0], "y": 2.3}
    ],
    "scenes": [
      {"id": "bright", "name": "Bright", "icon": "sun", "lights": {"*": {"on": true, "brightness": 1, "temp": 4200}}},
      {"id": "work", "name": "Work", "icon": "table", "lights": {"*": {"on": false}, "main.desk": {"on": true}, "main.ceiling": {"on": true, "brightness": 0.6, "temp": 4500}}},
      {"id": "chill", "name": "Chill", "icon": "sofa", "lights": {"*": {"on": false}, "main.shelf": {"on": true, "brightness": 0.8, "color": "#ff5fc4"}, "main.bed": {"on": true}}},
      {"id": "off", "name": "All off", "icon": "moon", "lights": {"*": {"on": false}}, "acs": {"*": {"on": false}}}
    ]
  };

  factory House3DTwinLayout.studioApartment() {
    return House3DTwinLayout.fromHouseControlJson(studioJsonMap);
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
    } catch (_) {}
    return House3DTwinLayout.defaultApartment();
  }
}
