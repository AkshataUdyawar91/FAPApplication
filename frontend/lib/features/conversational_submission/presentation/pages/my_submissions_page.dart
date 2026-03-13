import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/responsive/responsive.dart';

/// Simple submissions list page that shows the user's conversational
/// submissions with status and links to resume drafts or view details.
class MySubmissionsPage extends ConsumerStatefulWidget {
  const MySubmissionsPage({super.key});

  @override
  ConsumerState<MySubmissionsPage> createState() => _MySubmissionsPageState();
}

class _MySubmissionsPageState extends ConsumerState<MySubmissionsPage> {
  List<Map<String, dynamic>> _submissions = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSubmissions());
  }

  Future<void> _loadSubmissions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioClientProvider);
      final response = await dio.get(ApiConstants.submissions);
      final data = response.data;
      final items = data is Map && data.containsKey('items')
          ? List<Map<String, dynamic>>.from(data['items'])
          : data is List
              ? List<Map<String, dynamic>>.from(data)
              : <Map<String, dynamic>>[];

      if (mounted) {
        setState(() {
          _submissions = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load submissions';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Submissions'),
        backgroundColor: const Color(0xFF003087),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : _submissions.isEmpty
                  ? _buildEmptyState()
                  : _buildSubmissionsList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/conversational-submission'),
        backgroundColor: const Color(0xFF003087),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Claim'),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(_error!, style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadSubmissions,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No submissions yet',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a new claim to get going',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.go('/conversational-submission'),
            icon: const Icon(Icons.add_comment),
            label: const Text('New Submission'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF003087),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionsList() {
    return RefreshIndicator(
      onRefresh: _loadSubmissions,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final device = getDeviceType(constraints.maxWidth);
          final padding = device == DeviceType.mobile ? 12.0 : 24.0;

          return ListView.builder(
            padding: EdgeInsets.all(padding),
            itemCount: _submissions.length,
            itemBuilder: (context, index) =>
                _buildSubmissionCard(_submissions[index]),
          );
        },
      ),
    );
  }

  Widget _buildSubmissionCard(Map<String, dynamic> submission) {
    final id = submission['id']?.toString() ?? '';
    final submissionNumber = submission['submissionNumber']?.toString() ??
        'CIQ-${id.length >= 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase()}';
    final state = submission['state']?.toString() ?? 'Draft';
    final poNumber = submission['poNumber']?.toString() ?? '—';
    final createdAt = submission['createdAt']?.toString() ?? '';
    final currentStep = submission['currentStep'] as int? ?? 0;
    final isDraft = state.toLowerCase() == 'draft';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isDraft
            ? () => context.go('/conversational-submission')
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      submissionNumber,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF003087),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildStatusChip(state),
                ],
              ),
              const SizedBox(height: 8),
              _buildInfoRow('PO Number', poNumber),
              if (createdAt.isNotEmpty)
                _buildInfoRow('Created', _formatDate(createdAt)),
              if (isDraft)
                _buildInfoRow('Progress', 'Step $currentStep of 10'),
              if (isDraft) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        context.go('/conversational-submission'),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Resume'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF003087),
                      side: const BorderSide(color: Color(0xFF003087)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String state) {
    Color bg;
    Color fg;
    final label = _statusLabel(state);

    switch (state.toLowerCase()) {
      case 'draft':
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade700;
        break;
      case 'submitted':
      case 'pendingasm':
      case 'pendingra':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1E40AF);
        break;
      case 'approved':
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF065F46);
        break;
      case 'asmrejected':
      case 'rarejected':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFF991B1B);
        break;
      default:
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w500)),
    );
  }

  String _statusLabel(String state) {
    switch (state.toLowerCase()) {
      case 'draft':
        return 'Draft';
      case 'submitted':
        return 'Submitted';
      case 'pendingasm':
        return 'Pending ASM';
      case 'pendingra':
        return 'Pending RA';
      case 'approved':
        return 'Approved';
      case 'asmrejected':
        return 'ASM Rejected';
      case 'rarejected':
        return 'RA Rejected';
      default:
        return state;
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }
}
