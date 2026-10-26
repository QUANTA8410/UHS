import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:unified_home/services/real_iot_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Bug 4: Samsung Washer State Override & Multi-Component Target Support', () {
    test('When switchVal == "on" and washerState == "stop", device.isOn remains true (Standby power, no override!)', () async {
      late http.Request recordedHealthReq;
      late http.Request recordedStatusReq;

      final mockClient = MockClient((http.Request request) async {
        if (request.url.path.endsWith('/health')) {
          recordedHealthReq = request;
          return http.Response(jsonEncode({'state': 'ONLINE'}), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path.endsWith('/status')) {
          recordedStatusReq = request;
          return http.Response(
            jsonEncode({
              'components': {
                'main': {
                  'switch': {
                    'switch': {'value': 'on'}
                  },
                  'washerOperatingState': {
                    'machineState': {'value': 'stop'},
                    'completionTime': {'value': null}
                  },
                  'powerMeter': {
                    'power': {'value': 4.2}
                  }
                }
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final controller = RealIotController(client: mockClient);
      final washer = RealSmartDevice(
        id: 'samsung_washer_standby_01',
        name: 'Samsung AI Ecobubble',
        room: 'Laundry',
        category: 'washer',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {'token': 'valid_st_pat_token_test_123'},
        isOn: false,
        isOnline: true,
      );

      await controller.refreshDeviceStatus(washer);

      // Verify the fix: switch is 'on', washer machineState is 'stop' -> device.isOn MUST remain true!
      expect(washer.isOn, isTrue, reason: 'Washer in standby power with switch on must NOT be forced to false');
      expect(washer.isOnline, isTrue);
      expect(washer.liveAttributes['machineState'], equals('stop'));
      expect(washer.liveAttributes['powerW'], equals(4.2));
      expect(washer.liveWatts, equals(4.2));
      expect(recordedHealthReq.headers['Authorization'], contains('valid_st_pat_token_test_123'));
      expect(recordedStatusReq.headers['Authorization'], contains('valid_st_pat_token_test_123'));
    });

    test('When switchVal == null and washerState == "pause", device.isOn is true via activeStates', () async {
      final mockClient = MockClient((http.Request request) async {
        if (request.url.path.endsWith('/health')) {
          return http.Response(jsonEncode({'state': 'ONLINE'}), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path.endsWith('/status')) {
          return http.Response(
            jsonEncode({
              'components': {
                'main': {
                  // No switch capability present
                  'washerOperatingState': {
                    'machineState': {'value': 'pause'},
                    'washerJobState': {'value': 'rinse'},
                  },
                  'powerMeter': {
                    'power': {'value': 4.5}
                  }
                }
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final controller = RealIotController(client: mockClient);
      final washer = RealSmartDevice(
        id: 'samsung_washer_pause_01',
        name: 'Samsung AI Ecobubble Paused',
        room: 'Laundry',
        category: 'washer',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {'token': 'valid_st_pat_token_test_123'},
        isOn: false,
        isOnline: true,
      );

      await controller.refreshDeviceStatus(washer);

      expect(washer.isOn, isTrue, reason: 'Pause state without switch must infer active power');
      expect(washer.liveAttributes['machineState'], equals('pause'));
      expect(washer.liveAttributes['stage'], equals('rinse'));
      expect(washer.liveAttributes['powerW'], equals(4.5));
    });

    test('When switchVal == null and washerState == "stop", device.isOn is false via inactiveStates', () async {
      final mockClient = MockClient((http.Request request) async {
        if (request.url.path.endsWith('/health')) {
          return http.Response(jsonEncode({'state': 'ONLINE'}), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path.endsWith('/status')) {
          return http.Response(
            jsonEncode({
              'components': {
                'main': {
                  // No switch capability present
                  'washerOperatingState': {
                    'machineState': {'value': 'stop'},
                    'washerJobState': {'value': 'none'},
                  },
                  'powerMeter': {
                    'power': {'value': 0.0}
                  }
                }
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final controller = RealIotController(client: mockClient);
      final washer = RealSmartDevice(
        id: 'samsung_washer_stop_01',
        name: 'Samsung AI Ecobubble Stopped',
        room: 'Laundry',
        category: 'washer',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {'token': 'valid_st_pat_token_test_123'},
        isOn: true,
        isOnline: true,
      );

      await controller.refreshDeviceStatus(washer);

      expect(washer.isOn, isFalse, reason: 'Stop state without switch must evaluate to false');
      expect(washer.liveAttributes['machineState'], equals('stop'));
    });

    test('Two-tier power fallback when switchVal == null and machineState is absent/unknown', () async {
      // 1. High power draw (> 2.0 W) infers power ON
      final clientHighPower = MockClient((http.Request request) async {
        if (request.url.path.endsWith('/health')) {
          return http.Response(jsonEncode({'state': 'ONLINE'}), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response(
          jsonEncode({
            'components': {
              'main': {
                'powerMeter': {
                  'power': {'value': 120.0}
                }
              }
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final controller1 = RealIotController(client: clientHighPower);
      final dev1 = RealSmartDevice(
        id: 'generic_st_dev_01',
        name: 'Generic Appliance',
        room: 'Kitchen',
        category: 'washer',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {'token': 'valid_st_pat_token_test_123'},
        isOn: false,
      );
      await controller1.refreshDeviceStatus(dev1);
      expect(dev1.isOn, isTrue, reason: 'Power draw of 120W must infer power ON');

      // 2. Low power draw (<= 2.0 W) infers power OFF
      final clientLowPower = MockClient((http.Request request) async {
        if (request.url.path.endsWith('/health')) {
          return http.Response(jsonEncode({'state': 'ONLINE'}), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response(
          jsonEncode({
            'components': {
              'main': {
                'powerMeter': {
                  'power': {'value': 0.5}
                }
              }
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final controller2 = RealIotController(client: clientLowPower);
      final dev2 = RealSmartDevice(
        id: 'generic_st_dev_02',
        name: 'Generic Appliance',
        room: 'Kitchen',
        category: 'washer',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {'token': 'valid_st_pat_token_test_123'},
        isOn: true,
      );
      await controller2.refreshDeviceStatus(dev2);
      expect(dev2.isOn, isFalse, reason: 'Power draw <= 2.0W on washer must infer power OFF');

      // 3. Fridge category is always ON even with 0 power reported
      final clientFridge = MockClient((http.Request request) async {
        if (request.url.path.endsWith('/health')) {
          return http.Response(jsonEncode({'state': 'ONLINE'}), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response(
          jsonEncode({
            'components': {
              'main': {
                'powerMeter': {
                  'power': {'value': 0.0}
                }
              }
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final controller3 = RealIotController(client: clientFridge);
      final dev3 = RealSmartDevice(
        id: 'samsung_fridge_01',
        name: 'Family Hub Fridge',
        room: 'Kitchen',
        category: 'fridge',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {'token': 'valid_st_pat_token_test_123'},
        isOn: false,
      );
      await controller3.refreshDeviceStatus(dev3);
      expect(dev3.isOn, isTrue, reason: 'Fridge category must default to power ON');
    });

    test('Multi-component device with credentials: {"component": "sub"} queries "sub" and shares mains power', () async {
      final mockClient = MockClient((http.Request request) async {
        if (request.url.path.endsWith('/health')) {
          return http.Response(jsonEncode({'state': 'ONLINE'}), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path.endsWith('/status')) {
          return http.Response(
            jsonEncode({
              'components': {
                'main': {
                  'switch': {
                    'switch': {'value': 'off'}
                  },
                  'washerOperatingState': {
                    'machineState': {'value': 'stop'}
                  },
                  'powerMeter': {
                    'power': {'value': 480.0} // Shared mains sensor
                  }
                },
                'sub': {
                  'washerOperatingState': {
                    'machineState': {'value': 'wash'},
                    'washerJobState': {'value': 'wash'},
                    'completionTime': {'value': DateTime.now().add(const Duration(minutes: 32)).toIso8601String()}
                  },
                  'custom.washerWaterTemperature': {
                    'washerWaterTemperature': {'value': '60°C'}
                  },
                  'custom.washerSpinSpeed': {
                    'washerSpinSpeed': {'value': '1400 RPM'}
                  }
                }
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final controller = RealIotController(client: mockClient);
      final subDrumWasher = RealSmartDevice(
        id: 'samsung_flexwash_dual_drum',
        name: 'Samsung FlexWash™ Upper Drum',
        room: 'Laundry',
        category: 'washer',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {
          'token': 'valid_st_pat_token_test_123',
          'component': 'sub',
        },
        isOn: false,
        isOnline: true,
      );

      await controller.refreshDeviceStatus(subDrumWasher);

      // Verify sub-component state was selected:
      expect(subDrumWasher.isOn, isTrue, reason: 'Sub-drum is in active wash state');
      expect(subDrumWasher.liveAttributes['machineState'], equals('wash'));
      expect(subDrumWasher.liveAttributes['stage'], equals('wash'));
      expect(subDrumWasher.liveAttributes['waterTemperature'], equals('60°C'));
      expect(subDrumWasher.liveAttributes['spinSpeed'], equals('1400 RPM'));
      expect(subDrumWasher.liveAttributes['remainingMinutes'], inInclusiveRange(30, 33));

      // Verify power meter fell back to mainComp shared mains sensor:
      expect(subDrumWasher.liveAttributes['powerW'], equals(480.0));
      expect(subDrumWasher.liveWatts, equals(480.0));
    });

    test('setPower targets configured component in switch command', () async {
      late Map<String, dynamic> postedCommand;

      final mockClient = MockClient((http.Request request) async {
        if (request.url.path.endsWith('/commands')) {
          postedCommand = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({'results': [{'status': 'ACCEPTED'}]}), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not Found', 404);
      });

      final controller = RealIotController(client: mockClient);
      final subDrum = RealSmartDevice(
        id: 'samsung_washer_sub',
        name: 'FlexWash Sub Drum',
        room: 'Laundry',
        category: 'washer',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {'token': 'valid_st_pat_token_test_123', 'component': 'sub'},
        isOn: false,
      );

      await controller.setPower(subDrum, true);

      expect(subDrum.isOn, isTrue);
      final commands = postedCommand['commands'] as List<dynamic>;
      expect(commands.first['component'], equals('sub'), reason: 'setPower must send to configured "sub" component');
      expect(commands.first['capability'], equals('switch'));
      expect(commands.first['command'], equals('on'));
    });

    test('setPower falls back to operating state with targetComponent for washer, dryer, dishwasher when switch rejected', () async {
      final List<Map<String, dynamic>> postedCommands = [];

      final mockClient = MockClient((http.Request request) async {
        if (request.url.path.endsWith('/commands')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          postedCommands.add(body);
          final firstCmd = (body['commands'] as List<dynamic>).first as Map<String, dynamic>;
          if (firstCmd['capability'] == 'switch') {
            // Reject switch command (e.g. 422 Unprocessable Entity as Samsung appliances do)
            return http.Response(jsonEncode({'error': 'Switch not supported on this cycle'}), 422, headers: {'content-type': 'application/json'});
          }
          // Accept fallback operating state command
          return http.Response(jsonEncode({'results': [{'status': 'ACCEPTED'}]}), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not Found', 404);
      });

      final controller = RealIotController(client: mockClient);

      // 1. Washer fallback
      final washer = RealSmartDevice(
        id: 'washer_fallback_test',
        name: 'Washer Drum',
        room: 'Laundry',
        category: 'washer',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {'token': 'valid_token_123', 'component': 'sub'},
        isOn: false,
      );
      await controller.setPower(washer, true);
      expect(washer.isOn, isTrue);
      expect(washer.liveAttributes['machineState'], equals('run'));
      final washerFallbackCmd = postedCommands.last['commands'][0];
      expect(washerFallbackCmd['component'], equals('sub'));
      expect(washerFallbackCmd['capability'], equals('washerOperatingState'));
      expect(washerFallbackCmd['command'], equals('setMachineState'));
      expect(washerFallbackCmd['arguments'], equals(['run']));

      // 2. Dryer fallback
      postedCommands.clear();
      final dryer = RealSmartDevice(
        id: 'dryer_fallback_test',
        name: 'Smart Dryer',
        room: 'Laundry',
        category: 'dryer',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {'token': 'valid_token_123', 'component': 'dryerDrum'},
        isOn: false,
      );
      await controller.setPower(dryer, true);
      expect(dryer.isOn, isTrue);
      expect(dryer.liveAttributes['machineState'], equals('run'));
      final dryerFallbackCmd = postedCommands.last['commands'][0];
      expect(dryerFallbackCmd['component'], equals('dryerDrum'));
      expect(dryerFallbackCmd['capability'], equals('dryerOperatingState'));
      expect(dryerFallbackCmd['command'], equals('setMachineState'));

      // 3. Dishwasher fallback
      postedCommands.clear();
      final dishwasher = RealSmartDevice(
        id: 'dishwasher_fallback_test',
        name: 'Smart Dishwasher',
        room: 'Kitchen',
        category: 'dishwasher',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {'token': 'valid_token_123', 'component': 'main'},
        isOn: false,
      );
      await controller.setPower(dishwasher, true);
      expect(dishwasher.isOn, isTrue);
      expect(dishwasher.liveAttributes['machineState'], equals('run'));
      final dwFallbackCmd = postedCommands.last['commands'][0];
      expect(dwFallbackCmd['component'], equals('main'));
      expect(dwFallbackCmd['capability'], equals('dishwasherOperatingState'));
      expect(dwFallbackCmd['command'], equals('setMachineState'));
    });

    test('executeDeviceCommand uses credentials["component"] by default and respects explicit component override', () async {
      late Map<String, dynamic> lastPostedCommand;

      final mockClient = MockClient((http.Request request) async {
        if (request.url.path.endsWith('/commands')) {
          lastPostedCommand = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({'results': [{'status': 'ACCEPTED'}]}), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not Found', 404);
      });

      final controller = RealIotController(client: mockClient);
      final device = RealSmartDevice(
        id: 'st_multi_device_01',
        name: 'Multi Component Washer',
        room: 'Laundry',
        category: 'washer',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {'token': 'valid_token_123', 'component': 'sub'},
      );

      // 1. Without explicit component override -> uses credentials['component'] ('sub')
      await controller.executeDeviceCommand(device, 'custom.washerCycle', 'setWasherCycle', ['QuickWash']);
      final cmd1 = (lastPostedCommand['commands'] as List<dynamic>).first;
      expect(cmd1['component'], equals('sub'), reason: 'Should default to configured credentials component');
      expect(cmd1['capability'], equals('custom.washerCycle'));
      expect(cmd1['command'], equals('setWasherCycle'));
      expect(cmd1['arguments'], equals(['QuickWash']));

      // 2. With explicit component override -> uses passed component ('dryerSection')
      await controller.executeDeviceCommand(device, 'custom.washerCycle', 'setWasherCycle', ['HeavyDuty'], 'dryerSection');
      final cmd2 = (lastPostedCommand['commands'] as List<dynamic>).first;
      expect(cmd2['component'], equals('dryerSection'), reason: 'Explicit component parameter must take precedence');
      expect(cmd2['arguments'], equals(['HeavyDuty']));
    });

    test('setPrimaryLevel uses targetComponent in SmartThings command', () async {
      late Map<String, dynamic> lastPostedCommand;

      final mockClient = MockClient((http.Request request) async {
        if (request.url.path.endsWith('/commands')) {
          lastPostedCommand = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({'results': [{'status': 'ACCEPTED'}]}), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not Found', 404);
      });

      final controller = RealIotController(client: mockClient);
      final acDevice = RealSmartDevice(
        id: 'st_windfree_ac_zone2',
        name: 'WindFree Zone 2',
        room: 'Bedroom 2',
        category: 'ac',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {'token': 'valid_token_123', 'component': 'zone2'},
        primaryValue: 26.0,
      );

      await controller.setPrimaryLevel(acDevice, 22.0);

      expect(acDevice.primaryValue, equals(22.0));
      final cmd = (lastPostedCommand['commands'] as List<dynamic>).first;
      expect(cmd['component'], equals('zone2'), reason: 'setPrimaryLevel must use configured component');
      expect(cmd['capability'], equals('thermostatCoolingSetpoint'));
      expect(cmd['command'], equals('setCoolingSetpoint'));
      expect(cmd['arguments'], equals([22]));
    });

    test('Completion time calculates remainingMinutes accurately and sets stage/machineState', () async {
      final now = DateTime.now().toUtc();
      final completion = now.add(const Duration(minutes: 45));

      final mockClient = MockClient((http.Request request) async {
        if (request.url.path.endsWith('/health')) {
          return http.Response(jsonEncode({'state': 'ONLINE'}), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path.endsWith('/status')) {
          return http.Response(
            jsonEncode({
              'components': {
                'main': {
                  'dryerOperatingState': {
                    'machineState': {'value': 'drying'},
                    'dryerJobState': {'value': 'cooling'},
                    'completionTime': {'value': completion.toIso8601String()}
                  }
                }
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final controller = RealIotController(client: mockClient);
      final dryer = RealSmartDevice(
        id: 'samsung_dryer_completion_test',
        name: 'Samsung HeatPump Dryer',
        room: 'Laundry',
        category: 'dryer',
        protocol: ConnectionProtocol.smartThingsCloud,
        credentials: {'token': 'valid_token_123'},
      );

      await controller.refreshDeviceStatus(dryer);

      expect(dryer.isOn, isTrue);
      expect(dryer.liveAttributes['machineState'], equals('drying'));
      expect(dryer.liveAttributes['stage'], equals('cooling'));
      expect(dryer.liveAttributes['remainingMinutes'], inInclusiveRange(44, 46));
    });
  });
}
