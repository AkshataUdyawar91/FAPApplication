import 'package:flutter/material.dart';
import '../../data/models/assistant_response_model.dart';

/// Displays PO search results as a simple tappable list — PO number only.
class POSearchList extends StatelessWidget {
  final List<POItemModel> items;
  final ValueChanged<POItemModel> onSelect;

  const POSearchList({
    super.key,
    required this.items,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Purchase Orders',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
          ),
        ),
        ...items.map((po) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => onSelect(po),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Text(
                po.poNumber,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF003087),
                ),
              ),
            ),
          ),
        )),
      ],
    );
  }
}
