import 'package:flutter/material.dart';
import 'validation_report_dialog.dart';
import '../../../../core/theme/app_colors.dart';

/// Button to view enhanced validation report
class ViewValidationReportButton extends StatelessWidget {
  final String packageId;
  final bool isCompact;

  const ViewValidationReportButton({
    super.key,
    required this.packageId,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return IconButton(
        onPressed: () => ValidationReportDialog.show(context, packageId),
        icon: const Icon(Icons.assessment),
        tooltip: 'View AI Validation Report',
        color: AppColors.primary,
      );
    }

    return ElevatedButton.icon(
      onPressed: () => ValidationReportDialog.show(context, packageId),
      icon: const Icon(Icons.assessment),
      label: const Text('View AI Report'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}
