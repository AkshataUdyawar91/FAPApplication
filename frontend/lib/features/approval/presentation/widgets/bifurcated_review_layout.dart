import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// A layout widget that splits the review detail page into two sections:
/// left (~60%) for current data and right (~40%) for the approval flow.
/// Stacks vertically on mobile screens (< 600px).
class BifurcatedReviewLayout extends StatelessWidget {
  /// The widget displayed in the left (or top on mobile) section.
  final Widget leftChild;

  /// The widget displayed in the right (or bottom on mobile) section.
  final Widget rightChild;

  const BifurcatedReviewLayout({
    super.key,
    required this.leftChild,
    required this.rightChild,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        if (isMobile) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                leftChild,
                const SizedBox(height: 16),
                const Divider(color: AppColors.border, thickness: 1),
                const SizedBox(height: 16),
                rightChild,
              ],
            ),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: leftChild,
              ),
            ),
            Container(
              width: 1,
              color: AppColors.border,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: const SizedBox.shrink(),
              ),
            ),
            Expanded(
              flex: 4,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: rightChild,
              ),
            ),
          ],
        );
      },
    );
  }
}
