import 'package:flutter/material.dart';

/// Section data for the final review card.
class ReviewSection {
  final String title;
  final IconData icon;
  final List<ReviewField> fields;
  /// The conversation step to navigate back to for editing.
  final int editStep;

  const ReviewSection({
    required this.title,
    required this.icon,
    required this.fields,
    required this.editStep,
  });
}

/// A single key-value field in a review section.
class ReviewField {
  final String label;
  final String value;
  /// Optional status indicator (pass/fail/warning).
  final ReviewFieldStatus? status;

  const ReviewField({
    required this.label,
    required this.value,
    this.status,
  });
}

enum ReviewFieldStatus { pass, fail, warning }

/// Comprehensive pre-submit summary card with all sections and
/// edit buttons per section for navigating back to specific steps.
class FinalReviewCard extends StatelessWidget {
  final List<ReviewSection> sections;
  final void Function(int editStep) onEdit;

  const FinalReviewCard({
    super.key,
    required this.sections,
    required this.onEdit,
  });

  /// Convenience factory to build from the FinalReviewCardModel summary map.
  factory FinalReviewCard.fromSummaryMap({
    Key? key,
    required Map<String, dynamic> summary,
    required void Function(int editStep) onEdit,
  }) {
    final sections = <ReviewSection>[];

    // PO Details
    if (summary.containsKey('poNumber')) {
      sections.add(ReviewSection(
        title: 'Purchase Order',
        icon: Icons.receipt_long,
        editStep: 1,
        fields: [
          ReviewField(label: 'PO Number', value: '${summary['poNumber']}'),
          if (summary['poAmount'] != null)
            ReviewField(label: 'Amount', value: '₹${summary['poAmount']}'),
          if (summary['remainingBalance'] != null)
            ReviewField(
              label: 'Remaining',
              value: '₹${summary['remainingBalance']}',
            ),
        ],
      ),);
    }

    // State
    if (summary.containsKey('state')) {
      sections.add(ReviewSection(
        title: 'Activity Region',
        icon: Icons.location_on,
        editStep: 2,
        fields: [
          ReviewField(label: 'State', value: '${summary['state']}'),
        ],
      ),);
    }

    // Invoice
    if (summary.containsKey('invoiceNumber')) {
      sections.add(ReviewSection(
        title: 'Invoice',
        icon: Icons.description,
        editStep: 3,
        fields: [
          ReviewField(label: 'Number', value: '${summary['invoiceNumber']}'),
          if (summary['invoiceAmount'] != null)
            ReviewField(label: 'Amount', value: '₹${summary['invoiceAmount']}'),
          if (summary['invoiceValidation'] != null)
            ReviewField(
              label: 'Validation',
              value: '${summary['invoiceValidation']}',
              status: _parseStatus(summary['invoiceValidationStatus']),
            ),
        ],
      ),);
    }

    // Activity Summary
    if (summary.containsKey('activitySummaryStatus')) {
      sections.add(ReviewSection(
        title: 'Activity Summary',
        icon: Icons.assignment,
        editStep: 4,
        fields: [
          ReviewField(
            label: 'Status',
            value: '${summary['activitySummaryStatus']}',
            status: _parseStatus(summary['activitySummaryValidation']),
          ),
        ],
      ),);
    }

    // Cost Summary
    if (summary.containsKey('costSummaryStatus')) {
      sections.add(ReviewSection(
        title: 'Cost Summary',
        icon: Icons.attach_money,
        editStep: 5,
        fields: [
          ReviewField(
            label: 'Status',
            value: '${summary['costSummaryStatus']}',
            status: _parseStatus(summary['costSummaryValidation']),
          ),
        ],
      ),);
    }

    // Teams
    if (summary.containsKey('teamCount')) {
      final teamFields = <ReviewField>[
        ReviewField(label: 'Teams', value: '${summary['teamCount']}'),
      ];
      if (summary['totalPhotos'] != null) {
        teamFields.add(
          ReviewField(label: 'Photos', value: '${summary['totalPhotos']}'),
        );
      }
      sections.add(ReviewSection(
        title: 'Team Details',
        icon: Icons.groups,
        editStep: 6,
        fields: teamFields,
      ),);
    }

    // Enquiry Dump
    if (summary.containsKey('enquiryRecordCount')) {
      sections.add(ReviewSection(
        title: 'Enquiry Dump',
        icon: Icons.table_chart,
        editStep: 7,
        fields: [
          ReviewField(
            label: 'Records',
            value: '${summary['enquiryRecordCount']}',
          ),
          if (summary['enquiryComplete'] != null)
            ReviewField(
              label: 'Complete',
              value: '${summary['enquiryComplete']}',
            ),
        ],
      ),);
    }

    return FinalReviewCard(
      key: key,
      sections: sections,
      onEdit: onEdit,
    );
  }

  static ReviewFieldStatus? _parseStatus(dynamic value) {
    if (value == null) return null;
    switch ('$value'.toLowerCase()) {
      case 'pass':
      case 'passed':
        return ReviewFieldStatus.pass;
      case 'fail':
      case 'failed':
        return ReviewFieldStatus.fail;
      case 'warning':
        return ReviewFieldStatus.warning;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Row(
              children: [
                Icon(Icons.summarize, size: 22, color: Color(0xFF003087)),
                SizedBox(width: 8),
                Text(
                  'Submission Summary',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF003087),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            // Sections
            ...sections.map((section) => _buildSection(context, section)),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, ReviewSection section) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header + edit button
          Row(
            children: [
              Icon(section.icon, size: 18, color: Colors.grey.shade700),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  section.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () => onEdit(section.editStep),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit, size: 14, color: Color(0xFF003087)),
                      SizedBox(width: 4),
                      Text(
                        'Edit',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF003087),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Fields
          ...section.fields.map(_buildField),
        ],
      ),
    );
  }

  Widget _buildField(ReviewField field) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, bottom: 3),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              field.label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              field.value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          if (field.status != null) _buildStatusIcon(field.status!),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(ReviewFieldStatus status) {
    switch (status) {
      case ReviewFieldStatus.pass:
        return const Icon(Icons.check_circle, size: 16, color: Colors.green);
      case ReviewFieldStatus.fail:
        return const Icon(Icons.cancel, size: 16, color: Colors.red);
      case ReviewFieldStatus.warning:
        return const Icon(Icons.warning_amber, size: 16, color: Colors.orange);
    }
  }
}
