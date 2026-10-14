import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/device_model.dart';
import '../../providers/home_state.dart';
import '../../theme/app_theme.dart';
import 'sheets/washer_sheet.dart';
import 'sheets/samsung_washer_sheet.dart';
import 'sheets/refrigerator_sheet.dart';
import 'sheets/thermostat_sheet.dart';
import 'sheets/light_sheet.dart';
import 'sheets/oneplus_tv_sheet.dart';

class DeviceTile extends StatelessWidget {
  final SmartDevice device;

  const DeviceTile({super.key, required this.device});

  Color _getActiveColor() {
    switch (device.category) {
      case DeviceCategory.lighting:
        return AppTheme.activeAmber;
      case DeviceCategory.climate:
        return AppTheme.coolingCyan;
      case DeviceCategory.washer:
      case DeviceCategory.dryer:
        return AppTheme.applianceGreen;
      case DeviceCategory.refrigerator:
        return Colors.teal;
      case DeviceCategory.media:
        return Colors.redAccent;
      default:
        return AppTheme.googleBlue;
    }
  }

  void _openDeepSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        if (device is WasherDevice) {
          final washer = device as WasherDevice;
          if (washer.brand.toLowerCase().contains('samsung') || washer.ecoBubbleEnabled) {
            return SamsungWasherSheet(device: washer);
          }
          return WasherSheet(device: washer);
        } else if (device is RefrigeratorDevice) {
          return RefrigeratorSheet(device: device as RefrigeratorDevice);
        } else if (device is ThermostatDevice) {
          return ThermostatSheet(device: device as ThermostatDevice);
        } else if (device is LightDevice) {
          return LightSheet(device: device as LightDevice);
        } else if (device is TvDevice) {
          return OnePlusTvSheet(device: device as TvDevice);
        }
        return const SizedBox(height: 100);
      },
    );
  }

  void _showDeviceOptions(BuildContext context) {
    final state = context.read<HomeState>();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getActiveColor().withValues(alpha: 0.15),
                  child: Icon(device.icon, color: _getActiveColor()),
                ),
                title: Text(device.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${device.room} • ${_protocolLabel(device.protocol)}'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.power_settings_new_rounded),
                title: Text(device.isPowered ? 'Turn Off' : 'Turn On'),
                onTap: () {
                  Navigator.pop(ctx);
                  state.togglePower(device.id);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Rename Device'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showRenameDialog(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                title: const Text('Remove from Home', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete(context);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showRenameDialog(BuildContext context) {
    final state = context.read<HomeState>();
    final controller = TextEditingController(text: device.name);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Device'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Device Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                device.name = newName;
                state.updateDevice(device);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final state = context.read<HomeState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Device?'),
        content: Text('Are you sure you want to remove "${device.name}" from your home?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              state.removeDevice(device.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Removed "${device.name}" from home')),
              );
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<HomeState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = _getActiveColor();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openDeepSheet(context),
        onLongPress: () => _showDeviceOptions(context),
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: device.isPowered
                ? activeColor.withValues(alpha: isDark ? 0.22 : 0.12)
                : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: device.isPowered
                  ? activeColor.withValues(alpha: 0.5)
                  : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Icon with power toggle on tap
                  GestureDetector(
                    onTap: () => state.togglePower(device.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: device.isPowered ? activeColor : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        device.icon,
                        size: 20,
                        color: device.isPowered ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                      ),
                    ),
                  ),
                  // Badges: LIVE / DEMO & Protocol indicator
                  Row(
                    children: [
                      if (device.isDummy)
                        Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            'DEMO',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        )
                      else
                        Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            'LIVE',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _protocolLabel(device.protocol),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    device.statusSummary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: device.isPowered
                          ? (isDark ? Colors.grey.shade300 : Colors.black87)
                          : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _protocolLabel(DeviceProtocol proto) {
    switch (proto) {
      case DeviceProtocol.matter:
        return 'MATTER';
      case DeviceProtocol.lgThinQ:
        return 'THINQ';
      case DeviceProtocol.smartThings:
        return 'SMARTTHINGS';
      case DeviceProtocol.localLan:
        return 'LAN';
    }
  }
}
