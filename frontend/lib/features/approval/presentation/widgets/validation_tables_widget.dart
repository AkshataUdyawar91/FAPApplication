import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Widget to display 4 validation tables: Invoice, Cost Summary, Activity, and Enquiry
class ValidationTablesWidget extends StatelessWidget {
  final List<dynamic> invoiceValidations;
  final Map<String, dynamic> costSummaryValidation;
  final Map<String, dynamic> activityValidation;
  final Map<String, dynamic> enquiryValidation;

  const ValidationTablesWidget({
    super.key,
    required this.invoiceValidations,
    required this.costSummaryValidation,
    required this.activityValidation,
    required this.enquiryValidation,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Validation Results'),
        const SizedBox(height: 16),
        _buildInvoiceValidationsTable(context),
        const SizedBox(height: 24),
        _buildCostSummaryValidationTable(context),
        const SizedBox(height: 24),
        _buildActivityValidationTable(context),
        const SizedBox(height: 24),
        _buildEnquiryValidationTable(context),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.fact_check,
            color: AppColors.primary,
            size: 28,
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceValidationsTable(BuildContext context) {
    return _buildTableCard(
      context,
      title: 'Invoice Validations',
      icon: Icons.receipt_long,
      child: invoiceValidations.isEmpty
          ? _buildEmptyState('No invoice validations available')
          : Column(
              children: invoiceValidations.map((validation) {
                return _buildInvoiceValidationRow(context, validation);
              }).toList(),
            ),
    );
  }

  Widget _buildInvoiceValidationRow(
    BuildContext context,
    Map<String, dynamic> validation,
  ) {
    final allPassed = validation['allPassed'] ?? false;
    final fileName = validation['fileName'] ?? 'N/A';
    final failureReason = validation['failureReason'] ?? '';
    final validatedAt = validation['validatedAt'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: allPassed
            ? Colors.green.withValues(alpha: 0.05)
            : Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: allPassed
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                allPassed ? Icons.check_circle : Icons.cancel,
                color: allPassed ? Colors.green : Colors.red,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  fileName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          if (!allPassed && failureReason.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Missing Fields:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(failureReason),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (validatedAt.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Validated: ${_formatDateTime(validatedAt)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCostSummaryValidationTable(BuildContext context) {
    final allPassed = costSummaryValidation['allValidationsPassed'] ?? false;
    final failureReason = costSummaryValidation['failureReason'] ?? '';

    return _buildTableCard(
      context,
      title: 'Cost Summary Validation',
      icon: Icons.attach_money,
      child: _buildValidationDetailCard(
        context,
        allPassed: allPassed,
        failureReason: failureReason,
        validationData: costSummaryValidation,
      ),
    );
  }

  Widget _buildActivityValidationTable(BuildContext context) {
    final allPassed = activityValidation['allValidationsPassed'] ?? false;
    final failureReason = activityValidation['failureReason'] ?? '';

    return _buildTableCard(
      context,
      title: 'Activity Validation',
      icon: Icons.event_note,
      child: _buildValidationDetailCard(
        context,
        allPassed: allPassed,
        failureReason: failureReason,
        validationData: activityValidation,
      ),
    );
  }

  Widget _buildEnquiryValidationTable(BuildContext context) {
    final allPassed = enquiryValidation['allValidationsPassed'] ?? false;
    final failureReason = enquiryValidation['failureReason'] ?? '';

    return _buildTableCard(
      context,
      title: 'Enquiry Validation',
      icon: Icons.contact_mail,
      child: _buildValidationDetailCard(
        context,
        allPassed: allPassed,
        failureReason: failureReason,
        validationData: enquiryValidation,
      ),
    );
  }

  Widget _buildValidationDetailCard(
    BuildContext context, {
    required bool allPassed,
    required String failureReason,
    required Map<String, dynamic> validationData,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: allPassed
            ? Colors.green.withValues(alpha: 0.05)
            : Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: allPassed
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                allPassed ? Icons.check_circle : Icons.cancel,
                color: allPassed ? Colors.green : Colors.red,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  allPassed ? 'All Validations Passed' : 'Validation Failed',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: allPassed ? Colors.green : Colors.red,
                  ),
                ),
              ),
            ],
          ),
          if (!allPassed && failureReason.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Failure Reason:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(failureReason),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTableCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                ),
              ],
            ),
            const Divider(height: 24),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.info_outline,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(String dateTime) {
    try {
      final dt = DateTime.parse(dateTime);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTime;
    }
  }
}
