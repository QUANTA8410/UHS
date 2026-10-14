import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_home/providers/real_home_provider.dart';
import 'package:unified_home/theme/apple_glass_theme.dart';
import 'package:unified_home/ui/views/apple_glass_home_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('UnifiedHomeApp renders Apple Glass Spatial Shell and tabs', (WidgetTester tester) async {
    final provider = RealHomeProvider(autoStartPolling: false);

    await tester.pumpWidget(
      ChangeNotifierProvider<RealHomeProvider>.value(
        value: provider,
        child: MaterialApp(
          theme: AppleGlassTheme.themeData,
          home: const AppleGlassHomeShell(),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));

    // Verify Glass Shell Bottom Dock Pills
    expect(find.text('Home'), findsOneWidget);
    expect(find.byIcon(Icons.view_in_ar_rounded), findsOneWidget);
    expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);

    // Verify Pair Device Action
    expect(find.text('Pair Device'), findsOneWidget);

    // Switch to 3D Map Tab
    await tester.tap(find.byIcon(Icons.view_in_ar_rounded));
    await tester.pump(const Duration(milliseconds: 100));

    // Switch to Automations Tab
    await tester.tap(find.byIcon(Icons.bolt_rounded));
    await tester.pump(const Duration(milliseconds: 100));

    provider.dispose();
  });
}
