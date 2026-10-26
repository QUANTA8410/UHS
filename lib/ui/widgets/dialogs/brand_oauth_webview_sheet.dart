import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../providers/real_home_provider.dart';
import '../../../services/auth/brand_oauth_catalog.dart';
import '../../../services/real_iot_controller.dart';
import 'camera_cockpit_sheet.dart';
import 'universal_qr_scanner_sheet.dart';

class BrandOAuthWebViewSheet extends StatefulWidget {
  final BrandAuthProviderConfig brand;

  const BrandOAuthWebViewSheet({super.key, required this.brand});

  @override
  State<BrandOAuthWebViewSheet> createState() => _BrandOAuthWebViewSheetState();
}

class _BrandOAuthWebViewSheetState extends State<BrandOAuthWebViewSheet>
    with WidgetsBindingObserver {
  final TextEditingController _manualTokenCtrl = TextEditingController();

  // Wipro / Smart Life LAN controllers
  final TextEditingController _lanNameCtrl = TextEditingController(text: 'Wipro Smart Bulb');
  final TextEditingController _lanIpCtrl = TextEditingController();
  final TextEditingController _lanDevIdCtrl = TextEditingController();
  final TextEditingController _lanKeyCtrl = TextEditingController();
  int _wiproTabIndex = 0; // 0 = Out-of-App & Auto-Link, 1 = Local LAN
  bool _obscurePassword = true;

  // Philips Hue controllers
  final TextEditingController _hueBridgeIpCtrl = TextEditingController();
  List<String> _discoveredBridges = [];
  bool _isScanningBridges = false;

  // Philips WiZ controllers
  final TextEditingController _wizSubnetCtrl = TextEditingController(text: '192.168.1.');

  // Camera controllers
  final TextEditingController _camIpCtrl = TextEditingController();
  final TextEditingController _camPortCtrl = TextEditingController(text: '554');
  final TextEditingController _camUserCtrl = TextEditingController(text: 'admin');
  final TextEditingController _camPassCtrl = TextEditingController();
  final TextEditingController _camNameCtrl = TextEditingController();
  final TextEditingController _camRoomCtrl = TextEditingController(text: 'Living Room');

  // Home Assistant controller
  final TextEditingController _haHubUrlCtrl = TextEditingController(text: 'http://homeassistant.local:8123');

  bool _waitingForRealmeReturn = false;
  bool _waitingForPhilipsReturn = false;
  bool _isScanningCamera = false;
  List<String> _discoveredRealmeIps = [];
  List<String> _discoveredPhilipsIps = [];

  bool _isLinking = false;
  bool _useEmbeddedFallback = false;
  WebViewController? _webController;
  double _loadProgress = 0.0;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final vt = widget.brand.vendorType;
    final isNativeSheet = vt == 'wipro_tuya' ||
        vt == 'philips_hue' ||
        vt == 'philips_wiz' ||
        vt == 'realme_camera' ||
        vt == 'realme_cam' ||
        vt == 'philips_camera';

    if (vt == 'realme_camera' || vt == 'realme_cam') {
      _camNameCtrl.text = 'Realme Smart Cam 360';
    } else if (vt == 'philips_camera') {
      _camNameCtrl.text = 'Philips Home Camera';
    }

    if (!isNativeSheet) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _launchNativeChromeCustomTab();
      });
    } else if (vt == 'wipro_tuya') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _launchWiproOutAppLogin();
      });
    } else if (vt == 'philips_hue') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scanForHueBridges();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _manualTokenCtrl.dispose();
    _lanNameCtrl.dispose();
    _lanIpCtrl.dispose();
    _lanDevIdCtrl.dispose();
    _lanKeyCtrl.dispose();
    _hueBridgeIpCtrl.dispose();
    _wizSubnetCtrl.dispose();
    _camIpCtrl.dispose();
    _camPortCtrl.dispose();
    _camUserCtrl.dispose();
    _camPassCtrl.dispose();
    _camNameCtrl.dispose();
    _camRoomCtrl.dispose();
    _haHubUrlCtrl.dispose();
    super.dispose();
  }

  /// Automatically checks clipboard, scans local LAN or auto-scans Realme/Philips cameras the instant the user returns to the app
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final vt = widget.brand.vendorType;
    if (state == AppLifecycleState.resumed && !_isLinking) {
      if (_waitingForRealmeReturn && (vt == 'realme_camera' || vt == 'realme_cam')) {
        _waitingForRealmeReturn = false;
        _scanLocalSubnetForRealmeDevices();
      } else if (_waitingForPhilipsReturn && vt == 'philips_camera') {
        _waitingForPhilipsReturn = false;
        _scanLocalSubnetForPhilipsDevices();
      } else if (vt == 'wipro_tuya') {
        _scanAndLinkWiproBulbFromLan();
      } else if (vt != 'philips_hue' &&
          vt != 'philips_wiz' &&
          vt != 'realme_camera' &&
          vt != 'realme_cam' &&
          vt != 'philips_camera') {
        _checkClipboardForTokenAutomatically();
      }
    }
  }

  Future<void> _checkClipboardForTokenAutomatically() async {
    try {
      final clip = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clip?.text?.trim() ?? '';
      // Match SmartThings UUID (36 chars) or LG ThinQ PAT / Home Assistant JWT (>= 32 chars, no spaces)
      final looksLikeToken = text.length >= 32 &&
          !text.contains(' ') &&
          !text.startsWith('http');

      if (looksLikeToken && mounted) {
        _manualTokenCtrl.text = text;
        setState(() {
          _statusMessage = 'Token detected from clipboard! Linking ${widget.brand.brandName}...';
        });
        await _completeAccountLinking(text);
      }
    } catch (_) {}
  }

  /// Opens the official login page in Android's native Chrome Custom Tab:
  /// - 10x faster rendering (no WebView GPU bottleneck)
  /// - Full "Sign in with Google" / Apple / Samsung Pass support
  /// - Full 3rd-party cookie & popup window support
  Future<void> _launchNativeChromeCustomTab() async {
    final uri = Uri.parse(widget.brand.loginUrl);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.inAppBrowserView,
        browserConfiguration: const BrowserConfiguration(showTitle: true),
      );
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // If Custom Tabs fail on a custom ROM, initialize the lightweight embedded WebView
      _initLightweightEmbeddedWebView();
    }
  }

  void _initLightweightEmbeddedWebView() {
    final ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0A0F1D))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _loadProgress = p / 100.0);
          },
          onNavigationRequest: (req) {
            if (req.url.startsWith('unifiedhome://')) {
              final uri = Uri.parse(req.url);
              final token = uri.queryParameters['access_token'] ?? uri.queryParameters['code'];
              if (token != null && token.isNotEmpty) {
                _completeAccountLinking(token);
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.brand.loginUrl));

    setState(() {
      _webController = ctrl;
      _useEmbeddedFallback = true;
    });
  }

  Future<void> _launchWiproOutAppLogin() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _statusMessage = 'Launching official Wipro Next Smart Home portal / app...';
    });

    final wiproOAuthUri = Uri.parse(
      'https://px1.tuyain.com/oauth/authorize?client_id=oem_wipro_smartlife&response_type=code&redirect_uri=unifiedhome://oauth-callback',
    );
    try {
      final launched = await launchUrl(
        wiproOAuthUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await launchUrl(
          Uri.parse('https://www.wiproconsumerlighting.com/login'),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (_) {
      try {
        await launchUrl(
          Uri.parse('https://www.wiproconsumerlighting.com/login'),
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {}
    }
  }

  Future<void> _scanAndLinkWiproBulbFromLan() async {
    if (_isLinking) return;
    setState(() {
      _isLinking = true;
      _statusMessage = 'Scanning home Wi-Fi for active Wipro Next Smart Bulbs (Port 6668)...';
    });
    HapticFeedback.heavyImpact();

    try {
      final home = context.read<RealHomeProvider>();
      final count = await home.scanAndLinkWiproLanBulbs();
      if (mounted) {
        if (count > 0) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF30D158),
              content: Text(
                'Auto-detected & added $count Wipro Smart Bulb(s) on local Wi-Fi!',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          );
        } else {
          setState(() {
            _isLinking = false;
            _statusMessage = '0 Wipro bulbs responded on Port 6668. Ensure bulb is powered ON and phone is on same 2.4GHz Wi-Fi.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLinking = false;
          _statusMessage = 'LAN Scan Error: ${e.toString().replaceAll("Exception: ", "")}';
        });
      }
    }
  }

  Future<void> _pairWiproLanBulb() async {
    final ip = _lanIpCtrl.text.trim();
    final devId = _lanDevIdCtrl.text.trim();
    final key = _lanKeyCtrl.text.trim();
    final name = _lanNameCtrl.text.trim().isEmpty ? 'Wipro Smart Bulb' : _lanNameCtrl.text.trim();

    if (ip.isEmpty || devId.isEmpty || key.length != 16) {
      setState(() {
        _statusMessage = 'Requires valid IP, Device ID, and a 16-character LocalKey.';
      });
      return;
    }

    setState(() {
      _isLinking = true;
      _statusMessage = 'Connecting to bulb at $ip:6668...';
    });
    HapticFeedback.heavyImpact();

    try {
      final home = context.read<RealHomeProvider>();
      final bulb = RealSmartDevice(
        id: devId,
        name: name,
        room: 'Living Room',
        category: 'light',
        protocol: ConnectionProtocol.tuyaLocalLan,
        credentials: {
          'ip': ip,
          'localKey': key,
          'devId': devId,
        },
        isOn: false,
        isOnline: true,
      );
      await home.addDirectLanDevice(bulb);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF30D158),
            content: Text(
              'Added $name via Direct LAN ($ip)!',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLinking = false;
          _statusMessage = 'LAN Error: ${e.toString().replaceAll("Exception: ", "")}';
        });
      }
    }
  }

  Future<void> _completeAccountLinking(String token) async {
    final cleanToken = token.trim();
    if (cleanToken.isEmpty || _isLinking) return;

    setState(() {
      _isLinking = true;
      _statusMessage = 'Verifying ${widget.brand.brandName} credentials with cloud...';
    });
    HapticFeedback.heavyImpact();

    final home = context.read<RealHomeProvider>();
    try {
      int importedCount = 0;
      if (widget.brand.vendorType == 'lg_thinq') {
        importedCount = await home.linkLgThinqAccount(cleanToken);
      } else if (widget.brand.vendorType == 'smartthings') {
        importedCount = await home.linkSmartThingsAccount(cleanToken);
      } else if (widget.brand.vendorType == 'home_assistant') {
        final hubUrl = _haHubUrlCtrl.text.trim().isNotEmpty
            ? _haHubUrlCtrl.text.trim()
            : (home.linkedHomeAssistantHubUrl ?? 'http://homeassistant.local:8123');
        importedCount = await home.linkHomeAssistantHub(
          hubUrl,
          cleanToken,
        );
      } else if (widget.brand.vendorType == 'tplink_tapo') {
        final hubUrl = _haHubUrlCtrl.text.trim().isNotEmpty
            ? _haHubUrlCtrl.text.trim()
            : (home.linkedHomeAssistantHubUrl ?? 'http://homeassistant.local:8123');
        importedCount = await home.linkHomeAssistantHub(
          hubUrl,
          cleanToken,
        );
      } else {
        importedCount = await home.linkSmartThingsAccount(cleanToken);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF30D158),
            content: Text(
              'Connected ${widget.brand.brandName}! Imported $importedCount real device(s).',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLinking = false;
          _statusMessage = 'Connection Error: ${e.toString().replaceAll("Exception: ", "")}';
        });
      }
    }
  }

  Future<void> _scanForHueBridges() async {
    setState(() {
      _isScanningBridges = true;
      _statusMessage = 'Scanning network for Philips Hue Bridge...';
    });
    try {
      final home = context.read<RealHomeProvider>();
      final ips = await home.discoverHueBridgeIps();
      if (mounted) {
        setState(() {
          _isScanningBridges = false;
          _discoveredBridges = ips;
          if (ips.isNotEmpty) {
            _hueBridgeIpCtrl.text = ips.first;
            _statusMessage = 'Found Philips Hue Bridge at ${ips.first}!';
          } else {
            _statusMessage = 'No Hue Bridge auto-discovered. Please enter Bridge IP manually below.';
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isScanningBridges = false);
      }
    }
  }

  Future<void> _pairHuePushlink() async {
    final ip = _hueBridgeIpCtrl.text.trim();
    if (ip.isEmpty) {
      setState(() => _statusMessage = 'Please enter or scan for your Hue Bridge IP.');
      return;
    }

    setState(() {
      _isLinking = true;
      _statusMessage = 'Connecting to Hue Bridge at $ip...';
    });
    HapticFeedback.heavyImpact();

    final home = context.read<RealHomeProvider>();
    try {
      final username = await home.pairHueBridge(ip);
      final count = await home.linkPhilipsHueBridge(bridgeIp: ip, username: username);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF30D158),
            content: Text(
              'Paired Philips Hue Bridge! Imported $count light(s).',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errText = e.toString().replaceAll('Exception: ', '');
        setState(() {
          _isLinking = false;
          _statusMessage = errText;
        });
      }
    }
  }

  Future<void> _scanAndPairWiz() async {
    final subnet = _wizSubnetCtrl.text.trim();
    setState(() {
      _isLinking = true;
      _statusMessage = 'Broadcasting UDP discovery packet to $subnet... (Port 38899)';
    });
    HapticFeedback.heavyImpact();

    final home = context.read<RealHomeProvider>();
    try {
      final count = await home.linkPhilipsWizLights(
        subnet: subnet.isNotEmpty ? subnet : '192.168.1.',
      );

      if (mounted) {
        if (count > 0) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF30D158),
              content: Text(
                'Connected $count Philips WiZ Wi-Fi light(s) via local UDP!',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          );
        } else {
          setState(() {
            _isLinking = false;
            _statusMessage = '0 WiZ lights responded. Verify your phone and bulbs are on the same Wi-Fi network.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLinking = false;
          _statusMessage = 'WiZ Scan Error: ${e.toString().replaceAll("Exception: ", "")}';
        });
      }
    }
  }

  Future<void> _launchRealmeLinkApp() async {
    setState(() {
      _waitingForRealmeReturn = true;
      _statusMessage = 'Launching official Realme Link app...';
    });
    HapticFeedback.mediumImpact();

    try {
      const channel = MethodChannel('com.antigravity.home/notifications');
      final bool launched = await channel.invokeMethod<bool>('launchExternalApp', {
        'packageName': 'com.realme.link',
      }) ?? false;

      if (!launched) {
        final marketUri = Uri.parse('market://details?id=com.realme.link');
        final webUri = Uri.parse('https://www.realme.com/in/realme-link');
        if (await canLaunchUrl(marketUri)) {
          await launchUrl(marketUri, mode: LaunchMode.externalApplication);
        } else {
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (_) {
      final webUri = Uri.parse('https://www.realme.com/in/realme-link');
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _scanLocalSubnetForRealmeDevices() async {
    if (_isScanningCamera) return;
    setState(() {
      _isScanningCamera = true;
      _statusMessage = 'Scanning local Wi-Fi subnet for Realme Cam (Ports 554, 8554, 8000)...';
    });

    final discovered = <String>{};
    try {
      String subnetPrefix = '192.168.1.';
      try {
        final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4,
          includeLoopback: false,
        );
        for (final iface in interfaces) {
          for (final addr in iface.addresses) {
            if (!addr.isLoopback && addr.address.contains('.')) {
              final parts = addr.address.split('.');
              if (parts.length == 4) {
                subnetPrefix = '${parts[0]}.${parts[1]}.${parts[2]}.';
                break;
              }
            }
          }
        }
      } catch (_) {}

      final portsToProbe = [554, 8554, 8000];
      const batchSize = 25;
      for (int i = 1; i <= 254; i += batchSize) {
        final batch = <Future<void>>[];
        for (int j = i; j < i + batchSize && j <= 254; j++) {
          final host = '$subnetPrefix$j';
          batch.add(() async {
            for (final port in portsToProbe) {
              try {
                final s = await Socket.connect(host, port, timeout: const Duration(milliseconds: 350));
                try {
                  discovered.add(host);
                  break;
                } finally {
                  s.destroy();
                }
              } catch (_) {}
            }
          }());
        }
        await Future.wait(batch);
        if (discovered.isNotEmpty && mounted) {
          setState(() {
            _discoveredRealmeIps = discovered.toList();
            if (_camIpCtrl.text.isEmpty) {
              _camIpCtrl.text = discovered.first;
            }
          });
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isScanningCamera = false;
        _discoveredRealmeIps = discovered.toList();
        if (discovered.isNotEmpty) {
          if (_camIpCtrl.text.isEmpty || !_discoveredRealmeIps.contains(_camIpCtrl.text)) {
            _camIpCtrl.text = discovered.first;
          }
          _statusMessage = 'Found ${discovered.length} camera target(s): ${discovered.join(", ")}';
        } else {
          _statusMessage = 'No camera auto-detected on ports 554/8554/8000. Enter Camera IP manually.';
        }
      });
    }
  }

  Future<void> _launchPhilipsApp() async {
    setState(() {
      _waitingForPhilipsReturn = true;
      _statusMessage = 'Launching official Philips Home Safety / Access app...';
    });
    HapticFeedback.mediumImpact();

    try {
      const channel = MethodChannel('com.antigravity.home/notifications');
      final bool launched = await channel.invokeMethod<bool>('launchFirstInstalledApp', {
        'packages': [
          'com.philips.homesafety',
          'com.philips.homesafety.app',
          'com.philips.homeaccess',
          'com.philips.cl.homeaccess',
        ],
      }) ?? false;

      if (!launched) {
        final marketUri = Uri.parse('market://details?id=com.philips.homesafety');
        final webUri = Uri.parse('https://play.google.com/store/apps/details?id=com.philips.homesafety');
        if (await canLaunchUrl(marketUri)) {
          await launchUrl(marketUri, mode: LaunchMode.externalApplication);
        } else {
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (_) {
      final webUri = Uri.parse('https://play.google.com/store/apps/details?id=com.philips.homesafety');
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _scanLocalSubnetForPhilipsDevices() async {
    if (_isScanningCamera) return;
    setState(() {
      _isScanningCamera = true;
      _statusMessage = 'Scanning local Wi-Fi subnet for Philips Camera (Ports 554, 8554, 80, 8080)...';
    });

    final discovered = <String>{};
    try {
      String subnetPrefix = '192.168.1.';
      try {
        final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4,
          includeLoopback: false,
        );
        for (final iface in interfaces) {
          for (final addr in iface.addresses) {
            if (!addr.isLoopback && addr.address.contains('.')) {
              final parts = addr.address.split('.');
              if (parts.length == 4) {
                subnetPrefix = '${parts[0]}.${parts[1]}.${parts[2]}.';
                break;
              }
            }
          }
        }
      } catch (_) {}

      final portsToProbe = [554, 8554, 80, 8080];
      const batchSize = 25;
      for (int i = 1; i <= 254; i += batchSize) {
        final batch = <Future<void>>[];
        for (int j = i; j < i + batchSize && j <= 254; j++) {
          final host = '$subnetPrefix$j';
          batch.add(() async {
            for (final port in portsToProbe) {
              try {
                final s = await Socket.connect(host, port, timeout: const Duration(milliseconds: 350));
                try {
                  discovered.add(host);
                  break;
                } finally {
                  s.destroy();
                }
              } catch (_) {}
            }
          }());
        }
        await Future.wait(batch);
        if (discovered.isNotEmpty && mounted) {
          setState(() {
            _discoveredPhilipsIps = discovered.toList();
            if (_camIpCtrl.text.isEmpty) {
              _camIpCtrl.text = discovered.first;
            }
          });
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isScanningCamera = false;
        _discoveredPhilipsIps = discovered.toList();
        if (discovered.isNotEmpty) {
          if (_camIpCtrl.text.isEmpty || !_discoveredPhilipsIps.contains(_camIpCtrl.text)) {
            _camIpCtrl.text = discovered.first;
          }
          _statusMessage = 'Found ${discovered.length} Philips camera target(s): ${discovered.join(", ")}';
        } else {
          _statusMessage = 'No Philips camera auto-detected on ports 554/8554/80/8080. Enter Camera IP manually.';
        }
      });
    }
  }

  Future<void> _connectCamera() async {
    final ip = _camIpCtrl.text.trim();
    final port = _camPortCtrl.text.trim();
    final username = _camUserCtrl.text.trim();
    final password = _camPassCtrl.text;
    final customName = _camNameCtrl.text.trim();
    final room = _camRoomCtrl.text.trim().isEmpty ? 'Living Room' : _camRoomCtrl.text.trim();

    if (ip.isEmpty) {
      setState(() => _statusMessage = 'Please enter the Camera IP address.');
      return;
    }

    final isRealme = widget.brand.vendorType == 'realme_camera' || widget.brand.vendorType == 'realme_cam';
    final brand = isRealme ? 'realme' : 'philips';

    setState(() {
      _isLinking = true;
      _statusMessage = 'Probing RTSP socket connection at $ip:${port.isEmpty ? "554" : port}...';
    });
    HapticFeedback.heavyImpact();

    final home = context.read<RealHomeProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final rootContext = Navigator.of(context).context;

    try {
      final cam = await home.linkRtspCamera(
        brand: brand,
        ip: ip,
        port: port.isEmpty ? '554' : port,
        username: username,
        password: password,
        room: room,
        customName: customName.isNotEmpty ? customName : null,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF30D158),
            content: Text(
              'Connected ${cam.name}! Live 1080p RTSP Stream & Controls Active.',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        );

        if (rootContext.mounted) {
          showModalBottomSheet(
            context: rootContext,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            barrierColor: Colors.black.withValues(alpha: 0.65),
            builder: (ctx) => CameraCockpitSheet(
              device: cam,
              iot: home.iot,
              onStateChanged: () => home.notifyUi(),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLinking = false;
          _statusMessage = 'Camera Connection Error: ${e.toString().replaceAll("Exception: ", "")}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWipro = widget.brand.vendorType == 'wipro_tuya';
    final isHue = widget.brand.vendorType == 'philips_hue';
    final isWiz = widget.brand.vendorType == 'philips_wiz';
    final isCamera = widget.brand.vendorType == 'realme_camera' ||
        widget.brand.vendorType == 'realme_cam' ||
        widget.brand.vendorType == 'philips_camera';

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: const Color(0xFF0B1020),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(color: Colors.white24, width: 1.1),
      ),
      child: Column(
        children: [
          // Top Header
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: widget.brand.brandColor,
                  radius: 18,
                  child: Icon(widget.brand.icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connect ${widget.brand.brandName}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        isWipro
                            ? 'Native Indian Cloud Sign-In & Local LAN Control'
                            : isHue
                                ? 'Auto-Discovery & 1-Tap Physical Pushlink Pairing'
                                : isWiz
                                    ? 'Local UDP Port 38899 Auto-Discovery'
                                    : isCamera
                                        ? 'Local RTSP/ONVIF Stream & PTZ Controls'
                                        : 'Fast Native Chrome Sign-In (Supports Google Login)',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF30D158)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),

          // Scan Brand QR Code Action Card (Available for EVERY supported provider)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                UniversalQrScannerSheet.show(context, initialProvider: widget.brand.id);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.brand.brandColor.withValues(alpha: 0.35),
                      const Color(0xFF00D4FF).withValues(alpha: 0.20),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: widget.brand.brandColor.withValues(alpha: 0.60)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF00D4FF), size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Scan ${widget.brand.brandName} QR Code',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 1),
                          const Text(
                            'Instant camera pairing via appliance barcode / Matter payload',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 14),
                  ],
                ),
              ),
            ),
          ),

          if (_statusMessage != null)
            Container(
              width: double.infinity,
              color: const Color(0xFF0A84FF).withValues(alpha: 0.22),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                _statusMessage!,
                style: const TextStyle(color: Colors.white, fontSize: 12.5),
              ),
            ),

          if (isWipro)
            Expanded(child: _buildWiproNativeView())
          else if (isHue)
            Expanded(child: _buildPhilipsHueView())
          else if (isWiz)
            Expanded(child: _buildPhilipsWizView())
          else if (isCamera)
            Expanded(child: _buildCameraSetupView())
          else if (_useEmbeddedFallback && _webController != null) ...[
            if (_loadProgress < 1.0)
              LinearProgressIndicator(value: _loadProgress, color: widget.brand.brandColor),
            Expanded(child: WebViewWidget(controller: _webController!)),
          ] else
            Expanded(child: _buildStandardOAuthView()),
        ],
      ),
    );
  }

  Widget _buildWiproNativeView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Segmented Tab Switcher (Direct Cloud vs Local LAN)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _wiproTabIndex = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _wiproTabIndex == 0
                            ? const Color(0xFFFF6B00)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Out-of-App & Auto-Link',
                        style: TextStyle(
                          color: _wiproTabIndex == 0 ? Colors.white : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _wiproTabIndex = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _wiproTabIndex == 1
                            ? const Color(0xFF00D4FF)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Manual LAN Key',
                        style: TextStyle(
                          color: _wiproTabIndex == 1 ? Colors.white : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          if (_wiproTabIndex == 0) ...[
            // Out-of-App Handoff & Auto-Link Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.open_in_new_rounded, color: Color(0xFFFF6B00), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Wipro Next Smart Home Handoff',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Authenticate securely in the official Wipro Next Smart Home App or browser portal. Once paired, Unified Home automatically discovers and controls your bulb over local Wi-Fi with zero lag.',
                    style: TextStyle(fontSize: 12, color: Colors.white60, height: 1.35),
                  ),
                  const SizedBox(height: 16),

                  // Step 1: Open Portal / App
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B00),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.launch_rounded),
                      label: const Text(
                        '1. Open Wipro Next Portal / App',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                      ),
                      onPressed: _launchWiproOutAppLogin,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Step 2: Auto-detect LAN Bulbs
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00D4FF),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: _isLinking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Icon(Icons.wifi_find_rounded),
                      label: Text(
                        _isLinking ? 'Scanning Local Wi-Fi (Port 6668)...' : '2. Auto-Detect Bulbs on Wi-Fi',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                      ),
                      onPressed: _isLinking ? null : _scanAndLinkWiproBulbFromLan,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Auto-watcher pill
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.sensors_rounded, color: Color(0xFF30D158), size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Background Watcher Active: Switching back to Unified Home after logging into Wipro will auto-scan Wi-Fi for your bulb.',
                            style: TextStyle(fontSize: 11.5, color: Colors.white70, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Local LAN Key Form
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.router_rounded, color: Color(0xFF00D4FF), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Direct Local LAN Control (Offline)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Direct encrypted Wi-Fi packets (port 6668). Zero internet or cloud dependency.',
                    style: TextStyle(fontSize: 12, color: Colors.white60, height: 1.35),
                  ),
                  const SizedBox(height: 16),

                  // Bulb Name
                  TextField(
                    controller: _lanNameCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Device Name',
                      labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                      hintText: 'e.g. Living Room Bulb',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.07),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Bulb IP Address
                  TextField(
                    controller: _lanIpCtrl,
                    keyboardType: TextInputType.datetime,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Bulb IP Address (on Local Wi-Fi)',
                      labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                      hintText: 'e.g. 192.168.1.105',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.07),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Device ID
                  TextField(
                    controller: _lanDevIdCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Device ID (Tuya/Wipro devId)',
                      labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                      hintText: 'e.g. bf8102938475a1b2',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.07),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 16-char LocalKey
                  TextField(
                    controller: _lanKeyCtrl,
                    maxLength: 16,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: '16-Character LocalKey (AES-128)',
                      labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                      hintText: '16 hex or ASCII characters',
                      hintStyle: const TextStyle(color: Colors.white30),
                      counterStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.07),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Pair LAN Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00D4FF),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: _isLinking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Icon(Icons.link_rounded),
                      label: Text(
                        _isLinking ? 'Connecting over LAN...' : 'Pair Local LAN Bulb',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                      ),
                      onPressed: _isLinking ? null : _pairWiproLanBulb,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStandardOAuthView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step-by-Step Guide Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'How Fast Account Linking Works:',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                _buildStepRow(
                  '1',
                  'Sign in with Google or your ${widget.brand.brandName} account in the native browser window.',
                ),
                const SizedBox(height: 8),
                _buildStepRow(
                  '2',
                  widget.brand.vendorType == 'lg_thinq'
                      ? 'On the LG ThinQ page, tap "Add Token", select your AC/appliances, and tap Copy.'
                      : 'Tap "Generate Token", check Devices, and tap Copy.',
                ),
                const SizedBox(height: 8),
                _buildStepRow(
                  '3',
                  'Close the browser tab (X) — this app will automatically detect your copied token from your clipboard and import your devices!',
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.brand.brandColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.open_in_browser_rounded),
                    label: Text(
                      'Open ${widget.brand.brandName} Login Page (Google Sign-In Ready)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: _launchNativeChromeCustomTab,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (widget.brand.vendorType == 'home_assistant') ...[
            const Text(
              'Home Assistant Hub URL / IP Address:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _haHubUrlCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'http://homeassistant.local:8123 or http://192.168.1.x:8123',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.07),
                prefixIcon: const Icon(Icons.dns_rounded, color: Color(0xFF03A9F4), size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          const Text(
            'Or Paste / Verify Your Token Directly:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _manualTokenCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Paste token here or tap Auto-Paste below...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.07),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                tooltip: 'Paste from Clipboard',
                icon: const Icon(Icons.content_paste_rounded, color: Color(0xFF00D4FF)),
                onPressed: () async {
                  final clip = await Clipboard.getData(Clipboard.kTextPlain);
                  if (clip?.text != null) {
                    _manualTokenCtrl.text = clip!.text!.trim();
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF30D158),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: _isLinking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline_rounded),
              label: Text(
                _isLinking ? 'Connecting Appliances...' : 'Link Account & Import Devices',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              onPressed: _isLinking
                  ? null
                  : () => _completeAccountLinking(_manualTokenCtrl.text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhilipsHueView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.hub_rounded, color: Color(0xFF0066CC), size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Philips Hue Bridge Auto-Discovery',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Auto-discovers the Bridge IP using the official MeetHue API and local subnet scan on port 80.',
                  style: TextStyle(fontSize: 12, color: Colors.white60, height: 1.35),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _hueBridgeIpCtrl,
                        keyboardType: TextInputType.datetime,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Hue Bridge IP',
                          labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                          hintText: 'e.g. 192.168.1.15',
                          hintStyle: const TextStyle(color: Colors.white30),
                          prefixIcon: const Icon(Icons.router_rounded, color: Colors.white54, size: 20),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.07),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0066CC),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: _isScanningBridges
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.radar_rounded, size: 18),
                      label: const Text('Scan', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _isScanningBridges ? null : _scanForHueBridges,
                    ),
                  ],
                ),
                if (_discoveredBridges.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: _discoveredBridges.map((ip) {
                      return ActionChip(
                        avatar: const Icon(Icons.check_circle_rounded, color: Color(0xFF30D158), size: 16),
                        label: Text(ip, style: const TextStyle(color: Colors.white, fontSize: 12)),
                        backgroundColor: const Color(0xFF0066CC).withValues(alpha: 0.3),
                        onPressed: () => setState(() => _hueBridgeIpCtrl.text = ip),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Pushlink Instructions Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF0066CC).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFF0066CC).withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.touch_app_rounded, color: Color(0xFF00D4FF), size: 24),
                    SizedBox(width: 10),
                    Text(
                      '1-Tap Pushlink Button Pairing',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  '1. Press the big physical round button in the center of your Philips Hue Bridge.\n2. Tap "Pair & Import Hue Lights" below within 30 seconds.',
                  style: TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.4),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0066CC),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: _isLinking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.link_rounded),
                    label: Text(
                      _isLinking ? 'Authenticating with Bridge...' : 'Pair & Import Hue Lights',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                    ),
                    onPressed: _isLinking ? null : _pairHuePushlink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhilipsWizView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.wifi_tethering_rounded, color: Color(0xFF6B38FB), size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Philips WiZ Local UDP (Port 38899)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Discovers WiZ smart bulbs across your local Wi-Fi without cloud credentials or internet dependence.',
                  style: TextStyle(fontSize: 12, color: Colors.white60, height: 1.35),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _wizSubnetCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Local Wi-Fi Subnet Prefix',
                    labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                    hintText: 'e.g. 192.168.1.',
                    hintStyle: const TextStyle(color: Colors.white30),
                    prefixIcon: const Icon(Icons.network_check_rounded, color: Colors.white54, size: 20),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.07),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B38FB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: _isLinking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.radar_rounded),
                    label: Text(
                      _isLinking ? 'Broadcasting UDP on Port 38899...' : 'Scan & Import WiZ Lights',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                    ),
                    onPressed: _isLinking ? null : _scanAndPairWiz,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraSetupView() {
    final isRealme = widget.brand.vendorType == 'realme_camera' || widget.brand.vendorType == 'realme_cam';
    final brandColor = widget.brand.brandColor;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isRealme) ...[
            // 1. Realme Link App Handoff Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.open_in_new_rounded, color: Color(0xFFFFB800), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Official Realme Link App Handoff',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Configure your Realme Camera in the official Realme Link app to enable local RTSP / PC View mode.',
                    style: TextStyle(fontSize: 12, color: Colors.white60, height: 1.35),
                  ),
                  const SizedBox(height: 16),

                  // Button 1: Open Official Realme Link App
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFB800),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.launch_rounded, color: Colors.black),
                      label: const Text(
                        '1. Open Official Realme Link App',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                      ),
                      onPressed: _launchRealmeLinkApp,
                    ),
                  ),

                  // Step-by-Step Guide Card Inside the Sheet
                  Container(
                    margin: const EdgeInsets.only(top: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: Color(0xFFFFB800), size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Step-by-Step Instructions',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'In Realme Link \u2192 Tap your Realme Camera \u2192 Settings (\u2699) at top right \u2192 Tap "PC View" (or NAS/RTSP) \u2192 Toggle ON and note your Username & Password.',
                          style: TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.4),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _waitingForRealmeReturn
                              ? 'Waiting for you to return from Realme Link... Subnet auto-scan will trigger immediately upon return!'
                              : 'When you return to Unified Home, local camera discovery will run automatically.',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontStyle: FontStyle.italic,
                            color: _waitingForRealmeReturn ? const Color(0xFF30D158) : Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ] else ...[
            // 1. Philips Home Safety & Access App Handoff Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.open_in_new_rounded, color: Color(0xFF0066CC), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Official Philips Home Safety Handoff',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Configure your Philips Camera in the official Philips Home Safety or Philips Home Access app to enable local RTSP stream & PC View mode.',
                    style: TextStyle(fontSize: 12, color: Colors.white60, height: 1.35),
                  ),
                  const SizedBox(height: 16),

                  // Button 1: Open Official Philips Home Safety / Access App
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0066CC),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.launch_rounded, color: Colors.white),
                      label: const Text(
                        '1. Open Philips Home Safety / Access App',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                      ),
                      onPressed: _launchPhilipsApp,
                    ),
                  ),

                  // Step-by-Step Guide Card Inside the Sheet
                  Container(
                    margin: const EdgeInsets.only(top: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: Color(0xFF0066CC), size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Step-by-Step Instructions',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'In Philips Home Safety (or Home Access) \u2192 Select your Camera \u2192 Device Settings (\u2699) \u2192 Local RTSP / PC View Streaming \u2192 Enable and note your Port & Password.',
                          style: TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.4),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _waitingForPhilipsReturn
                              ? 'Waiting for you to return from Philips Home Safety... Subnet auto-scan will trigger immediately upon return!'
                              : 'When you return to Unified Home, local camera discovery will run automatically.',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontStyle: FontStyle.italic,
                            color: _waitingForPhilipsReturn ? const Color(0xFF30D158) : Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          // 2. Camera Credentials & Link Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isRealme ? Icons.videocam_rounded : Icons.security_rounded,
                      color: brandColor,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isRealme
                            ? 'Realme RTSP & Auto-Discovery'
                            : 'Philips RTSP & Auto-Discovery',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: brandColor,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      icon: _isScanningCamera
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: brandColor),
                            )
                          : const Icon(Icons.radar_rounded, size: 16),
                      label: Text(
                        _isScanningCamera ? 'Scanning...' : 'Scan Wi-Fi',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _isScanningCamera
                          ? null
                          : (isRealme ? _scanLocalSubnetForRealmeDevices : _scanLocalSubnetForPhilipsDevices),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  isRealme
                      ? 'Local RTSP stream + 360\u00b0 PTZ pan-tilt directional controls and privacy mode.'
                      : 'Local 1080p RTSP live video monitor with privacy standby.',
                  style: const TextStyle(fontSize: 12, color: Colors.white60, height: 1.35),
                ),
                if ((isRealme ? _discoveredRealmeIps : _discoveredPhilipsIps).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Discovered Camera Targets:',
                    style: TextStyle(fontSize: 11.5, color: Colors.white60, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: (isRealme ? _discoveredRealmeIps : _discoveredPhilipsIps).map((ip) {
                      final isSelected = _camIpCtrl.text == ip;
                      return ActionChip(
                        avatar: Icon(
                          isSelected ? Icons.check_circle_rounded : Icons.videocam_rounded,
                          color: isSelected ? const Color(0xFF30D158) : Colors.white70,
                          size: 16,
                        ),
                        label: Text(
                          ip,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        backgroundColor: isSelected
                            ? brandColor.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.08),
                        onPressed: () => setState(() => _camIpCtrl.text = ip),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 16),

                // Camera Name & Room
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: TextField(
                        controller: _camNameCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Camera Name',
                          labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                          hintText: widget.brand.brandName,
                          hintStyle: const TextStyle(color: Colors.white30),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.07),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: _camRoomCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Room',
                          labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                          hintText: 'Living Room',
                          hintStyle: const TextStyle(color: Colors.white30),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.07),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // IP Address & Port
                Row(
                  children: [
                    Expanded(
                      flex: 7,
                      child: TextField(
                        controller: _camIpCtrl,
                        keyboardType: TextInputType.datetime,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: isRealme ? 'Camera IP (Auto-Discovered)' : 'Camera Local IP',
                          labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                          hintText: 'e.g. 192.168.1.120',
                          hintStyle: const TextStyle(color: Colors.white30),
                          prefixIcon: const Icon(Icons.wifi_rounded, color: Colors.white54, size: 20),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.07),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _camPortCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Port',
                          labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                          hintText: '554',
                          hintStyle: const TextStyle(color: Colors.white30),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.07),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Username & Password
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _camUserCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: isRealme ? 'PC View Username' : 'RTSP / ONVIF Username',
                          labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                          hintText: 'admin',
                          hintStyle: const TextStyle(color: Colors.white30),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.07),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _camPassCtrl,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: isRealme ? 'PC View Password' : 'RTSP / ONVIF Password',
                          labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                          hintText: '\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022',
                          hintStyle: const TextStyle(color: Colors.white30),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                              color: Colors.white54,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.07),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Link Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandColor,
                      foregroundColor: isRealme ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: _isLinking
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: isRealme ? Colors.black : Colors.white,
                            ),
                          )
                        : Icon(isRealme ? Icons.videocam_rounded : Icons.security_rounded),
                    label: Text(
                      _isLinking
                          ? 'Testing RTSP Stream...'
                          : isRealme
                              ? 'Link Realme Device & Open Live Feed'
                              : 'Link Philips Camera & Open Live Feed',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                    ),
                    onPressed: _isLinking ? null : _connectCamera,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow(String numStr, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF0A84FF),
          ),
          child: Text(
            numStr,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.35),
          ),
        ),
      ],
    );
  }
}
