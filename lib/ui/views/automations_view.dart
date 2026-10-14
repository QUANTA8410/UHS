import 'package:flutter/material.dart';

class AutomationsView extends StatelessWidget {
  const AutomationsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Routines & Automations', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildRoutineCard(
            context,
            title: 'Morning Awakening',
            subtitle: 'At 07:00 AM on Weekdays',
            icon: Icons.wb_sunny_rounded,
            color: Colors.amber,
            actions: [
              'Turn on Living Room lights to 60%',
              'Set AC to 23°C (Eco mode)',
              'LG Fridge: Announce today\'s schedule',
            ],
            isEnabled: true,
          ),
          const SizedBox(height: 12),
          _buildRoutineCard(
            context,
            title: 'Leaving Home (SmartThings Rules)',
            subtitle: 'IF Phone leaves Geofence & Washer is idle',
            icon: Icons.directions_walk_rounded,
            color: Colors.blue,
            actions: [
              'Turn off all lighting & media',
              'Set AC to Away (26°C)',
              'Arm Home Security & Nest Cam',
              'Activate SmartThings AI Energy Mode',
            ],
            isEnabled: true,
          ),
          const SizedBox(height: 12),
          _buildRoutineCard(
            context,
            title: 'Laundry Finished Announcement',
            subtitle: 'IF LG Washer stage changes to "Done"',
            icon: Icons.local_laundry_service_rounded,
            color: Colors.green,
            actions: [
              'Broadcast voice alert to Google Nest speakers',
              'Flash Living Room light in green twice',
            ],
            isEnabled: true,
          ),
          const SizedBox(height: 12),
          _buildRoutineCard(
            context,
            title: 'Night Cinema (Matter + webOS)',
            subtitle: 'Triggered via Quick Action or Voice',
            icon: Icons.movie_filter_rounded,
            color: Colors.deepPurple,
            actions: [
              'Dim lights to 15% warm amber',
              'Turn on LG webOS TV',
              'Set AC to Quiet 22°C',
            ],
            isEnabled: false,
          ),
        ],
      ),
    );
  }

  Widget _buildRoutineCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<String> actions,
    required bool isEnabled,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Switch(
                  value: isEnabled,
                  activeThumbColor: color,
                  onChanged: (val) {},
                ),
              ],
            ),
            const Divider(height: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: actions.map((act) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Expanded(child: Text(act, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade300 : Colors.black87))),
                  ],
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
