import 'package:flutter/material.dart';
import '../../data/models/enhanced_validation_report_model.dart';
import '../../../../core/theme/app_colors.dart';

/// Main widget to display enhanced validation report
class EnhancedValidationReportWidget extends StatelessWidget {
  final EnhancedValidationReportModel report;

  const EnhancedValidationReportWidget({
    super.key,
    required this.report,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const Divider(height: 1),
          _buildSummarySection(context),
          const Divider(height: 1),
          _buildValidationCategories(context),
          const Divider(height: 1),
          _buildRecommendation(context),
          if (report.detailedEvidence.isNotEmpty) ...[
            const Divider(height: 1),
            _buildDetailedEvidence(context),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.primary.withOpacity(0.05),
      child: Row(
        children: [
          const Icon(
            Icons.assessment,
            color: AppColors.primary,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Validation Report',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Detailed analysis with actionable insights',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(BuildContext context) {
    final summary = report.summary;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Validation Summary',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildConfidenceCard(
                  context,
                  summary.overallConfidence,
                  summary.riskLevel,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildValidationStats(context, summary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceCard(
      BuildContext context, double confidence, String riskLevel,) {
    Color confidenceColor;
    IconData confidenceIcon;

    if (confidence >= 85) {
      confidenceColor = Colors.green;
      confidenceIcon = Icons.check_circle;
    } else if (confidence >= 70) {
      confidenceColor = Colors.orange;
      confidenceIcon = Icons.warning;
    } else if (confidence >= 50) {
      confidenceColor = Colors.deepOrange;
      confidenceIcon = Icons.error_outline;
    } else {
      confidenceColor = Colors.red;
      confidenceIcon = Icons.cancel;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: confidenceColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: confidenceColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(confidenceIcon, color: confidenceColor, size: 48),
          const SizedBox(height: 8),
          Text(
            '${confidence.toStringAsFixed(1)}%',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: confidenceColor,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Overall Confidence',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: confidenceColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              riskLevel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValidationStats(
      BuildContext context, ValidationSummaryModel summary,) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatRow(
            context,
            'Total Validations',
            summary.totalValidations.toString(),
            Colors.blue,
          ),
          const SizedBox(height: 8),
          _buildStatRow(
            context,
            'Passed',
            summary.passedValidations.toString(),
            Colors.green,
          ),
          const SizedBox(height: 8),
          _buildStatRow(
            context,
            'Failed',
            summary.failedValidations.toString(),
            Colors.red,
          ),
          const Divider(height: 16),
          if (summary.criticalIssues > 0)
            _buildStatRow(
              context,
              'Critical Issues',
              summary.criticalIssues.toString(),
              Colors.red,
            ),
          if (summary.highPriorityIssues > 0)
            _buildStatRow(
              context,
              'High Priority',
              summary.highPriorityIssues.toString(),
              Colors.orange,
            ),
          if (summary.mediumPriorityIssues > 0)
            _buildStatRow(
              context,
              'Medium Priority',
              summary.mediumPriorityIssues.toString(),
              Colors.amber,
            ),
        ],
      ),
    );
  }

  Widget _buildStatRow(
      BuildContext context, String label, String value, Color color,) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildValidationCategories(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Validation Details',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          ...report.categories.map((category) {
            return _buildValidationCategoryCard(context, category);
          }),
        ],
      ),
    );
  }

  Widget _buildValidationCategoryCard(
      BuildContext context, ValidationCategoryModel category,) {
    Color severityColor;
    IconData statusIcon;

    switch (category.severity.toLowerCase()) {
      case 'critical':
        severityColor = Colors.red;
        break;
      case 'high':
        severityColor = Colors.orange;
        break;
      case 'medium':
        severityColor = Colors.amber;
        break;
      default:
        severityColor = Colors.blue;
    }

    statusIcon = category.passed ? Icons.check_circle : Icons.cancel;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: ExpansionTile(
        leading: Icon(
          statusIcon,
          color: category.passed ? Colors.green : severityColor,
        ),
        title: Text(
          category.categoryName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(category.shortDescription),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: severityColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            category.severity,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: severityColor,
            ),
          ),
        ),
        children: [
          if (category.details != null)
            _buildValidationDetails(context, category.details!),
        ],
      ),
    );
  }

  Widget _buildValidationDetails(
      BuildContext context, ValidationDetailModel details,) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow(context, 'Description', details.description),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDetailBox(
                  context,
                  'Expected',
                  details.expectedValue,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailBox(
                  context,
                  'Actual',
                  details.actualValue,
                  Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDetailRow(context, 'Impact', details.impact),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Suggested Action',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(details.suggestedAction),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
        ),
        const SizedBox(height: 4),
        Text(value),
      ],
    );
  }

  Widget _buildDetailBox(
      BuildContext context, String label, String value, Color color,) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendation(BuildContext context) {
    final recommendation = report.recommendation;
    Color actionColor;
    IconData actionIcon;

    switch (recommendation.action.toLowerCase()) {
      case 'approve':
        actionColor = Colors.green;
        actionIcon = Icons.check_circle;
        break;
      case 'requestresubmission':
        actionColor = Colors.orange;
        actionIcon = Icons.refresh;
        break;
      case 'reject':
        actionColor = Colors.red;
        actionIcon = Icons.cancel;
        break;
      default:
        actionColor = Colors.grey;
        actionIcon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      color: actionColor.withOpacity(0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(actionIcon, color: actionColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Recommendation',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4,),
                      decoration: BoxDecoration(
                        color: actionColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _formatAction(recommendation.action),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reasoning',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 8),
                Text(recommendation.reasoning),
              ],
            ),
          ),
          if (recommendation.criticalIssues.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildIssuesList(
              context,
              'Critical Issues',
              recommendation.criticalIssues,
              Colors.red,
            ),
          ],
          if (recommendation.highPriorityIssues.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildIssuesList(
              context,
              'High Priority Issues',
              recommendation.highPriorityIssues,
              Colors.orange,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIssuesList(
      BuildContext context, String title, List<IssueModel> issues, Color color,) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        const SizedBox(height: 8),
        ...issues.map((issue) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.error_outline, color: color, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        issue.category,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(issue.description),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.arrow_forward, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        issue.suggestedAction,
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDetailedEvidence(BuildContext context) {
    return ExpansionTile(
      leading: const Icon(Icons.description),
      title: const Text(
        'Detailed AI Analysis',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[50],
          child: SelectableText(
            report.detailedEvidence,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
      ],
    );
  }

  String _formatAction(String action) {
    switch (action.toLowerCase()) {
      case 'approve':
        return 'APPROVE';
      case 'requestresubmission':
        return 'REQUEST RESUBMISSION';
      case 'reject':
        return 'REJECT';
      default:
        return action.toUpperCase();
    }
  }
}
