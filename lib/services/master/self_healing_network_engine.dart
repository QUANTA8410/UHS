import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:web_socket_channel/io.dart';
import '../real_iot_controller.dart';

class SelfHealingNetworkEngine {
  IOWebSocketChannel? _alwaysOnNodeChannel;
  bool isAlwaysOnNodeConnected = false;
  String? alwaysOnNodeUrl;
  final Map<String, bool> _inFlightDevices = {};

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

    String? wifiIp = await NetworkInfo().getWifiIP();
    final currentIp = device.credentials['ip'] ?? '';
    String subnetPrefix = '192.168.1';

    if (wifiIp != null && wifiIp.contains('.')) {
      subnetPrefix = wifiIp.substring(0, wifiIp.lastIndexOf('.'));
    } else if (currentIp.contains('.')) {
      subnetPrefix = currentIp.substring(0, currentIp.lastIndexOf('.'));
    }

    final completer = Completer<String?>();
    int remaining = 254;

    for (int i = 1; i <= 254; i++) {
      final candidateIp = '$subnetPrefix.$i';
      Socket.connect(candidateIp, targetPort, timeout: const Duration(milliseconds: 260))
          .then((socket) {
        socket.destroy();
        if (!completer.isCompleted) {
          device.credentials['ip'] = candidateIp;
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
