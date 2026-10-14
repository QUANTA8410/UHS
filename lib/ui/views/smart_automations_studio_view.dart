import 'package:flutter/material.dart';
import '../../services/automation/smart_automation_engine.dart';
import '../../theme/apple_glass_theme.dart';
import '../widgets/dialogs/smart_rule_studio_sheet.dart';

export '../widgets/dialogs/smart_rule_studio_sheet.dart';

/// Full-screen Apple Liquid Glass studio view for crafting multi-condition hardware rules.
class SmartAutomationsStudioView extends StatelessWidget {
  final MultiConditionAutomationRule? existingRule;
  final String? initialTemplate;

  const SmartAutomationsStudioView({
    super.key,
    this.existingRule,
    this.initialTemplate,
  });

  /// Opens the Rule Studio as an Apple Glass modal bottom sheet
  static Future<void> showAsSheet(
    BuildContext context, {
    MultiConditionAutomationRule? existingRule,
    String? initialTemplate,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SmartRuleStudioSheet(
        existingRule: existingRule,
        initialTemplate: initialTemplate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LiquidGlassScaffold(
      appBar: AppBar(
        title: Text(
          existingRule != null ? 'Edit Automation Rule' : 'Smart Rule Studio',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SmartRuleStudioSheet(
          existingRule: existingRule,
          initialTemplate: initialTemplate,
        ),
      ),
    );
  }
}
