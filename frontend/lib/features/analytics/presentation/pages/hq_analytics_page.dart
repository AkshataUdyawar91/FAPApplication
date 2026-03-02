import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class HQAnalyticsPage extends StatefulWidget {
  final String token;
  final String userName;

  const HQAnalyticsPage({
    super.key,
    required this.token,
    required this.userName,
  });

  @override
  State<HQAnalyticsPage> createState() => _HQAnalyticsPageState();
}

class _HQAnalyticsPageState extends State<HQAnalyticsPage> {
  final _dio = Dio(BaseOptions(baseUrl: 'http://localhost:5000/api'));
  
  bool _isLoading = true;
  Map<String, dynamic> _analytics = {};
  String _selectedTab = 'trends';

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await _dio.get(
        '/analytics/overview',
        options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
      );
      
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _analytics = response.data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.gradientBlue,
          ),
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF1E40AF)],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                onPressed: () => Navigator.pushReplacementNamed(context, '/'),
              ),
              const SizedBox(width: 8),
              const Text(
                'Back to Login',
                style: TextStyle(color: Color(0xFFBFDBFE), fontSize: 14),
              ),
              const Spacer(),
              const Icon(Icons.bar_chart, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text(
                'HQ Analytics Dashboard',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 24),
              OutlinedButton.icon(
                onPressed: () => Navigator.pushReplacementNamed(context, '/'),
                icon: const Icon(Icons.logout, size: 16),
                label: const Text('Logout'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white),
                ).copyWith(
                  foregroundColor: WidgetStateProperty.all(const Color(0xFF1E3A8A)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildOverviewStats(),
            const SizedBox(height: 24),
            _buildTabs(),
            const SizedBox(height: 24),
            _buildTabContent(),
            const SizedBox(height: 24),
            _buildAIPerformance(),
            const SizedBox(height: 24),
            _buildInsights(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewStats() {
    return Row(
      children: [
        Expanded(child: _buildStatCard(
          'Total Submissions',
          '248',
          Icons.bar_chart,
          const Color(0xFF3B82F6),
          '↑ 12% vs last month',
        )),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard(
          'Approved',
          '186',
          Icons.check_circle,
          const Color(0xFF10B981),
          '75% approval rate',
        )),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard(
          'Total Amount',
          '₹12.5Cr',
          Icons.currency_rupee,
          const Color(0xFF3B82F6),
          '₹9.3Cr approved',
        )),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard(
          'AI Confidence',
          '87%',
          Icons.psychology,
          const Color(0xFF3B82F6),
          '↑ 3% improvement',
        )),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, String subtitle) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: AppTextStyles.h1.copyWith(
                          color: color,
                          fontSize: 28,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: subtitle.startsWith('↑') 
                              ? const Color(0xFF10B981) 
                              : AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(icon, size: 40, color: color.withOpacity(0.3)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            _buildTab('trends', 'Monthly Trends'),
            const SizedBox(width: 8),
            _buildTab('distribution', 'Distribution'),
            const SizedBox(width: 8),
            _buildTab('agencies', 'Top Agencies'),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String value, String label) {
    final isSelected = _selectedTab == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.button.copyWith(
              color: isSelected ? Colors.white : AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 'trends':
        return _buildTrendsTab();
      case 'distribution':
        return _buildDistributionTab();
      case 'agencies':
        return _buildAgenciesTab();
      default:
        return const SizedBox();
    }
  }

  Widget _buildTrendsTab() {
    return Row(
      children: [
        Expanded(child: _buildSubmissionTrendChart()),
        const SizedBox(width: 16),
        Expanded(child: _buildAmountTrendChart()),
      ],
    );
  }

  Widget _buildSubmissionTrendChart() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Submission Trends',
              style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 20,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: AppColors.border,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
                          if (value.toInt() >= 0 && value.toInt() < months.length) {
                            return Text(
                              months[value.toInt()],
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        const FlSpot(0, 35),
                        const FlSpot(1, 42),
                        const FlSpot(2, 38),
                        const FlSpot(3, 45),
                        const FlSpot(4, 48),
                        const FlSpot(5, 52),
                      ],
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                    LineChartBarData(
                      spots: [
                        const FlSpot(0, 28),
                        const FlSpot(1, 32),
                        const FlSpot(2, 30),
                        const FlSpot(3, 35),
                        const FlSpot(4, 38),
                        const FlSpot(5, 40),
                      ],
                      isCurved: true,
                      color: const Color(0xFF10B981),
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                    LineChartBarData(
                      spots: [
                        const FlSpot(0, 7),
                        const FlSpot(1, 10),
                        const FlSpot(2, 8),
                        const FlSpot(3, 10),
                        const FlSpot(4, 10),
                        const FlSpot(5, 12),
                      ],
                      isCurved: true,
                      color: const Color(0xFFEF4444),
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Submissions', AppColors.primary),
                const SizedBox(width: 16),
                _buildLegendItem('Approved', const Color(0xFF10B981)),
                const SizedBox(width: 16),
                _buildLegendItem('Rejected', const Color(0xFFEF4444)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountTrendChart() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Amount Trends (₹ Lakhs)',
              style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 50,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: AppColors.border,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
                          if (value.toInt() >= 0 && value.toInt() < months.length) {
                            return Text(
                              months[value.toInt()],
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 180, color: AppColors.primary, width: 20, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))]),
                    BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 210, color: AppColors.primary, width: 20, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))]),
                    BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 190, color: AppColors.primary, width: 20, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))]),
                    BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: 225, color: AppColors.primary, width: 20, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))]),
                    BarChartGroupData(x: 4, barRods: [BarChartRodData(toY: 240, color: AppColors.primary, width: 20, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))]),
                    BarChartGroupData(x: 5, barRods: [BarChartRodData(toY: 260, color: AppColors.primary, width: 20, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionTab() {
    return Row(
      children: [
        Expanded(child: _buildApprovalDistribution()),
        const SizedBox(width: 16),
        Expanded(child: _buildIssueBreakdown()),
      ],
    );
  }

  Widget _buildApprovalDistribution() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Approval Distribution',
              style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: 186,
                      title: '75%',
                      color: const Color(0xFF10B981),
                      radius: 100,
                      titleStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      value: 42,
                      title: '17%',
                      color: const Color(0xFFEF4444),
                      radius: 100,
                      titleStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      value: 20,
                      title: '8%',
                      color: const Color(0xFFF59E0B),
                      radius: 100,
                      titleStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                  sectionsSpace: 2,
                  centerSpaceRadius: 0,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Approved', const Color(0xFF10B981)),
                const SizedBox(width: 16),
                _buildLegendItem('Rejected', const Color(0xFFEF4444)),
                const SizedBox(width: 16),
                _buildLegendItem('Pending', const Color(0xFFF59E0B)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIssueBreakdown() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Common Issues',
              style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 5,
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const issues = ['Amount\nMismatch', 'Missing\nDocs', 'Photo\nQuality', 'Date\nIssues'];
                          if (value.toInt() >= 0 && value.toInt() < issues.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                issues[value.toInt()],
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 15, color: const Color(0xFFEF4444), width: 40, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))]),
                    BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 12, color: const Color(0xFFEF4444), width: 40, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))]),
                    BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 8, color: const Color(0xFFEF4444), width: 40, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))]),
                    BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: 7, color: const Color(0xFFEF4444), width: 40, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgenciesTab() {
    final agencies = [
      {'name': 'Creative Marketing Solutions', 'submissions': 45, 'approved': 43, 'amount': 2850000},
      {'name': 'Digital Dynamics Agency', 'submissions': 38, 'approved': 35, 'amount': 2420000},
      {'name': 'Brand Builders Inc', 'submissions': 32, 'approved': 29, 'amount': 2050000},
      {'name': 'Media Masters', 'submissions': 28, 'approved': 25, 'amount': 1780000},
      {'name': 'Promotion Pros', 'submissions': 25, 'approved': 22, 'amount': 1590000},
    ];

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Performing Agencies',
              style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            ...agencies.asMap().entries.map((entry) {
              final index = entry.key;
              final agency = entry.value;
              return _buildAgencyCard(
                index + 1,
                agency['name'] as String,
                agency['submissions'] as int,
                agency['approved'] as int,
                agency['amount'] as int,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildAgencyCard(int rank, String name, int submissions, int approved, int amount) {
    final approvalRate = (approved / submissions * 100).round();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.reviewBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    rank.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '$submissions submissions • $approved approved',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${(amount / 100000).toStringAsFixed(1)}L',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '$approvalRate% approved',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: const Color(0xFF10B981),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: approved / submissions,
              backgroundColor: AppColors.reviewBorder,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIPerformance() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology, color: AppColors.primary, size: 24),
                const SizedBox(width: 8),
                Text(
                  'AI Performance Metrics',
                  style: AppTextStyles.h2.copyWith(color: AppColors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _buildAIMetricCard(
                  'Average Confidence',
                  '87%',
                  '↑ +3% vs last month',
                  const Color(0xFF3B82F6),
                )),
                const SizedBox(width: 16),
                Expanded(child: _buildAIMetricCard(
                  'Accuracy Rate',
                  '94%',
                  'AI predictions match ASM',
                  const Color(0xFF10B981),
                )),
                const SizedBox(width: 16),
                Expanded(child: _buildAIMetricCard(
                  'Processing Time',
                  '2.3s',
                  'Average per document',
                  const Color(0xFF8B5CF6),
                )),
                const SizedBox(width: 16),
                Expanded(child: _buildAIMetricCard(
                  'Flagged for Review',
                  '23',
                  '9% of total submissions',
                  const Color(0xFFF59E0B),
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIMetricCard(String label, String value, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.h1.copyWith(
              color: color,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTextStyles.bodySmall.copyWith(
              color: color,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsights() {
    return Row(
      children: [
        Expanded(
          child: Card(
            elevation: 2,
            color: const Color(0xFFEFF6FF),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 Key Insights',
                    style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 16),
                  _buildInsightItem(
                    Icons.check_circle,
                    const Color(0xFF10B981),
                    'AI confidence has improved by 3% this month, reducing manual review time',
                  ),
                  const SizedBox(height: 12),
                  _buildInsightItem(
                    Icons.warning,
                    const Color(0xFFF59E0B),
                    '15 documents flagged for amount mismatches - most common issue this month',
                  ),
                  const SizedBox(height: 12),
                  _buildInsightItem(
                    Icons.trending_up,
                    AppColors.primary,
                    'Creative Marketing Solutions maintains highest approval rate at 95%',
                  ),
                  const SizedBox(height: 12),
                  _buildInsightItem(
                    Icons.psychology,
                    const Color(0xFF8B5CF6),
                    'AI accuracy rate of 94% shows strong correlation with ASM decisions',
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Card(
            elevation: 2,
            color: const Color(0xFFF0FDF4),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📈 Recommendations',
                    style: AppTextStyles.h3.copyWith(color: const Color(0xFF065F46)),
                  ),
                  const SizedBox(height: 16),
                  _buildRecommendationItem(
                    'Consider automating approvals for documents with AI confidence above 95%',
                  ),
                  const SizedBox(height: 12),
                  _buildRecommendationItem(
                    'Provide training to agencies on proper documentation to reduce rejection rate',
                  ),
                  const SizedBox(height: 12),
                  _buildRecommendationItem(
                    'Review photo quality requirements with agencies to improve submission quality',
                  ),
                  const SizedBox(height: 12),
                  _buildRecommendationItem(
                    'Schedule quarterly review meetings with top-performing agencies',
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInsightItem(IconData icon, Color color, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '•',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF065F46),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodySmall.copyWith(
              color: const Color(0xFF065F46),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
