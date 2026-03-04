import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/analytics_providers.dart';
import '../providers/analytics_notifier.dart';
import '../widgets/kpi_card.dart';
import '../widgets/ai_insight_card.dart';

class AnalyticsDashboardPage extends ConsumerStatefulWidget {
  const AnalyticsDashboardPage({super.key});

  @override
  ConsumerState<AnalyticsDashboardPage> createState() =>
      _AnalyticsDashboardPageState();
}

class _AnalyticsDashboardPageState
    extends ConsumerState<AnalyticsDashboardPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(analyticsNotifierProvider.notifier).loadAllAnalytics(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(analyticsNotifierProvider);

    ref.listen<AnalyticsState>(
      analyticsNotifierProvider,
      (previous, next) {
        if (next.exportSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Analytics exported successfully')),
          );
          ref.read(analyticsNotifierProvider.notifier).resetExportSuccess();
        }
        if (next.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(next.error!)),
          );
          ref.read(analyticsNotifierProvider.notifier).clearError();
        }
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: state.isLoading
                ? null
                : () => ref
                    .read(analyticsNotifierProvider.notifier)
                    .exportToExcel(),
            tooltip: 'Export to Excel',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: state.isLoading
                ? null
                : () => ref
                    .read(analyticsNotifierProvider.notifier)
                    .loadAllAnalytics(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: state.isLoading && state.kpiDashboard == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref
                  .read(analyticsNotifierProvider.notifier)
                  .loadAllAnalytics(),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth < 600
                      ? 1
                      : constraints.maxWidth < 900
                          ? 2
                          : 3;

                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (state.kpiDashboard != null) ...[
                          GridView.count(
                            crossAxisCount: crossAxisCount,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.5,
                            children: [
                              KPICard(
                                title: 'Total Submissions',
                                value: state.kpiDashboard!.totalSubmissions
                                    .toString(),
                                icon: Icons.description,
                                color: const Color(0xFF003087),
                              ),
                              KPICard(
                                title: 'Approval Rate',
                                value:
                                    '${state.kpiDashboard!.approvalRate.toStringAsFixed(1)}%',
                                icon: Icons.check_circle,
                                color: Colors.green,
                              ),
                              KPICard(
                                title: 'Avg Processing Time',
                                value:
                                    '${state.kpiDashboard!.avgProcessingTimeHours.toStringAsFixed(1)}h',
                                icon: Icons.timer,
                                color: const Color(0xFF00A3E0),
                              ),
                              KPICard(
                                title: 'Auto-Approval Rate',
                                value:
                                    '${state.kpiDashboard!.autoApprovalRate.toStringAsFixed(1)}%',
                                icon: Icons.auto_awesome,
                                color: Colors.orange,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          AIInsightCard(
                            narrative: state.kpiDashboard!.aiNarrative,
                          ),
                          const SizedBox(height: 24),
                        ],
                        if (state.stateROI.isNotEmpty) ...[
                          Text(
                            'State-Level ROI',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 16),
                          Card(
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: state.stateROI.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(),
                              itemBuilder: (context, index) {
                                final stateData = state.stateROI[index];
                                return ListTile(
                                  title: Text(stateData.state),
                                  subtitle: Text(
                                    'Submissions: ${stateData.submissionCount} | '
                                    'Approval: ${stateData.approvalRate.toStringAsFixed(1)}%',
                                  ),
                                  trailing: Text(
                                    'ROI: ${stateData.roi.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        if (state.campaignBreakdown.isNotEmpty) ...[
                          Text(
                            'Campaign Breakdown',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 16),
                          Card(
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: state.campaignBreakdown.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(),
                              itemBuilder: (context, index) {
                                final campaign = state.campaignBreakdown[index];
                                return ListTile(
                                  title: Text(campaign.campaignName),
                                  subtitle: Text(
                                    'Submissions: ${campaign.submissionCount} | '
                                    'Approval: ${campaign.approvalRate.toStringAsFixed(1)}%',
                                  ),
                                  trailing: Text(
                                    '${campaign.avgConfidenceScore.toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
