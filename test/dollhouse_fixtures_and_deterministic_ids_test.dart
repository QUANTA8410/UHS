import 'package:flutter_test/flutter_test.dart';
import 'package:unified_home/models/house_3d_twin_model.dart';
import 'package:unified_home/services/real_iot_controller.dart';

void main() {
  group('Bug 13 & 14: 3D Dollhouse Fixture Binding & Deterministic IDs Tests', () {
    test('Bug 13: defaultApartment() has pre-populated default linkedRealDeviceId values matching sample home', () {
      final layout = House3DTwinLayout.defaultApartment();

      final livingAc = layout.fixtures.firstWhere((f) => f.id == 'living.ac');
      expect(livingAc.linkedRealDeviceId, 'lg_ac_dualcool_01');

      final livingMain = layout.fixtures.firstWhere((f) => f.id == 'living.main');
      expect(livingMain.linkedRealDeviceId, 'light_living_chandelier_01');

      final bedroomAc = layout.fixtures.firstWhere((f) => f.id == 'bedroom.ac');
      expect(bedroomAc.linkedRealDeviceId, 'samsung_ac_windfree_01');

      final washer = layout.fixtures.firstWhere((f) => f.id == 'kitchen.washer');
      expect(washer.linkedRealDeviceId, 'samsung_washer_ecobubble_01');
    });

    test('Bug 13: autoBindRealDevices binds unlinked fixtures to matching real devices', () {
      final layout = House3DTwinLayout(
        rooms: [],
        openings: [],
        furniture: [],
        fixtures: [
          Fixture3DNode(
            id: 'living.strip',
            label: 'Living Strip',
            fixtureType: 'strip',
            roomId: 'living',
            x: 0.1,
            y: 0.1,
          ),
          Fixture3DNode(
            id: 'bedroom.ceiling',
            label: 'Bedroom Main',
            fixtureType: 'ceiling',
            roomId: 'bedroom',
            x: 0.2,
            y: 0.2,
          ),
          Fixture3DNode(
            id: 'living.camera',
            label: 'Living Cam',
            fixtureType: 'camera',
            roomId: 'living',
            x: 0.5,
            y: 0.5,
          ),
        ],
      );

      final devices = <RealSmartDevice>[
        RealSmartDevice(
          id: 'real_wipro_bulb_living',
          name: 'Living Light',
          room: 'Living Room',
          category: 'light',
          protocol: ConnectionProtocol.tuyaCloudDirect,
          credentials: const {'token': 'dummy'},
        ),
        RealSmartDevice(
          id: 'real_philips_bulb_bedroom',
          name: 'Bedroom Bulb',
          room: 'Bedroom',
          category: 'light',
          protocol: ConnectionProtocol.philipsHueLocal,
          credentials: const {'ip': '192.168.1.100'},
        ),
        RealSmartDevice(
          id: 'real_security_cam_living',
          name: '360 Cam',
          room: 'Living',
          category: 'camera',
          protocol: ConnectionProtocol.rtspOnvifCamera,
          credentials: const {'streamUrl': 'rtsp://192.168.1.50/live'},
        ),
      ];

      layout.autoBindRealDevices(devices);

      final livingStrip = layout.fixtures.firstWhere((f) => f.id == 'living.strip');
      expect(livingStrip.linkedRealDeviceId, 'real_wipro_bulb_living');

      final bedroomCeiling = layout.fixtures.firstWhere((f) => f.id == 'bedroom.ceiling');
      expect(bedroomCeiling.linkedRealDeviceId, 'real_philips_bulb_bedroom');

      final livingCam = layout.fixtures.firstWhere((f) => f.id == 'living.camera');
      expect(livingCam.linkedRealDeviceId, 'real_security_cam_living');
    });

    test('Bug 14: Fixture3DNode and Furniture3DProp fromJson generate deterministic IDs instead of UniqueKey', () {
      final fixJson = {
        'roomId': 'bedroom',
        'fixtureType': 'ceiling',
      };
      final fix1 = Fixture3DNode.fromJson(fixJson);
      final fix2 = Fixture3DNode.fromJson(fixJson);

      expect(fix1.id, 'bedroom.ceiling');
      expect(fix2.id, 'bedroom.ceiling');
      expect(fix1.id, equals(fix2.id), reason: 'Must be deterministic across deserializations');

      final propJson = {
        'roomId': 'kitchen',
        'type': 'counter',
      };
      final prop1 = Furniture3DProp.fromJson(propJson);
      final prop2 = Furniture3DProp.fromJson(propJson);

      expect(prop1.id, 'kitchen.counter');
      expect(prop2.id, 'kitchen.counter');
      expect(prop1.id, equals(prop2.id), reason: 'Must be deterministic across deserializations');
    });
  });
}
