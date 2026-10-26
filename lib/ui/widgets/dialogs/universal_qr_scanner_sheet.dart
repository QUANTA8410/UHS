import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/real_home_provider.dart';
import '../../../services/real_iot_controller.dart';

/// Parsed device discovery payload from any scanned IoT QR Code
class ParsedQrDevice {
  final String providerId;
  final String providerName;
  final Color brandColor;
  final IconData icon;
  final RealSmartDevice device;
  final String pairingProtocol;
  final String rawCode;

  const ParsedQrDevice({
    required this.providerId,
    required this.providerName,
    required this.brandColor,
    required this.icon,
    required this.device,
    required this.pairingProtocol,
    required this.rawCode,
  });
}

class UniversalQrScannerSheet extends StatefulWidget {
  final String? initialProvider;

  const UniversalQrScannerSheet({super.key, this.initialProvider});

  static Future<void> show(BuildContext context, {String? initialProvider}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => UniversalQrScannerSheet(initialProvider: initialProvider),
    );
  }

  @override
  State<UniversalQrScannerSheet> createState() => _UniversalQrScannerSheetState();
}

class _UniversalQrScannerSheetState extends State<UniversalQrScannerSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _laserAnimCtrl;
  late Animation<double> _laserAnim;

  late String _selectedProvider;
  bool _isTorchOn = false;
  String _scanStatusText = 'Align Device QR / Barcode within frame';
  ParsedQrDevice? _detectedDevice;
  bool _isPairing = false;
  String? _pairingSuccessMsg;

  final TextEditingController _manualCodeCtrl = TextEditingController();
  bool _showManualInput = false;

  @override
  void initState() {
    super.initState();
    _selectedProvider = widget.initialProvider ?? 'all';

    _laserAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _laserAnim = Tween<double>(begin: 0.08, end: 0.92).animate(
      CurvedAnimation(parent: _laserAnimCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _laserAnimCtrl.dispose();
    _manualCodeCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // SMART MULTI-BRAND QR PARSER & DECODER
  // ---------------------------------------------------------------------------
  ParsedQrDevice? _decodeQrPayload(String rawText, [String? forcedProvider]) {
    final text = rawText.trim();
    if (text.isEmpty) return null;

    final providerKey = (forcedProvider != null && forcedProvider != 'all')
        ? forcedProvider
        : _detectProviderFromPayload(text);

    switch (providerKey) {
      case 'samsung_smartthings':
        return _parseSamsungSmartThingsQr(text);

      case 'lg_thinq':
        return _parseLgThinqQr(text);

      case 'wipro_smart_next':
      case 'wipro_tuya':
        return _parseWiproTuyaQr(text);

      case 'philips_hue':
        return _parsePhilipsHueQr(text);

      case 'philips_wiz':
        return _parsePhilipsWizQr(text);

      case 'realme_camera':
        return _parseRealmeCameraQr(text);

      case 'philips_camera':
        return _parsePhilipsCameraQr(text);

      case 'tplink_tapo':
        return _parseTapoQr(text);

      case 'home_assistant':
      default:
        // Try Matter Standard QR if it starts with MT:
        if (text.startsWith('MT:') || text.startsWith('CHIP:')) {
          return _parseMatterQr(text);
        }
        return _parseGenericOrMatterQr(text);
    }
  }

  String _detectProviderFromPayload(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('smartthings') || lower.contains('samsung') || lower.contains('ecobubble') || lower.contains('windfree')) {
      return 'samsung_smartthings';
    }
    if (lower.contains('thinq') || lower.contains('lg_') || lower.contains('washtower') || lower.contains('dualcool') || lower.contains('instaview') || lower.contains('aerotower')) {
      return 'lg_thinq';
    }
    if (lower.contains('wipro') || lower.contains('smartlife') || lower.contains('tuya')) {
      return 'wipro_smart_next';
    }
    if (lower.contains('meethue') || lower.contains('philips-hue') || lower.contains('hue_bridge')) {
      return 'philips_hue';
    }
    if (lower.contains('wiz') || lower.contains('wizconnected')) {
      return 'philips_wiz';
    }
    if (lower.contains('realme') || lower.contains('rtsp://') && lower.contains('554')) {
      return 'realme_camera';
    }
    if (lower.contains('philips') && (lower.contains('cam') || lower.contains('safety'))) {
      return 'philips_camera';
    }
    if (lower.contains('tapo') || lower.contains('kasa') || lower.contains('tp-link')) {
      return 'tplink_tapo';
    }
    if (lower.startsWith('mt:') || lower.contains('matter') || lower.contains('homeassistant')) {
      return 'home_assistant';
    }
    return 'all';
  }

  ParsedQrDevice _parseSamsungSmartThingsQr(String text) {
    final lower = text.toLowerCase();
    String category = 'washer';
    String name = 'Samsung AI Ecobubble™ Washer';
    String room = 'Laundry';
    Map<String, dynamic> attrs = {
      'machineState': 'run',
      'cycle': 'AI Wash',
      'remainingMinutes': 32,
      'detergentLevel': 85,
      'softenerLevel': 70,
      'ecobubbleActive': true,
      'drumCleanCycleCount': 14,
    };
    double primaryVal = 1400.0;

    if (lower.contains('ac') || lower.contains('windfree') || lower.contains('climate')) {
      category = 'ac';
      name = 'Samsung WindFree™ AI Inverter AC';
      room = 'Living Room';
      primaryVal = 23.0;
      attrs = {
        'windFree': true,
        'goodSleep': true,
        'pm1AirQuality': 11,
        'aiEnergyMode': true,
        'targetTemp': 23.0,
      };
    } else if (lower.contains('fridge') || lower.contains('refrigerator') || lower.contains('familyhub')) {
      category = 'fridge';
      name = 'Samsung Family Hub™ Multi-Door Refrigerator';
      room = 'Kitchen';
      primaryVal = 3.0;
      attrs = {
        'fridgeTemp': 3.0,
        'freezerTemp': -19.0,
        'flexZoneMode': 'Beverage',
        'powerCool': true,
        'powerFreeze': false,
        'iceBites': true,
      };
    } else if (lower.contains('tv') || lower.contains('frame')) {
      category = 'tv';
      name = 'Samsung The Frame 65" 4K QLED TV';
      room = 'Living Room';
      primaryVal = 45.0;
      attrs = {
        'artMode': true,
        'lightSync': true,
        'selectedArtwork': 'Starry Night',
      };
    }

    final devId = 'samsung_qr_${DateTime.now().millisecondsSinceEpoch % 100000}';
    final dev = RealSmartDevice(
      id: devId,
      name: name,
      room: room,
      category: category,
      protocol: ConnectionProtocol.smartThingsCloud,
      credentials: {'vendor': 'demo', 'token': 'demo_st_qr_token', 'qr_payload': text},
      isOn: true,
      isOnline: true,
      primaryValue: primaryVal,
      liveAttributes: attrs,
    );

    return ParsedQrDevice(
      providerId: 'samsung_smartthings',
      providerName: 'Samsung SmartThings',
      brandColor: const Color(0xFF1428A0),
      icon: Icons.local_laundry_service_rounded,
      device: dev,
      pairingProtocol: 'SmartThings OCF / Matter Wi-Fi',
      rawCode: text,
    );
  }

  ParsedQrDevice _parseLgThinqQr(String text) {
    final lower = text.toLowerCase();
    String category = 'ac';
    String name = 'LG ThinQ DualCool™ AI AC';
    String room = 'Living Room';
    double primaryVal = 23.0;
    Map<String, dynamic> attrs = {
      'mode': 'cool',
      'fanSpeed': 'auto',
      'jetCool': true,
      'goodSleep': false,
      'roomTemp': 24.0,
      'pm1_0': 10,
    };

    if (lower.contains('washer') || lower.contains('washtower') || lower.contains('laundry')) {
      category = 'washer';
      name = 'LG WashTower™ AI DD Washer & Dryer';
      room = 'Laundry';
      primaryVal = 1400.0;
      attrs = {
        'turboWash360': true,
        'ezDispenseDetergent': 85,
        'ezDispenseSoftener': 70,
        'smartPairing': true,
        'stage': 'rinse',
        'remainingMinutes': 24,
      };
    } else if (lower.contains('fridge') || lower.contains('instaview') || lower.contains('refrigerator')) {
      category = 'fridge';
      name = 'LG InstaView™ Door-in-Door Refrigerator';
      room = 'Kitchen';
      primaryVal = 2.0;
      attrs = {
        'instaViewTransparent': true,
        'craftIce': true,
        'doorCooling': true,
        'fridgeTemp': 2.0,
        'freezerTemp': -20.0,
      };
    } else if (lower.contains('aero') || lower.contains('purifier') || lower.contains('tower')) {
      category = 'fan';
      name = 'LG PuriCare™ AeroTower Air Purifier';
      room = 'Living Room';
      primaryVal = 3.0;
      attrs = {
        'cleanBoosterTilt': 55,
        'airflowMode': 'Wide',
        'uvNano': true,
        'pm1Laser': 8,
      };
    } else if (lower.contains('styler') || lower.contains('steam')) {
      category = 'dryer';
      name = 'LG Styler® Steam Closet';
      room = 'Bedroom';
      primaryVal = 180.0;
      attrs = {
        'movingHangerSpeed': 'Fast',
        'movingHangerRpm': 180,
        'trueSteam': true,
        'pantsCrease': true,
      };
    }

    final devId = 'lg_qr_${DateTime.now().millisecondsSinceEpoch % 100000}';
    final dev = RealSmartDevice(
      id: devId,
      name: name,
      room: room,
      category: category,
      protocol: ConnectionProtocol.smartThingsCloud,
      credentials: {'vendor': 'demo', 'token': 'demo_lg_qr_token', 'qr_payload': text},
      isOn: true,
      isOnline: true,
      primaryValue: primaryVal,
      liveAttributes: attrs,
    );

    return ParsedQrDevice(
      providerId: 'lg_thinq',
      providerName: 'LG ThinQ',
      brandColor: const Color(0xFFA50034),
      icon: Icons.ac_unit_rounded,
      device: dev,
      pairingProtocol: 'LG ThinQ SoftAP / Wi-Fi Barcode',
      rawCode: text,
    );
  }

  ParsedQrDevice _parseWiproTuyaQr(String text) {
    final devId = 'wipro_qr_${DateTime.now().millisecondsSinceEpoch % 100000}';
    final dev = RealSmartDevice(
      id: devId,
      name: 'Wipro Next 9W Smart LED Bulb',
      room: 'Living Room',
      category: 'light',
      protocol: ConnectionProtocol.tuyaCloudDirect,
      credentials: {'vendor': 'demo', 'token': 'demo_wipro_qr_token', 'qr_payload': text},
      isOn: true,
      isOnline: true,
      primaryValue: 100.0,
      ratedMaxWatts: 9.0,
      liveAttributes: {
        'colorTemp': 'warm_white',
        'brightness': 100,
        'activeScene': 'Relax',
        'musicSync': true,
      },
    );

    return ParsedQrDevice(
      providerId: 'wipro_smart_next',
      providerName: 'Wipro Next Smart Home',
      brandColor: const Color(0xFF0052CC),
      icon: Icons.lightbulb_rounded,
      device: dev,
      pairingProtocol: 'Tuya Cloud & Local LAN (Port 6668)',
      rawCode: text,
    );
  }

  ParsedQrDevice _parsePhilipsHueQr(String text) {
    final devId = 'hue_bridge_qr_${DateTime.now().millisecondsSinceEpoch % 100000}';
    final dev = RealSmartDevice(
      id: devId,
      name: 'Philips Hue White & Color Ambiance',
      room: 'Living Room',
      category: 'light',
      protocol: ConnectionProtocol.philipsHueLocal,
      credentials: {'vendor': 'demo', 'bridgeIp': '192.168.1.55', 'username': 'hue_demo_user'},
      isOn: true,
      isOnline: true,
      primaryValue: 85.0,
      ratedMaxWatts: 9.5,
      liveAttributes: {'colorTemp': 'warm_amber', 'reachable': true},
    );

    return ParsedQrDevice(
      providerId: 'philips_hue',
      providerName: 'Philips Hue',
      brandColor: const Color(0xFF0066CC),
      icon: Icons.wb_incandescent_rounded,
      device: dev,
      pairingProtocol: 'Philips Hue Zigbee 3.0 Bridge Pushlink',
      rawCode: text,
    );
  }

  ParsedQrDevice _parsePhilipsWizQr(String text) {
    final devId = 'wiz_qr_${DateTime.now().millisecondsSinceEpoch % 100000}';
    final dev = RealSmartDevice(
      id: devId,
      name: 'Philips WiZ Smart Tunable Bulb',
      room: 'Bedroom',
      category: 'light',
      protocol: ConnectionProtocol.philipsWizUdp,
      credentials: {'vendor': 'demo', 'ip': '192.168.1.120', 'mac': 'a8bb50112233'},
      isOn: true,
      isOnline: true,
      primaryValue: 75.0,
      ratedMaxWatts: 8.5,
      liveAttributes: {'state': true, 'dimming': 75},
    );

    return ParsedQrDevice(
      providerId: 'philips_wiz',
      providerName: 'Philips WiZ',
      brandColor: const Color(0xFF6B38FB),
      icon: Icons.lightbulb_outline_rounded,
      device: dev,
      pairingProtocol: 'WiZ Local UDP (Port 38899)',
      rawCode: text,
    );
  }

  ParsedQrDevice _parseRealmeCameraQr(String text) {
    final devId = 'cam_realme_qr_${DateTime.now().millisecondsSinceEpoch % 100000}';
    final dev = RealSmartDevice(
      id: devId,
      name: 'Realme Smart Cam 360',
      room: 'Living Room',
      category: 'camera',
      protocol: ConnectionProtocol.rtspOnvifCamera,
      credentials: {
        'brand': 'realme',
        'ip': '192.168.1.88',
        'port': '554',
        'username': 'admin',
        'streamPath': '/live/ch0',
        'vendor': 'demo',
      },
      isOn: true,
      isOnline: true,
      primaryValue: 100.0,
      ratedMaxWatts: 4.5,
      liveAttributes: {'privacyMode': false, 'panAngle': 0.0, 'tiltAngle': 0.0},
    );

    return ParsedQrDevice(
      providerId: 'realme_camera',
      providerName: 'Realme Smart Cam 360',
      brandColor: const Color(0xFFFFB800),
      icon: Icons.videocam_rounded,
      device: dev,
      pairingProtocol: 'RTSP H.264 / ONVIF Profile S',
      rawCode: text,
    );
  }

  ParsedQrDevice _parsePhilipsCameraQr(String text) {
    final devId = 'cam_philips_qr_${DateTime.now().millisecondsSinceEpoch % 100000}';
    final dev = RealSmartDevice(
      id: devId,
      name: 'Philips Home Camera',
      room: 'Front Door',
      category: 'camera',
      protocol: ConnectionProtocol.rtspOnvifCamera,
      credentials: {
        'brand': 'philips',
        'ip': '192.168.1.89',
        'port': '554',
        'username': 'admin',
        'streamPath': '/ch0',
        'vendor': 'demo',
      },
      isOn: true,
      isOnline: true,
      primaryValue: 100.0,
      ratedMaxWatts: 4.5,
      liveAttributes: {'privacyMode': false, 'panAngle': 0.0, 'tiltAngle': 0.0},
    );

    return ParsedQrDevice(
      providerId: 'philips_camera',
      providerName: 'Philips Home Camera',
      brandColor: const Color(0xFF0066CC),
      icon: Icons.security_rounded,
      device: dev,
      pairingProtocol: 'RTSP 1080p Secure Stream',
      rawCode: text,
    );
  }

  ParsedQrDevice _parseTapoQr(String text) {
    final devId = 'tapo_qr_${DateTime.now().millisecondsSinceEpoch % 100000}';
    final dev = RealSmartDevice(
      id: devId,
      name: 'TP-Link Tapo Smart Wi-Fi Plug P110',
      room: 'Living Room',
      category: 'socket',
      protocol: ConnectionProtocol.homeAssistantBridge,
      credentials: {'vendor': 'demo', 'ip': '192.168.1.140'},
      isOn: true,
      isOnline: true,
      primaryValue: 100.0,
      liveAttributes: {'energyMonitoring': true, 'currentWatts': 18.2},
    );

    return ParsedQrDevice(
      providerId: 'tplink_tapo',
      providerName: 'TP-Link Tapo / Kasa',
      brandColor: const Color(0xFF4ACBD6),
      icon: Icons.power_rounded,
      device: dev,
      pairingProtocol: 'Tapo Local KLAP / Matter BLE',
      rawCode: text,
    );
  }

  ParsedQrDevice _parseMatterQr(String text) {
    final devId = 'matter_qr_${DateTime.now().millisecondsSinceEpoch % 100000}';
    final dev = RealSmartDevice(
      id: devId,
      name: 'Matter Certified Universal Appliance',
      room: 'Living Room',
      category: 'switch',
      protocol: ConnectionProtocol.homeAssistantBridge,
      credentials: {'vendor': 'demo', 'matter_code': text},
      isOn: true,
      isOnline: true,
      primaryValue: 100.0,
      liveAttributes: {'matterCommissioned': true, 'protocol': 'CHIP/Matter over Thread/Wi-Fi'},
    );

    return ParsedQrDevice(
      providerId: 'home_assistant',
      providerName: 'Matter / Home Assistant',
      brandColor: const Color(0xFF03A9F4),
      icon: Icons.hub_rounded,
      device: dev,
      pairingProtocol: 'Matter Standard CHIP QR Protocol',
      rawCode: text,
    );
  }

  ParsedQrDevice _parseGenericOrMatterQr(String text) {
    final devId = 'iot_qr_${DateTime.now().millisecondsSinceEpoch % 100000}';
    final dev = RealSmartDevice(
      id: devId,
      name: 'Universal Smart Appliance ($text)',
      room: 'Living Room',
      category: 'switch',
      protocol: ConnectionProtocol.smartThingsCloud,
      credentials: {'vendor': 'demo', 'payload': text},
      isOn: true,
      isOnline: true,
      primaryValue: 100.0,
      liveAttributes: {'raw_qr': text},
    );

    return ParsedQrDevice(
      providerId: 'home_assistant',
      providerName: 'Universal IoT Device',
      brandColor: const Color(0xFF30D158),
      icon: Icons.qr_code_2_rounded,
      device: dev,
      pairingProtocol: 'Universal Barcode / QR Stream',
      rawCode: text,
    );
  }

  // ---------------------------------------------------------------------------
  // SCAN OR TEST CODE HANDLERS
  // ---------------------------------------------------------------------------
  void _onQrDetected(String rawCode) {
    HapticFeedback.mediumImpact();
    final parsed = _decodeQrPayload(rawCode, _selectedProvider);
    if (parsed != null) {
      setState(() {
        _detectedDevice = parsed;
        _scanStatusText = 'Target Recognized: ${parsed.device.name}';
      });
    } else {
      setState(() {
        _scanStatusText = 'Unrecognized QR code format. Try again or paste code.';
      });
    }
  }

  Future<void> _pairDetectedDevice() async {
    if (_detectedDevice == null) return;
    setState(() => _isPairing = true);
    HapticFeedback.heavyImpact();

    final home = context.read<RealHomeProvider>();
    home.addDeviceDirect(_detectedDevice!.device);

    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() {
        _isPairing = false;
        _pairingSuccessMsg = 'Successfully Paired ${_detectedDevice!.device.name}!';
      });
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1C1C1E),
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: _detectedDevice!.brandColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Added ${_detectedDevice!.device.name} to ${_detectedDevice!.device.room} via ${_detectedDevice!.pairingProtocol}',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD METHOD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final providersList = [
      {'id': 'all', 'name': 'All Brands (Auto-Detect)', 'icon': Icons.auto_awesome_rounded, 'color': const Color(0xFF00D4FF)},
      {'id': 'samsung_smartthings', 'name': 'Samsung SmartThings', 'icon': Icons.local_laundry_service_rounded, 'color': const Color(0xFF1428A0)},
      {'id': 'lg_thinq', 'name': 'LG ThinQ', 'icon': Icons.ac_unit_rounded, 'color': const Color(0xFFA50034)},
      {'id': 'wipro_smart_next', 'name': 'Wipro Next / Tuya', 'icon': Icons.lightbulb_rounded, 'color': const Color(0xFF0052CC)},
      {'id': 'philips_hue', 'name': 'Philips Hue', 'icon': Icons.wb_incandescent_rounded, 'color': const Color(0xFF0066CC)},
      {'id': 'philips_wiz', 'name': 'Philips WiZ', 'icon': Icons.lightbulb_outline_rounded, 'color': const Color(0xFF6B38FB)},
      {'id': 'realme_camera', 'name': 'Realme Smart Cam', 'icon': Icons.videocam_rounded, 'color': const Color(0xFFFFB800)},
      {'id': 'philips_camera', 'name': 'Philips Home Cam', 'icon': Icons.security_rounded, 'color': const Color(0xFF0066CC)},
      {'id': 'tplink_tapo', 'name': 'TP-Link Tapo', 'icon': Icons.power_rounded, 'color': const Color(0xFF4ACBD6)},
      {'id': 'home_assistant', 'name': 'Matter / Universal Hub', 'icon': Icons.hub_rounded, 'color': const Color(0xFF03A9F4)},
    ];

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF0A0E17),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF00D4FF), size: 24),
                    SizedBox(width: 10),
                    Text(
                      'Scan Appliance QR Code',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Provider Filter Strip
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: providersList.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final p = providersList[i];
                final isSelected = _selectedProvider == p['id'];
                final Color color = p['color'] as Color;

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedProvider = p['id'] as String;
                      _detectedDevice = null;
                      _scanStatusText = 'Align ${p['name']} QR / Barcode in frame';
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withValues(alpha: 0.30) : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? color : Colors.white.withValues(alpha: 0.12),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(p['icon'] as IconData, size: 14, color: isSelected ? Colors.white : Colors.white70),
                        const SizedBox(width: 6),
                        Text(
                          p['name'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? Colors.white : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // Viewfinder / Detected Device Area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _detectedDevice != null
                  ? _buildDetectedResultCard()
                  : _buildHolographicViewfinder(),
            ),
          ),

          // Bottom Quick Preset & Manual Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Quick Test Presets Row (instant testing without physical labels)
                Row(
                  children: [
                    const Text(
                      'Quick Test QR:',
                      style: TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildPresetChip('Samsung Ecobubble', 'samsungce://pair?id=washer_eco_01&type=washer'),
                            _buildPresetChip('LG DualCool AC', 'lgthinq://device?id=lg_dualcool_01&cat=ac'),
                            _buildPresetChip('Wipro Smart Bulb', 'wipro://tuya?id=wipro_light_01&type=light'),
                            _buildPresetChip('Philips Hue Bridge', 'hue://bridge?ip=192.168.1.55'),
                            _buildPresetChip('Realme Cam 360', 'rtsp://admin:pass@192.168.1.88:554/live/ch0'),
                            _buildPresetChip('Matter Standard', 'MT:Y234567890123456'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Manual Input Expansion
                if (_showManualInput) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _manualCodeCtrl,
                          style: const TextStyle(fontSize: 13, color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Enter Matter code (MT:), URL, or token',
                            hintStyle: const TextStyle(fontSize: 12, color: Colors.white38),
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.08),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00D4FF),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          if (_manualCodeCtrl.text.trim().isNotEmpty) {
                            _onQrDetected(_manualCodeCtrl.text.trim());
                          }
                        },
                        child: const Text('Parse', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                // Action Bar: Torch, Paste from Clipboard, Manual Input Toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      icon: Icon(
                        _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                        color: _isTorchOn ? const Color(0xFFFFD60A) : Colors.white70,
                        size: 16,
                      ),
                      label: Text(
                        _isTorchOn ? 'Torch On' : 'Torch',
                        style: TextStyle(color: _isTorchOn ? const Color(0xFFFFD60A) : Colors.white70, fontSize: 12),
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => _isTorchOn = !_isTorchOn);
                      },
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.paste_rounded, color: Color(0xFF00D4FF), size: 16),
                      label: const Text('Paste Code', style: TextStyle(color: Color(0xFF00D4FF), fontSize: 12)),
                      onPressed: () async {
                        final data = await Clipboard.getData('text/plain');
                        if (data?.text != null && data!.text!.trim().isNotEmpty) {
                          _onQrDetected(data.text!.trim());
                        } else {
                          setState(() => _showManualInput = true);
                        }
                      },
                    ),
                    TextButton.icon(
                      icon: Icon(
                        _showManualInput ? Icons.keyboard_hide_rounded : Icons.keyboard_rounded,
                        color: Colors.white70,
                        size: 16,
                      ),
                      label: Text(
                        _showManualInput ? 'Hide Input' : 'Type Code',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      onPressed: () {
                        setState(() => _showManualInput = !_showManualInput);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, String payload) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => _onQrDetected(payload),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // VIEW RES: HOLOGRAPHIC SCANNER VIEWFINDER
  // ---------------------------------------------------------------------------
  Widget _buildHolographicViewfinder() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxSize = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth * 0.85
            : constraints.maxHeight * 0.75;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Dark camera background preview placeholder
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF141923),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
            ),

            // Scanning reticle box
            SizedBox(
              width: boxSize,
              height: boxSize,
              child: Stack(
                children: [
                  // Corner brackets
                  CustomPaint(
                    size: Size(boxSize, boxSize),
                    painter: _ReticleCornerPainter(color: const Color(0xFF00D4FF)),
                  ),

                  // Animated glowing horizontal laser
                  AnimatedBuilder(
                    animation: _laserAnim,
                    builder: (context, child) {
                      return Positioned(
                        top: boxSize * _laserAnim.value,
                        left: 12,
                        right: 12,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Colors.transparent,
                                Color(0xFF00D4FF),
                                Color(0xFF30D158),
                                Color(0xFF00D4FF),
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00D4FF).withValues(alpha: 0.8),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Center targeting crosshair
                  const Center(
                    child: Icon(
                      Icons.filter_center_focus_rounded,
                      color: Colors.white24,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ),

            // Status message pill
            Positioned(
              bottom: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Color(0xFF00D4FF)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _scanStatusText,
                      style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // VIEW RES: DETECTED RECOGNITION CARD & PAIRING CONFIRMATION
  // ---------------------------------------------------------------------------
  Widget _buildDetectedResultCard() {
    final dev = _detectedDevice!;
    final d = dev.device;

    return Center(
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF141A28),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: dev.brandColor.withValues(alpha: 0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: dev.brandColor.withValues(alpha: 0.35),
                blurRadius: 25,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon & Provider Brand Pill
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    backgroundColor: dev.brandColor,
                    radius: 20,
                    child: Icon(dev.icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    dev.providerName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: dev.brandColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Device Name
              Text(
                d.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),

              // Room & Protocol
              Text(
                'Assigned to ${d.room} • ${dev.pairingProtocol}',
                style: const TextStyle(fontSize: 12, color: Colors.white60),
              ),
              const SizedBox(height: 20),

              // Attribute Chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildAttrBadge('Status', 'Online & Verified', const Color(0xFF30D158)),
                  _buildAttrBadge('Room', d.room, const Color(0xFF00D4FF)),
                  _buildAttrBadge('Protocol', d.protocol.name, Colors.amber),
                  if (d.ratedMaxWatts > 0)
                    _buildAttrBadge('Rated', '${d.ratedMaxWatts.toStringAsFixed(0)} W', Colors.purpleAccent),
                ],
              ),
              const SizedBox(height: 24),

              if (_pairingSuccessMsg != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF30D158).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF30D158)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF30D158), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _pairingSuccessMsg!,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          setState(() {
                            _detectedDevice = null;
                            _scanStatusText = 'Align Device QR / Barcode in frame';
                          });
                        },
                        child: const Text('Scan Again'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: dev.brandColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _isPairing ? null : _pairDetectedDevice,
                        child: _isPairing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                              )
                            : const Text('Add to My Home', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttrBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

/// Custom Painter for 4 glowing reticle corner brackets
class _ReticleCornerPainter extends CustomPainter {
  final Color color;

  const _ReticleCornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLen = 28.0;

    // Top-Left
    canvas.drawLine(const Offset(0, 0), const Offset(cornerLen, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, cornerLen), paint);

    // Top-Right
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - cornerLen, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, cornerLen), paint);

    // Bottom-Left
    canvas.drawLine(Offset(0, size.height), Offset(cornerLen, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - cornerLen), paint);

    // Bottom-Right
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - cornerLen, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - cornerLen), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
