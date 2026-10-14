import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/real_home_provider.dart';
import 'apple_glass_home_shell.dart';

class LiquidGlassSplashScreen extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const LiquidGlassSplashScreen({
    super.key,
    this.child = const AppleGlassHomeShell(),
    this.duration = const Duration(milliseconds: 2800),
  });

  @override
  State<LiquidGlassSplashScreen> createState() =>
      _LiquidGlassSplashScreenState();
}

class _LiquidGlassSplashScreenState extends State<LiquidGlassSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _completed = false;
  bool _ignitedHapticSent = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);

    // Initial soft haptic thrum on launch
    HapticFeedback.selectionClick();

    // Trigger background hardware sync during splash if provider exists
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final home = context.read<RealHomeProvider?>();
        home?.syncAllDevicesSilent();
      } catch (_) {}
    });

    _ctrl.addListener(() {
      if (_ctrl.value >= 0.42 && !_ignitedHapticSent) {
        _ignitedHapticSent = true;
        HapticFeedback.lightImpact(); // Fires right as the 3D rooms ignite
      }
    });

    _ctrl.forward().whenComplete(() {
      if (mounted) {
        setState(() => _completed = true);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_completed) return widget.child;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Underlying live dashboard pre-warmed and ready
        widget.child,

        // Animated 3D Spatial Splash Overlay with Portal Zoom & Liquid Wave Exit
        AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final t = _ctrl.value;

            // Stage 4 portal zoom & fade out (0.80 -> 1.00)
            final exitT = ((t - 0.80) / 0.20).clamp(0.0, 1.0);
            final exitCurve = Curves.easeInCubic.transform(exitT);
            final portalScale = 1.0 + (exitCurve * 2.35);
            final overlayOpacity = (1.0 - exitCurve).clamp(0.0, 1.0);

            // Sub-stage curves
            final blueprintT =
                Curves.easeOutCubic.transform(((t - 0.05) / 0.35).clamp(0.0, 1.0));
            final extrudeT =
                Curves.easeOutBack.transform(((t - 0.22) / 0.38).clamp(0.0, 1.0));
            final roomGlowT =
                Curves.easeInOut.transform(((t - 0.38) / 0.30).clamp(0.0, 1.0));
            final sheenT = ((t - 0.48) / 0.32).clamp(0.0, 1.0);
            final textT =
                Curves.easeOutCubic.transform(((t - 0.36) / 0.32).clamp(0.0, 1.0));

            return IgnorePointer(
              ignoring: t > 0.78,
              child: Opacity(
                opacity: overlayOpacity,
                child: ClipPath(
                  clipper: _LiquidIrisPortalClipper(exitProgress: exitCurve),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(0.0, -0.12),
                        radius: 1.15,
                        colors: [
                          Color(0xFF172246),
                          Color(0xFF0A1022),
                          Color(0xFF040710),
                        ],
                      ),
                    ),
                    child: Transform.scale(
                      scale: portalScale,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // 1. Converging Quantum Light Particles & Ambient Aura
                          CustomPaint(
                            size: MediaQuery.of(context).size,
                            painter: _SplashParticleFieldPainter(progress: t),
                          ),

                          // 2. Center 3D Glass Squircle + Extruding Isometric House
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 190,
                                height: 190,
                                child: CustomPaint(
                                  painter: _Isometric3DSplashLogoPainter(
                                    blueprintProgress: blueprintT,
                                    extrudeProgress: extrudeT,
                                    roomGlowProgress: roomGlowT,
                                    sheenProgress: sheenT,
                                    orbitAngle: t * 0.35,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),

                              // 3. Staggered Specular Typography
                              Opacity(
                                opacity: textT,
                                child: Transform.translate(
                                  offset: Offset(0, (1.0 - textT) * 18),
                                  child: Column(
                                    children: [
                                      ShaderMask(
                                        shaderCallback: (bounds) =>
                                            LinearGradient(
                                          begin: Alignment(-1.0 + sheenT * 3.0, -0.5),
                                          end: Alignment(-0.2 + sheenT * 3.0, 0.5),
                                          colors: const [
                                            Colors.white,
                                            Color(0xFFFFD580),
                                            Color(0xFF00D4FF),
                                            Colors.white,
                                          ],
                                        ).createShader(bounds),
                                        child: const Text(
                                          'UNIFIED HOME',
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 4.5,
                                            color: Colors.white,
                                            decoration: TextDecoration.none,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '3D SPATIAL SMART CONTROLLER',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 2.8,
                                          color: const Color(0xFF00D4FF)
                                              .withValues(alpha: 0.85),
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                      const SizedBox(height: 22),
                                      // Sleek Liquid Progress Pill
                                      Container(
                                        width: 140,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: Colors.white12,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        alignment: Alignment.centerLeft,
                                        child: FractionallySizedBox(
                                          widthFactor: (t / 0.82).clamp(0.0, 1.0),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFFFF9F0A),
                                                  Color(0xFF00D4FF),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Isometric3DSplashLogoPainter extends CustomPainter {
  final double blueprintProgress;
  final double extrudeProgress;
  final double roomGlowProgress;
  final double sheenProgress;
  final double orbitAngle;

  _Isometric3DSplashLogoPainter({
    required this.blueprintProgress,
    required this.extrudeProgress,
    required this.roomGlowProgress,
    required this.sheenProgress,
    required this.orbitAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 12);
    final radius = size.width * 0.42;

    // 1. Warm Amber + Cyan Dual Volumetric Halo Behind Squircle
    if (roomGlowProgress > 0) {
      final haloPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFF9F0A).withValues(alpha: 0.42 * roomGlowProgress),
            const Color(0xFF00D4FF).withValues(alpha: 0.22 * roomGlowProgress),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 1.45));
      canvas.drawCircle(center, radius * 1.45, haloPaint);
    }

    // 2. Frosted Apple Glass Squircle Container
    final squircleRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width * 0.82,
        height: size.height * 0.82,
      ),
      const Radius.circular(38),
    );
    canvas.drawRRect(
      squircleRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x38FFFFFF), Color(0x0DFFFFFF)],
        ).createShader(squircleRect.outerRect),
    );
    canvas.drawRRect(
      squircleRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..shader = LinearGradient(
          begin: Alignment(-1.0 + sheenProgress * 2.5, -1.0),
          end: Alignment(0.2 + sheenProgress * 2.5, 1.0),
          colors: const [
            Color(0x44FFFFFF),
            Color(0xFFFFFFFF),
            Color(0x5500D4FF),
            Color(0x22FFFFFF),
          ],
        ).createShader(squircleRect.outerRect),
    );

    // Helper for 3D Isometric projection
    Offset iso(double x, double y, double z) {
      final yaw = -0.7854 + math.sin(orbitAngle) * 0.12; // ~45 deg isometric with gentle float
      final rx = x * math.cos(yaw) - y * math.sin(yaw);
      final ry = x * math.sin(yaw) + y * math.cos(yaw);
      final sx = center.dx + rx * 0.866;
      final sy = center.dy + ry * 0.5 - z;
      return Offset(sx, sy);
    }

    final double r = size.width * 0.25 * blueprintProgress;
    final double wallH = (size.height * 0.22) * extrudeProgress.clamp(0.0, 1.2);

    // Base Floor Corners
    final pFront = iso(r, r, 0);
    final pRight = iso(r, -r, 0);
    final pBack = iso(-r, -r, 0);
    final pLeft = iso(-r, r, 0);

    // Extruded Roof Corners
    final tFront = iso(r, r, wallH);
    final tRight = iso(r, -r, wallH);
    final tBack = iso(-r, -r, wallH);
    final tLeft = iso(-r, r, wallH);

    // 3. Draw Glowing Dollhouse Floor Plan (Living, Bedroom, Kitchen)
    final floorPath = Path()
      ..moveTo(pFront.dx, pFront.dy)
      ..lineTo(pRight.dx, pRight.dy)
      ..lineTo(pBack.dx, pBack.dy)
      ..lineTo(pLeft.dx, pLeft.dy)
      ..close();

    canvas.drawPath(
      floorPath,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Color.lerp(const Color(0xFF1E293B), const Color(0xFFFFB340),
                roomGlowProgress * 0.85)!,
            Color.lerp(const Color(0xFF0F172A), const Color(0xFF00D4FF),
                roomGlowProgress * 0.55)!,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: r * 1.5)),
    );

    // 4. Extruded Left Cutaway Wall (Warm Tungsten Smart Lighting Glow)
    if (extrudeProgress > 0.01) {
      final leftWall = Path()
        ..moveTo(pLeft.dx, pLeft.dy)
        ..lineTo(pFront.dx, pFront.dy)
        ..lineTo(tFront.dx, tFront.dy)
        ..lineTo(tLeft.dx, tLeft.dy)
        ..close();
      canvas.drawPath(
        leftWall,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFFFB340).withValues(alpha: 0.35 + 0.55 * roomGlowProgress),
              const Color(0xFFFF6B00).withValues(alpha: 0.25 + 0.55 * roomGlowProgress),
            ],
          ).createShader(squircleRect.outerRect),
      );

      // Extruded Right Cutaway Wall (Cool Climate Cyan Glass)
      final rightWall = Path()
        ..moveTo(pFront.dx, pFront.dy)
        ..lineTo(pRight.dx, pRight.dy)
        ..lineTo(tRight.dx, tRight.dy)
        ..lineTo(tFront.dx, tFront.dy)
        ..close();
      canvas.drawPath(
        rightWall,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF00D4FF).withValues(alpha: 0.30 + 0.45 * roomGlowProgress),
              const Color(0xFF1E3A8A).withValues(alpha: 0.65),
            ],
          ).createShader(squircleRect.outerRect),
      );

      // Top Translucent Glass Roof Prism
      final roofPath = Path()
        ..moveTo(tFront.dx, tFront.dy)
        ..lineTo(tRight.dx, tRight.dy)
        ..lineTo(tBack.dx, tBack.dy)
        ..lineTo(tLeft.dx, tLeft.dy)
        ..close();
      canvas.drawPath(
        roofPath,
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.42),
              const Color(0xFF64D2FF).withValues(alpha: 0.22),
            ],
          ).createShader(squircleRect.outerRect),
      );

      // Interior Room Divider Walls (3D Dollhouse Cutaway Effect)
      final mid1Base = iso(0, r * 0.2, 0);
      final mid1Top = iso(0, r * 0.2, wallH * 0.78);
      final dividerPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.75 * extrudeProgress)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(iso(-r, r * 0.2, wallH * 0.78), mid1Top, dividerPaint);
      canvas.drawLine(iso(0, -r, wallH * 0.78), mid1Top, dividerPaint);
      canvas.drawLine(mid1Base, mid1Top, dividerPaint);
    }

    // 5. Crisp Specular Wireframe Edges
    final edgePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9 * blueprintProgress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(floorPath, edgePaint);
    if (extrudeProgress > 0.02) {
      final roofOutline = Path()
        ..moveTo(tFront.dx, tFront.dy)
        ..lineTo(tRight.dx, tRight.dy)
        ..lineTo(tBack.dx, tBack.dy)
        ..lineTo(tLeft.dx, tLeft.dy)
        ..close();
      canvas.drawPath(roofOutline, edgePaint);
      canvas.drawLine(pFront, tFront, edgePaint);
      canvas.drawLine(pRight, tRight, edgePaint);
      canvas.drawLine(pLeft, tLeft, edgePaint);
      canvas.drawLine(pBack, tBack, edgePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _Isometric3DSplashLogoPainter oldDelegate) => true;
}

class _SplashParticleFieldPainter extends CustomPainter {
  final double progress;
  _SplashParticleFieldPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 20);
    final maxR = size.longestSide * 0.55;

    for (int i = 0; i < 28; i++) {
      final seed = i * 1.37;
      // Particles spiral inward during 0..0.45, then orbit gently
      final collapse = (1.0 - (progress / 0.48).clamp(0.0, 1.0));
      final dist = 65.0 + (collapse * maxR * ((i % 5 + 1) / 5.0));
      final angle = seed + progress * (i.isEven ? 3.2 : -2.6);
      final pos = Offset(
        center.dx + math.cos(angle) * dist,
        center.dy + math.sin(angle) * dist * 0.75,
      );

      final isWarm = i % 2 == 0;
      final color = isWarm ? const Color(0xFFFFB340) : const Color(0xFF00D4FF);
      final paint = Paint()
        ..color = color.withValues(alpha: (0.18 + (1.0 - collapse) * 0.45).clamp(0.0, 0.75))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

      canvas.drawCircle(pos, (i % 3 + 1.8), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SplashParticleFieldPainter oldDelegate) => true;
}

class _LiquidIrisPortalClipper extends CustomClipper<Path> {
  final double exitProgress;
  _LiquidIrisPortalClipper({required this.exitProgress});

  @override
  Path getClip(Size size) {
    final full = Path()..addRect(Offset.zero & size);
    if (exitProgress <= 0.01) return full;

    final center = Offset(size.width / 2, size.height / 2 - 20);
    final maxRadius = size.longestSide * 1.1;
    final holeRadius = exitProgress * maxRadius;

    final hole = Path();
    const int points = 64;
    for (int i = 0; i <= points; i++) {
      final theta = (i / points) * 2 * math.pi;
      // Organic liquid wave ripple along the expanding portal edge
      final wave = math.sin(theta * 6 + exitProgress * 12) * 14.0 * (1.0 - exitProgress);
      final r = (holeRadius + wave).clamp(0.0, maxRadius * 1.2);
      final pt = Offset(center.dx + math.cos(theta) * r, center.dy + math.sin(theta) * r);
      if (i == 0) {
        hole.moveTo(pt.dx, pt.dy);
      } else {
        hole.lineTo(pt.dx, pt.dy);
      }
    }
    hole.close();

    return Path.combine(PathOperation.difference, full, hole);
  }

  @override
  bool shouldReclip(covariant _LiquidIrisPortalClipper oldClipper) =>
      oldClipper.exitProgress != exitProgress;
}
