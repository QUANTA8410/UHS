import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/home_state.dart';
import '../widgets/device_tile.dart';
import '../widgets/dialogs/add_device_dialog.dart';
import 'ota_update_view.dart';

class DevicesView extends StatelessWidget {
  const DevicesView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HomeState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rooms & Devices', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: state.hasUpdatesAvailable,
              child: const Icon(Icons.system_update_rounded),
            ),
            tooltip: 'System & Device OTA Updates',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OtaUpdateView()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add & Connect Real Device',
            onPressed: () => AddDeviceDialog.show(context),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              if (val == 'clear_dummy') {
                state.clearDummyDevices();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cleared all preloaded dummy devices')),
                );
              } else if (val == 'restore_demo') {
                state.restoreDemoFleet();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Restored demo device fleet')),
                );
              } else if (val == 'add') {
                AddDeviceDialog.show(context);
              } else if (val == 'ota') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OtaUpdateView()),
                );
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'ota',
                child: Row(
                  children: [
                    Icon(Icons.system_update_rounded, color: Colors.teal),
                    SizedBox(width: 8),
                    Text('OTA & Firmware Updates'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'add',
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline, color: Colors.blueAccent),
                    SizedBox(width: 8),
                    Text('Add Real Device'),
                  ],
                ),
              ),
              if (state.hasDummyDevices)
                const PopupMenuItem(
                  value: 'clear_dummy',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep_rounded, color: Colors.deepOrange),
                      SizedBox(width: 8),
                      Text('Clear Dummy Devices'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'restore_demo',
                child: Row(
                  children: [
                    Icon(Icons.restart_alt_rounded, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('Restore Demo Fleet'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        children: [
          // Banner for Preloaded Dummy Devices
          if (state.hasDummyDevices)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 26),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sample Demo Devices Active', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('Clear dummy devices anytime to control only your real hardware.', style: TextStyle(fontSize: 11, color: Colors.black87)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      state.clearDummyDevices();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Purged all preloaded dummy devices')),
                      );
                    },
                    child: const Text('Clear All', style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

          if (state.allDevices.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              margin: const EdgeInsets.only(top: 40),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Icon(Icons.home_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 14),
                  const Text(
                    'No Devices Connected',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add your Samsung Washing Machine, LG DualCool AC, Wipro Smart Bulbs, or OnePlus TV.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Connect Real Hardware', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => AddDeviceDialog.show(context),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => state.restoreDemoFleet(),
                    child: const Text('Load Demo Devices for Testing'),
                  ),
                ],
              ),
            )
          else
            ...state.rooms.map((room) {
              final devices = state.devicesInRoom(room);
              return Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          room,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${devices.length} devices',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (devices.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text('No devices assigned to $room', style: const TextStyle(color: Colors.grey)),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.15,
                        ),
                        itemCount: devices.length,
                        itemBuilder: (context, dIndex) {
                          return DeviceTile(device: devices[dIndex]);
                        },
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
