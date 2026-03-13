import 'package:flutter/material.dart';

/// A progress bar widget designed to sit in the AppBar bottom slot.
///
/// Shows the current step progress (0–100%) as a [LinearProgressIndicator]
/// with the ClaimsIQ brand color and a step label.
class StepProgressBar extends StatelessWidget implements PreferredSizeWidget {
  /// Progress value from 0 to 100.
  final int progressPercent;

  /// Current step index (0-based).
  final int currentStep;

  const StepProgressBar({
    super.key,
    required this.progressPercent,
    required this.currentStep,
  });

  static const _stepLabels = [
    'Welcome',
    'PO Selection',
    'State Selection',
    'Invoice Upload',
    'Activity Summary',
    'Cost Summary',
    'Team Details',
    'Enquiry Dump',
    'Additional Docs',
    'Final Review',
    'Submitted',
  ];

  @override
  Size get preferredSize => const Size.fromHeight(32);

  @override
  Widget build(BuildContext context) {
    final label = currentStep < _stepLabels.length
        ? _stepLabels[currentStep]
        : 'Step $currentStep';
    final progress = (progressPercent / 100).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                '$progressPercent%',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.grey.shade300,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF003087),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
