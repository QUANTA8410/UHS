import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/device_model.dart';
import '../../providers/home_state.dart';
import '../../theme/app_theme.dart';
import '../views/ota_update_view.dart';

class QuickActionPills extends StatelessWidget {
  const QuickActionPills({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HomeState>();

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildPill(
            context,
            icon: Icons.lightbulb_rounded,
            label: 'Lights',
            status: '${state.activeLightsCount} on',
            isSelected: state.selectedFilter == DeviceCategory.lighting,
            activeColor: AppTheme.activeAmber,
            onTap: () => state.setFilter(DeviceCategory.lighting),
          ),
          const SizedBox(width: 8),
          _buildPill(
            context,
            icon: Icons.thermostat_rounded,
            label: 'Climate',
            status: '${state.averageClimateTemp.toStringAsFixed(1)}°C',
            isSelected: state.selectedFilter == DeviceCategory.climate,
            activeColor: AppTheme.coolingCyan,
            onTap: () => state.setFilter(DeviceCategory.climate),
          ),
          const SizedBox(width: 8),
          _buildPill(
            context,
            icon: Icons.kitchen_rounded,
            label: 'Appliances',
            status: '${state.activeAppliancesCount} active',
            isSelected: state.selectedFilter == DeviceCategory.washer ||
                state.selectedFilter == DeviceCategory.refrigerator,
            activeColor: AppTheme.applianceGreen,
            onTap: () => state.setFilter(DeviceCategory.washer),
          ),
          const SizedBox(width: 8),
          _buildPill(
            context,
            icon: Icons.bolt_rounded,
            label: 'Energy',
            status: '${(state.totalPowerWatts / 1000).toStringAsFixed(2)} kW',
            isSelected: false,
            activeColor: Colors.deepPurple,
            onTap: () {
              // Quick action for energy
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Real-time power: ${(state.totalPowerWatts).toStringAsFixed(0)} W across ${state.devices.length} devices',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          _buildPill(
            context,
            icon: Icons.system_update_rounded,
            label: 'Updates',
            status: state.hasUpdatesAvailable
                ? '${state.totalUpdatesCount} available'
                : 'Up to date',
            isSelected: state.hasUpdatesAvailable,
            activeColor: Colors.teal,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OtaUpdateView()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPill(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String status,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: 0.18)
                : (isDark ? const Color(0xFF2A2A2A) : Colors.white),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isSelected ? activeColor : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? activeColor : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: isSelected ? activeColor : (isDark ? Colors.white : Colors.black87),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '• $status',
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected
                      ? activeColor.withValues(alpha: 0.9)
                      : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
