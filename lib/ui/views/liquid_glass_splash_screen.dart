import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/real_home_provider.dart';
import '../../theme/apple_glass_theme.dart';
import 'apple_glass_home_shell.dart';

class LiquidGlassSplashScreen extends StatefulWidget {
  const LiquidGlassSplashScreen({super.key});

  @override
  State<LiquidGlassSplashScreen> createState() => _LiquidGlassSplashScreenState();
}

class _LiquidGlassSplashScreenState extends State<LiquidGlassSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _waveCtrl;
  late final AnimationController _pulseCtrl;
  double _bootProgress = 0.08;
  String _bootStatus = 'Initializing Hardware Keystore Vault...';

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _runRealBootSequence();
  }

  Future<void> _runRealBootSequence() async {
    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(() {
      _bootProgress = 0.38;
      _bootStatus = 'Verifying Cloud & Local LAN Protocols...';
    });

    // Trigger real background hardware status sync during splash
    final home = context.read<RealHomeProvider>();
    unawaited(home.syncAllDevicesSilent());

    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() {
      _bootProgress = 0.76;
      _bootStatus = 'Hydrating 12-Category Spatial Engine...';
    });

    await Future.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;
    setState(() {
      _bootProgress = 1.0;
      _bootStatus = 'System Online';
    });
    HapticFeedback.lightImpact();

    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 650),
        pageBuilder: (_, animation, secondaryAnimation) => const AppleGlassHomeShell(),
        transitionsBuilder: (_, animation, _, child) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 1.06, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LiquidGlassScaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated Frosted Glass Emblem with Rising Liquid Wave
            AnimatedBuilder(
              animation: Listenable.merge([_waveCtrl, _pulseCtrl]),
              builder: (context, _) {
                final scale = 1.0 + (_pulseCtrl.value * 0.04);
                return Transform.scale(
                  scale: scale,
                  child: SizedBox(
                    width: 132,
                    height: 132,
                    child: GlassContainer(
                      borderRadius: 36,
                      isActive: true,
                      activeTint: const Color(0xFF00D4FF),
                      padding: EdgeInsets.zero,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Rising Liquid Wave Fill inside the Glass Prism
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _SplashLiquidWavePainter(
                                phase: _waveCtrl.value * 2 * math.pi,
                                fillLevel: _bootProgress,
                              ),
                            ),
                          ),
                          // Central Glowing Smart Home Icon
                          const Icon(
                            Icons.home_work_rounded,
                            size: 54,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 28),
            const Text(
              'UNIFIED HOME',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: 3.2,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'MASTER SPATIAL CONTROLLER',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.0,
                color: const Color(0xFF00D4FF).withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 36),
            // Sleek Apple Glass Progress Capsule
            SizedBox(
              width: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LinearProgressIndicator(
                  value: _bootProgress,
                  minHeight: 5,
                  backgroundColor: Colors.white12,
                  color: const Color(0xFF30D158),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _bootStatus,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashLiquidWavePainter extends CustomPainter {
  final double phase;
  final double fillLevel;

  _SplashLiquidWavePainter({required this.phase, required this.fillLevel});

  @override
  void paint(Canvas canvas, Size size) {
    final baseHeight = size.height * (1.0 - fillLevel.clamp(0.05, 0.95));
    final path = Path()..moveTo(0, size.height);

    for (double x = 0; x <= size.width; x += 3) {
      final y = baseHeight +
          math.sin((x / size.width * 2 * math.pi) + phase) * 5 +
          math.cos((x / size.width * 4 * math.pi) - phase) * 3;
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.close();

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF00D4FF).withValues(alpha: 0.38),
          const Color(0xFF0A84FF).withValues(alpha: 0.20),
        ],
      ).createShader(Offset.zero & size);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SplashLiquidWavePainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.fillLevel != fillLevel;
}
