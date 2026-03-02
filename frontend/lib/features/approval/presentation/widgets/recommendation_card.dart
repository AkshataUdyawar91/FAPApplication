import 'package:flutter/material.dart';
import '../../domain/entities/recommendation.dart';

class RecommendationCard extends StatelessWidget {
  final Recommendation recommendation;

  const RecommendationCard({
    super.key,
    required this.recommendation,
  });

  Color _getRecommendationColor(RecommendationType type) {
    switch (type) {
      case RecommendationType.approve:
        return Colors.green;
      case RecommendationType.review:
        return Colors.orange;
      case RecommendationType.reject:
        return Colors.red;
    }
  }

  IconData _getRecommendationIcon(RecommendationType type) {
    switch (type) {
      case RecommendationType.approve:
        return Icons.check_circle;
      case RecommendationType.review:
        return Icons.rate_review;
      case RecommendationType.reject:
        return Icons.cancel;
    }
  }

  String _getRecommendationText(RecommendationType type) {
    switch (type) {
      case RecommendationType.approve:
        return 'APPROVE';
      case RecommendationType.review:
        return 'REVIEW';
      case RecommendationType.reject:
        return 'REJECT';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getRecommendationColor(recommendation.type);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getRecommendationIcon(recommendation.type),
                  color: color,
                  size: 32,
                  semanticLabel: 'AI recommendation',
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI Recommendation',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      _getRecommendationText(recommendation.type),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Evidence:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                recommendation.evidence,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
