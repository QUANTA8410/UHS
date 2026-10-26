import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_home/providers/real_home_provider.dart';
import 'package:unified_home/services/real_iot_controller.dart';
import 'package:unified_home/services/tv/oneplus_connect_service.dart';
import 'package:unified_home/ui/views/apple_glass_home_shell.dart';
import 'package:unified_home/ui/widgets/sheets/samsung_future_devices_sheet.dart';

class FakeOnePlusConnectService extends OnePlusConnectService {
  final List<Map<String, dynamic>> sentKeys = [];
  final List<Map<String, dynamic>> launchedApps = [];

  @override
  Future<bool> sendRemoteKey({
    required String tvId,
    required String keyAction,
    String? host,
  }) async {
    sentKeys.add({'tvId': tvId, 'keyAction': keyAction, 'host': host});
    return true;
  }

  @override
  Future<bool> launchApp({
    required String tvId,
    required String appName,
    String? host,
  }) async {
    launchedApps.add({'tvId': tvId, 'appName': appName, 'host': host});
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Bug 29: TV Control Routing and OnePlus TV Remote & App Launchers', () {
    testWidgets('Samsung TV routes to SamsungFutureDevicesSheet ("The Frame Art Mode")', (tester) async {
      final home = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);

      final samsungTv = RealSmartDevice(
        id: 'samsung_tv_theframe_01',
        name: 'The Frame 65"',
        room: 'Living Room',
        category: 'tv',
        protocol: ConnectionProtocol.customHttpWebhook,
        credentials: {'vendor': 'samsung'},
        isOn: true,
        isOnline: true,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<RealHomeProvider>.value(
          value: home,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDeviceControlSheet(context, samsungTv),
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.byType(SamsungFutureDevicesSheet), findsOneWidget);
      expect(find.byType(AppleGlassDeviceControlSheet), findsNothing);
    });

    testWidgets('OnePlus TV routes to AppleGlassDeviceControlSheet (NOT Samsung sheet)', (tester) async {
      final home = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);

      final oneplusTv = RealSmartDevice(
        id: 'oneplus_tv_01',
        name: 'OnePlus TV 55 U1S',
        room: 'Living Room',
        category: 'tv',
        protocol: ConnectionProtocol.onePlusTvLan,
        credentials: {'ip': '192.168.1.120'},
        isOn: true,
        isOnline: true,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<RealHomeProvider>.value(
          value: home,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDeviceControlSheet(context, oneplusTv),
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.byType(SamsungFutureDevicesSheet), findsNothing);
      expect(find.byType(AppleGlassDeviceControlSheet), findsOneWidget);
      expect(find.text('Virtual D-Pad Remote'), findsOneWidget);
      expect(find.text('Quick App Launchers'), findsOneWidget);
    });

    testWidgets('D-Pad remote buttons dispatch correct keys via OnePlusConnectService', (tester) async {
      final home = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);
      final fakeTvService = FakeOnePlusConnectService();

      final oneplusTv = RealSmartDevice(
        id: 'oneplus_tv_living',
        name: 'OnePlus TV Q1 Pro',
        room: 'Living Room',
        category: 'tv',
        protocol: ConnectionProtocol.onePlusTvLan,
        credentials: {'ip': '192.168.1.150'},
        isOn: true,
        isOnline: true,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<RealHomeProvider>.value(
          value: home,
          child: MaterialApp(
            home: Scaffold(
              body: AppleGlassDeviceControlSheet(
                initialDevice: oneplusTv,
                tvService: fakeTvService,
              ),
            ),
          ),
        ),
      );

      // 1. Up
      await tester.tap(find.byIcon(Icons.arrow_drop_up_rounded));
      await tester.pump();
      expect(fakeTvService.sentKeys.last, {
        'tvId': 'oneplus_tv_living',
        'keyAction': 'DPAD_UP',
        'host': '192.168.1.150',
      });

      // 2. Down
      await tester.tap(find.byIcon(Icons.arrow_drop_down_rounded));
      await tester.pump();
      expect(fakeTvService.sentKeys.last, {
        'tvId': 'oneplus_tv_living',
        'keyAction': 'DPAD_DOWN',
        'host': '192.168.1.150',
      });

      // 3. Left
      await tester.tap(find.byIcon(Icons.arrow_left_rounded));
      await tester.pump();
      expect(fakeTvService.sentKeys.last, {
        'tvId': 'oneplus_tv_living',
        'keyAction': 'DPAD_LEFT',
        'host': '192.168.1.150',
      });

      // 4. Right
      await tester.tap(find.byIcon(Icons.arrow_right_rounded));
      await tester.pump();
      expect(fakeTvService.sentKeys.last, {
        'tvId': 'oneplus_tv_living',
        'keyAction': 'DPAD_RIGHT',
        'host': '192.168.1.150',
      });

      // 5. OK (ENTER)
      await tester.tap(find.text('OK'));
      await tester.pump();
      expect(fakeTvService.sentKeys.last, {
        'tvId': 'oneplus_tv_living',
        'keyAction': 'ENTER',
        'host': '192.168.1.150',
      });

      // 6. Back
      await tester.tap(find.text('Back'));
      await tester.pump();
      expect(fakeTvService.sentKeys.last, {
        'tvId': 'oneplus_tv_living',
        'keyAction': 'BACK',
        'host': '192.168.1.150',
      });

      // 7. Home
      await tester.tap(find.text('Home'));
      await tester.pump();
      expect(fakeTvService.sentKeys.last, {
        'tvId': 'oneplus_tv_living',
        'keyAction': 'HOME',
        'host': '192.168.1.150',
      });

      expect(fakeTvService.sentKeys.length, 7);
    });

    testWidgets('Quick App Launchers dispatch launchApp and update action status', (tester) async {
      final home = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);
      final fakeTvService = FakeOnePlusConnectService();

      final oneplusTv = RealSmartDevice(
        id: 'oneplus_tv_living',
        name: 'OnePlus TV 55 U1S',
        room: 'Living Room',
        category: 'tv',
        protocol: ConnectionProtocol.onePlusTvLan,
        credentials: {'ip': '192.168.1.150'},
        isOn: true,
        isOnline: true,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<RealHomeProvider>.value(
          value: home,
          child: MaterialApp(
            home: Scaffold(
              body: AppleGlassDeviceControlSheet(
                initialDevice: oneplusTv,
                tvService: fakeTvService,
              ),
            ),
          ),
        ),
      );

      // Launch YouTube
      await tester.tap(find.text('YouTube'));
      await tester.pump();

      expect(fakeTvService.launchedApps.last, {
        'tvId': 'oneplus_tv_living',
        'appName': 'YouTube',
        'host': '192.168.1.150',
      });
      expect(find.text('Launching YouTube on OnePlus TV 55 U1S...'), findsOneWidget);

      // Launch Netflix
      await tester.tap(find.text('Netflix'));
      await tester.pump();

      expect(fakeTvService.launchedApps.last, {
        'tvId': 'oneplus_tv_living',
        'appName': 'Netflix',
        'host': '192.168.1.150',
      });
      expect(find.text('Launching Netflix on OnePlus TV 55 U1S...'), findsOneWidget);

      // Launch Prime Video
      await tester.tap(find.text('Prime Video'));
      await tester.pump();

      expect(fakeTvService.launchedApps.last, {
        'tvId': 'oneplus_tv_living',
        'appName': 'Prime Video',
        'host': '192.168.1.150',
      });
      expect(find.text('Launching Prime Video on OnePlus TV 55 U1S...'), findsOneWidget);

      expect(fakeTvService.launchedApps.length, 3);
    });

    testWidgets('Controls are disabled when device is offline', (tester) async {
      final home = RealHomeProvider(autoInitStorage: false, autoStartPolling: false);
      final fakeTvService = FakeOnePlusConnectService();

      final offlineTv = RealSmartDevice(
        id: 'oneplus_tv_offline',
        name: 'OnePlus TV Bedroom',
        room: 'Bedroom',
        category: 'tv',
        protocol: ConnectionProtocol.onePlusTvLan,
        credentials: {'ip': '192.168.1.151'},
        isOn: false,
        isOnline: false,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<RealHomeProvider>.value(
          value: home,
          child: MaterialApp(
            home: Scaffold(
              body: AppleGlassDeviceControlSheet(
                initialDevice: offlineTv,
                tvService: fakeTvService,
              ),
            ),
          ),
        ),
      );

      // Offline warning should be displayed
      expect(find.textContaining('Device is Offline'), findsOneWidget);

      // Verify buttons are disabled (onPressed == null)
      final upButton = tester.widget<IconButton>(
        find.ancestor(of: find.byIcon(Icons.arrow_drop_up_rounded), matching: find.byType(IconButton)),
      );
      expect(upButton.onPressed, isNull);

      final youtubeChip = tester.widget<ActionChip>(
        find.ancestor(of: find.text('YouTube'), matching: find.byType(ActionChip)),
      );
      expect(youtubeChip.onPressed, isNull);

      expect(fakeTvService.sentKeys, isEmpty);
      expect(fakeTvService.launchedApps, isEmpty);
    });
  });
}
