import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../services/real_iot_controller.dart';
import '../../../theme/apple_glass_theme.dart';

class AnimatedPowerFlowCard extends StatefulWidget {
  final List<RealSmartDevice> devices;

  const AnimatedPowerFlowCard({super.key, required this.devices});

  @override
  State<AnimatedPowerFlowCard> createState() => _AnimatedPowerFlowCardState();
}

class _AnimatedPowerFlowCardState extends State<AnimatedPowerFlowCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flowCtrl;
  bool _aiEcoMode = true;

  @override
  void initState() {
    super.initState();
    _flowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _flowCtrl.dispose();
    super.dispose();
  }

  // Bug 39 fix: Read d.liveWatts directly without calling
  // computeDeviceLiveWattage during build(), which would mutate device
  // state (d.liveWatts, d.liveAttributes) 60 times per second.
  double _getDeviceWatts(RealSmartDevice d) {
    return d.isOnline ? d.liveWatts : 0.0;
  }

  double get _totalWatts =>
      widget.devices.fold<double>(0.0, (sum, d) => sum + _getDeviceWatts(d));

  double get _hvacWatts => widget.devices
      .where((d) => d.category == 'ac' || d.category == 'washer')
      .fold<double>(0.0, (sum, d) => sum + _getDeviceWatts(d));

  double get _lightingMediaWatts => widget.devices
      .where((d) => d.category != 'ac' && d.category != 'washer')
      .fold<double>(0.0, (sum, d) => sum + _getDeviceWatts(d));

  int get _activeDrawingCount =>
      widget.devices.where((d) => d.isOnline && _getDeviceWatts(d) > 1.5).length;

  @override
  Widget build(BuildContext context) {
    final rawWatts = _totalWatts;
    final totalWatts = _aiEcoMode ? (rawWatts * 0.85) : rawWatts;
    final hvacWatts = _aiEcoMode ? (_hvacWatts * 0.85) : _hvacWatts;
    final lightMediaWatts = _lightingMediaWatts;

    final kw = totalWatts / 1000.0;
    final hour = DateTime.now().hour;
    final isPeak = hour >= 18 && hour <= 22;
    final rateInr = isPeak ? 8.50 : 5.80;
    final costPerHourInr = kw * rateInr;

    return GlassContainer(
      borderRadius: 28,
      isActive: totalWatts > 100,
      activeTint: const Color(0xFF30D158),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header with Live Metric & AI Eco Filter Chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LIVE POWER TOPOLOGY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: Color(0xFF30D158),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${totalWatts.round()} W  •  ₹${costPerHourInr.toStringAsFixed(2)}/hr',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('AI Energy (-15%)'),
                selected: _aiEcoMode,
                onSelected: (v) => setState(() => _aiEcoMode = v),
                selectedColor: const Color(0xFF30D158).withValues(alpha: 0.30),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Real-Time Mini Bento Metrics Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildBentoMetric(
                    'GRID DRAW',
                    '${totalWatts.toStringAsFixed(1)} W',
                    const Color(0xFF30D158),
                  ),
                ),
                Container(width: 1, height: 22, color: Colors.white12),
                Expanded(
                  child: _buildBentoMetric(
                    '24H EST.',
                    '${((totalWatts * 24) / 1000).toStringAsFixed(2)} kWh',
                    const Color(0xFF00D4FF),
                  ),
                ),
                Container(width: 1, height: 22, color: Colors.white12),
                Expanded(
                  child: _buildBentoMetric(
                    'TARIFF',
                    '₹${rateInr.toStringAsFixed(2)}/u',
                    isPeak ? const Color(0xFFFF9F0A) : const Color(0xFF5AC8FA),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3. Tesla-Style Animated Topology Canvas
          SizedBox(
            height: 145,
            width: double.infinity,
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _flowCtrl,
                builder: (context, _) => CustomPaint(
                  isComplex: true,
                  willChange: true,
                  painter: _TeslaPowerTopologyPainter(
                    totalWatts: totalWatts,
                    hvacWatts: hvacWatts,
                    lightingMediaWatts: lightMediaWatts,
                    onlineCount: widget.devices.where((d) => d.isOnline).length,
                    totalCount: widget.devices.length,
                    progress: _flowCtrl.value,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 4. Live Per-Appliance Telemetry List
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'APPLIANCE TELEMETRY',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: Colors.white70,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF30D158).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF30D158).withValues(alpha: 0.35)),
                ),
                child: Text(
                  '$_activeDrawingCount ACTIVE',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF30D158),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (widget.devices.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'No appliances paired. Tap + Add Device to connect.',
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.45)),
                ),
              ),
            )
          else
            ...widget.devices.map((dev) => _buildApplianceTelemetryRow(dev, isPeak, rateInr)),

          const SizedBox(height: 10),
          // 5. Utility Tariff Window Footer
          Text(
            isPeak
                ? '⚠️ Peak Utility Window (₹8.50/kWh) • AI Eco Curtailed Heavy Compressors'
                : '✅ Off-Peak Window (₹5.80/kWh) • Optimal Time for Samsung Laundry Cycle',
            style: const TextStyle(fontSize: 11.5, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildBentoMetric(String label, String value, Color tint) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 8.5,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 1.5),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: tint),
          ),
        ),
      ],
    );
  }

  Widget _buildApplianceTelemetryRow(RealSmartDevice dev, bool isPeak, double rateInr) {
    final watts = _getDeviceWatts(dev);
    final isDrawing = dev.isOnline && watts > 1.5;
    final kwh24h = (watts * 24) / 1000.0;
    final cost24h = kwh24h * rateInr;
    final powerSource = dev.liveAttributes['powerSource']?.toString() ??
        (dev.isOnline ? (dev.isOn ? 'Active Telemetry' : 'Standby Draw') : 'Offline (0.0 W)');

    IconData icon;
    Color iconTint;
    switch (dev.category) {
      case 'washer':
        icon = Icons.local_laundry_service_rounded;
        iconTint = const Color(0xFF0A84FF);
        break;
      case 'ac':
        icon = Icons.ac_unit_rounded;
        iconTint = const Color(0xFF00D4FF);
        break;
      case 'tv':
        icon = Icons.tv_rounded;
        iconTint = const Color(0xFFBF5AF2);
        break;
      case 'light':
        icon = Icons.lightbulb_rounded;
        iconTint = const Color(0xFFFF9F0A);
        break;
      default:
        icon = Icons.power_rounded;
        iconTint = const Color(0xFF30D158);
    }

    if (!dev.isOnline) {
      iconTint = Colors.white24;
    } else if (!dev.isOn) {
      iconTint = iconTint.withValues(alpha: 0.50);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: dev.isOn ? 0.07 : 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: dev.isOn
              ? iconTint.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconTint.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: iconTint),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dev.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 1.5),
                Text(
                  '${dev.room} • $powerSource',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.60)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: !dev.isOnline
                          ? Colors.white12
                          : (dev.isOn ? const Color(0xFF30D158).withValues(alpha: 0.20) : const Color(0xFFFF9F0A).withValues(alpha: 0.20)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      !dev.isOnline ? 'OFFLINE' : (dev.isOn ? 'ACTIVE' : 'STANDBY'),
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: !dev.isOnline
                            ? Colors.white38
                            : (dev.isOn ? const Color(0xFF30D158) : const Color(0xFFFF9F0A)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${dev.isOnline ? watts.toStringAsFixed(1) : "0.0"} W',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isDrawing ? Colors.white : Colors.white60,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 1.5),
              Text(
                '${kwh24h.toStringAsFixed(2)} kWh/d • ₹${cost24h.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 9.5, color: Colors.white.withValues(alpha: 0.45)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TeslaPowerTopologyPainter extends CustomPainter {
  final double totalWatts;
  final double hvacWatts;
  final double lightingMediaWatts;
  final int onlineCount;
  final int totalCount;
  final double progress;

  _TeslaPowerTopologyPainter({
    required this.totalWatts,
    required this.hvacWatts,
    required this.lightingMediaWatts,
    required this.onlineCount,
    required this.totalCount,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final topNode = Offset(size.width * 0.50, 22);
    final centerNode = Offset(size.width * 0.50, size.height * 0.52);
    final leftNode = Offset(size.width * 0.22, size.height - 24);
    final rightNode = Offset(size.width * 0.78, size.height - 24);

    final isFlowing = totalWatts > 0;

    // 1. Spline 1: Top (Main Grid) -> Center (Smart Home Bus)
    final pathTop = Path()
      ..moveTo(topNode.dx, topNode.dy)
      ..cubicTo(
        topNode.dx,
        topNode.dy + (centerNode.dy - topNode.dy) * 0.5,
        centerNode.dx,
        topNode.dy + (centerNode.dy - topNode.dy) * 0.5,
        centerNode.dx,
        centerNode.dy,
      );

    canvas.drawPath(
      pathTop,
      Paint()
        ..color = isFlowing
            ? const Color(0xFF30D158).withValues(alpha: 0.45)
            : Colors.white12
        ..style = PaintingStyle.stroke
        ..strokeWidth = isFlowing ? 2.5 : 1.5,
    );

    // 2. Spline 2: Center -> Left (Heavy Appliances: Washer & AC)
    final pathLeft = Path()
      ..moveTo(centerNode.dx, centerNode.dy)
      ..cubicTo(
        centerNode.dx - 30,
        centerNode.dy + 15,
        leftNode.dx + 25,
        leftNode.dy - 15,
        leftNode.dx,
        leftNode.dy,
      );

    canvas.drawPath(
      pathLeft,
      Paint()
        ..color = hvacWatts > 0
            ? const Color(0xFF00D4FF).withValues(alpha: 0.45)
            : Colors.white12
        ..style = PaintingStyle.stroke
        ..strokeWidth = hvacWatts > 0 ? 2.2 : 1.5,
    );

    // 3. Spline 3: Center -> Right (Lighting & Media)
    final pathRight = Path()
      ..moveTo(centerNode.dx, centerNode.dy)
      ..cubicTo(
        centerNode.dx + 30,
        centerNode.dy + 15,
        rightNode.dx - 25,
        rightNode.dy - 15,
        rightNode.dx,
        rightNode.dy,
      );

    canvas.drawPath(
      pathRight,
      Paint()
        ..color = lightingMediaWatts > 0
            ? const Color(0xFFBF5AF2).withValues(alpha: 0.45)
            : Colors.white12
        ..style = PaintingStyle.stroke
        ..strokeWidth = lightingMediaWatts > 0 ? 2.2 : 1.5,
    );

    // 4. Flowing Energy Particles (Velocity scaled by totalLiveWatts)
    if (isFlowing) {
      _drawParticlesOnPath(canvas, pathTop, progress, 4, const Color(0xFF30D158));

      if (hvacWatts > 0) {
        _drawParticlesOnPath(canvas, pathLeft, progress, 3, const Color(0xFF00D4FF));
      }
      if (lightingMediaWatts > 0) {
        _drawParticlesOnPath(canvas, pathRight, progress, 3, const Color(0xFFBF5AF2));
      }
    }

    // 5. Render Node Halos and Core Rings
    _drawNode(
      canvas,
      topNode,
      const Color(0xFF30D158),
      'MAIN GRID',
      '${totalWatts.round()} W',
      pulsing: isFlowing,
    );

    _drawNode(
      canvas,
      centerNode,
      const Color(0xFF0A84FF),
      'SMART BUS',
      '$onlineCount/$totalCount ONLINE',
      radius: 14,
    );

    _drawNode(
      canvas,
      leftNode,
      hvacWatts > 0 ? const Color(0xFF00D4FF) : Colors.white30,
      'HVAC / LAUNDRY',
      '${hvacWatts.round()} W',
      radius: 13,
    );

    _drawNode(
      canvas,
      rightNode,
      lightingMediaWatts > 0 ? const Color(0xFFBF5AF2) : Colors.white30,
      'LIGHTS / MEDIA',
      '${lightingMediaWatts.round()} W',
      radius: 13,
    );
  }

  void _drawParticlesOnPath(
    Canvas canvas,
    Path path,
    double progress,
    int count,
    Color particleColor,
  ) {
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;

    for (int p = 0; p < count; p++) {
      final t = (progress + (p / count)) % 1.0;
      final tangent = metric.getTangentForOffset(metric.length * t);
      if (tangent != null) {
        // Outer soft glow
        canvas.drawCircle(
          tangent.position,
          5.5,
          Paint()..color = particleColor.withValues(alpha: 0.25),
        );
        // Inner intense core
        canvas.drawCircle(
          tangent.position,
          2.6,
          Paint()..color = Colors.white,
        );
      }
    }
  }

  void _drawNode(
    Canvas canvas,
    Offset center,
    Color tint,
    String label,
    String sublabel, {
    double radius = 15,
    bool pulsing = false,
  }) {
    final pulseScale = pulsing ? (1.0 + 0.15 * math.sin(progress * 2 * math.pi)) : 1.0;

    // Soft Ambient Glow
    canvas.drawCircle(
      center,
      radius * 1.8 * pulseScale,
      Paint()..color = tint.withValues(alpha: 0.18),
    );

    // Inner Shell
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF0B1220)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = tint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Core Dot
    canvas.drawCircle(
      center,
      4.0,
      Paint()..color = tint,
    );

    // Text Badges
    final textPainter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label\n',
            style: TextStyle(
              fontSize: 7.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: tint.withValues(alpha: 0.90),
            ),
          ),
          TextSpan(
            text: sublabel,
            style: const TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    final isTop = center.dy < 40;
    final textOffset = Offset(
      center.dx - (textPainter.width / 2),
      isTop ? center.dy + radius + 4 : center.dy - radius - textPainter.height - 3,
    );
    textPainter.paint(canvas, textOffset);
  }

  @override
  bool shouldRepaint(covariant _TeslaPowerTopologyPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.totalWatts != totalWatts ||
      oldDelegate.hvacWatts != hvacWatts ||
      oldDelegate.lightingMediaWatts != lightingMediaWatts;
}
