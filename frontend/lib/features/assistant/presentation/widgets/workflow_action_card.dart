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
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
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
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
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
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
