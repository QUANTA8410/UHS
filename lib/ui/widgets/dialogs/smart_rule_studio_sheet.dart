import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/real_home_provider.dart';
import '../../../services/automation/smart_automation_engine.dart';
import '../../../services/real_iot_controller.dart';

class SmartRuleStudioSheet extends StatefulWidget {
  final MultiConditionAutomationRule? existingRule;
  final String? initialTemplate;

  const SmartRuleStudioSheet({
    super.key,
    this.existingRule,
    this.initialTemplate,
  });

  @override
  State<SmartRuleStudioSheet> createState() => _SmartRuleStudioSheetState();
}

class _SmartRuleStudioSheetState extends State<SmartRuleStudioSheet> {
  final TextEditingController _nameCtrl = TextEditingController(text: 'My Smart Routine');

  // Trigger state
  TriggerKind _selectedTriggerKind = TriggerKind.timeSchedule;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 22, minute: 0);
  String _solarEvent = 'sunset';
  String _presenceEvent = 'leave_home';
  String? _triggerDeviceId;
  String _triggerDeviceState = 'on';
  final List<int> _selectedWeekdays = [1, 2, 3, 4, 5, 6, 7];

  // Preconditions state
  final Set<PreconditionKind> _selectedPreconditions = {};

  // Actions sequence
  final List<_EditableActionStep> _actionSteps = [];

  @override
  void initState() {
    super.initState();
    final rule = widget.existingRule;
    if (rule != null) {
      _nameCtrl.text = rule.name;
      _selectedTriggerKind = rule.trigger.kind;
      if (rule.trigger.kind == TriggerKind.timeSchedule) {
        final parts = rule.trigger.value.split(':');
        if (parts.length == 2) {
          _selectedTime = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 22,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        }
      } else if (rule.trigger.kind == TriggerKind.solarEvent) {
        _solarEvent = rule.trigger.value;
      } else if (rule.trigger.kind == TriggerKind.wifiPresence) {
        _presenceEvent = rule.trigger.value;
      } else if (rule.trigger.kind == TriggerKind.deviceState) {
        _triggerDeviceId = rule.trigger.sourceDeviceId;
        _triggerDeviceState = rule.trigger.value;
      }
      _selectedWeekdays
        ..clear()
        ..addAll(rule.trigger.weekdays);

      for (final p in rule.preconditions) {
        _selectedPreconditions.add(p.kind);
      }

      for (final a in rule.actions) {
        _actionSteps.add(
          _EditableActionStep(
            targetDeviceId: a.targetDeviceId,
            targetDeviceName: a.targetDeviceName,
            turnOn: a.turnOn,
            targetLevel: a.targetLevel,
            delaySecondsBefore: a.delaySecondsBefore,
          ),
        );
      }
    } else if (widget.initialTemplate != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final home = context.read<RealHomeProvider>();
        if (widget.initialTemplate == 'washer_finished' ||
            widget.initialTemplate == 'washer') {
          _applyWasherFinishedAlertTemplate(home.devices);
        } else if (widget.initialTemplate == 'goodnight') {
          _applyGoodnightTemplate(home.devices);
        } else if (widget.initialTemplate == 'cinema') {
          _applyCinemaNightTemplate(home.devices);
        }
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final home = context.watch<RealHomeProvider>();
    final devices = home.devices;

    // Ensure initial action step if empty and devices exist
    if (_actionSteps.isEmpty && devices.isNotEmpty) {
      final first = devices.first;
      _actionSteps.add(
        _EditableActionStep(
          targetDeviceId: first.id,
          targetDeviceName: first.name,
          turnOn: true,
          targetLevel: first.category == 'light' ? 80.0 : (first.category == 'ac' ? 24.0 : null),
          delaySecondsBefore: 0,
        ),
      );
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: Colors.white24, width: 1.1),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFBF5AF2).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_fix_high_rounded, color: Color(0xFFBF5AF2), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.existingRule != null ? 'Edit Automation Rule' : 'Visual Apple Glass Rule Studio',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        'WHEN (Trigger) ➔ ONLY IF (Guards) ➔ THEN (Sequence)',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
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
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Quick Routine Templates
                _buildQuickTemplatesSection(devices),

                // 1. Rule Name
                const Text(
                  'RULE NAME',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 0.8),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameCtrl,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'e.g. Cinema Night Mode',
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.07),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 20),

                // 2. WHEN (TRIGGER)
                _buildSectionHeader('1. WHEN (TRIGGER)', Icons.flash_on_rounded, const Color(0xFFFF9F0A)),
                const SizedBox(height: 8),
                _buildTriggerCard(context, devices),
                const SizedBox(height: 20),

                // 3. ONLY IF (PRECONDITIONS)
                _buildSectionHeader('2. ONLY IF (PRECONDITIONS)', Icons.shield_rounded, const Color(0xFF0A84FF)),
                const SizedBox(height: 8),
                _buildPreconditionsCard(),
                const SizedBox(height: 20),

                // 4. THEN (ACTION SEQUENCE)
                _buildSectionHeader('3. THEN (MULTI-STEP ACTION SEQUENCE)', Icons.play_arrow_rounded, const Color(0xFF30D158)),
                const SizedBox(height: 8),
                _buildActionsCard(context, devices),
                const SizedBox(height: 30),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF30D158),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 4,
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 22),
                    label: const Text(
                      'Save & Deploy Rule',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    onPressed: () => _saveRule(context),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTemplatesSection(List<RealSmartDevice> devices) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ROUTINE TEMPLATES & PRESETS',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 0.8),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildTemplateChip(
                key: const Key('template_washer_finished_alert'),
                label: '🧺 Washer Finished Alert',
                color: const Color(0xFF30D158),
                icon: Icons.local_laundry_service_rounded,
                onTap: () => _applyWasherFinishedAlertTemplate(devices),
              ),
              const SizedBox(width: 8),
              _buildTemplateChip(
                key: const Key('template_goodnight_mode'),
                label: '🌙 Goodnight Mode',
                color: const Color(0xFF0A84FF),
                icon: Icons.bedtime_rounded,
                onTap: () => _applyGoodnightTemplate(devices),
              ),
              const SizedBox(width: 8),
              _buildTemplateChip(
                key: const Key('template_cinema_night'),
                label: '🎬 Cinema Night',
                color: const Color(0xFFBF5AF2),
                icon: Icons.movie_filter_rounded,
                onTap: () => _applyCinemaNightTemplate(devices),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTemplateChip({
    Key? key,
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      key: key,
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _applyWasherFinishedAlertTemplate(List<RealSmartDevice> devices) {
    if (devices.isEmpty) return;
    final washer = devices.firstWhere(
      (d) => d.category == 'washer',
      orElse: () => devices.first,
    );
    final bulb = devices.firstWhere(
      (d) => d.category == 'light',
      orElse: () => devices.firstWhere((d) => d.id != washer.id, orElse: () => washer),
    );

    setState(() {
      _nameCtrl.text = '🧺 Washer Finished Alert';
      _selectedTriggerKind = TriggerKind.deviceState;
      _triggerDeviceId = washer.id;
      _triggerDeviceState = 'off';
      _selectedPreconditions.clear();

      _actionSteps
        ..clear()
        ..addAll([
          _EditableActionStep(
            targetDeviceId: bulb.id,
            targetDeviceName: bulb.name,
            turnOn: true,
            targetLevel: 100.0,
            delaySecondsBefore: 0,
          ),
          _EditableActionStep(
            targetDeviceId: bulb.id,
            targetDeviceName: bulb.name,
            turnOn: false,
            targetLevel: null,
            delaySecondsBefore: 2,
          ),
          _EditableActionStep(
            targetDeviceId: bulb.id,
            targetDeviceName: bulb.name,
            turnOn: true,
            targetLevel: 100.0,
            delaySecondsBefore: 2,
          ),
          _EditableActionStep(
            targetDeviceId: bulb.id,
            targetDeviceName: bulb.name,
            turnOn: false,
            targetLevel: null,
            delaySecondsBefore: 2,
          ),
        ]);
    });
    HapticFeedback.lightImpact();
  }

  void _applyGoodnightTemplate(List<RealSmartDevice> devices) {
    if (devices.isEmpty) return;
    setState(() {
      _nameCtrl.text = '🌙 Goodnight Mode';
      _selectedTriggerKind = TriggerKind.timeSchedule;
      _selectedTime = const TimeOfDay(hour: 23, minute: 0);
      _selectedPreconditions
        ..clear()
        ..add(PreconditionKind.onlyWhenHome);
      _actionSteps
        ..clear()
        ..addAll(
          devices.map(
            (d) => _EditableActionStep(
              targetDeviceId: d.id,
              targetDeviceName: d.name,
              turnOn: false,
              delaySecondsBefore: 0,
            ),
          ),
        );
    });
    HapticFeedback.lightImpact();
  }

  void _applyCinemaNightTemplate(List<RealSmartDevice> devices) {
    if (devices.isEmpty) return;
    final tv = devices.firstWhere((d) => d.category == 'tv', orElse: () => devices.first);
    final light = devices.firstWhere((d) => d.category == 'light', orElse: () => devices.last);
    setState(() {
      _nameCtrl.text = '🎬 Cinema Night';
      _selectedTriggerKind = TriggerKind.deviceState;
      _triggerDeviceId = tv.id;
      _triggerDeviceState = 'on';
      _selectedPreconditions
        ..clear()
        ..add(PreconditionKind.onlyAtNight);
      _actionSteps
        ..clear()
        ..addAll([
          _EditableActionStep(
            targetDeviceId: light.id,
            targetDeviceName: light.name,
            turnOn: true,
            targetLevel: 15.0,
            delaySecondsBefore: 1,
          ),
        ]);
    });
    HapticFeedback.lightImpact();
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.5),
        ),
      ],
    );
  }

  Widget _buildTriggerCard(BuildContext context, List<RealSmartDevice> devices) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trigger Kind Dropdown
          DropdownButtonFormField<TriggerKind>(
            initialValue: _selectedTriggerKind,
            dropdownColor: const Color(0xFF161F36),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Trigger Type',
              labelStyle: const TextStyle(color: Colors.white60),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            items: const [
              DropdownMenuItem(value: TriggerKind.timeSchedule, child: Text('⏱️ Specific Time Schedule')),
              DropdownMenuItem(value: TriggerKind.solarEvent, child: Text('☀️ Solar Event (Sunset / Sunrise)')),
              DropdownMenuItem(value: TriggerKind.wifiPresence, child: Text('📍 Geofence / Wi-Fi Presence')),
              DropdownMenuItem(value: TriggerKind.deviceState, child: Text('⚡ Hardware Device State Change')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedTriggerKind = val);
            },
          ),
          const SizedBox(height: 14),

          // Time Schedule Controls
          if (_selectedTriggerKind == TriggerKind.timeSchedule) ...[
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _selectedTime,
                      );
                      if (picked != null) {
                        setState(() => _selectedTime = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFF9F0A).withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Scheduled Time:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          Text(
                            _selectedTime.format(context),
                            style: const TextStyle(color: Color(0xFFFF9F0A), fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('REPEAT ON DAYS:', style: TextStyle(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                _buildDayChip('M', 1),
                _buildDayChip('T', 2),
                _buildDayChip('W', 3),
                _buildDayChip('T', 4),
                _buildDayChip('F', 5),
                _buildDayChip('S', 6),
                _buildDayChip('S', 7),
              ],
            ),
          ] else if (_selectedTriggerKind == TriggerKind.solarEvent) ...[
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('🌇 At Sunset (18:30)'),
                    selected: _solarEvent == 'sunset',
                    selectedColor: const Color(0xFFFF9F0A),
                    onSelected: (val) => setState(() => _solarEvent = 'sunset'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('🌅 At Sunrise (06:00)'),
                    selected: _solarEvent == 'sunrise',
                    selectedColor: const Color(0xFFFF9F0A),
                    onSelected: (val) => setState(() => _solarEvent = 'sunrise'),
                  ),
                ),
              ],
            ),
          ] else if (_selectedTriggerKind == TriggerKind.wifiPresence) ...[
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('🚶 Leaving Home'),
                    selected: _presenceEvent == 'leave_home',
                    selectedColor: const Color(0xFF0A84FF),
                    onSelected: (val) => setState(() => _presenceEvent = 'leave_home'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('🏠 Arriving Home'),
                    selected: _presenceEvent == 'arrive_home',
                    selectedColor: const Color(0xFF0A84FF),
                    onSelected: (val) => setState(() => _presenceEvent = 'arrive_home'),
                  ),
                ),
              ],
            ),
          ] else if (_selectedTriggerKind == TriggerKind.deviceState) ...[
            DropdownButtonFormField<String>(
              initialValue: _triggerDeviceId ?? (devices.isNotEmpty ? devices.first.id : null),
              dropdownColor: const Color(0xFF161F36),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Source Device',
                labelStyle: const TextStyle(color: Colors.white60),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
              items: devices.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList(),
              onChanged: (val) => setState(() => _triggerDeviceId = val),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Turns ON'),
                    selected: _triggerDeviceState == 'on',
                    selectedColor: const Color(0xFF30D158),
                    onSelected: (val) => setState(() => _triggerDeviceState = 'on'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Turns OFF'),
                    selected: _triggerDeviceState == 'off',
                    selectedColor: const Color(0xFFFF453A),
                    onSelected: (val) => setState(() => _triggerDeviceState = 'off'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDayChip(String label, int day) {
    final isSel = _selectedWeekdays.contains(day);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSel) {
            if (_selectedWeekdays.length > 1) _selectedWeekdays.remove(day);
          } else {
            _selectedWeekdays.add(day);
          }
        });
      },
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSel ? const Color(0xFFFF9F0A) : Colors.white10,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSel ? Colors.black : Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildPreconditionsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Guard conditions that must be satisfied for the rule to fire:',
            style: TextStyle(fontSize: 11.5, color: Colors.white60),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPreconditionFilterChip('🌙 Only at Night (18:30 - 06:00)', PreconditionKind.onlyAtNight),
              _buildPreconditionFilterChip('☀️ Only Daytime (06:00 - 18:30)', PreconditionKind.onlyDaytime),
              _buildPreconditionFilterChip('📍 Only When at Home', PreconditionKind.onlyWhenHome),
              _buildPreconditionFilterChip('💼 Only on Weekdays', PreconditionKind.onlyWeekdays),
              _buildPreconditionFilterChip('🌴 Only on Weekends', PreconditionKind.onlyWeekends),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreconditionFilterChip(String label, PreconditionKind kind) {
    final isSel = _selectedPreconditions.contains(kind);
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: isSel ? Colors.white : Colors.white70)),
      selected: isSel,
      selectedColor: const Color(0xFF0A84FF),
      backgroundColor: Colors.white.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (val) {
        setState(() {
          if (val) {
            _selectedPreconditions.add(kind);
          } else {
            _selectedPreconditions.remove(kind);
          }
        });
      },
    );
  }

  Widget _buildActionsCard(BuildContext context, List<RealSmartDevice> devices) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...List.generate(_actionSteps.length, (index) {
            final step = _actionSteps[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Step ${index + 1}',
                        style: const TextStyle(color: Color(0xFF30D158), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      if (_actionSteps.length > 1)
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFFFF453A), size: 18),
                          onPressed: () => setState(() => _actionSteps.removeAt(index)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Target device selector
                  DropdownButtonFormField<String>(
                    initialValue: devices.any((d) => d.id == step.targetDeviceId)
                        ? step.targetDeviceId
                        : (devices.isNotEmpty ? devices.first.id : null),
                    dropdownColor: const Color(0xFF161F36),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Target Device',
                      labelStyle: const TextStyle(color: Colors.white60),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    items: devices.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        final matched = devices.firstWhere((d) => d.id == val);
                        setState(() {
                          step.targetDeviceId = matched.id;
                          step.targetDeviceName = matched.name;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 10),

                  // Power toggle
                  Row(
                    children: [
                      const Text('Power:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const Spacer(),
                      ChoiceChip(
                        label: const Text('Turn ON'),
                        selected: step.turnOn,
                        selectedColor: const Color(0xFF30D158),
                        onSelected: (val) => setState(() => step.turnOn = true),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Turn OFF'),
                        selected: !step.turnOn,
                        selectedColor: const Color(0xFFFF453A),
                        onSelected: (val) => setState(() => step.turnOn = false),
                      ),
                    ],
                  ),

                  // Level slider if turned ON
                  if (step.turnOn) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Level (Brightness / Temp):', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text(
                          step.targetLevel != null ? '${step.targetLevel!.round()}' : 'Default',
                          style: const TextStyle(color: Color(0xFF30D158), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Slider(
                      value: step.targetLevel ?? 80.0,
                      min: 10.0,
                      max: 100.0,
                      divisions: 18,
                      activeColor: const Color(0xFF30D158),
                      onChanged: (val) => setState(() => step.targetLevel = val),
                    ),
                  ],

                  // Wait Delay selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Wait before running:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      DropdownButton<int>(
                        value: step.delaySecondsBefore,
                        dropdownColor: const Color(0xFF161F36),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        items: {0, 1, 2, 3, 5, 10, 30, 60, step.delaySecondsBefore}
                            .map((s) => DropdownMenuItem<int>(
                                  value: s,
                                  child: Text(s == 0 ? 'No delay' : 'Wait ${s}s'),
                                ))
                            .toList()
                          ..sort((a, b) => (a.value ?? 0).compareTo(b.value ?? 0)),
                        onChanged: (val) {
                          if (val != null) setState(() => step.delaySecondsBefore = val);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),

          // Add Step Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF30D158),
                side: const BorderSide(color: Color(0xFF30D158)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Sequenced Action Step'),
              onPressed: () {
                if (devices.isNotEmpty) {
                  final first = devices.first;
                  setState(() {
                    _actionSteps.add(
                      _EditableActionStep(
                        targetDeviceId: first.id,
                        targetDeviceName: first.name,
                        turnOn: false,
                        targetLevel: null,
                        delaySecondsBefore: 5,
                      ),
                    );
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  void _saveRule(BuildContext context) async {
    final name = _nameCtrl.text.trim().isEmpty ? 'Smart Routine' : _nameCtrl.text.trim();
    final home = context.read<RealHomeProvider>();
    final devices = home.devices;

    // Assemble Trigger
    String trigVal = '';
    String? srcDevId;
    String? srcDevName;

    switch (_selectedTriggerKind) {
      case TriggerKind.timeSchedule:
        trigVal = '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';
        break;
      case TriggerKind.solarEvent:
        trigVal = _solarEvent;
        break;
      case TriggerKind.wifiPresence:
        trigVal = _presenceEvent;
        break;
      case TriggerKind.deviceState:
        srcDevId = _triggerDeviceId ?? (devices.isNotEmpty ? devices.first.id : '');
        final matched = devices.where((d) => d.id == srcDevId);
        srcDevName = matched.isNotEmpty ? matched.first.name : 'Device';
        trigVal = _triggerDeviceState;
        break;
      default:
        trigVal = '22:00';
    }

    final trigger = SmartTrigger(
      kind: _selectedTriggerKind,
      value: trigVal,
      sourceDeviceId: srcDevId,
      sourceDeviceName: srcDevName,
      weekdays: _selectedWeekdays,
    );

    // Assemble Preconditions
    final preconditions = _selectedPreconditions.map((k) => SmartPrecondition(kind: k)).toList();

    // Assemble Actions
    final actions = _actionSteps.map((e) {
      return SmartActionStep(
        targetDeviceId: e.targetDeviceId,
        targetDeviceName: e.targetDeviceName,
        turnOn: e.turnOn,
        targetLevel: e.targetLevel,
        delaySecondsBefore: e.delaySecondsBefore,
      );
    }).toList();

    final ruleId = widget.existingRule?.id ?? 'rule_${DateTime.now().millisecondsSinceEpoch}';

    final rule = MultiConditionAutomationRule(
      id: ruleId,
      name: name,
      isEnabled: true,
      trigger: trigger,
      preconditions: preconditions,
      actions: actions,
    );

    if (widget.existingRule != null) {
      await home.updateMultiConditionRule(rule);
    } else {
      await home.addMultiConditionRule(rule);
    }

    HapticFeedback.heavyImpact();
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF30D158),
          content: Text('Saved and deployed "$name" to real hardware!'),
        ),
      );
    }
  }
}

class _EditableActionStep {
  String targetDeviceId;
  String targetDeviceName;
  bool turnOn;
  double? targetLevel;
  int delaySecondsBefore;

  _EditableActionStep({
    required this.targetDeviceId,
    required this.targetDeviceName,
    required this.turnOn,
    this.targetLevel,
    this.delaySecondsBefore = 0,
  });
}
