import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:unified_home/services/real_iot_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Bug 6: Home Assistant Bridge executeDeviceCommand Hardened Implementation Tests', () {
    test('1. Map payload arguments: Merges map properties into payload while preserving entity_id', () async {
      late http.Request recordedReq;

      final mockClient = MockClient((http.Request request) async {
        recordedReq = request;
        return http.Response(
          jsonEncode([
            {'entity_id': 'light.living_room_ceiling', 'state': 'on'}
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final controller = RealIotController(client: mockClient);
      final haDevice = RealSmartDevice(
        id: 'light.living_room_ceiling',
        name: 'Ceiling Light',
        room: 'Living Room',
        category: 'light',
        protocol: ConnectionProtocol.homeAssistantBridge,
        credentials: {
          'hubUrl': 'http://192.168.1.50:8123',
          'token': 'ha_long_lived_access_token_123',
        },
      );

      await controller.executeDeviceCommand(
        haDevice,
        'light',
        'turn_on',
        [
          {'brightness_pct': 85, 'color_temp': 370, 'transition': 2}
        ],
      );

      expect(recordedReq.method, equals('POST'));
      expect(
        recordedReq.url.toString(),
        equals('http://192.168.1.50:8123/api/services/light/turn_on'),
      );
      expect(
        recordedReq.headers['Authorization'],
        equals('Bearer ha_long_lived_access_token_123'),
      );
      expect(recordedReq.headers['Content-Type'], equals('application/json'));

      final sentBody = jsonDecode(recordedReq.body) as Map<String, dynamic>;
      expect(sentBody['entity_id'], equals('light.living_room_ceiling'));
      expect(sentBody['brightness_pct'], equals(85));
      expect(sentBody['color_temp'], equals(370));
      expect(sentBody['transition'], equals(2));
    });

    test('2. Primitive arguments: Intelligently maps domain/command primitives and falls back cleanly without dropping', () async {
      final List<http.Request> recordedRequests = [];

      final mockClient = MockClient((http.Request request) async {
        recordedRequests.add(request);
        return http.Response('[]', 200, headers: {'content-type': 'application/json'});
      });

      final controller = RealIotController(client: mockClient);

      // (a) Climate set_temperature primitive [24.0]
      final climateDev = RealSmartDevice(
        id: 'climate.living_room_ac',
        name: 'Living Room AC',
        room: 'Living Room',
        category: 'ac',
        protocol: ConnectionProtocol.homeAssistantBridge,
        credentials: {
          'hubUrl': 'http://192.168.1.50:8123',
          'token': 'test_token',
        },
      );
      await controller.executeDeviceCommand(climateDev, 'climate', 'set_temperature', [24.0]);

      // (b) Media player select_source primitive ['Netflix']
      final tvDev = RealSmartDevice(
        id: 'media_player.living_room_tv',
        name: 'Living Room TV',
        room: 'Living Room',
        category: 'tv',
        protocol: ConnectionProtocol.homeAssistantBridge,
        credentials: {
          'hubUrl': 'http://192.168.1.50:8123',
          'token': 'test_token',
        },
      );
      await controller.executeDeviceCommand(tvDev, 'media_player', 'select_source', ['Netflix']);

      // (c) Light turn_on primitive brightness [100]
      final lightDev = RealSmartDevice(
        id: 'light.desk_lamp',
        name: 'Desk Lamp',
        room: 'Office',
        category: 'light',
        protocol: ConnectionProtocol.homeAssistantBridge,
        credentials: {
          'hubUrl': 'http://192.168.1.50:8123',
          'token': 'test_token',
        },
      );
      await controller.executeDeviceCommand(lightDev, 'light', 'turn_on', [100]);

      // (d) Generic unknown capability/command fallback primitive ['custom_preset']
      final genericDev = RealSmartDevice(
        id: 'custom.hub_node',
        name: 'Custom Hub Node',
        room: 'Basement',
        category: 'switch',
        protocol: ConnectionProtocol.homeAssistantBridge,
        credentials: {
          'hubUrl': 'http://192.168.1.50:8123',
          'token': 'test_token',
        },
      );
      await controller.executeDeviceCommand(genericDev, 'custom_domain', 'apply_preset', ['cinema_mode']);

      expect(recordedRequests.length, equals(4));

      // Verify (a)
      final bodyClimate = jsonDecode(recordedRequests[0].body) as Map<String, dynamic>;
      expect(recordedRequests[0].url.toString(), equals('http://192.168.1.50:8123/api/services/climate/set_temperature'));
      expect(bodyClimate['entity_id'], equals('climate.living_room_ac'));
      expect(bodyClimate['temperature'], equals(24.0));

      // Verify (b)
      final bodyTv = jsonDecode(recordedRequests[1].body) as Map<String, dynamic>;
      expect(recordedRequests[1].url.toString(), equals('http://192.168.1.50:8123/api/services/media_player/select_source'));
      expect(bodyTv['entity_id'], equals('media_player.living_room_tv'));
      expect(bodyTv['source'], equals('Netflix'));

      // Verify (c)
      final bodyLight = jsonDecode(recordedRequests[2].body) as Map<String, dynamic>;
      expect(recordedRequests[2].url.toString(), equals('http://192.168.1.50:8123/api/services/light/turn_on'));
      expect(bodyLight['entity_id'], equals('light.desk_lamp'));
      expect(bodyLight['brightness_pct'], equals(100));

      // Verify (d)
      final bodyGeneric = jsonDecode(recordedRequests[3].body) as Map<String, dynamic>;
      expect(recordedRequests[3].url.toString(), equals('http://192.168.1.50:8123/api/services/custom_domain/apply_preset'));
      expect(bodyGeneric['entity_id'], equals('custom.hub_node'));
      expect(bodyGeneric['value'], equals('cinema_mode'));
    });

    test('3. Empty arguments: Sends payload with only entity_id', () async {
      late http.Request recordedReq;

      final mockClient = MockClient((http.Request request) async {
        recordedReq = request;
        return http.Response('[]', 200, headers: {'content-type': 'application/json'});
      });

      final controller = RealIotController(client: mockClient);
      final switchDev = RealSmartDevice(
        id: 'switch.kitchen_fan',
        name: 'Kitchen Fan Switch',
        room: 'Kitchen',
        category: 'switch',
        protocol: ConnectionProtocol.homeAssistantBridge,
        credentials: {
          'hubUrl': 'http://192.168.1.50:8123',
          'token': 'test_token',
        },
      );

      await controller.executeDeviceCommand(switchDev, 'switch', 'toggle', []);

      expect(recordedReq.url.toString(), equals('http://192.168.1.50:8123/api/services/switch/toggle'));
      final sentBody = jsonDecode(recordedReq.body) as Map<String, dynamic>;
      expect(sentBody, equals({'entity_id': 'switch.kitchen_fan'}));
    });

    test('4. Trailing slash on hubUrl: Sanitizes single and multiple trailing slashes without malformed double slashes', () async {
      final recordedUrls = <String>[];

      final mockClient = MockClient((http.Request request) async {
        recordedUrls.add(request.url.toString());
        return http.Response('[]', 200, headers: {'content-type': 'application/json'});
      });

      final controller = RealIotController(client: mockClient);

      // Single trailing slash
      final devSingleSlash = RealSmartDevice(
        id: 'light.porch',
        name: 'Porch Light',
        room: 'Outdoor',
        category: 'light',
        protocol: ConnectionProtocol.homeAssistantBridge,
        credentials: {
          'hubUrl': 'http://homeassistant.local:8123/',
          'token': 'test_token',
        },
      );
      await controller.executeDeviceCommand(devSingleSlash, 'light', 'turn_off');

      // Multiple trailing slashes
      final devMultiSlash = RealSmartDevice(
        id: 'light.garage',
        name: 'Garage Light',
        room: 'Garage',
        category: 'light',
        protocol: ConnectionProtocol.homeAssistantBridge,
        credentials: {
          'hubUrl': 'https://ha.example.com:8123///',
          'token': 'test_token',
        },
      );
      await controller.executeDeviceCommand(devMultiSlash, 'light', 'turn_on');

      expect(recordedUrls[0], equals('http://homeassistant.local:8123/api/services/light/turn_off'));
      expect(recordedUrls[0].contains('//api'), isFalse);

      expect(recordedUrls[1], equals('https://ha.example.com:8123/api/services/light/turn_on'));
      expect(recordedUrls[1].contains('//api'), isFalse);
    });

    test('5. Missing hubUrl / token credential: Throws descriptive exception via _requireCredential without null check operator crash', () async {
      final controller = RealIotController();

      // (a) Empty credentials map
      final noCredsDev = RealSmartDevice(
        id: 'light.bedroom',
        name: 'Bedroom Light',
        room: 'Bedroom',
        category: 'light',
        protocol: ConnectionProtocol.homeAssistantBridge,
        credentials: {},
      );

      expect(
        () async => await controller.executeDeviceCommand(noCredsDev, 'light', 'turn_on'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains("Missing required credential 'hubUrl' for device 'Bedroom Light'"),
          ),
        ),
      );

      // (b) HubUrl present, but token missing
      final missingTokenDev = RealSmartDevice(
        id: 'light.bedroom',
        name: 'Bedroom Light',
        room: 'Bedroom',
        category: 'light',
        protocol: ConnectionProtocol.homeAssistantBridge,
        credentials: {'hubUrl': 'http://192.168.1.50:8123'},
      );

      expect(
        () async => await controller.executeDeviceCommand(missingTokenDev, 'light', 'turn_on'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains("Missing required credential 'token' for device 'Bedroom Light'"),
          ),
        ),
      );

      // (c) Blank / whitespace-only hubUrl
      final blankHubUrlDev = RealSmartDevice(
        id: 'light.bedroom',
        name: 'Bedroom Light',
        room: 'Bedroom',
        category: 'light',
        protocol: ConnectionProtocol.homeAssistantBridge,
        credentials: {'hubUrl': '   ', 'token': 'test_token'},
      );

      expect(
        () async => await controller.executeDeviceCommand(blankHubUrlDev, 'light', 'turn_on'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains("Missing required credential 'hubUrl' for device 'Bedroom Light'"),
          ),
        ),
      );
    });

    test('6. Non-200 status code: Throws descriptive exception containing both HTTP status code and response body', () async {
      final mockClient = MockClient((http.Request request) async {
        if (request.url.path.contains('climate/set_temperature')) {
          return http.Response(
            '{"message": "Temperature 45.0 is out of valid range [16.0, 30.0]"}',
            400,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.contains('light/turn_on')) {
          return http.Response(
            'Internal Server Error: Zigbee coordinator timeout',
            500,
            headers: {'content-type': 'text/plain'},
          );
        }
        return http.Response('Service Not Found', 404);
      });

      final controller = RealIotController(client: mockClient);
      final dev = RealSmartDevice(
        id: 'climate.hall_ac',
        name: 'Hall AC',
        room: 'Hall',
        category: 'ac',
        protocol: ConnectionProtocol.homeAssistantBridge,
        credentials: {
          'hubUrl': 'http://192.168.1.50:8123',
          'token': 'test_token',
        },
      );

      // Expect HTTP 400 with status code and JSON error body
      expect(
        () async => await controller.executeDeviceCommand(dev, 'climate', 'set_temperature', [45.0]),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            allOf([
              contains('Hub command failed (400)'),
              contains('Temperature 45.0 is out of valid range'),
            ]),
          ),
        ),
      );

      // Expect HTTP 500 with status code and plain text error body
      final lightDev = RealSmartDevice(
        id: 'light.chandelier',
        name: 'Chandelier',
        room: 'Dining',
        category: 'light',
        protocol: ConnectionProtocol.homeAssistantBridge,
        credentials: {
          'hubUrl': 'http://192.168.1.50:8123',
          'token': 'test_token',
        },
      );

      expect(
        () async => await controller.executeDeviceCommand(lightDev, 'light', 'turn_on'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            allOf([
              contains('Hub command failed (500)'),
              contains('Zigbee coordinator timeout'),
            ]),
          ),
        ),
      );
    });
  });
}
