import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'providers/real_home_provider.dart';
import 'theme/apple_glass_theme.dart';
import 'ui/views/apple_glass_home_shell.dart';
import 'ui/views/liquid_glass_splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
  ));
  runApp(const UnifiedAppleGlassApp());
}

class UnifiedAppleGlassApp extends StatelessWidget {
  final RealHomeProvider? provider;
  const UnifiedAppleGlassApp({super.key, this.provider});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<RealHomeProvider>(
      create: (_) => provider ?? RealHomeProvider(),
      child: MaterialApp(
        title: 'Unified Smart Home',
        debugShowCheckedModeBanner: false,
        theme: AppleGlassTheme.themeData,
        home: const LiquidGlassSplashScreen(
          child: AppleGlassHomeShell(),
        ),
      ),
    );
  }
}

class UnifiedHomeApp extends StatelessWidget {
  const UnifiedHomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const UnifiedAppleGlassApp();
  }
}
