import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/real_iot_controller.dart';
import '../../../theme/apple_glass_theme.dart';

enum UniversalDeviceArchetype {
  lighting,
  climateAc,
  fanAir,
  laundry,
  refrigeration,
  tvMedia,
  speakerAudio,
  robotVacuum,
  cameraSecurity,
  lockAccess,
  curtainShade,
  plugEnergy,
}

class UniversalCategoryClassifier {
  /// Automatically classifies ANY smart device from ANY brand into one of 12 visual archetypes
  static UniversalDeviceArchetype classify(RealSmartDevice device) {
    final hay = '${device.category} ${device.id} ${device.name}'.toLowerCase();

    if (hay.contains('vacuum') || hay.contains('roborock') || hay.contains('roomba') || hay.contains('mop')) {
      return UniversalDeviceArchetype.robotVacuum;
    }
    if (hay.contains('camera') || hay.contains('cam') || hay.contains('doorbell') || hay.contains('ring') || hay.contains('arlo') || hay.contains('eufy')) {
      return UniversalDeviceArchetype.cameraSecurity;
    }
    if (hay.contains('lock') || hay.contains('door') || hay.contains('gate') || hay.contains('garage') || hay.contains('yale') || hay.contains('nuki')) {
      return UniversalDeviceArchetype.lockAccess;
    }
    if (hay.contains('curtain') || hay.contains('blind') || hay.contains('shade') || hay.contains('roller') || hay.contains('somfy')) {
      return UniversalDeviceArchetype.curtainShade;
    }
    if (hay.contains('fridge') || hay.contains('refrigerator') || hay.contains('freezer') || hay.contains('ice')) {
      return UniversalDeviceArchetype.refrigeration;
    }
    if (hay.contains('washer') || hay.contains('laundry') || hay.contains('dryer') || hay.contains('dishwasher')) {
      return UniversalDeviceArchetype.laundry;
    }
    if (hay.contains('fan') || hay.contains('purifier') || hay.contains('humidifier') || hay.contains('exhaust') || hay.contains('dyson')) {
      return UniversalDeviceArchetype.fanAir;
    }
    if (hay.contains('ac') || hay.contains('aircon') || hay.contains('climate') || hay.contains('thermostat') || hay.contains('dualcool') || hay.contains('heater')) {
      return UniversalDeviceArchetype.climateAc;
    }
    if (hay.contains('speaker') || hay.contains('sonos') || hay.contains('soundbar') || hay.contains('echo') || hay.contains('homepod') || hay.contains('bose') || hay.contains('audio')) {
      return UniversalDeviceArchetype.speakerAudio;
    }
    if (hay.contains('tv') || hay.contains('television') || hay.contains('oneplus') || hay.contains('chromecast') || hay.contains('projector') || hay.contains('media')) {
      return UniversalDeviceArchetype.tvMedia;
    }
    if (hay.contains('light') || hay.contains('bulb') || hay.contains('lamp') || hay.contains('strip') || hay.contains('wipro') || hay.contains('hue') || hay.contains('nanoleaf') || hay.contains('lifx') || hay.contains('yeelight')) {
      return UniversalDeviceArchetype.lighting;
    }
    return UniversalDeviceArchetype.plugEnergy;
  }

  static Color colorFor(UniversalDeviceArchetype type) {
    switch (type) {
      case UniversalDeviceArchetype.lighting:
        return const Color(0xFFFF9F0A); // Warm Amber
      case UniversalDeviceArchetype.climateAc:
        return const Color(0xFF00D4FF); // Cryo Cyan
      case UniversalDeviceArchetype.fanAir:
        return const Color(0xFF5AC8FA); // Sky Breeze
      case UniversalDeviceArchetype.laundry:
        return const Color(0xFF30D158); // EcoBubble Emerald
      case UniversalDeviceArchetype.refrigeration:
        return const Color(0xFF64D2FF); // Glacial Ice
      case UniversalDeviceArchetype.tvMedia:
        return const Color(0xFFBF5AF2); // Cinema Violet
      case UniversalDeviceArchetype.speakerAudio:
        return const Color(0xFFFF2D55); // Acoustic Magenta
      case UniversalDeviceArchetype.robotVacuum:
        return const Color(0xFF00E5A3); // LiDAR Mint
      case UniversalDeviceArchetype.cameraSecurity:
        return const Color(0xFFFF453A); // Sentinel Crimson
      case UniversalDeviceArchetype.lockAccess:
        return const Color(0xFFFFD60A); // Vault Gold
      case UniversalDeviceArchetype.curtainShade:
        return const Color(0xFFFFCC00); // Daylight Gold
      case UniversalDeviceArchetype.plugEnergy:
        return const Color(0xFF0A84FF); // Electric Blue
    }
  }

  static IconData iconFor(UniversalDeviceArchetype type) {
    switch (type) {
      case UniversalDeviceArchetype.lighting:
        return Icons.lightbulb_rounded;
      case UniversalDeviceArchetype.climateAc:
        return Icons.ac_unit_rounded;
      case UniversalDeviceArchetype.fanAir:
        return Icons.mode_fan_off_rounded;
      case UniversalDeviceArchetype.laundry:
        return Icons.local_laundry_service_rounded;
      case UniversalDeviceArchetype.refrigeration:
        return Icons.kitchen_rounded;
      case UniversalDeviceArchetype.tvMedia:
        return Icons.tv_rounded;
      case UniversalDeviceArchetype.speakerAudio:
        return Icons.speaker_rounded;
      case UniversalDeviceArchetype.robotVacuum:
        return Icons.smart_toy_rounded;
      case UniversalDeviceArchetype.cameraSecurity:
        return Icons.videocam_rounded;
      case UniversalDeviceArchetype.lockAccess:
        return Icons.lock_rounded;
      case UniversalDeviceArchetype.curtainShade:
        return Icons.roller_shades_rounded;
      case UniversalDeviceArchetype.plugEnergy:
        return Icons.bolt_rounded;
    }
  }

  static bool supportsHorizontalSlider(UniversalDeviceArchetype type) {
    return type == UniversalDeviceArchetype.lighting ||
        type == UniversalDeviceArchetype.climateAc ||
        type == UniversalDeviceArchetype.fanAir ||
        type == UniversalDeviceArchetype.speakerAudio ||
        type == UniversalDeviceArchetype.curtainShade;
  }
}

/// Universal Animated Apple Liquid Glass Card that adapts to all 12 device archetypes
class UniversalAnimatedGlassCard extends StatefulWidget {
  final RealSmartDevice device;
  final bool isSyncing;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onPowerToggle;
  final ValueChanged<double>? onHorizontalLevelDrag;

  const UniversalAnimatedGlassCard({
    super.key,
    required this.device,
    this.isSyncing = false,
    required this.onTap,
    required this.onLongPress,
    this.onPowerToggle,
    this.onHorizontalLevelDrag,
  });

  @override
  State<UniversalAnimatedGlassCard> createState() => _UniversalAnimatedGlassCardState();
}

class _UniversalAnimatedGlassCardState extends State<UniversalAnimatedGlassCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double? _dragPreview;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dev = widget.device;
    final archetype = UniversalCategoryClassifier.classify(dev);
    final tint = UniversalCategoryClassifier.colorFor(archetype);
    final canSlide = UniversalCategoryClassifier.supportsHorizontalSlider(archetype);
    final isClimate = archetype == UniversalDeviceArchetype.climateAc;
    final currentVal = _dragPreview ?? dev.primaryValue;
    final fillFraction = isClimate
        ? ((currentVal.clamp(16.0, 30.0) - 16.0) / 14.0)
        : (currentVal.clamp(0.0, 100.0) / 100.0);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onHorizontalDragUpdate: (!canSlide || widget.onHorizontalLevelDrag == null)
          ? null
          : (details) {
              final box = context.findRenderObject() as RenderBox?;
              if (box == null) return;
              final delta = details.primaryDelta! / box.size.width;
              setState(() {
                final base = _dragPreview ?? dev.primaryValue;
                _dragPreview = isClimate
                    ? (base + delta * 14.0).clamp(16.0, 30.0)
                    : (base + delta * 100.0).clamp(1.0, 100.0);
              });
              HapticFeedback.selectionClick();
            },
      onHorizontalDragEnd: (!canSlide || widget.onHorizontalLevelDrag == null)
          ? null
          : (_) {
              if (_dragPreview != null) {
                final val = _dragPreview!;
                setState(() => _dragPreview = null);
                widget.onHorizontalLevelDrag!(val);
              }
            },
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: GlassContainer(
          isActive: dev.isOn,
          activeTint: tint,
          padding: EdgeInsets.zero,
          child: Stack(
            children: [
              // 0. Active Animation Contrast Shield (Zero Color Bleed against Circadian Sky)
              if (dev.isOn)
                Positioned.fill(
                  child: Container(color: const Color(0x59040711)),
                ),

              // 1. Liquid Level Fill for Slidable Archetypes
              if (dev.isOn && canSlide)
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: fillFraction.clamp(0.06, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            tint.withValues(alpha: 0.28),
                            tint.withValues(alpha: 0.06),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // 2. 12-Archetype Procedural Background Canvas Animation with GPU RepaintBoundary
              if (dev.isOn)
                Positioned.fill(
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) => CustomPaint(
                        isComplex: true,
                        willChange: dev.isOn,
                        painter: _UniversalArchetypePainter(
                          archetype: archetype,
                          phase: _controller.value * 2 * math.pi,
                          level: currentVal,
                          tint: tint,
                        ),
                      ),
                    ),
                  ),
                ),

              // 3. Foreground Emblem & Live Status Telemetry
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            if (widget.onPowerToggle != null) {
                              widget.onPowerToggle!();
                            } else {
                              widget.onTap();
                            }
                          },
                          child: _buildDynamicEmblem(archetype, dev.isOn, tint),
                        ),
                        _buildStatusBadge(dev),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dev.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _formatArchetypeStatus(archetype, dev, currentVal),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: dev.isOn ? Colors.white : Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicEmblem(UniversalDeviceArchetype type, bool isOn, Color tint) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value * 2 * math.pi;
        double rotation = 0.0;
        double scale = 1.0;

        if (isOn) {
          if (type == UniversalDeviceArchetype.fanAir ||
              type == UniversalDeviceArchetype.laundry) {
            rotation = t;
          } else if (type == UniversalDeviceArchetype.robotVacuum) {
            rotation = math.sin(t) * 0.45;
          } else if (type == UniversalDeviceArchetype.speakerAudio ||
              type == UniversalDeviceArchetype.lighting) {
            scale = 1.0 + 0.09 * math.sin(t * 2);
          }
        }

        return Transform.scale(
          scale: scale,
          child: Transform.rotate(
            angle: rotation,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOn ? tint.withValues(alpha: 0.35) : Colors.white12,
                boxShadow: [
                  if (isOn)
                    BoxShadow(
                      color: tint.withValues(alpha: 0.65),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                ],
              ),
              child: Icon(
                type == UniversalDeviceArchetype.fanAir
                    ? Icons.wind_power_rounded
                    : UniversalCategoryClassifier.iconFor(type),
                color: Colors.white,
                size: 21,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(RealSmartDevice dev) {
    final isSync = widget.isSyncing;
    final color = isSync
        ? const Color(0xFFFF9F0A)
        : (dev.isOnline ? const Color(0xFF30D158) : const Color(0xFFFF453A));
    final text = isSync ? 'SYNCING' : (dev.isOnline ? 'LIVE' : 'OFFLINE');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.22),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  String _formatArchetypeStatus(
    UniversalDeviceArchetype type,
    RealSmartDevice dev,
    double val,
  ) {
    if (!dev.isOn) return '${dev.room} • Off';
    switch (type) {
      case UniversalDeviceArchetype.lighting:
        return '💡 Brightness ${val.round()}%';
      case UniversalDeviceArchetype.climateAc:
        return '❄️ Cooling • ${val.round()}°C';
      case UniversalDeviceArchetype.fanAir:
        return '🌀 Airflow Speed ${val.round()}%';
      case UniversalDeviceArchetype.laundry:
        return '🧺 ${dev.liveAttributes['machineState'] ?? 'Cycle Active'}';
      case UniversalDeviceArchetype.refrigeration:
        return '🧊 Chilling • 3°C / -18°C';
      case UniversalDeviceArchetype.tvMedia:
        return '📺 Media Active';
      case UniversalDeviceArchetype.speakerAudio:
        return '🎵 Volume ${val.round()}%';
      case UniversalDeviceArchetype.robotVacuum:
        return '🤖 LiDAR Cleaning';
      case UniversalDeviceArchetype.cameraSecurity:
        return '🔴 Live Guard Active';
      case UniversalDeviceArchetype.lockAccess:
        return '🔒 Secured & Locked';
      case UniversalDeviceArchetype.curtainShade:
        return '🪟 Open ${val.round()}%';
      case UniversalDeviceArchetype.plugEnergy:
        return '⚡ Power Flowing';
    }
  }
}

/// Renders all 12 procedural animations using GPU Canvas primitives
class _UniversalArchetypePainter extends CustomPainter {
  final UniversalDeviceArchetype archetype;
  final double phase;
  final double level;
  final Color tint;

  _UniversalArchetypePainter({
    required this.archetype,
    required this.phase,
    required this.level,
    required this.tint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (archetype) {
      case UniversalDeviceArchetype.lighting:
        _paintLightingBloom(canvas, size);
        break;
      case UniversalDeviceArchetype.climateAc:
        _paintClimateStreamlines(canvas, size);
        break;
      case UniversalDeviceArchetype.fanAir:
        _paintFanVortexRings(canvas, size);
        break;
      case UniversalDeviceArchetype.laundry:
        _paintLaundryWavesAndBubbles(canvas, size);
        break;
      case UniversalDeviceArchetype.refrigeration:
        _paintFridgeSnowflakes(canvas, size);
        break;
      case UniversalDeviceArchetype.tvMedia:
        _paintTvAmbilight(canvas, size);
        break;
      case UniversalDeviceArchetype.speakerAudio:
        _paintSpeakerEqualizerBars(canvas, size);
        break;
      case UniversalDeviceArchetype.robotVacuum:
        _paintVacuumLidarRadar(canvas, size);
        break;
      case UniversalDeviceArchetype.cameraSecurity:
        _paintCameraScanReticle(canvas, size);
        break;
      case UniversalDeviceArchetype.lockAccess:
        _paintLockSecurityShield(canvas, size);
        break;
      case UniversalDeviceArchetype.curtainShade:
        _paintCurtainSunbeams(canvas, size);
        break;
      case UniversalDeviceArchetype.plugEnergy:
        _paintElectricCurrentPulses(canvas, size);
        break;
    }
  }

  void _paintLightingBloom(Canvas canvas, Size size) {
    final radius = size.width * (0.48 + 0.08 * math.sin(phase));
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          tint.withValues(alpha: 0.42 * (level / 100.0).clamp(0.25, 1.0)),
          tint.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: const Offset(34, 34), radius: radius));
    canvas.drawCircle(const Offset(34, 34), radius, paint);
  }

  void _paintClimateStreamlines(Canvas canvas, Size size) {
    final p = Paint()
      ..color = tint.withValues(alpha: 0.26)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    for (int i = 0; i < 3; i++) {
      final path = Path();
      final y0 = size.height * (0.32 + i * 0.20);
      for (double x = 0; x <= size.width; x += 6) {
        final y = y0 + math.sin((x / size.width * 2 * math.pi) - phase + i) * 6;
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, p);
    }
  }

  void _paintFanVortexRings(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.72, size.height * 0.42);
    final p = Paint()
      ..color = tint.withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    for (int i = 0; i < 4; i++) {
      final startAngle = phase + (i * math.pi / 2);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: 14.0 + i * 9.0),
        startAngle,
        math.pi * 0.65,
        false,
        p,
      );
    }
  }

  void _paintLaundryWavesAndBubbles(Canvas canvas, Size size) {
    final path = Path()..moveTo(0, size.height);
    for (double x = 0; x <= size.width; x += 5) {
      final y = size.height * 0.68 +
          math.sin((x / size.width * 2 * math.pi) + phase) * 7 +
          math.cos((x / size.width * 4 * math.pi) - phase) * 4;
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, Paint()..color = tint.withValues(alpha: 0.22));

    final bubblePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (int i = 0; i < 6; i++) {
      final prog = ((phase / (2 * math.pi)) + i * 0.16) % 1.0;
      final bx = size.width * (0.18 + i * 0.13) + math.sin(phase + i) * 4;
      final by = size.height * (1.0 - prog * 0.82);
      canvas.drawCircle(Offset(bx, by), 2.5 + (i % 3) * 1.5, bubblePaint);
    }
  }

  void _paintFridgeSnowflakes(Canvas canvas, Size size) {
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.45);
    for (int i = 0; i < 8; i++) {
      final prog = ((phase / (2 * math.pi)) + i * 0.125) % 1.0;
      final x = size.width * (0.12 + (i * 0.11)) + math.sin(phase + i) * 4;
      final y = size.height * prog;
      canvas.drawCircle(Offset(x, y), 2.2, dot);
    }
  }

  void _paintTvAmbilight(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(size.width * 0.15, 0, size.width * 0.7, size.height * 0.45);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            tint.withValues(alpha: 0.32 + 0.10 * math.sin(phase)),
            tint.withValues(alpha: 0.0),
          ],
        ).createShader(rect),
    );
  }

  void _paintSpeakerEqualizerBars(Canvas canvas, Size size) {
    final barPaint = Paint()
      ..color = tint.withValues(alpha: 0.35)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.0;
    const barCount = 12;
    final spacing = size.width / (barCount + 2);
    for (int i = 1; i <= barCount; i++) {
      final x = i * spacing;
      final h = 8.0 + 22.0 * ((math.sin(phase * 2 + i * 0.7) + 1) / 2);
      canvas.drawLine(Offset(x, size.height - 6), Offset(x, size.height - 6 - h), barPaint);
    }
  }

  void _paintVacuumLidarRadar(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.75, size.height * 0.40);
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [tint.withValues(alpha: 0.0), tint.withValues(alpha: 0.40)],
        transform: GradientRotation(phase),
      ).createShader(Rect.fromCircle(center: center, radius: 42));
    canvas.drawCircle(center, 42, sweepPaint);
  }

  void _paintCameraScanReticle(Canvas canvas, Size size) {
    final scanX = size.width * (0.5 + 0.4 * math.sin(phase));
    canvas.drawLine(
      Offset(scanX, 0),
      Offset(scanX, size.height),
      Paint()
        ..color = tint.withValues(alpha: 0.30)
        ..strokeWidth = 1.5,
    );
  }

  void _paintLockSecurityShield(Canvas canvas, Size size) {
    const center = Offset(34, 34);
    for (int i = 1; i <= 2; i++) {
      final prog = ((phase / (2 * math.pi)) + i * 0.5) % 1.0;
      canvas.drawCircle(
        center,
        14 + prog * 36,
        Paint()
          ..color = tint.withValues(alpha: (1.0 - prog) * 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  void _paintCurtainSunbeams(Canvas canvas, Size size) {
    final openRatio = (level / 100.0).clamp(0.1, 1.0);
    const slatCount = 5;
    final p = Paint()
      ..color = tint.withValues(alpha: 0.22)
      ..strokeWidth = 2.0;
    for (int i = 1; i <= slatCount; i++) {
      final y = (size.height * 0.65 * openRatio) * (i / slatCount);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  void _paintElectricCurrentPulses(Canvas canvas, Size size) {
    final path = Path();
    final midY = size.height * 0.52;
    for (double x = 0; x <= size.width; x += 8) {
      final spike = math.sin((x / 18.0) - phase * 2) * 8;
      if (x == 0) {
        path.moveTo(x, midY + spike);
      } else {
        path.lineTo(x, midY + spike);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = tint.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
  }

  @override
  bool shouldRepaint(covariant _UniversalArchetypePainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.level != level;
}
