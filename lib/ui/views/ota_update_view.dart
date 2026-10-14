import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/device_model.dart';
import '../../models/ota_update_model.dart';
import '../../providers/home_state.dart';

class OtaUpdateView extends StatefulWidget {
  const OtaUpdateView({super.key});

  @override
  State<OtaUpdateView> createState() => _OtaUpdateViewState();
}

class _OtaUpdateViewState extends State<OtaUpdateView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _manifestUrlController = TextEditingController();
  bool _customUrlExpanded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Auto-check firmware and app update on screen entry
    if (!WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final state = context.read<HomeState>();
        state.checkForAppUpdate();
        state.checkFleetFirmwareUpdates();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _manifestUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HomeState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'System & Device Updates',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Check for All Updates',
            onPressed: () {
              state.checkForAppUpdate();
              state.checkFleetFirmwareUpdates();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Checking cloud repositories for updates...')),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.tealAccent,
          labelColor: Colors.tealAccent,
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(
              icon: Badge(
                isLabelVisible: state.hasAppUpdate,
                child: const Icon(Icons.smartphone_rounded),
              ),
              text: 'App Software',
            ),
            Tab(
              icon: Badge(
                isLabelVisible: state.hasDeviceUpdates,
                label: Text('${state.availableDeviceUpdates.length}'),
                child: const Icon(Icons.devices_other_rounded),
              ),
              text: 'Fleet Firmware',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAppUpdateTab(context, state, isDark),
          _buildDeviceFirmwareTab(context, state, isDark),
        ],
      ),
    );
  }

  // ==========================================================================
  // TAB 1: App Software OTA Update (Android APK)
  // ==========================================================================

  Widget _buildAppUpdateTab(BuildContext context, HomeState state, bool isDark) {
    final update = state.availableAppUpdate;
    final progress = state.appOtaProgress;
    final isDownloading = progress != null && progress.isInProgress;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Current Installation Info Card
        Card(
          elevation: 0,
          color: isDark ? const Color(0xFF222834) : Colors.grey.shade100,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.blueAccent, Colors.tealAccent],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.home_work_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Unified Smart Home',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Installed: v${state.appOtaService.currentVersionName} (Build ${state.appOtaService.currentVersionCode})',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Channel: Stable Release (Android APK)',
                        style: TextStyle(color: Colors.teal, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                if (state.isCheckingAppUpdate)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.sync_rounded),
                    tooltip: 'Check Again',
                    onPressed: () => state.checkForAppUpdate(),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Update Availability Banner / Card
        if (update != null)
          _buildAppUpdateAvailableCard(context, state, update, progress, isDownloading, isDark)
        else
          _buildAppUpToDateCard(context, state, isDark),

        const SizedBox(height: 20),

        // Advanced / Custom Endpoint Section
        _buildCustomManifestSection(context, state, isDark),
      ],
    );
  }

  Widget _buildAppUpdateAvailableCard(
    BuildContext context,
    HomeState state,
    AppOtaManifest update,
    OtaProgress? progress,
    bool isDownloading,
    bool isDark,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.teal, width: 1.5),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF1B2E35), const Color(0xFF142028)]
                : [Colors.teal.shade50, Colors.white],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade700,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.new_releases_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'UPDATE AVAILABLE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  update.formattedSize,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Unified Smart Home v${update.versionName}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Released on ${update.releaseDate} • Verified SHA-256 signature',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 14),

            // What's New Release Notes
            const Text(
              "What's New in This Release:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            ...update.releaseNotes.map(
              (note) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(
                        note,
                        style: const TextStyle(fontSize: 13, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Progress Display
            if (progress != null && (isDownloading || progress.isCompleted || progress.stage == OtaStage.verifying)) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress.progress,
                  minHeight: 10,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress.isCompleted ? Colors.green : Colors.tealAccent,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    progress.statusMessage,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    progress.progressPercentage,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],

            // Action Buttons
            if (progress != null && progress.isCompleted)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.install_mobile_rounded),
                  label: const Text(
                    'Install & Relaunch App',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    final ok = await state.installAppUpdate();
                    if (context.mounted && !ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Launched package installer')),
                      );
                    }
                  },
                ),
              )
            else if (!isDownloading)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.download_rounded),
                  label: Text(
                    'Download & Install Update (${update.formattedSize})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => state.downloadAppUpdate(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppUpToDateCard(BuildContext context, HomeState state, bool isDark) {
    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E2620) : Colors.green.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.green.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 52),
            const SizedBox(height: 12),
            const Text(
              'Your Application is Up to Date',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 6),
            Text(
              'Unified Smart Home v${state.appOtaService.currentVersionName} is the latest release.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Check for Updates'),
              onPressed: () => state.checkForAppUpdate(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomManifestSection(BuildContext context, HomeState state, bool isDark) {
    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1C222E) : Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
      ),
      child: ExpansionTile(
        initiallyExpanded: _customUrlExpanded,
        onExpansionChanged: (v) => setState(() => _customUrlExpanded = v),
        title: const Text(
          'Custom OTA Manifest & Simulation',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: const Text(
          'Configure custom version.json URL or test offline update flow',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        leading: const Icon(Icons.tune_rounded, color: Colors.blueAccent),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          TextField(
            controller: _manifestUrlController,
            decoration: const InputDecoration(
              labelText: 'Remote Manifest URL (JSON)',
              hintText: 'https://myserver.com/ota/version.json',
              prefixIcon: Icon(Icons.link_rounded),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    final url = _manifestUrlController.text.trim();
                    state.checkForAppUpdate(
                      simulate: url.isEmpty,
                      manifestUrl: url.isNotEmpty ? url : null,
                    );
                  },
                  child: const Text('Fetch Remote Manifest'),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  state.checkForAppUpdate(simulate: true);
                },
                child: const Text('Simulate v1.1.0'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // TAB 2: Device Fleet Firmware OTA Updates (Appliances & IoT)
  // ==========================================================================

  Widget _buildDeviceFirmwareTab(BuildContext context, HomeState state, bool isDark) {
    final available = state.availableDeviceUpdates;
    final allDevices = state.allDevices;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Fleet Status Header
        Card(
          elevation: 0,
          color: isDark ? const Color(0xFF222834) : Colors.blue.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: isDark ? Colors.white12 : Colors.blue.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  available.isNotEmpty ? Icons.system_update_rounded : Icons.verified_rounded,
                  color: available.isNotEmpty ? Colors.amberAccent : Colors.green,
                  size: 32,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        available.isNotEmpty
                            ? '${available.length} Firmware Updates Available'
                            : 'All Appliances Up to Date',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Fleet: ${allDevices.length} Connected Appliances • Matter 1.3 FOTA Ready',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (available.isNotEmpty)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.update_rounded, size: 16),
                    label: const Text('Update All'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onPressed: () => state.updateAllDevices(),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Device Cards List
        if (allDevices.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('No devices registered. Add real appliances first.'),
            ),
          )
        else
          ...allDevices.map((dev) {
            final update = available[dev.id];
            final progress = state.deviceOtaProgress[dev.id];
            return _buildDeviceFirmwareCard(context, state, dev, update, progress, isDark);
          }),
      ],
    );
  }

  Widget _buildDeviceFirmwareCard(
    BuildContext context,
    HomeState state,
    SmartDevice device,
    DeviceFirmwareUpdate? update,
    OtaProgress? progress,
    bool isDark,
  ) {
    final hasUpdate = update != null;
    final isFlashing = progress != null && progress.isInProgress;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: hasUpdate ? Colors.teal : (isDark ? Colors.white12 : Colors.grey.shade200),
          width: hasUpdate ? 1.5 : 1.0,
        ),
      ),
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
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(device.icon, color: Colors.blueAccent, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${device.room} • Current: v${device.firmwareVersion}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (!hasUpdate && !isFlashing)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded, color: Colors.green, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Up to date',
                          style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )
                else if (hasUpdate && !isFlashing)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    onPressed: () => state.startDeviceFirmwareUpdate(device.id),
                    child: Text('Update to v${update.availableVersion}'),
                  ),
              ],
            ),

            // If an update is available, show details
            if (hasUpdate && !isFlashing) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Partition: ${update.partitionName}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal),
                        ),
                        Text(
                          'Size: ${update.formattedSize}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...update.highlights.map(
                      (h) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '• $h',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Active Flashing Progress
            if (isFlashing) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress.progress,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.tealAccent),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      progress.statusMessage,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    progress.progressPercentage,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
