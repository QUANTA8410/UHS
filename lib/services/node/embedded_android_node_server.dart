import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../providers/real_home_provider.dart';
import '../real_iot_controller.dart';

/// 24/7 Always-On Android Home Node Server (`EmbeddedAndroidNodeServer` on Port 8765)
///
/// Turns an old Android phone into an Always-On Smart Home Hub:
/// 1. Runs embedded HTTP & WebSocket server on port 8765.
/// 2. Acquires Android Native CPU WakeLock & High-Perf WifiLock so the radio never sleeps.
/// 3. Serves an Apple Liquid Glass HTML5 Web Dashboard accessible from any browser on LAN.
/// 4. Provides REST API + real-time bi-directional WebSockets for external control.
class EmbeddedAndroidNodeServer extends ChangeNotifier {
  static const MethodChannel _keepAliveChannel =
      MethodChannel('com.antigravity.home/notifications');

  HttpServer? _server;
  final List<WebSocket> _wsClients = [];
  RealHomeProvider? _homeProvider;
  Timer? _telemetryTimer;

  int _port = 8765;
  String? _serverIp;
  DateTime? _startedAt;
  int _requestsHandled = 0;
  final List<String> _serverLogs = [];
  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  bool get isRunning => _server != null;
  int get port => _port;
  String? get serverIp => _serverIp;
  DateTime? get startedAt => _startedAt;
  int get connectedClientsCount => _wsClients.length;
  int get requestsHandled => _requestsHandled;
  List<String> get serverLogs => List.unmodifiable(_serverLogs);

  String get dashboardUrl =>
      _serverIp != null ? 'http://$_serverIp:$_port/' : 'http://localhost:$_port/';

  Duration get uptime => _startedAt != null
      ? DateTime.now().difference(_startedAt!)
      : Duration.zero;

  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    final entry = '[$timestamp] $message';
    _serverLogs.insert(0, entry);
    if (_serverLogs.length > 100) {
      _serverLogs.removeLast();
    }
    if (kDebugMode) {
      debugPrint('[NodeServer] $entry');
    }
  }

  /// Scans local network interfaces to determine the phone's LAN IPv4 address
  Future<String?> resolveLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && !addr.address.startsWith('127.')) {
            _serverIp = addr.address;
            return _serverIp;
          }
        }
      }
    } catch (e) {
      _log('Failed to resolve network interface: $e');
    }
    _serverIp ??= '127.0.0.1';
    return _serverIp;
  }

  /// Starts the 24/7 Node Server and acquires native Android WakeLock/WifiLock
  Future<bool> startServer(RealHomeProvider home, {int port = 8765}) async {
    if (isRunning) return true;
    _homeProvider = home;
    _port = port;

    await resolveLocalIp();

    try {
      // 1. Acquire Android WakeLock + WifiLock + Screen Keep-On
      await _enableNativeKeepAlive();

      // 2. Bind HTTP Server
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port, shared: true);
      _startedAt = DateTime.now();
      _log('Server listening on http://${_serverIp ?? "0.0.0.0"}:$_port');

      _server!.listen(
        _handleHttpRequest,
        onError: (e) {
          _log('HTTP Server Error: $e');
        },
        onDone: () {
          _log('HTTP Server Stopped');
        },
      );

      // 3. Listen to RealHomeProvider updates to broadcast to WebSocket clients
      _homeProvider?.addListener(_onHomeProviderUpdated);

      // 4. Heartbeat & Telemetry broadcast timer
      _telemetryTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        _broadcastStateSnapshot();
      });

      notifyListeners();
      return true;
    } catch (e) {
      _log('Failed to start Node Server on port $_port: $e');
      await stopServer();
      return false;
    }
  }

  /// Stops the 24/7 Node Server and releases WakeLock/WifiLock
  Future<void> stopServer() async {
    _telemetryTimer?.cancel();
    _telemetryTimer = null;

    _homeProvider?.removeListener(_onHomeProviderUpdated);

    for (final ws in List<WebSocket>.from(_wsClients)) {
      try {
        await ws.close(WebSocketStatus.normalClosure, 'Server shutting down');
      } catch (_) {}
    }
    _wsClients.clear();

    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }

    _startedAt = null;
    await _disableNativeKeepAlive();
    _log('Server terminated cleanly.');
    notifyListeners();
  }

  Future<void> _enableNativeKeepAlive() async {
    try {
      await _keepAliveChannel.invokeMethod('enableNodeKeepAlive');
      _log('Native Android WakeLock & WifiLock acquired.');
    } catch (e) {
      _log('KeepAlive MethodChannel error: $e');
    }
  }

  Future<void> _disableNativeKeepAlive() async {
    try {
      await _keepAliveChannel.invokeMethod('disableNodeKeepAlive');
      _log('Native Android WakeLock & WifiLock released.');
    } catch (_) {}
  }

  Future<Map<String, dynamic>> checkKeepAliveStatus() async {
    try {
      final res = await _keepAliveChannel.invokeMethod<Map<dynamic, dynamic>>('getNodeKeepAliveStatus');
      return res != null ? Map<String, dynamic>.from(res) : {};
    } catch (_) {
      return {};
    }
  }

  void _onHomeProviderUpdated() {
    _broadcastStateSnapshot();
    notifyListeners();
  }

  void _broadcastStateSnapshot() {
    if (_wsClients.isEmpty || _homeProvider == null) return;

    final snapshot = jsonEncode({
      'type': 'telemetry',
      'serverTime': DateTime.now().toIso8601String(),
      'uptimeSeconds': uptime.inSeconds,
      'totalWatts': _homeProvider!.totalLiveWatts,
      'devices': _homeProvider!.devices.map((d) => _deviceToMap(d)).toList(),
    });

    for (final ws in List<WebSocket>.from(_wsClients)) {
      try {
        if (ws.readyState == WebSocket.open) {
          ws.add(snapshot);
        }
      } catch (_) {
        _wsClients.remove(ws);
      }
    }
  }

  Map<String, dynamic> _deviceToMap(RealSmartDevice d) {
    return {
      'id': d.id,
      'name': d.name,
      'room': d.room,
      'category': d.category,
      'protocol': d.protocol.name,
      'isOn': d.isOn,
      'primaryValue': d.primaryValue,
      'liveWatts': d.liveWatts,
      'isOnline': d.isOnline,
      'liveAttributes': d.liveAttributes,
    };
  }

  Future<void> _handleHttpRequest(HttpRequest request) async {
    _requestsHandled++;
    final res = request.response;

    // Apply Global CORS Headers
    res.headers.set('Access-Control-Allow-Origin', '*');
    res.headers.set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    res.headers.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

    if (request.method == 'OPTIONS') {
      res.statusCode = HttpStatus.noContent;
      await res.close();
      return;
    }

    final path = request.uri.path;

    try {
      // 1. WebSocket Endpoint
      if (path == '/api/ws' || path == '/ws') {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          final ws = await WebSocketTransformer.upgrade(request);
          _wsClients.add(ws);
          _log('New WebSocket client connected (${_wsClients.length} active)');

          // Send immediate state payload
          if (_homeProvider != null) {
            ws.add(jsonEncode({
              'type': 'initial',
              'serverTime': DateTime.now().toIso8601String(),
              'uptimeSeconds': uptime.inSeconds,
              'totalWatts': _homeProvider!.totalLiveWatts,
              'devices': _homeProvider!.devices.map((d) => _deviceToMap(d)).toList(),
            }));
          }

          ws.listen(
            (data) => _handleWebSocketMessage(ws, data),
            onDone: () {
              _wsClients.remove(ws);
              _log('WebSocket client disconnected (${_wsClients.length} active)');
              notifyListeners();
            },
            onError: (_) {
              _wsClients.remove(ws);
              notifyListeners();
            },
          );
          notifyListeners();
          return;
        } else {
          res.statusCode = HttpStatus.badRequest;
          res.write('Expected WebSocket Upgrade Request');
          await res.close();
          return;
        }
      }

      // 2. REST API: Node Status
      if (path == '/api/status' && request.method == 'GET') {
        res.headers.contentType = ContentType.json;
        res.write(jsonEncode({
          'status': 'online',
          'server': 'UnifiedHomeAndroidNode',
          'version': '1.0.0',
          'port': _port,
          'serverIp': _serverIp,
          'uptimeSeconds': uptime.inSeconds,
          'startedAt': _startedAt?.toIso8601String(),
          'connectedClients': _wsClients.length,
          'requestsHandled': _requestsHandled,
          'totalDevices': _homeProvider?.devices.length ?? 0,
          'totalLiveWatts': _homeProvider?.totalLiveWatts ?? 0.0,
          'todayKwh': _homeProvider?.todayAccumulatedKwh ?? 0.0,
        }));
        await res.close();
        return;
      }

      // 3. REST API: Device List
      if (path == '/api/devices' && request.method == 'GET') {
        res.headers.contentType = ContentType.json;
        final list = _homeProvider?.devices.map((d) => _deviceToMap(d)).toList() ?? [];
        res.write(jsonEncode({
          'success': true,
          'count': list.length,
          'devices': list,
        }));
        await res.close();
        return;
      }

      // 4. REST API: Device Control & Toggles
      if (path.startsWith('/api/devices/') && request.method == 'POST') {
        final segments = request.uri.pathSegments; // ['api', 'devices', '{id}', 'control'|'toggle']
        if (segments.length >= 3) {
          final devId = segments[2];
          final dev = _homeProvider?.devices.firstWhere(
            (d) => d.id == devId,
            orElse: () => throw Exception('Device not found'),
          );

          if (dev != null && _homeProvider != null) {
            final action = segments.length >= 4 ? segments[3] : 'toggle';

            try {
              if (action == 'toggle') {
                await _homeProvider!.toggleDevicePower(dev);
                _log('REST: Toggled ${dev.name} -> ${dev.isOn ? "ON" : "OFF"}');
              } else if (action == 'control') {
                final bodyStr = await utf8.decodeStream(request);
                final body = bodyStr.isNotEmpty ? jsonDecode(bodyStr) : {};
                if (body is Map) {
                  if (body.containsKey('power')) {
                    final targetPower = body['power'] == true;
                    if (dev.isOn != targetPower) {
                      await _homeProvider!.toggleDevicePower(dev);
                    }
                  }
                  if (body.containsKey('level')) {
                    final lvl = (body['level'] as num).toDouble();
                    await _homeProvider!.setDeviceLevel(dev, lvl);
                  }
                  if (body.containsKey('flash') && body['flash'] == true) {
                    await _homeProvider!.flashDevice(dev);
                  }
                }
                _log('REST: Controlled ${dev.name} ($bodyStr)');
              }
            } catch (err) {
              _log('REST control notice for ${dev.name}: $err');
            }

            res.headers.contentType = ContentType.json;
            res.write(jsonEncode({
              'success': true,
              'device': _deviceToMap(dev),
            }));
            await res.close();
            return;
          }
        }
      }

      // 5. REST API: Logs
      if (path == '/api/logs' && request.method == 'GET') {
        res.headers.contentType = ContentType.json;
        res.write(jsonEncode({
          'logs': _serverLogs,
        }));
        await res.close();
        return;
      }

      // 6. Apple Liquid Glass Web Dashboard (GET / or /dashboard)
      if (path == '/' || path == '/dashboard' || path == '/index.html') {
        res.headers.contentType = ContentType.html;
        res.write(_generateLiquidGlassHtmlDashboard());
        await res.close();
        return;
      }

      // 404 Fallback
      res.statusCode = HttpStatus.notFound;
      res.headers.contentType = ContentType.json;
      res.write(jsonEncode({'error': 'Not Found', 'path': path}));
      await res.close();
    } catch (e) {
      res.statusCode = HttpStatus.internalServerError;
      res.headers.contentType = ContentType.json;
      res.write(jsonEncode({'error': e.toString()}));
      try {
        await res.close();
      } catch (_) {}
    }
  }

  Future<void> _handleWebSocketMessage(WebSocket ws, dynamic data) async {
    try {
      final msg = jsonDecode(data.toString());
      if (msg is Map && msg.containsKey('action')) {
        final action = msg['action'];
        final devId = msg['deviceId']?.toString();

        if (devId != null && _homeProvider != null) {
          final dev = _homeProvider!.devices.where((d) => d.id == devId).firstOrNull;
          if (dev == null) return;
          if (action == 'toggle') {
            await _homeProvider!.toggleDevicePower(dev);
          } else if (action == 'level') {
            final val = (msg['value'] as num).toDouble();
            await _homeProvider!.setDeviceLevel(dev, val);
          } else if (action == 'flash') {
            await _homeProvider!.flashDevice(dev);
          }
        }
      }
    } catch (e) {
      _log('WebSocket message execution error: $e');
    }
  }

  /// Self-contained Apple Liquid Glass HTML5 Responsive Web Dashboard
  String _generateLiquidGlassHtmlDashboard() {
    return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>Unified Home • Always-On Hub Node</title>
  <style>
    :root {
      --bg: #070B14;
      --card-bg: rgba(255, 255, 255, 0.045);
      --card-border: rgba(255, 255, 255, 0.12);
      --card-hover: rgba(255, 255, 255, 0.08);
      --accent-cyan: #00D4FF;
      --accent-green: #30D158;
      --accent-orange: #FF9F0A;
      --text-primary: #FFFFFF;
      --text-secondary: rgba(255, 255, 255, 0.65);
    }
    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
      font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Segoe UI", Roboto, sans-serif;
      -webkit-font-smoothing: antialiased;
    }
    body {
      background-color: var(--bg);
      color: var(--text-primary);
      min-height: 100vh;
      padding: 24px 16px;
      overflow-x: hidden;
      position: relative;
    }
    .background-orb {
      position: fixed;
      border-radius: 50%;
      filter: blur(120px);
      z-index: -1;
      opacity: 0.35;
      pointer-events: none;
    }
    .orb-1 { width: 320px; height: 320px; background: #0052CC; top: -50px; left: -50px; }
    .orb-2 { width: 380px; height: 380px; background: #FF6B00; bottom: -80px; right: -80px; }
    .orb-3 { width: 250px; height: 250px; background: #30D158; top: 40%; left: 60%; }

    .container {
      max-width: 1100px;
      margin: 0 auto;
    }
    header {
      display: flex;
      flex-wrap: wrap;
      justify-content: space-between;
      align-items: center;
      gap: 16px;
      margin-bottom: 28px;
      background: rgba(255, 255, 255, 0.03);
      backdrop-filter: blur(25px);
      -webkit-backdrop-filter: blur(25px);
      padding: 20px 24px;
      border-radius: 26px;
      border: 1px solid var(--card-border);
    }
    .title-group h1 {
      font-size: 24px;
      font-weight: 700;
      letter-spacing: -0.5px;
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .live-badge {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 4px 12px;
      background: rgba(48, 209, 88, 0.15);
      border: 1px solid rgba(48, 209, 88, 0.3);
      border-radius: 20px;
      font-size: 12px;
      font-weight: 600;
      color: var(--accent-green);
    }
    .pulse-dot {
      width: 7px;
      height: 7px;
      background: var(--accent-green);
      border-radius: 50%;
      box-shadow: 0 0 10px var(--accent-green);
      animation: pulse 1.8s infinite;
    }
    @keyframes pulse {
      0%, 100% { opacity: 1; transform: scale(1); }
      50% { opacity: 0.4; transform: scale(0.85); }
    }
    .stats-bar {
      display: flex;
      gap: 12px;
      flex-wrap: wrap;
    }
    .stat-pill {
      background: rgba(255, 255, 255, 0.06);
      border: 1px solid rgba(255, 255, 255, 0.08);
      padding: 8px 14px;
      border-radius: 16px;
      font-size: 13px;
      display: flex;
      align-items: center;
      gap: 6px;
    }
    .stat-pill strong {
      color: var(--accent-cyan);
    }

    .devices-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(310px, 1fr));
      gap: 20px;
    }
    .glass-card {
      background: var(--card-bg);
      backdrop-filter: blur(20px);
      -webkit-backdrop-filter: blur(20px);
      border: 1px solid var(--card-border);
      border-radius: 22px;
      padding: 20px;
      transition: all 0.25s ease;
      position: relative;
      overflow: hidden;
    }
    .glass-card:hover {
      background: var(--card-hover);
      border-color: rgba(255, 255, 255, 0.22);
      transform: translateY(-2px);
    }
    .card-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 14px;
    }
    .device-icon-wrap {
      width: 44px;
      height: 44px;
      border-radius: 14px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 20px;
      background: rgba(255, 255, 255, 0.07);
      border: 1px solid rgba(255, 255, 255, 0.1);
    }
    .device-icon-wrap.active {
      background: rgba(0, 212, 255, 0.15);
      border-color: rgba(0, 212, 255, 0.4);
      color: var(--accent-cyan);
    }
    .toggle-switch {
      position: relative;
      display: inline-block;
      width: 52px;
      height: 30px;
    }
    .toggle-switch input {
      opacity: 0;
      width: 0;
      height: 0;
    }
    .slider {
      position: absolute;
      cursor: pointer;
      top: 0; left: 0; right: 0; bottom: 0;
      background-color: rgba(255, 255, 255, 0.15);
      border-radius: 34px;
      transition: 0.3s;
      border: 1px solid rgba(255, 255, 255, 0.12);
    }
    .slider:before {
      position: absolute;
      content: "";
      height: 22px;
      width: 22px;
      left: 3px;
      bottom: 3px;
      background-color: white;
      border-radius: 50%;
      transition: 0.3s cubic-bezier(0.4, 0, 0.2, 1);
      box-shadow: 0 2px 6px rgba(0,0,0,0.4);
    }
    input:checked + .slider {
      background-color: var(--accent-green);
    }
    input:checked + .slider:before {
      transform: translateX(22px);
    }

    .device-name {
      font-size: 17px;
      font-weight: 600;
      margin-bottom: 4px;
    }
    .device-meta {
      font-size: 12.5px;
      color: var(--text-secondary);
      display: flex;
      justify-content: space-between;
      margin-bottom: 14px;
    }
    .watts-badge {
      color: #FFD60A;
      font-weight: 600;
    }

    .slider-row {
      display: flex;
      align-items: center;
      gap: 12px;
      margin-top: 10px;
    }
    .slider-row input[type="range"] {
      flex: 1;
      accent-color: var(--accent-cyan);
      height: 6px;
      border-radius: 4px;
      background: rgba(255, 255, 255, 0.15);
    }
    .level-val {
      font-size: 13px;
      font-weight: 600;
      min-width: 42px;
      text-align: right;
      color: var(--accent-cyan);
    }

    .btn-flash {
      margin-top: 12px;
      width: 100%;
      padding: 8px;
      border-radius: 12px;
      border: 1px solid rgba(255, 255, 255, 0.12);
      background: rgba(255, 255, 255, 0.06);
      color: white;
      font-size: 12px;
      font-weight: 600;
      cursor: pointer;
      transition: 0.2s;
    }
    .btn-flash:hover {
      background: rgba(255, 255, 255, 0.12);
    }

    footer {
      margin-top: 40px;
      text-align: center;
      font-size: 12px;
      color: var(--text-secondary);
    }
  </style>
</head>
<body>
  <div class="background-orb orb-1"></div>
  <div class="background-orb orb-2"></div>
  <div class="background-orb orb-3"></div>

  <div class="container">
    <header>
      <div class="title-group">
        <h1>
          <span>🏛️</span> Unified Home Node
          <span class="live-badge"><span class="pulse-dot"></span> ALWAYS-ON HUB</span>
        </h1>
      </div>
      <div class="stats-bar">
        <div class="stat-pill">⚡ Live Load: <strong id="total-watts">--</strong> W</div>
        <div class="stat-pill">⏳ Uptime: <span id="uptime-clock">--</span></div>
        <div class="stat-pill">📱 Link: <span id="ws-status" style="color: #30D158">Connecting...</span></div>
      </div>
    </header>

    <main class="devices-grid" id="devices-container">
      <div style="grid-column: 1 / -1; text-align: center; padding: 40px; color: var(--text-secondary);">
        Discovering smart devices on home node...
      </div>
    </main>

    <footer>
      Unified Home • Embedded Android Node Server • Port 8765 • Zero-Cloud Local-First Control
    </footer>
  </div>

  <script>
    let devices = [];
    let ws = null;
    let uptimeSeconds = 0;

    function getIcon(category) {
      switch (category) {
        case 'washer': return '🧺';
        case 'ac': return '❄️';
        case 'light': return '💡';
        case 'tv': return '📺';
        case 'camera': return '📹';
        default: return '⚡';
      }
    }

    function formatUptime(seconds) {
      const h = Math.floor(seconds / 3600);
      const m = Math.floor((seconds % 3600) / 60);
      const s = seconds % 60;
      return `\${h}h \${m}m \${s}s`;
    }

    function renderDevices() {
      const container = document.getElementById('devices-container');
      if (!devices || devices.length === 0) {
        container.innerHTML = '<div style="grid-column: 1 / -1; text-align: center; padding: 40px; color: var(--text-secondary);">No devices paired. Open the Unified Home app to link appliances.</div>';
        return;
      }

      container.innerHTML = devices.map(d => {
        const isLight = d.category === 'light';
        const isAc = d.category === 'ac';
        const hasSlider = isLight || isAc;
        const sliderLabel = isAc ? 'Temp' : 'Brightness';
        const sliderUnit = isAc ? '°C' : '%';
        const minVal = isAc ? 16 : 1;
        const maxVal = isAc ? 30 : 100;

        return `
          <div class="glass-card" id="card-\${d.id}">
            <div class="card-header">
              <div class="device-icon-wrap \${d.isOn ? 'active' : ''}">
                \${getIcon(d.category)}
              </div>
              <label class="toggle-switch">
                <input type="checkbox" \${d.isOn ? 'checked' : ''} onchange="toggleDevice('\${d.id}')">
                <span class="slider"></span>
              </label>
            </div>
            <div class="device-name">\${d.name}</div>
            <div class="device-meta">
              <span>\${d.room} • \${d.protocol}</span>
              <span class="watts-badge">\${d.liveWatts ? d.liveWatts.toFixed(1) : '0.0'} W</span>
            </div>

            \${hasSlider ? `
              <div class="slider-row">
                <span style="font-size: 11px; color: var(--text-secondary)">\${sliderLabel}</span>
                <input type="range" min="\${minVal}" max="\${maxVal}" value="\${d.primaryValue || minVal}"
                  onchange="setDeviceLevel('\${d.id}', this.value)"
                  oninput="document.getElementById('val-\${d.id}').innerText = this.value + '\${sliderUnit}'"
                >
                <span class="level-val" id="val-\${d.id}">\${Math.round(d.primaryValue || minVal)}\${sliderUnit}</span>
              </div>
            ` : ''}

            \${isLight ? `
              <button class="btn-flash" onclick="flashBulb('\${d.id}')">✨ 3-Pulse Flash Alert</button>
            ` : ''}
          </div>
        `;
      }).join('');
    }

    function toggleDevice(devId) {
      if (ws && ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ action: 'toggle', deviceId: devId }));
      } else {
        fetch('/api/devices/' + devId + '/toggle', { method: 'POST' });
      }
    }

    function setDeviceLevel(devId, val) {
      if (ws && ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ action: 'level', deviceId: devId, value: parseFloat(val) }));
      } else {
        fetch('/api/devices/' + devId + '/control', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ level: parseFloat(val) })
        });
      }
    }

    function flashBulb(devId) {
      if (ws && ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ action: 'flash', deviceId: devId }));
      } else {
        fetch('/api/devices/' + devId + '/control', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ flash: true })
        });
      }
    }

    function connectWs() {
      const protocol = location.protocol === 'https:' ? 'wss:' : 'ws:';
      const wsUrl = `\${protocol}//\${location.host}/api/ws`;
      ws = new WebSocket(wsUrl);

      ws.onopen = () => {
        document.getElementById('ws-status').innerText = 'Connected (Real-time)';
        document.getElementById('ws-status').style.color = '#30D158';
      };

      ws.onmessage = (event) => {
        try {
          const payload = JSON.parse(event.data);
          if (payload.devices) {
            devices = payload.devices;
            renderDevices();
          }
          if (payload.totalWatts !== undefined) {
            document.getElementById('total-watts').innerText = payload.totalWatts.toFixed(1);
          }
          if (payload.uptimeSeconds !== undefined) {
            uptimeSeconds = payload.uptimeSeconds;
            document.getElementById('uptime-clock').innerText = formatUptime(uptimeSeconds);
          }
        } catch (e) {}
      };

      ws.onclose = () => {
        document.getElementById('ws-status').innerText = 'Reconnecting...';
        document.getElementById('ws-status').style.color = '#FF9F0A';
        setTimeout(connectWs, 3000);
      };

      ws.onerror = () => {
        ws.close();
      };
    }

    // Initial HTTP Fetch & WebSocket connect
    fetch('/api/status')
      .then(res => res.json())
      .then(data => {
        document.getElementById('total-watts').innerText = (data.totalLiveWatts || 0).toFixed(1);
        uptimeSeconds = data.uptimeSeconds || 0;
        document.getElementById('uptime-clock').innerText = formatUptime(uptimeSeconds);
      }).catch(() => {});

    fetch('/api/devices')
      .then(res => res.json())
      .then(data => {
        if (data.devices) {
          devices = data.devices;
          renderDevices();
        }
      }).catch(() => {});

    setInterval(() => {
      uptimeSeconds++;
      document.getElementById('uptime-clock').innerText = formatUptime(uptimeSeconds);
    }, 1000);

    connectWs();
  </script>
</body>
</html>
''';
  }
}
