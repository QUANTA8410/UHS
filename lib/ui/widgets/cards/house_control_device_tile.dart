import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/real_iot_controller.dart';
import '../animations/universal_device_animations.dart';

/// Authentic House Control Device Tile (`.tile`).
/// Faithfully ported from `https://github.com/0xProbabillity/house-control.git`:
/// - 76px height, 22px squircle borderRadius
/// - Glowing `.bubble` with device category emblem
/// - Bottom `.tile-level` line for dimmable fixtures
/// - Interactive horizontal swipe to dim
/// - AC full-width tile with `- 23° +` stepper and mini power toggle
/// - Washer live telemetry (cycle stage, remaining min, EcoBubble)
class HouseControlDeviceTile extends StatefulWidget {
  final RealSmartDevice device;
  final VoidCallback onTap;
  final VoidCallback onPowerToggle;
  final VoidCallback onLongPress;
  final ValueChanged<double>? onLevelChanged;
  final ValueChanged<double>? onTempChanged;

  const HouseControlDeviceTile({
    super.key,
    required this.device,
    required this.onTap,
    required this.onPowerToggle,
    required this.onLongPress,
    this.onLevelChanged,
    this.onTempChanged,
  });

  @override
  State<HouseControlDeviceTile> createState() => _HouseControlDeviceTileState();
}

class _HouseControlDeviceTileState extends State<HouseControlDeviceTile> {
  double? _dragLevel;

  @override
  Widget build(BuildContext context) {
    final dev = widget.device;
    final archetype = UniversalCategoryClassifier.classify(dev);
    final isAc = archetype == UniversalDeviceArchetype.climateAc || dev.category == 'ac';
    final isWasher = archetype == UniversalDeviceArchetype.laundry || dev.category == 'washer';
    final isLight = archetype == UniversalDeviceArchetype.lighting || dev.category == 'light';
    final tint = UniversalCategoryClassifier.colorFor(archetype);
    final isOn = dev.isOn;

    final double level = _dragLevel ?? (dev.primaryValue / 100.0).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        widget.onLongPress();
      },
      onHorizontalDragUpdate: isLight && isOn
          ? (details) {
              final box = context.findRenderObject() as RenderBox?;
              if (box == null) return;
              final width = box.size.width;
              final deltaRatio = details.delta.dx / width;
              final current = _dragLevel ?? (dev.primaryValue / 100.0);
              final newLevel = (current + deltaRatio).clamp(0.05, 1.0);
              setState(() => _dragLevel = newLevel);
              widget.onLevelChanged?.call(newLevel * 100.0);
            }
          : null,
      onHorizontalDragEnd: isLight && isOn
          ? (_) {
              setState(() => _dragLevel = null);
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isOn
              ? Color.alphaBlend(tint.withValues(alpha: 0.18), const Color(0xFF101726))
              : const Color(0xFF0F1522),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isOn ? tint.withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.08),
            width: isOn ? 1.4 : 1.0,
          ),
          boxShadow: [
            if (isOn)
              BoxShadow(
                color: tint.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Content Row
              Row(
                children: [
                  // 1. Glowing Squircle Bubble
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      widget.onPowerToggle();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isOn ? tint : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          if (isOn)
                            BoxShadow(
                              color: tint.withValues(alpha: 0.65),
                              blurRadius: 14,
                              spreadRadius: 1,
                            ),
                        ],
                      ),
                      child: Icon(
                        UniversalCategoryClassifier.iconFor(archetype),
                        size: 20,
                        color: isOn ? _getContrastColor(tint) : Colors.white54,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 2. Tile Title & Subtitle
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dev.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            color: Color(0xFFF3F5FA),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _buildSubtitle(dev, archetype, isOn),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isOn
                                ? Color.lerp(tint, Colors.white, 0.65)
                                : Colors.white.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 3. Right Action Controls
                  if (isAc)
                    _buildAcStepper(context, dev, tint, isOn)
                  else if (isWasher)
                    _buildWasherControl(context, dev, tint, isOn)
                  else if (isOn && isLight)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: tint.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${(level * 100).round()}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: tint,
                        ),
                      ),
                    ),
                ],
              ),

              // 4. Bottom Dimmable Level Bar (.tile-level)
              if (isLight && isOn)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 3.5,
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: level.clamp(0.02, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: tint,
                          boxShadow: [
                            BoxShadow(color: tint.withValues(alpha: 0.8), blurRadius: 4),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAcStepper(BuildContext context, RealSmartDevice dev, Color tint, bool isOn) {
    final double target = dev.primaryValue;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Minus Button
        _stepperButton(
          icon: Icons.remove_rounded,
          onTap: isOn
              ? () {
                  HapticFeedback.selectionClick();
                  final next = (target - 1.0).clamp(16.0, 30.0);
                  widget.onTempChanged?.call(next);
                }
              : null,
        ),
        const SizedBox(width: 2),
        // Temperature Display
        SizedBox(
          width: 38,
          child: Text(
            '${target.round()}°',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isOn ? Colors.white : Colors.white38,
            ),
          ),
        ),
        const SizedBox(width: 2),
        // Plus Button
        _stepperButton(
          icon: Icons.add_rounded,
          onTap: isOn
              ? () {
                  HapticFeedback.selectionClick();
                  final next = (target + 1.0).clamp(16.0, 30.0);
                  widget.onTempChanged?.call(next);
                }
              : null,
        ),
        const SizedBox(width: 8),
        // Mini Power Button
        GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            widget.onPowerToggle();
          },
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOn ? tint : Colors.white.withValues(alpha: 0.08),
              boxShadow: [
                if (isOn)
                  BoxShadow(
                    color: tint.withValues(alpha: 0.5),
                    blurRadius: 10,
                  ),
              ],
            ),
            child: Icon(
              Icons.power_settings_new_rounded,
              size: 18,
              color: isOn ? _getContrastColor(tint) : Colors.white38,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWasherControl(BuildContext context, RealSmartDevice dev, Color tint, bool isOn) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onPowerToggle();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isOn ? tint.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOn ? tint.withValues(alpha: 0.5) : Colors.white12,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isOn ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 15,
              color: isOn ? tint : Colors.white60,
            ),
            const SizedBox(width: 4),
            Text(
              isOn ? 'Pause' : 'Start',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isOn ? tint : Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepperButton({required IconData icon, required VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap != null ? Colors.white70 : Colors.white24,
        ),
      ),
    );
  }

  String _buildSubtitle(RealSmartDevice dev, UniversalDeviceArchetype archetype, bool isOn) {
    if (!dev.isOnline) return 'Offline';
    if (!isOn) return 'Off · Standby';

    switch (archetype) {
      case UniversalDeviceArchetype.lighting:
        return 'On · ${dev.primaryValue.round()}%';
      case UniversalDeviceArchetype.climateAc:
        final windFree = dev.windFreeEnabled ? ' · WindFree™' : '';
        return 'Cool · ${dev.primaryValue.round()}°C$windFree';
      case UniversalDeviceArchetype.laundry:
        final stage = dev.washerStage;
        final min = dev.remainingMinutes;
        return '$stage · ${min}m left';
      case UniversalDeviceArchetype.refrigeration:
        return '${dev.fridgeTemp.round()}°C / ${dev.freezerTemp.round()}°C';
      case UniversalDeviceArchetype.tvMedia:
        return dev.artModeEnabled ? 'Art Mode' : 'Online';
      default:
        return 'Active · Running';
    }
  }

  Color _getContrastColor(Color bg) {
    final luminance = bg.computeLuminance();
    return luminance > 0.45 ? const Color(0xFF101726) : Colors.white;
  }
}
