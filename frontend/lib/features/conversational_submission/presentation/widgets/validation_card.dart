import 'package:flutter/material.dart';
import '../../domain/entities/validation_rule_result.dart';

/// Per-document validation results card with color-coded rows.
/// Green border for pass, red for fail, yellow/orange for warning.
class ValidationCard extends StatelessWidget {
  final String documentType;
  final List<ValidationRuleResult> rules;
  final VoidCallback? onReUpload;

  const ValidationCard({
    super.key,
    required this.documentType,
    required this.rules,
    this.onReUpload,
  });

  int get _passCount => rules.where((r) => r.severity == ValidationSeverity.pass).length;
  int get _failCount => rules.where((r) => r.severity == ValidationSeverity.fail).length;
  int get _warnCount => rules.where((r) => r.severity == ValidationSeverity.warning).length;
  bool get _allPassed => _failCount == 0 && _warnCount == 0;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  _allPassed ? Icons.check_circle : Icons.warning_amber,
                  color: _allPassed ? Colors.green : Colors.orange,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$documentType Validation',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Summary chips
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _CountChip(label: '$_passCount passed', color: Colors.green),
                if (_failCount > 0)
                  _CountChip(label: '$_failCount failed', color: Colors.red),
                if (_warnCount > 0)
                  _CountChip(label: '$_warnCount warnings', color: Colors.orange),
              ],
            ),
            const SizedBox(height: 10),
            // Rule rows
            ...rules.map(_buildRuleRow),
            // Re-upload action
            if (!_allPassed && onReUpload != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onReUpload,
                  icon: const Icon(Icons.upload, size: 16),
                  label: const Text('Re-upload'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF003087),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRuleRow(ValidationRuleResult rule) {
    final Color borderColor;
    final IconData icon;

    switch (rule.severity) {
      case ValidationSeverity.pass:
        borderColor = Colors.green;
        icon = Icons.check_circle_outline;
        break;
      case ValidationSeverity.warning:
        borderColor = Colors.orange;
        icon = Icons.warning_amber;
        break;
      case ValidationSeverity.fail:
        borderColor = Colors.red;
        icon = Icons.cancel_outlined;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: borderColor, width: 3)),
        color: borderColor.withValues(alpha: 0.05),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: borderColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _humanReadableRule(rule.ruleCode),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                if (rule.message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      rule.message!,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ),
              ],
            ),
          ),
          if (rule.extractedValue != null)
            Text(
              rule.extractedValue!,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
        ],
      ),
    );
  }

  /// Converts rule codes like INV_INVOICE_NUMBER_PRESENT to readable text.
  String _humanReadableRule(String code) {
    // Strip prefix (INV_, AS_, CS_, PHOTO_)
    final stripped = code.replaceFirst(RegExp(r'^(INV|AS|CS|PHOTO)_'), '');
    return stripped
        .split('_')
        .map((w) => w.isNotEmpty
            ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}'
            : '',)
        .join(' ');
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final Color color;

  const _CountChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}
