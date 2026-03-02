import 'package:flutter/material.dart';
import '../../domain/entities/validation_result.dart';

class ValidationResultCard extends StatelessWidget {
  final ValidationResult validationResult;

  const ValidationResultCard({
    super.key,
    required this.validationResult,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  validationResult.passed ? Icons.check_circle : Icons.error,
                  color: validationResult.passed ? Colors.green : Colors.red,
                  semanticLabel: validationResult.passed
                      ? 'Validation passed'
                      : 'Validation failed',
                ),
                const SizedBox(width: 8),
                Text(
                  validationResult.passed
                      ? 'Validation Passed'
                      : 'Validation Failed',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            if (validationResult.issues.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Issues:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...validationResult.issues.map(
                (issue) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: _IssueItem(issue: issue),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IssueItem extends StatelessWidget {
  final ValidationIssue issue;

  const _IssueItem({required this.issue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            issue.field,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(issue.message),
          if (issue.expectedValue != null || issue.actualValue != null) ...[
            const SizedBox(height: 8),
            if (issue.expectedValue != null)
              Text(
                'Expected: ${issue.expectedValue}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
            if (issue.actualValue != null)
              Text(
                'Actual: ${issue.actualValue}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
