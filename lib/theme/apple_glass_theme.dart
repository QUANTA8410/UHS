import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

class AppleGlassTheme {
  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: const Color(0xFF070C18),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xE6101935),
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0x44FFFFFF), width: 1.1),
        ),
      ),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF0A84FF),   // iOS System Blue
        secondary: Color(0xFF30D158), // iOS System Green
        tertiary: Color(0xFFFF9F0A),  // HomeKit Warm Gold
        error: Color(0xFFFF453A),     // iOS System Red
        surface: Colors.transparent,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.7,
          color: Colors.white,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          color: Colors.white,
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: Color(0xB3FFFFFF),
        ),
      ),
    );
  }
}

/// Animated Apple visionOS Mesh Wallpaper that refracts through all glass cards
class LiquidGlassScaffold extends StatefulWidget {
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? appBar;

  const LiquidGlassScaffold({
    super.key,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.appBar,
  });

  @override
  State<LiquidGlassScaffold> createState() => _LiquidGlassScaffoldState();
}

class CircadianSkyPalette {
  final List<Color> backgroundGradient;
  final Color orb1;
  final Color orb2;
  final Color orb3;

  const CircadianSkyPalette({
    required this.backgroundGradient,
    required this.orb1,
    required this.orb2,
    required this.orb3,
  });
}

class _LiquidGlassScaffoldState extends State<LiquidGlassScaffold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _orbController;

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _orbController.dispose();
    super.dispose();
  }

  CircadianSkyPalette _getCircadianPalette() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour <= 8) {
      // Dawn (5..8): Deep Rose/Amber
      return const CircadianSkyPalette(
        backgroundGradient: [
          Color(0xFF1F1124),
          Color(0xFF261327),
          Color(0xFF2E1C2B),
          Color(0xFF150B1B),
        ],
        orb1: Color(0xFFFF9F0A),
        orb2: Color(0xFFFF375F),
        orb3: Color(0xFFFF7A00),
      );
    } else if (hour >= 9 && hour <= 16) {
      // Daylight (9..16): Deep Cerulean Sky
      return const CircadianSkyPalette(
        backgroundGradient: [
          Color(0xFF07162C),
          Color(0xFF0B213D),
          Color(0xFF0E2A47),
          Color(0xFF05101E),
        ],
        orb1: Color(0xFF0A84FF),
        orb2: Color(0xFF5AC8FA),
        orb3: Color(0xFF00C7BE),
      );
    } else if (hour >= 17 && hour <= 19) {
      // Golden Hour (17..19): Sunset Horizon
      return const CircadianSkyPalette(
        backgroundGradient: [
          Color(0xFF1B0E26),
          Color(0xFF231024),
          Color(0xFF2B1222),
          Color(0xFF13091B),
        ],
        orb1: Color(0xFFFF6B00),
        orb2: Color(0xFFBF5AF2),
        orb3: Color(0xFFFF2D55),
      );
    } else {
      // Midnight (20..4): Deep Titanium Obsidian
      return const CircadianSkyPalette(
        backgroundGradient: [
          Color(0xFF05070E),
          Color(0xFF0B1020),
          Color(0xFF0E152B),
          Color(0xFF04060B),
        ],
        orb1: Color(0xFF0A84FF),
        orb2: Color(0xFF30D158),
        orb3: Color(0xFF5E5CE6),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = _getCircadianPalette();

    return Stack(
      children: [
        // Base Deep Titanium / Circadian Space Gradient (covers entire viewport)
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: palette.backgroundGradient,
              ),
            ),
          ),
        ),
        // 120 FPS GPU Repaint Isolation: wrap drifting ambient orbs in RepaintBoundary & cap opacity <= 0.24
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _orbController,
              builder: (context, _) {
                final t = _orbController.value;
                return Stack(
                  children: [
                    Positioned(
                      top: -60 + (math.sin(t * math.pi * 2) * 40),
                      left: -40 + (math.cos(t * math.pi * 2) * 35),
                      child: _BlurLightOrb(
                        color: palette.orb1.withValues(alpha: 0.24),
                        size: 320,
                      ),
                    ),
                    Positioned(
                      top: 260 - (math.cos(t * math.pi * 2) * 50),
                      right: -70 + (math.sin(t * math.pi * 2) * 40),
                      child: _BlurLightOrb(
                        color: palette.orb2.withValues(alpha: 0.22),
                        size: 300,
                      ),
                    ),
                    Positioned(
                      bottom: 90 + (math.sin(t * math.pi) * 30),
                      left: 50,
                      child: _BlurLightOrb(
                        color: palette.orb3.withValues(alpha: 0.18),
                        size: 260,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          resizeToAvoidBottomInset: false,
          appBar: widget.appBar,
          body: SafeArea(bottom: false, child: widget.body),
          bottomNavigationBar: widget.bottomNavigationBar,
          floatingActionButton: widget.floatingActionButton,
        ),
      ],
    );
  }
}

class _BlurLightOrb extends StatelessWidget {
  final Color color;
  final double size;

  const _BlurLightOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 75, sigmaY: 75),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

/// Reusable Apple Liquid Glass Container with Specular Rim Highlight
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final bool isActive;
  final Color activeTint;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 26.0,
    this.blur = 28.0,
    this.padding = const EdgeInsets.all(18.0),
    this.margin,
    this.isActive = false,
    this.activeTint = const Color(0xFFFF9F0A),
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: isActive
                ? activeTint.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.32),
            blurRadius: isActive ? 28 : 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: GestureDetector(
            onTap: onTap,
            onLongPress: onLongPress,
            behavior: HitTestBehavior.opaque,
            child: CustomPaint(
              painter: _AppleSpecularBorderPainter(
                radius: borderRadius,
                isActive: isActive,
                tint: activeTint,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                padding: padding,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(borderRadius),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isActive
                        ? [
                            Colors.white.withValues(alpha: 0.26),
                            activeTint.withValues(alpha: 0.16),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.13),
                            Colors.white.withValues(alpha: 0.04),
                          ],
                  ),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppleSpecularBorderPainter extends CustomPainter {
  final double radius;
  final bool isActive;
  final Color tint;

  _AppleSpecularBorderPainter({
    required this.radius,
    required this.isActive,
    required this.tint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect.deflate(0.6), Radius.circular(radius));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: isActive ? 0.75 : 0.42),
          isActive ? tint.withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.10),
          Colors.white.withValues(alpha: 0.03),
          Colors.white.withValues(alpha: 0.22),
        ],
        stops: const [0.0, 0.35, 0.7, 1.0],
      ).createShader(rect);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _AppleSpecularBorderPainter old) =>
      old.isActive != isActive || old.tint != tint;
}
