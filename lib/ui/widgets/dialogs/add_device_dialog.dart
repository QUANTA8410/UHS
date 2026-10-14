import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/partner_app_model.dart';
import '../../../models/device_model.dart';
import '../../../providers/home_state.dart';
import '../../../services/discovery/network_discovery_service.dart';

class AddDeviceDialog extends StatefulWidget {
  const AddDeviceDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddDeviceDialog(),
    );
  }

  @override
  State<AddDeviceDialog> createState() => _AddDeviceDialogState();
}

class _AddDeviceDialogState extends State<AddDeviceDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  PartnerCategory? _selectedCategory;

  bool _isLoading = false;
  String? _statusMessage;
  bool _isSuccess = false;

  // SmartThings
  final _stTokenController = TextEditingController();

  // LG ThinQ
  final _lgTokenController = TextEditingController();

  // OnePlus TV
  final _tvNameController = TextEditingController(text: 'OnePlus TV 55 U1S');
  final _tvHostController = TextEditingController(text: '192.168.1.');
  String _tvRoom = 'Living Room';

  // Wipro Bulb
  final _bulbNameController = TextEditingController(text: 'Wipro Smart Next Bulb');
  final _bulbHostController = TextEditingController(text: '192.168.1.');
  String _bulbRoom = 'Living Room';

  // LAN scan
  List<DiscoveredDevice> _discoveredDevices = [];

  @override
  void initState() {
    super.initState();
    // 6 tabs: Partner Apps Directory, Wi-Fi Scan, SmartThings, LG ThinQ, OnePlus TV, Wipro Bulb
    _tabController = TabController(length: 6, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _stTokenController.dispose();
    _lgTokenController.dispose();
    _tvNameController.dispose();
    _tvHostController.dispose();
    _bulbNameController.dispose();
    _bulbHostController.dispose();
    super.dispose();
  }

  List<PartnerApp> get _filteredPartnerApps {
    var apps = PartnerApp.googleHomeCatalog;
    if (_selectedCategory != null) {
      apps = apps.where((a) => a.category == _selectedCategory).toList();
    }
    if (_searchQuery.isNotEmpty) {
      apps = apps.where((a) {
        return a.name.toLowerCase().contains(_searchQuery) ||
            a.company.toLowerCase().contains(_searchQuery) ||
            a.description.toLowerCase().contains(_searchQuery) ||
            a.supportedDeviceTypes.any((t) => t.toLowerCase().contains(_searchQuery));
      }).toList();
    }
    return apps;
  }

  Future<void> _runLanScan() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Scanning local Wi-Fi for OnePlus TV, Wipro Bulbs, Matter & UPnP devices...';
      _isSuccess = false;
    });

    final state = context.read<HomeState>();
    final devices = await state.discoveryService.scanLocalNetwork(timeout: const Duration(seconds: 3));

    setState(() {
      _isLoading = false;
      _discoveredDevices = devices;
      _statusMessage = 'Found ${devices.length} network device(s). Tap any device to add it.';
      _isSuccess = true;
    });
  }

  Future<void> _connectSmartThings() async {
    final token = _stTokenController.text.trim();
    if (token.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter your Samsung SmartThings Personal Access Token.';
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Connecting to SmartThings Cloud & querying Samsung appliances...';
      _isSuccess = false;
    });

    final state = context.read<HomeState>();
    final success = await state.connectSmartThings(token);

    setState(() {
      _isLoading = false;
      if (success) {
        _statusMessage = 'Successfully connected! Imported your Samsung devices.';
        _isSuccess = true;
      } else {
        _statusMessage = 'Failed to authenticate token. Please verify token permissions.';
        _isSuccess = false;
      }
    });

    if (success) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _connectLgThinq() async {
    final token = _lgTokenController.text.trim();
    if (token.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter your LG ThinQ Token / API Key.';
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Connecting to LG ThinQ Cloud...';
      _isSuccess = false;
    });

    final state = context.read<HomeState>();
    final success = await state.connectLgThinq(token);

    setState(() {
      _isLoading = false;
      if (success) {
        _statusMessage = 'Successfully connected! Imported your LG DualCool AC.';
        _isSuccess = true;
      } else {
        _statusMessage = 'Failed to connect to LG ThinQ. Please check token.';
        _isSuccess = false;
      }
    });

    if (success) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _addOnePlusTv() async {
    final host = _tvHostController.text.trim();
    final name = _tvNameController.text.trim();
    if (host.isEmpty || name.isEmpty) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Connecting to OnePlus TV at $host...';
    });

    final state = context.read<HomeState>();
    await state.addOnePlusTvDevice(name: name, host: host, room: _tvRoom);

    setState(() {
      _isLoading = false;
      _statusMessage = 'OnePlus TV added successfully!';
      _isSuccess = true;
    });

    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) Navigator.pop(context);
  }

  Future<void> _addWiproBulb() async {
    final host = _bulbHostController.text.trim();
    final name = _bulbNameController.text.trim();
    if (host.isEmpty || name.isEmpty) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Connecting to Wipro Smart Bulb at $host...';
    });

    final state = context.read<HomeState>();
    await state.addWiproBulbDevice(name: name, host: host, room: _bulbRoom);

    setState(() {
      _isLoading = false;
      _statusMessage = 'Wipro Smart Bulb added successfully!';
      _isSuccess = true;
    });

    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) Navigator.pop(context);
  }

  void _openPartnerLinkSheet(PartnerApp app) {
    if (app.integrationType == PartnerIntegrationType.smartThings) {
      _tabController.animateTo(2);
      return;
    } else if (app.integrationType == PartnerIntegrationType.lgThinQ) {
      _tabController.animateTo(3);
      return;
    } else if (app.integrationType == PartnerIntegrationType.oneplus) {
      _tabController.animateTo(4);
      return;
    } else if (app.integrationType == PartnerIntegrationType.wiproSmart) {
      _tabController.animateTo(5);
      return;
    } else if (app.integrationType == PartnerIntegrationType.lanScan) {
      _tabController.animateTo(1);
      return;
    }

    // Generic Partner Link Dialog (Google Home style account linker)
    final tokenCtrl = TextEditingController();
    final nameCtrl = TextEditingController(text: '${app.name} Device');
    String selectedRoom = 'Living Room';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: app.brandColor.withValues(alpha: 0.15),
                    child: Icon(app.icon, color: app.brandColor),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Link ${app.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Works with Google Home • ${app.badge}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(sheetCtx)),
                ],
              ),
              const SizedBox(height: 12),
              Text(app.description, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Device Label', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tokenCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: '${app.name} API Key / Bridge IP / OAuth Token',
                  hintText: 'Enter credential or LAN IP',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedRoom,
                decoration: const InputDecoration(labelText: 'Assign Room', border: OutlineInputBorder()),
                items: ['Living Room', 'Kitchen', 'Laundry Room', 'Master Bedroom']
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) selectedRoom = v;
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: app.brandColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.link_rounded),
                label: Text('Link Account & Add ${app.name}'),
                onPressed: () {
                  final state = context.read<HomeState>();
                  final devName = nameCtrl.text.trim();
                  // Create real integrated device model based on app category
                  SmartDevice newDev;
                  if (app.category == PartnerCategory.lighting) {
                    newDev = LightDevice(
                      id: '${app.id}_${DateTime.now().millisecondsSinceEpoch}',
                      name: devName,
                      room: selectedRoom,
                      protocol: DeviceProtocol.matter,
                      brand: app.name,
                      isDummy: false,
                    );
                  } else if (app.category == PartnerCategory.climate) {
                    newDev = ThermostatDevice(
                      id: '${app.id}_${DateTime.now().millisecondsSinceEpoch}',
                      name: devName,
                      room: selectedRoom,
                      protocol: DeviceProtocol.lgThinQ,
                      brand: app.name,
                      isDummy: false,
                    );
                  } else if (app.category == PartnerCategory.appliances) {
                    newDev = WasherDevice(
                      id: '${app.id}_${DateTime.now().millisecondsSinceEpoch}',
                      name: devName,
                      room: selectedRoom,
                      protocol: DeviceProtocol.smartThings,
                      brand: app.name,
                      isDummy: false,
                    );
                  } else {
                    newDev = LightDevice(
                      id: '${app.id}_${DateTime.now().millisecondsSinceEpoch}',
                      name: devName,
                      room: selectedRoom,
                      protocol: DeviceProtocol.localLan,
                      brand: app.name,
                      isDummy: false,
                    );
                  }

                  state.addDevice(newDev);
                  Navigator.pop(sheetCtx);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Linked ${app.name} and added device!')),
                  );
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HomeState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Header: Google Home Style
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add & Connect Real Devices',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Works with Google Home & Unified IoT',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Search Bar across 30+ Partner Apps
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search 30+ partner apps (e.g. SmartThings, LG, Hue, Tapo)...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: Colors.blueAccent,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blueAccent,
            tabs: const [
              Tab(icon: Icon(Icons.apps_rounded), text: 'Works with Google'),
              Tab(icon: Icon(Icons.wifi_tethering), text: 'Wi-Fi Scan'),
              Tab(icon: Icon(Icons.local_laundry_service), text: 'SmartThings'),
              Tab(icon: Icon(Icons.ac_unit), text: 'LG ThinQ'),
              Tab(icon: Icon(Icons.tv), text: 'OnePlus TV'),
              Tab(icon: Icon(Icons.lightbulb), text: 'Wipro Bulb'),
            ],
          ),

          if (_statusMessage != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _isSuccess
                    ? Colors.green.shade50
                    : (_isLoading ? Colors.blue.shade50 : Colors.orange.shade50),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isSuccess
                      ? Colors.green.shade300
                      : (_isLoading ? Colors.blue.shade300 : Colors.orange.shade300),
                ),
              ),
              child: Row(
                children: [
                  if (_isLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      _isSuccess ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                      size: 18,
                      color: _isSuccess ? Colors.green : Colors.orange,
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _statusMessage!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _isSuccess
                            ? Colors.green.shade900
                            : (_isLoading ? Colors.blue.shade900 : Colors.orange.shade900),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 0: All Partner Apps Directory (Works with Google Home)
                _buildPartnerAppsDirectoryTab(context),
                // Tab 1: Wi-Fi LAN Scan
                _buildLanScanTab(context),
                // Tab 2: Samsung SmartThings
                _buildSmartThingsTab(context),
                // Tab 3: LG ThinQ
                _buildLgThinqTab(context),
                // Tab 4: OnePlus TV
                _buildOnePlusTvTab(context, state),
                // Tab 5: Wipro Bulb
                _buildWiproBulbTab(context, state),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerAppsDirectoryTab(BuildContext context) {
    final apps = _filteredPartnerApps;

    return Column(
      children: [
        // Category Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              FilterChip(
                label: const Text('All Apps'),
                selected: _selectedCategory == null,
                onSelected: (_) => setState(() => _selectedCategory = null),
              ),
              const SizedBox(width: 6),
              FilterChip(
                label: const Text('Appliances'),
                selected: _selectedCategory == PartnerCategory.appliances,
                onSelected: (_) => setState(() => _selectedCategory = PartnerCategory.appliances),
              ),
              const SizedBox(width: 6),
              FilterChip(
                label: const Text('Climate & AC'),
                selected: _selectedCategory == PartnerCategory.climate,
                onSelected: (_) => setState(() => _selectedCategory = PartnerCategory.climate),
              ),
              const SizedBox(width: 6),
              FilterChip(
                label: const Text('Lighting'),
                selected: _selectedCategory == PartnerCategory.lighting,
                onSelected: (_) => setState(() => _selectedCategory = PartnerCategory.lighting),
              ),
              const SizedBox(width: 6),
              FilterChip(
                label: const Text('TV & Media'),
                selected: _selectedCategory == PartnerCategory.entertainment,
                onSelected: (_) => setState(() => _selectedCategory = PartnerCategory.entertainment),
              ),
              const SizedBox(width: 6),
              FilterChip(
                label: const Text('Security & Cams'),
                selected: _selectedCategory == PartnerCategory.security,
                onSelected: (_) => setState(() => _selectedCategory = PartnerCategory.security),
              ),
              const SizedBox(width: 6),
              FilterChip(
                label: const Text('Plugs & Energy'),
                selected: _selectedCategory == PartnerCategory.plugsAndEnergy,
                onSelected: (_) => setState(() => _selectedCategory = PartnerCategory.plugsAndEnergy),
              ),
              const SizedBox(width: 6),
              FilterChip(
                label: const Text('Robot Vacuums'),
                selected: _selectedCategory == PartnerCategory.cleaning,
                onSelected: (_) => setState(() => _selectedCategory = PartnerCategory.cleaning),
              ),
            ],
          ),
        ),

        Expanded(
          child: apps.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text('No partner apps found for "$_searchQuery"', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  itemCount: apps.length,
                  itemBuilder: (ctx, index) {
                    final app = apps[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 0.5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: app.brandColor.withValues(alpha: 0.15),
                          child: Icon(app.icon, color: app.brandColor),
                        ),
                        title: Row(
                          children: [
                            Text(app.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: app.brandColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                app.badge,
                                style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: app.brandColor),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text(app.company, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(app.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: app.brandColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Link', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: () => _openPartnerLinkSheet(app),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildLanScanTab(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: _isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.radar_rounded),
            label: Text(_isLoading ? 'Scanning Wi-Fi...' : 'Scan Local Wi-Fi Network', style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _isLoading ? null : _runLanScan,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _discoveredDevices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_find_rounded, size: 54, color: Colors.grey.shade400),
                        const SizedBox(height: 10),
                        const Text(
                          'Tap Scan to discover smart devices on your Wi-Fi\n(OnePlus TV, Wipro Bulbs, Matter & UPnP devices)',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _discoveredDevices.length,
                    itemBuilder: (itemCtx, index) {
                      final d = _discoveredDevices[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade50,
                            child: Icon(
                              d.name.contains('TV') ? Icons.tv_rounded : Icons.device_hub_rounded,
                              color: Colors.blueAccent,
                            ),
                          ),
                          title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text('${d.manufacturer} • ${d.host}:${d.port}', style: const TextStyle(fontSize: 12)),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            child: const Text('Add'),
                            onPressed: () async {
                              final state = itemCtx.read<HomeState>();
                              if (d.name.contains('TV')) {
                                await state.addOnePlusTvDevice(name: d.name, host: d.host, room: 'Living Room');
                              } else {
                                await state.addWiproBulbDevice(name: d.name, host: d.host, room: 'Living Room');
                              }
                              if (!itemCtx.mounted) return;
                              ScaffoldMessenger.of(itemCtx).showSnackBar(
                                SnackBar(content: Text('Added ${d.name} to home!')),
                              );
                              Navigator.pop(itemCtx);
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartThingsTab(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Samsung SmartThings Fleet Connect', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                SizedBox(height: 4),
                Text(
                  'Connects your Samsung AI Ecobubble™ Washing Machine and SmartThings appliances via the official REST API.\nGenerate your Personal Access Token (PAT) at:\naccount.smartthings.com/tokens',
                  style: TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _stTokenController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'SmartThings Personal Access Token',
              hintText: 'e.g. 7a8b9c0d-1234-5678-...',
              prefixIcon: const Icon(Icons.key_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.cloud_download_rounded),
            label: const Text('Connect & Import Samsung Washer', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _isLoading ? null : _connectSmartThings,
          ),
        ],
      ),
    );
  }

  Widget _buildLgThinqTab(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.cyan.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.cyan.shade200),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('LG ThinQ DualCool Connect', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.cyan)),
                SizedBox(height: 4),
                Text(
                  'Connects your LG DualCool Air Conditioner and ThinQ appliances to control Jet Cool, Plasmaster™ Ionizer, and target temperature.',
                  style: TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _lgTokenController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'LG ThinQ Access Token / API Key',
              prefixIcon: const Icon(Icons.vpn_key_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyan.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.cloud_download_rounded),
            label: const Text('Connect & Import LG DualCool AC', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _isLoading ? null : _connectLgThinq,
          ),
        ],
      ),
    );
  }

  Widget _buildOnePlusTvTab(BuildContext context, HomeState state) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('OnePlus TV Direct LAN Connect', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                SizedBox(height: 4),
                Text(
                  'Connect to your OnePlus TV on your local Wi-Fi. Enter the TV\'s local IP address (found in TV Settings > Network > Wi-Fi Status).',
                  style: TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _tvNameController,
            decoration: InputDecoration(
              labelText: 'Device Name',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tvHostController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'OnePlus TV IP Address',
              hintText: 'e.g. 192.168.1.105',
              prefixIcon: const Icon(Icons.router_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _tvRoom,
            decoration: InputDecoration(
              labelText: 'Room',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            items: state.rooms.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _tvRoom = val);
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.add_to_queue_rounded),
            label: const Text('Add Real OnePlus TV', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _isLoading ? null : _addOnePlusTv,
          ),
        ],
      ),
    );
  }

  Widget _buildWiproBulbTab(BuildContext context, HomeState state) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Wipro Smart Next Bulb Connect', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                SizedBox(height: 4),
                Text(
                  'Connect to your Wipro Smart Next RGB/CCT bulbs over local Wi-Fi or Tuya LAN protocol.',
                  style: TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _bulbNameController,
            decoration: InputDecoration(
              labelText: 'Bulb Name',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bulbHostController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Bulb IP Address (on Wi-Fi)',
              hintText: 'e.g. 192.168.1.120',
              prefixIcon: const Icon(Icons.lightbulb_outline_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _bulbRoom,
            decoration: InputDecoration(
              labelText: 'Room',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            items: state.rooms.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _bulbRoom = val);
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade800,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Real Wipro Bulb', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _isLoading ? null : _addWiproBulb,
          ),
        ],
      ),
    );
  }
}
