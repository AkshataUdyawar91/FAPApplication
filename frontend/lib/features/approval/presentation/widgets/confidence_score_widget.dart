import 'package:flutter/material.dart';
import '../../domain/entities/confidence_score.dart';

class ConfidenceScoreWidget extends StatelessWidget {
  final ConfidenceScore confidenceScore;

  const ConfidenceScoreWidget({
    super.key,
    required this.confidenceScore,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confidence Score',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _ScoreBar(
              label: 'Overall',
              score: confidenceScore.overallConfidence,
              isOverall: true,
            ),
            const SizedBox(height: 12),
            _ScoreBar(
              label: 'Purchase Order',
              score: confidenceScore.poConfidence,
            ),
            const SizedBox(height: 8),
            _ScoreBar(
              label: 'Invoice',
              score: confidenceScore.invoiceConfidence,
            ),
            const SizedBox(height: 8),
            _ScoreBar(
              label: 'Cost Summary',
              score: confidenceScore.costSummaryConfidence,
            ),
            const SizedBox(height: 8),
            _ScoreBar(
              label: 'Activity',
              score: confidenceScore.activityConfidence,
            ),
            const SizedBox(height: 8),
            _ScoreBar(
              label: 'Photos',
              score: confidenceScore.photoConfidence,
            ),
            if (confidenceScore.requiresReview) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This submission requires manual review due to low confidence score.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final String label;
  final double score;
  final bool isOverall;

  const _ScoreBar({
    required this.label,
    required this.score,
    this.isOverall = false,
  });

  Color _getScoreColor(double score) {
    if (score >= 85) return Colors.green;
    if (score >= 70) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getScoreColor(score);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: isOverall ? FontWeight.bold : FontWeight.normal,
                fontSize: isOverall ? 16 : 14,
              ),
            ),
            Text(
              '${score.toStringAsFixed(1)}%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: isOverall ? 16 : 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score / 100,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: isOverall ? 12 : 8,
            semanticsLabel: '$label confidence score: ${score.toStringAsFixed(1)}%',
          ),
        ),
      ],
    );
  }
}
