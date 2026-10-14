import 'package:flutter_test/flutter_test.dart';
import 'package:unified_home/main.dart';

void main() {
  testWidgets('UnifiedHomeApp renders Google Home tabs and quick action pills', (WidgetTester tester) async {
    await tester.pumpWidget(const UnifiedHomeApp());
    await tester.pumpAndSettle();

    // Verify Home Name AppBar
    expect(find.text('My Smart Home'), findsOneWidget);

    // Verify Quick Action Pills
    expect(find.text('Lights'), findsOneWidget);
    expect(find.text('Climate'), findsOneWidget);
    expect(find.text('Appliances'), findsOneWidget);
    expect(find.text('Energy'), findsOneWidget);

    // Verify Bottom NavigationBar Tabs and Pills exist
    expect(find.text('Favorites'), findsAtLeastNWidgets(1));
    expect(find.text('Devices'), findsAtLeastNWidgets(1));
    expect(find.text('Automations'), findsAtLeastNWidgets(1));
    expect(find.text('3D Map'), findsAtLeastNWidgets(1));

    // Switch to Devices Tab in NavigationBar
    await tester.tap(find.text('Devices').last);
    await tester.pumpAndSettle();
    expect(find.text('Rooms & Devices'), findsOneWidget);
    expect(find.text('Living Room'), findsOneWidget);

    // Switch to Energy Tab in NavigationBar
    await tester.tap(find.text('Energy').last);
    await tester.pumpAndSettle();
    expect(find.text('SmartThings Energy Hub'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('AI Energy Mode (SmartThings)'), 200);
    expect(find.text('AI Energy Mode (SmartThings)'), findsOneWidget);
  });
}
