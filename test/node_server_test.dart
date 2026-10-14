import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_home/providers/real_home_provider.dart';
import 'package:unified_home/services/node/embedded_android_node_server.dart';
import 'package:unified_home/services/real_iot_controller.dart';
import 'package:unified_home/ui/widgets/dialogs/node_server_dashboard_sheet.dart';

class _RealHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (cert, host, port) => true;
    return client;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    HttpOverrides.global = _RealHttpOverrides();
  });

  group('EmbeddedAndroidNodeServer HTTP & REST Integration Tests', () {
    test('EmbeddedAndroidNodeServer binds port and responds to REST endpoints', () async {
      final home = RealHomeProvider();
      final testDevice = RealSmartDevice(
        id: 'node_test_bulb_1',
        name: 'Living Room Smart Bulb',
        room: 'Living Room',
        category: 'light',
        protocol: ConnectionProtocol.tuyaLocalLan,
        credentials: {'ip': '192.168.1.55', 'localKey': '0123456789abcdef'},
        isOn: false,
        primaryValue: 80.0,
      );
      home.addDeviceDirect(testDevice);

      final server = EmbeddedAndroidNodeServer();
      const testPort = 8791;

      final started = await server.startServer(home, port: testPort);
      expect(started, isTrue);
      expect(server.isRunning, isTrue);
      expect(server.port, equals(testPort));
      expect(server.dashboardUrl, contains(':$testPort/'));

      final client = HttpClient();

      try {
        // 1. Test GET /api/status
        final statusReq = await client.getUrl(Uri.parse('http://127.0.0.1:$testPort/api/status'));
        final statusRes = await statusReq.close();
        expect(statusRes.statusCode, HttpStatus.ok);
        final statusBody = jsonDecode(await utf8.decodeStream(statusRes));
        expect(statusBody['status'], equals('online'));
        expect(statusBody['port'], equals(testPort));
        expect(statusBody['totalDevices'], equals(1));

        // 2. Test GET /api/devices
        final devReq = await client.getUrl(Uri.parse('http://127.0.0.1:$testPort/api/devices'));
        final devRes = await devReq.close();
        expect(devRes.statusCode, HttpStatus.ok);
        final devBody = jsonDecode(await utf8.decodeStream(devRes));
        expect(devBody['success'], isTrue);
        expect(devBody['count'], equals(1));
        expect(devBody['devices'][0]['id'], equals('node_test_bulb_1'));

        // 3. Test GET / (HTML Dashboard)
        final htmlReq = await client.getUrl(Uri.parse('http://127.0.0.1:$testPort/'));
        final htmlRes = await htmlReq.close();
        expect(htmlRes.statusCode, HttpStatus.ok);
        expect(htmlRes.headers.contentType?.mimeType, equals('text/html'));
        final htmlContent = await utf8.decodeStream(htmlRes);
        expect(htmlContent.contains('Unified Home Node'), isTrue);
        expect(htmlContent.contains('ALWAYS-ON HUB'), isTrue);

        // 4. Test POST /api/devices/{id}/control
        final controlReq = await client.postUrl(
          Uri.parse('http://127.0.0.1:$testPort/api/devices/node_test_bulb_1/control'),
        );
        controlReq.headers.contentType = ContentType.json;
        controlReq.write(jsonEncode({'level': 50.0}));
        final controlRes = await controlReq.close();
        expect(controlRes.statusCode, HttpStatus.ok);
        final controlBody = jsonDecode(await utf8.decodeStream(controlRes));
        expect(controlBody['success'], isTrue);

        // 5. Test GET /api/logs
        final logsReq = await client.getUrl(Uri.parse('http://127.0.0.1:$testPort/api/logs'));
        final logsRes = await logsReq.close();
        expect(logsRes.statusCode, HttpStatus.ok);
        final logsBody = jsonDecode(await utf8.decodeStream(logsRes));
        expect(logsBody['logs'], isNotEmpty);
      } finally {
        client.close();
        await server.stopServer();
        expect(server.isRunning, isFalse);
        home.dispose();
      }
    });

    test('EmbeddedAndroidNodeServer handles 404 for unknown endpoints', () async {
      final home = RealHomeProvider();
      final server = EmbeddedAndroidNodeServer();
      const testPort = 8792;

      await server.startServer(home, port: testPort);
      final client = HttpClient();

      try {
        final req = await client.getUrl(Uri.parse('http://127.0.0.1:$testPort/api/unknown_route'));
        final res = await req.close();
        expect(res.statusCode, equals(HttpStatus.notFound));
      } finally {
        client.close();
        await server.stopServer();
        home.dispose();
      }
    });
  });

  group('NodeServerDashboardSheet Widget Tests', () {
    testWidgets('Renders NodeServerDashboardSheet in standby state', (tester) async {
      final home = RealHomeProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<RealHomeProvider>.value(
            value: home,
            child: const Scaffold(
              body: NodeServerDashboardSheet(),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('24/7 Always-On Hub Node'), findsOneWidget);
      expect(find.text('HUB STANDBY'), findsOneWidget);
      expect(find.text('Start 24/7 Android Hub Node Server'), findsOneWidget);
      expect(find.text('OLED Burn-in Protection Clock'), findsOneWidget);
      expect(find.byIcon(Icons.dns_rounded), findsOneWidget);

      home.dispose();
    });
  });
}
