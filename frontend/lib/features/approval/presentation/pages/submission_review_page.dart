import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/approval_providers.dart';
import '../providers/approval_notifier.dart';
import '../widgets/validation_result_card.dart';
import '../widgets/confidence_score_widget.dart';
import '../widgets/recommendation_card.dart';
import '../widgets/approval_action_buttons.dart';
import '../../data/models/validation_result_model.dart';
import '../../data/models/confidence_score_model.dart';
import '../../data/models/recommendation_model.dart';

class SubmissionReviewPage extends ConsumerStatefulWidget {
  final String packageId;

  const SubmissionReviewPage({
    super.key,
    required this.packageId,
  });

  @override
  ConsumerState<SubmissionReviewPage> createState() =>
      _SubmissionReviewPageState();
}

class _SubmissionReviewPageState extends ConsumerState<SubmissionReviewPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(approvalNotifierProvider.notifier)
          .loadPackageDetails(widget.packageId),
    );
  }

  void _showApproveDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Submission'),
        content: const Text(
          'Are you sure you want to approve this submission? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(approvalNotifierProvider.notifier)
                  .approvePackage(widget.packageId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog() {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Submission'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please provide a reason for rejection:'),
              const SizedBox(height: 16),
              TextFormField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  border: OutlineInputBorder(),
                  hintText: 'Enter rejection reason',
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please provide a reason';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                ref
                    .read(approvalNotifierProvider.notifier)
                    .rejectPackage(widget.packageId, reasonController.text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _showRequestReuploadDialog() {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final selectedFields = <String>{};

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Request Re-upload'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select fields that need correction:'),
                  const SizedBox(height: 8),
                  ...[
                    'Purchase Order',
                    'Invoice',
                    'Cost Summary',
                    'Activity Photos',
                    'Additional Documents',
                  ].map(
                    (field) => CheckboxListTile(
                      title: Text(field),
                      value: selectedFields.contains(field),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            selectedFields.add(field);
                          } else {
                            selectedFields.remove(field);
                          }
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: reasonController,
                    decoration: const InputDecoration(
                      labelText: 'Reason',
                      border: OutlineInputBorder(),
                      hintText: 'Explain what needs to be corrected',
                    ),
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please provide a reason';
                      }
                      if (selectedFields.isEmpty) {
                        return 'Please select at least one field';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate() &&
                    selectedFields.isNotEmpty) {
                  Navigator.pop(context);
                  ref.read(approvalNotifierProvider.notifier).requestReupload(
                        widget.packageId,
                        selectedFields.toList(),
                        reasonController.text,
                      );
                }
              },
              child: const Text('Request Re-upload'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(approvalNotifierProvider);

    ref.listen<ApprovalState>(
      approvalNotifierProvider,
      (previous, next) {
        if (next.actionSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Action completed successfully')),
          );
          ref.read(approvalNotifierProvider.notifier).resetActionSuccess();
          Navigator.pop(context);
        }
        if (next.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(next.error!)),
          );
          ref.read(approvalNotifierProvider.notifier).clearError();
        }
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Submission'),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.currentPackage == null
              ? const Center(child: Text('Package not found'))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 600;
                    return Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: isMobile
                                ? _buildMobileLayout(state)
                                : _buildDesktopLayout(state),
                          ),
                        ),
                        ApprovalActionButtons(
                          onApprove: _showApproveDialog,
                          onReject: _showRejectDialog,
                          onRequestReupload: _showRequestReuploadDialog,
                          isLoading: state.isLoading,
                        ),
                      ],
                    );
                  },
                ),
    );
  }

  Widget _buildMobileLayout(ApprovalState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPackageInfo(state),
        const SizedBox(height: 16),
        _buildDocumentsList(state),
        const SizedBox(height: 16),
        // TODO: Add validation result when backend provides it
        // if (state.currentPackage!.validationResult != null)
        //   ValidationResultCard(
        //     validationResult: ValidationResultModel.fromJson(
        //       state.currentPackage!.validationResult!,
        //     ),
        //   ),
        // const SizedBox(height: 16),
        // if (state.currentPackage!.confidenceScore != null)
        //   ConfidenceScoreWidget(
        //     confidenceScore: ConfidenceScoreModel.fromJson(
        //       state.currentPackage!.confidenceScore!,
        //     ),
        //   ),
        // const SizedBox(height: 16),
        // if (state.currentPackage!.recommendation != null)
        //   RecommendationCard(
        //     recommendation: RecommendationModel.fromJson(
        //       state.currentPackage!.recommendation!,
        //     ),
        //   ),
      ],
    );
  }

  Widget _buildDesktopLayout(ApprovalState state) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 1,
          child: Column(
            children: [
              _buildPackageInfo(state),
              const SizedBox(height: 16),
              _buildDocumentsList(state),
            ],
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(
          flex: 1,
          child: Column(
            children: [
              // TODO: Add validation result when backend provides it
              // if (state.currentPackage!.validationResult != null)
              //   ValidationResultCard(
              //     validationResult: ValidationResultModel.fromJson(
              //       state.currentPackage!.validationResult!,
              //     ),
              //   ),
              // const SizedBox(height: 16),
              // if (state.currentPackage!.confidenceScore != null)
              //   ConfidenceScoreWidget(
              //     confidenceScore: ConfidenceScoreModel.fromJson(
              //       state.currentPackage!.confidenceScore!,
              //     ),
              //   ),
              // const SizedBox(height: 16),
              // if (state.currentPackage!.recommendation != null)
              //   RecommendationCard(
              //     recommendation: RecommendationModel.fromJson(
              //       state.currentPackage!.recommendation!,
              //     ),
              //   ),
              Text('Validation details will appear here'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPackageInfo(ApprovalState state) {
    final package = state.currentPackage!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Submission Details',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _InfoRow(label: 'Package ID', value: package.id),
            _InfoRow(label: 'State', value: package.state),
            _InfoRow(
              label: 'Submitted',
              value: package.createdAt.toString().split('.')[0],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentsList(ApprovalState state) {
    final package = state.currentPackage!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Documents',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            ...package.documents.map(
              (doc) => ListTile(
                leading: const Icon(Icons.description),
                title: Text(doc.type),
                subtitle: Text(doc.fileName),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
