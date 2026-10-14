import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/device_model.dart';
import '../../../providers/home_state.dart';
import '../../../services/tv/oneplus_connect_service.dart';

class OnePlusTvSheet extends StatelessWidget {
  final TvDevice device;

  const OnePlusTvSheet({super.key, required this.device});

  void _editTvIp(BuildContext context, HomeState state) {
    final controller = TextEditingController(text: device.host ?? '192.168.1.');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Configure OnePlus TV IP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the local Wi-Fi IP address of your OnePlus TV (check TV Settings > Network):',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'TV IP Address',
                hintText: 'e.g. 192.168.1.105',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final newIp = controller.text.trim();
              if (newIp.isNotEmpty) {
                device.host = newIp;
                device.isDummy = false;
                state.updateDevice(device);
                state.tvService.checkConnectivity(newIp).then((online) {
                  device.isOnline = online;
                  state.refresh();
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save & Connect'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HomeState>();

    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header: OnePlus TV & OnePlus Connect
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.tv_rounded, color: Colors.redAccent, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('OnePlus Connect', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
                          ),
                          const SizedBox(width: 6),
                          Text(device.room, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: device.isPowered,
                  activeThumbColor: Colors.redAccent,
                  onChanged: (val) => state.togglePower(device.id),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Real Connection Status & IP Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (device.host != null && device.host!.isNotEmpty)
                    ? Colors.green.shade50
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: (device.host != null && device.host!.isNotEmpty)
                      ? Colors.green.shade300
                      : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    device.isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                    size: 18,
                    color: device.isOnline ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      device.host != null && device.host!.isNotEmpty
                          ? 'IP: ${device.host} • ${device.isOnline ? "Connected" : "Offline / Standby"}'
                          : (device.isDummy ? 'Sample Demo Mode (IP not set)' : 'LAN IP not set'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: device.isOnline ? Colors.green.shade900 : Colors.grey.shade800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _editTvIp(context, state),
                    child: const Text('Edit IP', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Current Media Status Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.currentApp,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Input: ${device.currentInput}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.volume_up, size: 16, color: Colors.redAccent),
                        const SizedBox(width: 4),
                        Text(
                          device.isMuted ? 'Muted' : '${device.volume}%',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.redAccent),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Virtual D-Pad / Remote Navigation
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  IconButton.filledTonal(
                    icon: const Icon(Icons.keyboard_arrow_up),
                    onPressed: () => state.sendTvKey(device.id, 'dpad_up'),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.filledTonal(
                        icon: const Icon(Icons.keyboard_arrow_left),
                        onPressed: () => state.sendTvKey(device.id, 'dpad_left'),
                      ),
                      const SizedBox(width: 14),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(22),
                          backgroundColor: Colors.redAccent,
                        ),
                        onPressed: () => state.sendTvKey(device.id, 'enter'),
                        child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 14),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.keyboard_arrow_right),
                        onPressed: () => state.sendTvKey(device.id, 'dpad_right'),
                      ),
                    ],
                  ),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.keyboard_arrow_down),
                    onPressed: () => state.sendTvKey(device.id, 'dpad_down'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        tooltip: 'Back',
                        onPressed: () => state.sendTvKey(device.id, 'back'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.home),
                        tooltip: 'Home (OxygenPlay)',
                        onPressed: () {
                          state.sendTvKey(device.id, 'home');
                          state.updateTv(device.id, app: 'OxygenPlay');
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.menu),
                        tooltip: 'Menu',
                        onPressed: () => state.sendTvKey(device.id, 'menu'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Volume Controls & OnePlus Smart Volume
            Row(
              children: [
                IconButton(
                  icon: Icon(device.isMuted ? Icons.volume_off : Icons.volume_up),
                  onPressed: () => state.updateTv(device.id, isMuted: !device.isMuted),
                ),
                Expanded(
                  child: Slider(
                    value: device.volume.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 100,
                    activeColor: Colors.redAccent,
                    onChanged: (val) => state.updateTv(device.id, volume: val.round(), isMuted: false),
                  ),
                ),
                Text('${device.volume}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Smart Volume (OnePlus Connect)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              subtitle: const Text('Auto-reduces TV volume during incoming smartphone calls', style: TextStyle(fontSize: 11)),
              value: device.smartVolumeEnabled,
              activeThumbColor: Colors.redAccent,
              onChanged: (val) => state.updateTv(device.id, smartVolume: val),
            ),
            const Divider(),

            // Quick App Switcher (OxygenPlay / OTT)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Quick App Switcher', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: OnePlusConnectService.availableApps.map((app) {
                  final isCurrent = device.currentApp == app;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(app),
                      selected: isCurrent,
                      selectedColor: Colors.red.shade100,
                      onSelected: (selected) {
                        if (selected) {
                          state.launchTvApp(device.id, app);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            // Input Sources & Picture Mode
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: device.currentInput,
                    decoration: InputDecoration(
                      labelText: 'Input Source',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: OnePlusConnectService.inputSources.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (v) {
                      if (v != null) state.updateTv(device.id, input: v);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: device.pictureMode,
                    decoration: InputDecoration(
                      labelText: 'Picture Engine',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: OnePlusConnectService.pictureModes.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (v) {
                      if (v != null) state.updateTv(device.id, pictureMode: v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Remove Device Button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Remove TV from Home'),
              onPressed: () {
                state.removeDevice(device.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Removed ${device.name}')),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
