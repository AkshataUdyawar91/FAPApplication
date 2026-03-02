import 'package:flutter/material.dart';

class ApprovalActionButtons extends StatelessWidget {
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onRequestReupload;
  final bool isLoading;

  const ApprovalActionButtons({
    super.key,
    required this.onApprove,
    required this.onReject,
    required this.onRequestReupload,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : onApprove,
              icon: const Icon(Icons.check),
              label: const Text('Approve'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(48, 48),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: isLoading ? null : onRequestReupload,
              icon: const Icon(Icons.upload),
              label: const Text('Request Re-upload'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(48, 48),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : onReject,
              icon: const Icon(Icons.close),
              label: const Text('Reject'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(48, 48),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
