import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:web_socket_channel/io.dart';
import '../real_iot_controller.dart';

typedef SocketConnectFn = Future<Socket> Function(dynamic host, int port, {Duration? timeout});

/// Checks if an IPv4 address string is a valid private LAN / loopback address (RFC 1918 / Loopback / Link-Local).
bool isPrivateLanIp(String? ip) {
  if (ip == null) {
    return false;
  }
  final clean = ip.trim();
  if (clean.isEmpty) {
    return false;
  }
  final parts = clean.split('.');
  if (parts.length != 4) {
    return false;
  }
  final octet1 = int.tryParse(parts[0]);
  final octet2 = int.tryParse(parts[1]);
  final octet3 = int.tryParse(parts[2]);
  final octet4 = int.tryParse(parts[3]);
  if (octet1 == null || octet2 == null || octet3 == null || octet4 == null) {
    return false;
  }
  if (octet1 < 0 || octet1 > 255 || octet2 < 0 || octet2 > 255 ||
      octet3 < 0 || octet3 > 255 || octet4 < 0 || octet4 > 255) {
    return false;
  }

  // 10.0.0.0/8 (10.0.0.0 - 10.255.255.255)
  if (octet1 == 10) {
    return true;
  }
  // 172.16.0.0/12 (172.16.0.0 - 172.31.255.255)
  if (octet1 == 172 && octet2 >= 16 && octet2 <= 31) {
    return true;
  }
  // 192.168.0.0/16 (192.168.0.0 - 192.168.255.255)
  if (octet1 == 192 && octet2 == 168) {
    return true;
  }
  // 127.0.0.0/8 (Loopback)
  if (octet1 == 127) {
    return true;
  }
  // 169.254.0.0/16 (Link-Local / APIPA)
  if (octet1 == 169 && octet2 == 254) {
    return true;
  }

  return false;
}

class SelfHealingNetworkEngine {
  final NetworkInfo? _networkInfo;
  final SocketConnectFn? _socketConnect;
  IOWebSocketChannel? _alwaysOnNodeChannel;
  bool isAlwaysOnNodeConnected = false;
  String? alwaysOnNodeUrl;
  final Map<String, bool> _inFlightDevices = {};

  SelfHealingNetworkEngine({
    NetworkInfo? networkInfo,
    SocketConnectFn? socketConnect,
  })  : _networkInfo = networkInfo,
        _socketConnect = socketConnect;

  bool isDeviceInFlight(String deviceId) => _inFlightDevices[deviceId] ?? false;

  // ---------------------------------------------------------------------------
  // PILLAR 1: ALWAYS-ON LOCAL/TUNNEL NODE BRIDGE (24/7 BRAIN)
  // ---------------------------------------------------------------------------
  Future<void> connectAlwaysOnNode(
    String wsUrl, {
    required void Function(Map<String, dynamic> event) onRemoteHardwareEvent,
  }) async {
    alwaysOnNodeUrl = wsUrl.trim();
    try {
      _alwaysOnNodeChannel?.sink.close();
      _alwaysOnNodeChannel = IOWebSocketChannel.connect(
        Uri.parse(alwaysOnNodeUrl!),
        pingInterval: const Duration(seconds: 15),
      );
      isAlwaysOnNodeConnected = true;

      _alwaysOnNodeChannel!.stream.listen(
        (message) {
          final decoded = jsonDecode(message.toString()) as Map<String, dynamic>;
          onRemoteHardwareEvent(decoded);
        },
        onDone: () => isAlwaysOnNodeConnected = false,
        onError: (_) => isAlwaysOnNodeConnected = false,
      );
    } catch (e) {
      isAlwaysOnNodeConnected = false;
      rethrow;
    }
  }

  void relayCommandToAlwaysOnNode(Map<String, dynamic> commandPayload) {
    if (isAlwaysOnNodeConnected && _alwaysOnNodeChannel != null) {
      _alwaysOnNodeChannel!.sink.add(jsonEncode(commandPayload));
    }
  }

  // ---------------------------------------------------------------------------
  // PILLAR 6A: SELF-HEALING DHCP IP RESOLVER (AUTO-SWEEPS SUBNET ON TIMEOUT)
  // ---------------------------------------------------------------------------
  Future<String?> healDeviceIpAddress(RealSmartDevice device) async {
    final targetPort = int.tryParse(
          device.credentials['port'] ??
              (device.protocol == ConnectionProtocol.tuyaLocalLan ? '6668' : '8008'),
        ) ??
        8008;

    // For Tuya Local LAN bulbs, first attempt passive UDP 6667 beacon listen for exact devId
    if (device.protocol == ConnectionProtocol.tuyaLocalLan) {
      try {
        final udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 6667, reuseAddress: true);
        udpSocket.broadcastEnabled = true;
        final udpCompleter = Completer<String?>();

        final sub = udpSocket.listen((event) {
          if (event == RawSocketEvent.read) {
            final dg = udpSocket.receive();
            if (dg != null) {
              final senderIp = dg.address.address;
              final parsed = RealIotController.decodeTuyaUdpPacket(dg.data, senderIp);
              if (parsed != null && (parsed['devId'] == device.id || parsed['devId'] == device.credentials['devId'])) {
                if (!udpCompleter.isCompleted && isPrivateLanIp(senderIp)) {
                  udpCompleter.complete(senderIp);
                }
              }
            }
          }
        });

        final resolvedUdpIp = await udpCompleter.future.timeout(
          const Duration(milliseconds: 1500),
          onTimeout: () => null,
        );
        await sub.cancel();
        udpSocket.close();

        if (resolvedUdpIp != null && isPrivateLanIp(resolvedUdpIp)) {
          device.credentials['ip'] = resolvedUdpIp;
          device.credentials.remove('isPendingLanIp');
          return resolvedUdpIp;
        }
      } catch (_) {}
    }

    String? wifiIp;
    try {
      wifiIp = await (_networkInfo ?? NetworkInfo()).getWifiIP();
    } catch (_) {}
    final currentIp = device.credentials['ip'] ?? '';
    String subnetPrefix = '192.168.1';

    // Guard against WAN IP sweep: only use IP for subnet prefix if it is a private LAN IP
    if (wifiIp != null && isPrivateLanIp(wifiIp)) {
      subnetPrefix = wifiIp.substring(0, wifiIp.lastIndexOf('.'));
    } else if (isPrivateLanIp(currentIp)) {
      subnetPrefix = currentIp.substring(0, currentIp.lastIndexOf('.'));
    }

    final completer = Completer<String?>();
    int remaining = 254;
    final connectFn = _socketConnect ?? Socket.connect;

    for (int i = 1; i <= 254; i++) {
      final candidateIp = '$subnetPrefix.$i';
      connectFn(candidateIp, targetPort, timeout: const Duration(milliseconds: 260))
          .then((socket) {
        try {
          socket.destroy();
        } catch (_) {}
        if (!completer.isCompleted) {
          device.credentials['ip'] = candidateIp;
          device.credentials.remove('isPendingLanIp');
          completer.complete(candidateIp);
        }
      }).catchError((_) {}).whenComplete(() {
        remaining--;
        if (remaining == 0 && !completer.isCompleted) {
          completer.complete(null);
        }
      });
    }

    return completer.future;
  }

  // ---------------------------------------------------------------------------
  // PILLAR 6B: HONEST TELEMETRY & OPTIMISTIC UI WITH AUTOMATIC ROLLBACK
  // ---------------------------------------------------------------------------
  Future<void> executeWithOptimisticRollback<T>({
    required RealSmartDevice device,
    required T optimisticValue,
    required T Function() getCurrentValue,
    required void Function(T val) applyValueLocal,
    required Future<void> Function() networkCall,
    required void Function() notifyUi,
  }) async {
    final previousValue = getCurrentValue();
    _inFlightDevices[device.id] = true;
    applyValueLocal(optimisticValue);
    device.lastError = null;
    notifyUi();

    try {
      await networkCall().timeout(const Duration(seconds: 4));
      _inFlightDevices[device.id] = false;
      HapticFeedback.lightImpact();
      notifyUi();
    } catch (firstError) {
      // Attempt self-healing IP discovery if this is a LAN device
      if (device.protocol == ConnectionProtocol.tuyaLocalLan ||
          device.protocol == ConnectionProtocol.onePlusTvLan) {
        final healedIp = await healDeviceIpAddress(device);
        if (healedIp != null) {
          try {
            await networkCall().timeout(const Duration(seconds: 4));
            _inFlightDevices[device.id] = false;
            notifyUi();
            return;
          } catch (_) {}
        }
      }

      // Rollback optimistic state immediately and vibrate error
      _inFlightDevices[device.id] = false;
      applyValueLocal(previousValue);
      device.isOnline = false;
      device.lastError =
          'Unreachable (${firstError.toString().replaceAll("Exception: ", "")}) — Rolled back.';
      HapticFeedback.heavyImpact();
      notifyUi();
      rethrow;
    }
  }
}
