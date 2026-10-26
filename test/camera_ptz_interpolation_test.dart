import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:unified_home/services/real_iot_controller.dart';

void main() {
  group('Bug 25: Camera PTZ String Interpolation & ONVIF/CGI Network Tests', () {
    test('sendCameraPtzCommand correctly interpolates IP and velocity in ONVIF SOAP call', () async {
      final List<http.Request> interceptedRequests = [];

      final mockClient = MockClient((request) async {
        interceptedRequests.add(request);
        if (request.url.path.contains('onvif/ptz_service')) {
          return http.Response(
            '<soap:Envelope><soap:Body><ContinuousMoveResponse/></soap:Body></soap:Envelope>',
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final controller = RealIotController(client: mockClient);
      final camera = RealSmartDevice(
        id: 'realme_cam_01',
        name: 'Living Room Camera',
        room: 'living',
        category: 'camera',
        protocol: ConnectionProtocol.rtspOnvifCamera,
        credentials: {'ip': '192.168.1.88'},
        liveAttributes: {'panAngle': 0.0, 'tiltAngle': 0.0},
      );

      // 1. Move left
      await controller.sendCameraPtzCommand(camera, 'left');

      expect(interceptedRequests.length, equals(1));
      final onvifReq = interceptedRequests.first;
      expect(
        onvifReq.url.toString(),
        equals('http://192.168.1.88:8000/onvif/ptz_service'),
        reason: 'Should interpolate real IP and not literal \$ip',
      );
      expect(onvifReq.body.contains('x="-0.5" y="0.0"'), isTrue);
      expect(onvifReq.body.contains(r'$'), isFalse, reason: 'No unescaped or literal dollar signs');
      expect(camera.liveAttributes['lastPtzDirection'], equals('left'));
      expect(camera.liveAttributes['panAngle'], equals(-30.0));

      // 2. Move up
      interceptedRequests.clear();
      await controller.sendCameraPtzCommand(camera, 'up');

      expect(interceptedRequests.length, equals(1));
      final upReq = interceptedRequests.first;
      expect(upReq.body.contains('x="0.0" y="0.5"'), isTrue);
      expect(camera.liveAttributes['lastPtzDirection'], equals('up'));
      expect(camera.liveAttributes['tiltAngle'], equals(15.0));

      // 3. Move right
      interceptedRequests.clear();
      await controller.sendCameraPtzCommand(camera, 'right');

      expect(interceptedRequests.length, equals(1));
      final rightReq = interceptedRequests.first;
      expect(rightReq.body.contains('x="0.5" y="0.0"'), isTrue);

      // 4. Move down
      interceptedRequests.clear();
      await controller.sendCameraPtzCommand(camera, 'down');

      expect(interceptedRequests.length, equals(1));
      final downReq = interceptedRequests.first;
      expect(downReq.body.contains('x="0.0" y="-0.5"'), isTrue);
    });

    test('sendCameraPtzCommand falls back to CGI URL when ONVIF endpoint fails with proper interpolation', () async {
      final List<http.Request> interceptedRequests = [];

      final mockClient = MockClient((request) async {
        interceptedRequests.add(request);
        if (request.url.path.contains('onvif/ptz_service')) {
          throw Exception('Connection refused on port 8000');
        }
        if (request.url.path.contains('cgi-bin/ptz.cgi')) {
          return http.Response('OK', 200);
        }
        return http.Response('Error', 500);
      });

      final controller = RealIotController(client: mockClient);
      final camera = RealSmartDevice(
        id: 'philips_cam_01',
        name: 'Front Door Camera',
        room: 'entrance',
        category: 'camera',
        protocol: ConnectionProtocol.rtspOnvifCamera,
        credentials: {'ip': '192.168.1.120'},
        liveAttributes: {'panAngle': 0.0, 'tiltAngle': 0.0},
      );

      await controller.sendCameraPtzCommand(camera, 'right');

      // Both ONVIF attempt and CGI fallback attempt were dispatched
      expect(interceptedRequests.length, equals(2));
      final cgiReq = interceptedRequests.last;
      expect(
        cgiReq.url.toString(),
        equals('http://192.168.1.120/cgi-bin/ptz.cgi?action=move&dir=right'),
        reason: 'CGI fallback URL should interpolate both ip and direction cleanly',
      );
      expect(camera.liveAttributes['panAngle'], equals(30.0));
    });
  });
}
