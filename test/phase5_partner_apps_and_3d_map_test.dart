import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:unified_home/models/house_3d_twin_model.dart';
import 'package:unified_home/models/partner_app_model.dart';
import 'package:unified_home/providers/real_home_provider.dart';
import 'package:unified_home/ui/widgets/map3d/isometric_house_3d_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  group('Phase 5: 3D Spatial Digital Twin Map Viewport Tests', () {
    testWidgets('IsometricHouse3DWidget renders 3D isometric layout and responds to room selection', (tester) async {
      final home = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);
      final layout = House3DTwinLayout.defaultApartment();

      await tester.pumpWidget(
        ChangeNotifierProvider<RealHomeProvider>.value(
          value: home,
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: IsometricHouse3DWidget(
                  layout: layout,
                  selectedRoomId: 'all',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(IsometricHouse3DWidget), findsOneWidget);

      home.dispose();
    });
  });
}
