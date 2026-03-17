import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/validation_report_provider.dart';
import 'enhanced_validation_report_widget.dart';
import '../../../../core/network/dio_client.dart';

/// Dialog to display enhanced validation report
class ValidationReportDialog extends ConsumerWidget {
  final String packageId;
  final String? token;

  const ValidationReportDialog({
    super.key,
    required this.packageId,
    this.token,
  });

  static Future<void> show(BuildContext context, String packageId, {String? token}) {
    return showDialog(
      context: context,
      builder: (context) => ValidationReportDialog(packageId: packageId, token: token),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Set auth token if provided
    if (token != null && token!.isNotEmpty) {
      Future.microtask(() {
        ref.read(authTokenProvider.notifier).state = token;
      });
    }

    final reportState = ref.watch(validationReportProvider(packageId));

    return Dialog(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.9,
        child: Column(
          children: [
            _buildHeader(context, ref),
            Expanded(
              child: reportState.when(
                data: (report) => SingleChildScrollView(
                  child: EnhancedValidationReportWidget(report: report),
                ),
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (error, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load validation report',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error.toString(),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            ref
                                .read(validationReportProvider(packageId).notifier)
                                .refresh();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.assessment, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enhanced Validation Report',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  'Package ID: $packageId',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              ref.read(validationReportProvider(packageId).notifier).refresh();
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }
}
