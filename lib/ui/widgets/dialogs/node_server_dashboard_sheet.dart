import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../providers/real_home_provider.dart';

/// 24/7 Always-On Android Home Node Server Cockpit & Dashboard
class NodeServerDashboardSheet extends StatefulWidget {
  const NodeServerDashboardSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NodeServerDashboardSheet(),
    );
  }

  @override
  State<NodeServerDashboardSheet> createState() => _NodeServerDashboardSheetState();
}

class _NodeServerDashboardSheetState extends State<NodeServerDashboardSheet> {
  Timer? _ticker;
  bool _isOledClockActive = false;
  Map<String, dynamic> _keepAliveStatus = {};

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkStatus());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    final home = context.read<RealHomeProvider>();
    final status = await home.nodeServer.checkKeepAliveStatus();
    if (mounted) {
      setState(() => _keepAliveStatus = status);
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${h}h ${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    if (_isOledClockActive) {
      return _buildOledScreensaver();
    }

    final home = context.watch<RealHomeProvider>();
    final node = home.nodeServer;
    final isRunning = node.isRunning;
    final serverUrl = node.dashboardUrl;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: const Color(0xFF090E1A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 40,
            spreadRadius: 10,
          )
        ],
      ),
      child: Column(
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isRunning
                        ? const Color(0xFF30D158).withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isRunning
                          ? const Color(0xFF30D158).withValues(alpha: 0.5)
                          : Colors.white12,
                    ),
                  ),
                  child: Icon(
                    Icons.dns_rounded,
                    color: isRunning ? const Color(0xFF30D158) : Colors.white70,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '24/7 Always-On Hub Node',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isRunning
                            ? 'Native Android WakeLock & High-Perf WifiLock Active'
                            : 'Turn this phone into a permanent Smart Home Hub',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isRunning ? const Color(0xFF30D158) : Colors.white54,
                          fontWeight: FontWeight.w500,
                        ),
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

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Status & URL Hero Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isRunning
                            ? [
                                const Color(0xFF003366).withValues(alpha: 0.45),
                                const Color(0xFF002244).withValues(alpha: 0.65),
                              ]
                            : [
                                Colors.white.withValues(alpha: 0.05),
                                Colors.white.withValues(alpha: 0.02),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isRunning
                            ? const Color(0xFF00D4FF).withValues(alpha: 0.35)
                            : Colors.white12,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isRunning
                                    ? const Color(0xFF30D158).withValues(alpha: 0.18)
                                    : Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isRunning
                                      ? const Color(0xFF30D158).withValues(alpha: 0.4)
                                      : Colors.white12,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isRunning ? const Color(0xFF30D158) : Colors.white38,
                                      boxShadow: isRunning
                                          ? [
                                              const BoxShadow(
                                                color: Color(0xFF30D158),
                                                blurRadius: 8,
                                              )
                                            ]
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isRunning ? 'ONLINE • PORT ${node.port}' : 'HUB STANDBY',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isRunning ? const Color(0xFF30D158) : Colors.white60,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isRunning)
                              Text(
                                'Uptime: ${_formatDuration(node.uptime)}',
                                style: const TextStyle(fontSize: 12, color: Colors.white70),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        if (isRunning) ...[
                          const Text(
                            'Local Web Dashboard URL:',
                            style: TextStyle(fontSize: 12, color: Colors.white60),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.link_rounded, color: Color(0xFF00D4FF), size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    serverUrl,
                                    style: const TextStyle(
                                      color: Color(0xFF00D4FF),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Copy URL',
                                  icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 18),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: serverUrl));
                                    HapticFeedback.lightImpact();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        backgroundColor: Color(0xFF30D158),
                                        content: Text('Dashboard URL copied to clipboard!'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00D4FF),
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                                  label: const Text('Open Web Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
                                  onPressed: () => launchUrl(
                                    Uri.parse(serverUrl),
                                    mode: LaunchMode.externalApplication,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFFF453A),
                                  side: const BorderSide(color: Color(0xFFFF453A)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                ),
                                icon: const Icon(Icons.power_settings_new_rounded, size: 18),
                                label: const Text('Stop'),
                                onPressed: () async {
                                  HapticFeedback.heavyImpact();
                                  await home.stopNodeServer();
                                  _checkStatus();
                                },
                              ),
                            ],
                          ),
                        ] else ...[
                          const Text(
                            'Turn this device into a 24/7 Local Home Server',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Controls your Samsung Washer, LG AC, Wipro Bulbs, and Cameras from any browser on Wi-Fi without cloud lag. Native WakeLocks prevent Android from putting the Wi-Fi radio or server to sleep.',
                            style: TextStyle(fontSize: 12.5, color: Colors.white60, height: 1.35),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF30D158),
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              icon: const Icon(Icons.power_settings_new_rounded),
                              label: const Text(
                                'Start 24/7 Android Hub Node Server',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                              ),
                              onPressed: () async {
                                HapticFeedback.heavyImpact();
                                final messenger = ScaffoldMessenger.of(context);
                                final ok = await home.startNodeServer();
                                if (!ok) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      backgroundColor: Colors.redAccent,
                                      content: Text('Failed to bind port 8765. Verify Wi-Fi connection.'),
                                    ),
                                  );
                                }
                                if (mounted) {
                                  _checkStatus();
                                }
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Real-time Metrics 3-Pack
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile(
                          icon: Icons.electric_bolt_rounded,
                          color: const Color(0xFFFFD60A),
                          title: 'Live Telemetry',
                          value: '${home.totalLiveWatts.toStringAsFixed(1)} W',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricTile(
                          icon: Icons.devices_rounded,
                          color: const Color(0xFF00D4FF),
                          title: 'Hub Devices',
                          value: '${home.devices.length} Units',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricTile(
                          icon: Icons.wifi_tethering_rounded,
                          color: const Color(0xFF30D158),
                          title: 'Web Clients',
                          value: '${node.connectedClientsCount} Links',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // AMOLED Burn-in Protection Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.bedtime_rounded, color: Color(0xFFBF5AF2), size: 24),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'OLED Burn-in Protection Clock',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Low-wattage black screen clock while keeping 24/7 hub active',
                                style: TextStyle(color: Colors.white54, fontSize: 11.5),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFBF5AF2).withValues(alpha: 0.2),
                            foregroundColor: const Color(0xFFBF5AF2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          child: const Text('Enter Clock', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            setState(() => _isOledClockActive = true);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Keep-Alive Hardware Telemetry
                  const Text(
                    'Hardware Keep-Alive Locks (Android Kernel):',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                        _buildLockRow(
                          'CPU Partial WakeLock',
                          _keepAliveStatus['wakeLock'] == true,
                          'Prevents deep processor sleep',
                        ),
                        const Divider(height: 16, color: Colors.white10),
                        _buildLockRow(
                          'High-Perf WifiLock',
                          _keepAliveStatus['wifiLock'] == true,
                          'Forces Wi-Fi radio at low latency',
                        ),
                        const Divider(height: 16, color: Colors.white10),
                        _buildLockRow(
                          'Battery Optimization Exemption',
                          _keepAliveStatus['batteryOptimizationIgnored'] == true,
                          'Exempt from Doze mode termination',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Server Activity Log
                  const Text(
                    'Live Server Activity Log:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    height: 130,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: node.serverLogs.isEmpty
                        ? const Center(
                            child: Text(
                              'Server idle. Logs will appear here.',
                              style: TextStyle(color: Colors.white30, fontSize: 12),
                            ),
                          )
                        : ListView.builder(
                            itemCount: node.serverLogs.length,
                            itemBuilder: (_, i) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                node.serverLogs[i],
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: Color(0xFF30D158),
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 11, color: Colors.white54)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockRow(String name, bool active, String description) {
    return Row(
      children: [
        Icon(
          active ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          color: active ? const Color(0xFF30D158) : Colors.white30,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              Text(
                description,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ),
        Text(
          active ? 'LOCKED' : 'INACTIVE',
          style: TextStyle(
            color: active ? const Color(0xFF30D158) : Colors.white38,
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// OLED True Black Screensaver to protect old phone displays from burn-in
  Widget _buildOledScreensaver() {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final home = context.watch<RealHomeProvider>();

    return GestureDetector(
      onTap: () => setState(() => _isOledClockActive = false),
      child: Container(
        color: Colors.black,
        width: double.infinity,
        height: double.infinity,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shield_rounded, color: Colors.white24, size: 36),
            const SizedBox(height: 20),
            Text(
              timeStr,
              style: const TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.w200,
                color: Colors.white54,
                letterSpacing: -2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${home.totalLiveWatts.toStringAsFixed(1)} W LIVE • 24/7 NODE SERVER ACTIVE',
              style: const TextStyle(
                color: Color(0xFF30D158),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Tap anywhere to return to Dashboard',
              style: TextStyle(color: Colors.white24, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
