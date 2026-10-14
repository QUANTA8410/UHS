import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'providers/home_state.dart';
import 'providers/real_home_provider.dart';
import 'theme/app_theme.dart';
import 'theme/apple_glass_theme.dart';
import 'ui/views/apple_glass_home_shell.dart';
import 'ui/views/liquid_glass_splash_screen.dart';
import 'ui/views/main_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
  ));
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RealHomeProvider()),
        ChangeNotifierProvider(create: (_) => HomeState(autoInitStorage: true)),
      ],
      child: const UnifiedAppleGlassApp(),
    ),
  );
}

class UnifiedAppleGlassApp extends StatelessWidget {
  const UnifiedAppleGlassApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Unified Smart Home',
      debugShowCheckedModeBanner: false,
      theme: AppleGlassTheme.themeData,
      home: const LiquidGlassSplashScreen(
        child: AppleGlassHomeShell(),
      ),
    );
  }
}

class UnifiedHomeApp extends StatelessWidget {
  const UnifiedHomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HomeState(autoInitStorage: true)),
        ChangeNotifierProvider(create: (_) => RealHomeProvider()),
      ],
      child: MaterialApp(
        title: 'Unified Smart Home',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const MainShell(),
      ),
    );
  }
}
