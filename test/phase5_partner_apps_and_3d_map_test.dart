import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:unified_home/models/partner_app_model.dart';
import 'package:unified_home/providers/home_state.dart';
import 'package:unified_home/ui/widgets/dialogs/add_device_dialog.dart';
import 'package:unified_home/ui/views/map_view.dart';

void main() {
  group('Phase 5: Google Home Partner Apps Directory Tests', () {
    test('Google Home catalog contains 30+ top ecosystem brands', () {
      final catalog = PartnerApp.googleHomeCatalog;
      expect(catalog.length, greaterThanOrEqualTo(30));

      final appIds = catalog.map((a) => a.id).toSet();
      expect(appIds.contains('smartthings'), true);
      expect(appIds.contains('lg_thinq'), true);
      expect(appIds.contains('wipro_smart'), true);
      expect(appIds.contains('oneplus_connect'), true);
      expect(appIds.contains('matter'), true);
      expect(appIds.contains('philips_hue'), true);
      expect(appIds.contains('tuya_smart'), true);
      expect(appIds.contains('tp_link_tapo'), true);
      expect(appIds.contains('mi_home'), true);
      expect(appIds.contains('google_nest'), true);
      expect(appIds.contains('roborock'), true);
    });

    test('Partner apps cover all standard home automation categories', () {
      final categories = PartnerApp.googleHomeCatalog.map((a) => a.category).toSet();
      expect(categories.contains(PartnerCategory.appliances), true);
      expect(categories.contains(PartnerCategory.climate), true);
      expect(categories.contains(PartnerCategory.lighting), true);
      expect(categories.contains(PartnerCategory.entertainment), true);
      expect(categories.contains(PartnerCategory.security), true);
      expect(categories.contains(PartnerCategory.plugsAndEnergy), true);
      expect(categories.contains(PartnerCategory.cleaning), true);
      expect(categories.contains(PartnerCategory.hubAndBridges), true);
    });
  });

  group('Phase 5: AddDeviceDialog Google Home Catalog UI Tests', () {
    testWidgets('Renders search input and Works with Google tab', (tester) async {
      final state = HomeState();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: state,
          child: const MaterialApp(
            home: Scaffold(
              body: AddDeviceDialog(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Add & Connect Real Devices'), findsOneWidget);
      expect(find.text('Works with Google Home & Unified IoT'), findsOneWidget);
      expect(find.text('Works with Google'), findsOneWidget);

      // Verify category filter chips are present
      expect(find.text('All Apps'), findsOneWidget);
      expect(find.text('Appliances'), findsOneWidget);
      expect(find.text('Climate & AC'), findsOneWidget);
      expect(find.text('Lighting'), findsOneWidget);
    });
  });

  group('Phase 5: 3D Spatial Digital Twin Map View Tests', () {
    testWidgets('MapView provides camera controls and orbit hints', (tester) async {
      final state = HomeState();

      await tester.pumpWidget(
        ChangeNotifierProvider<HomeState>.value(
          value: state,
          child: const MaterialApp(
            home: Scaffold(
              body: MapView(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Camera preset HUD buttons
      expect(find.byTooltip('3D Orbit View'), findsOneWidget);
      expect(find.byTooltip('Top-Down Blueprint'), findsOneWidget);
      expect(find.byTooltip('Front 3D Elevation'), findsOneWidget);

      // Tap Top-Down Blueprint preset
      await tester.tap(find.byTooltip('Top-Down Blueprint'));
      await tester.pumpAndSettle();

      // Tap 3D Orbit View preset
      await tester.tap(find.byTooltip('3D Orbit View'));
      await tester.pumpAndSettle();

      expect(find.text('Interactive 3D Digital Twin • Drag to Orbit'), findsOneWidget);
    });
  });
}
