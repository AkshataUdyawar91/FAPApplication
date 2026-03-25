import 'package:flutter/material.dart';
import '../../data/models/assistant_response_model.dart';

/// A tappable workflow card (Create Request, View Requests, etc.)
class WorkflowActionCard extends StatelessWidget {
  final WorkflowCardModel card;
  final VoidCallback onTap;

  const WorkflowActionCard({
    super.key,
    required this.card,
    required this.onTap,
  });

  IconData _resolveIcon(String iconName) {
    switch (iconName) {
      case 'add_circle_outline':
        return Icons.add_circle_outline;
      case 'list_alt':
        return Icons.list_alt;
      case 'pending_actions':
        return Icons.pending_actions;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFDBEAFE)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: const Border(left: BorderSide(color: Color(0xFF003087), width: 4)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF003087).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _resolveIcon(card.icon),
                  color: const Color(0xFF003087),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF003087),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      card.subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF003087)),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
