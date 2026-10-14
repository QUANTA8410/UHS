import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/home_state.dart';
import '../widgets/quick_action_pills.dart';
import '../widgets/device_tile.dart';
import '../widgets/copilot/ai_copilot_sheet.dart';
import '../widgets/dialogs/add_device_dialog.dart';

class FavoritesView extends StatelessWidget {
  const FavoritesView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HomeState>();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.auto_awesome, color: Colors.amberAccent),
        label: const Text('Ask Copilot', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => AiCopilotSheet.show(context),
      ),
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              state.homeName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const Icon(Icons.arrow_drop_down_rounded),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Real Device',
            onPressed: () => AddDeviceDialog.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {},
          ),
          const Padding(
            padding: EdgeInsets.only(right: 14),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blueAccent,
              child: Text('H', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 8, bottom: 12),
              child: QuickActionPills(),
            ),
          ),

          // Quick Scene Launchers
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildSceneChip(context, Icons.wb_sunny_rounded, 'Good Morning'),
                    const SizedBox(width: 8),
                    _buildSceneChip(context, Icons.directions_walk_rounded, 'Leaving Home'),
                    const SizedBox(width: 8),
                    _buildSceneChip(context, Icons.movie_filter_rounded, 'Movie Night'),
                    const SizedBox(width: 8),
                    _buildSceneChip(context, Icons.bedtime_rounded, 'Good Night'),
                  ],
                ),
              ),
            ),
          ),

          // Section Title
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Favorites',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${state.devices.length} Devices',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),

          if (state.devices.isEmpty)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Icon(Icons.devices_other_rounded, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 10),
                    const Text('No devices found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 6),
                    const Text(
                      'Tap below to connect your real appliances or scan local Wi-Fi.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add Real Device'),
                      onPressed: () => AddDeviceDialog.show(context),
                    ),
                  ],
                ),
              ),
            )
          else
            // Pinned Devices Grid
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.15,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final dev = state.devices[index];
                    return DeviceTile(device: dev);
                  },
                  childCount: state.devices.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 30)),
        ],
      ),
    );
  }

  Widget _buildSceneChip(BuildContext context, IconData icon, String label) {
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Triggered "$label" routine across all ecosystems')),
        );
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    );
  }
}
