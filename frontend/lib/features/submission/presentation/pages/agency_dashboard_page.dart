import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../../../../core/constants/api_constants.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/network/dio_client.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/widgets/app_sidebar.dart';
import '../../../../core/widgets/app_drawer.dart';
import '../../../../core/widgets/chat_side_panel.dart';
import '../../../assistant/presentation/widgets/assistant_chat_panel.dart';
import '../../../../core/widgets/chat_end_drawer.dart';
import '../../../../core/widgets/nav_item.dart';
import '../../../../core/widgets/pagination_bar.dart';

class AgencyDashboardPage extends ConsumerStatefulWidget {
  final String token;
  final String userName;

  const AgencyDashboardPage({
    super.key,
    required this.token,
    required this.userName,
  });

  @override
  ConsumerState<AgencyDashboardPage> createState() =>
      _AgencyDashboardPageState();
}

class _AgencyDashboardPageState extends ConsumerState<AgencyDashboardPage> {
  final _dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl))
    ..interceptors.add(PrettyDioLogger());
  final _searchController = TextEditingController();

  String _statusFilter = 'all';
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  bool _isChatOpen = false;
  bool _isSidebarCollapsed = true;
  bool _isChatbotOpen = true;
  // 'chatbot' = show assistant, 'requests' = show requests table
  String _mainView = 'chatbot';
  // when true, requests view shows only pending claims (no header/stats)
  bool _pendingClaimsMode = false;

  // Pagination state
  int _currentPage = 1;
  int _totalItems = 0;
  int _totalPages = 1;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    // Sync token into authTokenProvider so AssistantChatPanel's dio interceptor picks it up
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.token.isNotEmpty) {
        ref.read(authTokenProvider.notifier).state = widget.token;
      }
    });
    _loadRequests();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests({int page = 1}) async {
    setState(() => _isLoading = true);
    try {
      final response = await _dio.get(
        '/submissions',
        queryParameters: {'page': page, 'pageSize': _pageSize},
        options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
      );
      if (response.statusCode == 200 && mounted) {
        setState(() {
          final data = response.data;
          _requests = data is Map && data.containsKey('items')
              ? List<Map<String, dynamic>>.from(data['items'])
              : [];
          _totalItems = data is Map ? (data['total'] ?? 0) : 0;
          _totalPages = data is Map ? (data['totalPages'] ?? 1) : 1;
          _currentPage = page;
          _isLoading = false;

          // Reset filter to 'all' if current filter is not available in the new data
          if (!_availableStatuses.contains(_statusFilter)) {
            _statusFilter = 'all';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to load requests: $e'),
              backgroundColor: AppColors.rejectedText),
        );
      }
    }
  }

  List<String> get _availableStatuses {
    final statuses = <String>{'all'}; // Always include 'all'

    for (var req in _requests) {
      final state = req['state']?.toString().toLowerCase() ?? '';

      // Map backend states to dropdown values
      if (['uploaded', 'draft'].contains(state)) {
        statuses.add('uploaded');
      } else if ([
        'extracting',
        'validating',
        'validated',
        'scoring',
        'recommending'
      ].contains(state)) {
        statuses.add('extracting');
      } else if (['pendingapproval', 'pendingchapproval', 'pendingch'].contains(state)) {
        statuses.add('pending_with_asm');
      } else if (['asmapproved', 'pendinghqapproval', 'pendingra'].contains(state)) {
        statuses.add('pending_with_ra');
      } else if (state == 'approved') {
        statuses.add('approved');
      } else if (['rejected', 'rejectedbyasm', 'reuploadrequested', 'chrejected']
          .contains(state)) {
        statuses.add('rejected_by_asm');
      } else if (['rejectedbyhq', 'rejectedbyra', 'rarejected'].contains(state)) {
        statuses.add('rejected_by_ra');
      }
    }

    return statuses.toList();
  }

  List<DropdownMenuItem<String>> _buildDropdownItems() {
    final availableStatuses = _availableStatuses;
    final statusLabels = {
      'all': 'All Status',
      'uploaded': 'Submitted',
      'extracting': 'Extracting',
      'pending_with_asm': 'Pending with CH',
      'pending_with_ra': 'Pending with RA',
      'approved': 'Approved',
      'rejected_by_asm': 'Rejected by CH',
      'rejected_by_ra': 'Rejected by RA',
    };

    // Define the order we want statuses to appear
    final orderedKeys = [
      'all',
      'uploaded',
      'extracting',
      'pending_with_asm',
      'pending_with_ra',
      'approved',
      'rejected_by_asm',
      'rejected_by_ra',
    ];

    return orderedKeys
        .where((key) => availableStatuses.contains(key))
        .map((key) => DropdownMenuItem<String>(
              value: key,
              child: Text(statusLabels[key]!),
            ))
        .toList();
  }

  List<Map<String, dynamic>> get _filteredRequests {
    return _requests.where((req) {
      final matchesSearch = _searchController.text.isEmpty ||
          req['id']
              .toString()
              .toLowerCase()
              .contains(_searchController.text.toLowerCase());
      if (_statusFilter == 'all') return matchesSearch;
      final state = req['state']?.toString().toLowerCase() ?? '';
      bool matchesStatus = false;
      switch (_statusFilter) {
        case 'uploaded':
          matchesStatus = ['uploaded', 'draft'].contains(state);
          break;
        case 'extracting':
          matchesStatus = [
            'extracting',
            'validating',
            'validated',
            'scoring',
            'recommending'
          ].contains(state);
          break;
        case 'pending_with_asm':
          matchesStatus =
              ['pendingapproval', 'pendingchapproval', 'pendingch'].contains(state);
          break;
        case 'pending_with_ra':
          matchesStatus = ['asmapproved', 'pendinghqapproval', 'pendingra'].contains(state);
          break;
        case 'approved':
          matchesStatus = state == 'approved';
          break;
        case 'rejected_by_asm':
          matchesStatus = ['rejected', 'rejectedbyasm', 'reuploadrequested', 'chrejected']
              .contains(state);
          break;
        case 'rejected_by_ra':
          matchesStatus = ['rejectedbyhq', 'rejectedbyra', 'rarejected'].contains(state);
          break;
      }
      return matchesSearch && matchesStatus;
    }).toList();
  }

  Map<String, int> get _stats {
    return {
      'total': _totalItems,
      'uploaded': _requests.where((r) {
        final s = r['state']?.toString().toLowerCase() ?? '';
        return ['uploaded', 'draft'].contains(s);
      }).length,
      'extracting': _requests.where((r) {
        final s = r['state']?.toString().toLowerCase() ?? '';
        return [
          'extracting',
          'validating',
          'validated',
          'scoring',
          'recommending'
        ].contains(s);
      }).length,
      'pendingWithASM': _requests.where((r) {
        final s = r['state']?.toString().toLowerCase() ?? '';
        return ['pendingapproval', 'pendingchapproval', 'pendingch'].contains(s);
      }).length,
      'pendingWithRA': _requests.where((r) {
        final s = r['state']?.toString().toLowerCase() ?? '';
        return ['asmapproved', 'pendinghqapproval', 'pendingra'].contains(s);
      }).length,
      'approved': _requests
          .where((r) => r['state']?.toString().toLowerCase() == 'approved')
          .length,
      'rejectedByASM': _requests.where((r) {
        final s = r['state']?.toString().toLowerCase() ?? '';
        return ['rejected', 'rejectedbyasm', 'reuploadrequested'].contains(s);
      }).length,
      'rejectedByRA': _requests.where((r) {
        final s = r['state']?.toString().toLowerCase() ?? '';
        return ['rejectedbyhq', 'rejectedbyra'].contains(s);
      }).length,
    };
  }


  // ─── BUILD ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final device = getDeviceType(width);
        final isMobile = device == DeviceType.mobile;

        return Scaffold(
          appBar: isMobile
              ? AppBar(
                  backgroundColor: const Color(0xFF1E3A8A),
                  title: const Text('Bajaj',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  iconTheme: const IconThemeData(color: Colors.white),
                  actions: [
                    IconButton(
                        icon: const Icon(Icons.add_comment, color: Colors.white),
                        onPressed: _navigateToChatbot),
                  ],
                )
              : null,
          drawer: isMobile
              ? AppDrawer(
                  userName: widget.userName,
                  userRole: 'Agency',
                  navItems: _getNavItems(context),
                  onLogout: () => handleLogout(context, ref),
                )
              : null,
          body: Column(
            children: [
              if (!isMobile) _buildTopBar(),
              Expanded(
                child: Row(
                  children: [
                    if (!isMobile)
                      AppSidebar(
                        userName: widget.userName,
                        userRole: 'Agency',
                        navItems: _getNavItems(context),
                        onLogout: () => handleLogout(context, ref),
                        isCollapsed: _isSidebarCollapsed,
                        onToggleCollapse: () => setState(
                            () => _isSidebarCollapsed = !_isSidebarCollapsed),
                      ),
                    // Main content area — chatbot or requests table
                    Expanded(
                      child: _mainView == 'chatbot'
                          ? AssistantChatPanel(
                              onClose: () => setState(() => _mainView = 'requests'),
                              onNewRequest: _navigateToUpload,
                              isFullWidth: true,
                            )
                          : Column(
                              children: [
                                if (!isMobile && !_pendingClaimsMode) _buildHeader(device),
                                Expanded(
                                  child: _isLoading
                                      ? const Center(child: CircularProgressIndicator())
                                      : _buildContent(device),
                                ),
                              ],
                            ),
                    ),
                    if (_isChatOpen && !isMobile)
                      ChatSidePanel(
                        token: widget.token,
                        userName: widget.userName,
                        deviceType: device,
                        onClose: () => setState(() => _isChatOpen = false),
                      ),
                  ],
                ),
              ),
            ],
          ),
          endDrawer: isMobile
              ? ChatEndDrawer(token: widget.token, userName: widget.userName)
              : null,
          floatingActionButton: isMobile
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 16, right: 4),
                  child: Builder(
                    builder: (ctx) => FloatingActionButton(
                      onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                      backgroundColor: AppColors.primary,
                      tooltip: 'Open Assistant',
                      child: const Icon(Icons.smart_toy, color: Colors.white),
                    ),
                  ),
                )
              : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        );
      },
    );
  }

  void _navigateToUpload() async {
    if (!mounted) return;

    // Create draft submission first
    try {
      final dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
      final response = await dio.post(
        '/submissions/draft',
        data: {},
        options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
      );

      if (response.statusCode == 201 && mounted) {
        final submissionId = response.data['submissionId'];
        debugPrint('Draft submission created: $submissionId');

        context.pushNamed('agency-upload', extra: {
          'token': widget.token,
          'userName': widget.userName,
          'submissionId': submissionId,
        });
      }
    } catch (e) {
      debugPrint('Error creating draft submission: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create submission: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToChatbot() {
    setState(() {
      _isChatbotOpen = !_isChatbotOpen;
      // Close the AI assistant panel when opening chatbot
      if (_isChatbotOpen) _isChatOpen = false;
    });
  }

  List<NavItem> _getNavItems(BuildContext context) {
    return [
      NavItem(
          icon: Icons.smart_toy,
          label: 'Assistant',
          isActive: _mainView == 'chatbot',
          onTap: () => setState(() => _mainView = 'chatbot')),
      NavItem(
          icon: Icons.list_alt,
          label: 'My Requests',
          isActive: _mainView == 'requests',
          onTap: () => setState(() {
            _mainView = 'requests';
            _pendingClaimsMode = false;
          })),
      NavItem(
          icon: Icons.add,
          label: 'New Claim',
          onTap: _navigateToUpload),
      NavItem(
          icon: Icons.notifications,
          label: 'Notifications',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifications coming soon')));
          }),
      NavItem(
          icon: Icons.settings,
          label: 'Settings',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings coming soon')));
          }),
    ];
  }

  /// Full-width top bar with Bajaj branding — spans sidebar + content.
  Widget _buildTopBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFF003087),
      child: Row(
        children: [
          const Icon(Icons.business, color: Colors.white, size: 22),
          const SizedBox(width: 8),
          const Text(
            'Bajaj',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  // ─── HEADER (tablet/desktop) ──────────────────────────────────────────
  Widget _buildHeader(DeviceType device) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: device == DeviceType.desktop ? 24 : 16,
        vertical: 16,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('My Requests', style: AppTextStyles.h2),
          const SizedBox(height: 4),
          Text('View and track all your reimbursement requests',
              style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }

  // ─── MAIN CONTENT ─────────────────────────────────────────────────────
  Widget _buildContent(DeviceType device) {
    final hPad = responsiveValue<double>(MediaQuery.of(context).size.width,
        mobile: 12, tablet: 16, desktop: 24);

    // Pending claims mode: no stats, pre-filtered to pending, with a simple header
    if (_pendingClaimsMode) {
      // Force filter to pending states
      final pendingStates = {'uploaded', 'extracting', 'pending_with_asm', 'pending_with_ra'};
      if (!pendingStates.contains(_statusFilter)) {
        // reset to 'all' so _filteredRequests shows everything, then we filter below
      }
      final pendingRequests = _requests.where((req) {
        final state = req['state']?.toString().toLowerCase() ?? '';
        return [
          'uploaded', 'draft', 'extracting', 'validating', 'validated',
          'scoring', 'recommending', 'pendingapproval', 'pendingchapproval',
          'pendingch', 'asmapproved', 'pendinghqapproval', 'pendingra',
        ].contains(state);
      }).toList();

      return RefreshIndicator(
        onRefresh: () => _loadRequests(page: 1),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(hPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text('Pending Claims', style: AppTextStyles.h2),
              const SizedBox(height: 4),
              Text('Your claims currently under review',
                  style: AppTextStyles.bodySmall),
              const SizedBox(height: 16),
              if (pendingRequests.isEmpty)
                _buildEmptyState()
              else
                Column(
                  children: [
                    _buildTable(pendingRequests),
                    PaginationBar(
                      currentPage: _currentPage,
                      totalPages: _totalPages,
                      totalItems: pendingRequests.length,
                      pageSize: _pageSize,
                      onPageChanged: (page) => _loadRequests(page: page),
                    ),
                  ],
                ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadRequests(page: 1),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(hPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (device == DeviceType.mobile) ...[
              Text('My Requests', style: AppTextStyles.h2),
              const SizedBox(height: 4),
              Text('View and track all your reimbursement requests',
                  style: AppTextStyles.bodySmall),
              const SizedBox(height: 16),
            ],
            _buildStatsCards(device),
            const SizedBox(height: 24),
            _buildFilterRow(device),
            const SizedBox(height: 16),
            _buildRequestsList(device),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // ─── STATS CARDS ──────────────────────────────────────────────────────
  Widget _buildStatsCards(DeviceType device) {
    final stats = _stats;
    final cards = [
      _StatData('Pending with CH', stats['pendingWithASM']!.toString(),
          Icons.schedule, const Color(0xFF3B82F6), 'pending_with_asm'),
      _StatData('Approved', stats['approved']!.toString(), Icons.check_circle,
          const Color(0xFF10B981), 'approved'),
    ];

    // Use LayoutBuilder so cards respond to actual available width, not screen width
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        // Wide layout: single row
        if (w >= 600) {
          return Row(
            children: cards
                .map((c) => Expanded(
                      child: Padding(
                        padding:
                            EdgeInsets.only(right: c == cards.last ? 0 : 12),
                        child: _buildStatCard(
                            c.label, c.value, c.icon, c.color, w / 4,
                            filterKey: c.filterKey),
                      ),
                    ))
                .toList(),
          );
        }
        // Mobile: single row with 2 cards
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                child: _buildStatCard(cards[0].label, cards[0].value,
                    cards[0].icon, cards[0].color, w / 2,
                    filterKey: cards[0].filterKey)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildStatCard(cards[1].label, cards[1].value,
                    cards[1].icon, cards[1].color, w / 2,
                    filterKey: cards[1].filterKey)),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color, double cardWidth,
      {String? filterKey}) {
    // Use column layout when card is too narrow for side-by-side icon+text
    final useColumn = cardWidth < 200;
    final isActive = filterKey != null && _statusFilter == filterKey;

    // Determine font size based on card width for better responsiveness
    final valueFontSize = useColumn
        ? (cardWidth < 150 ? 18.0 : 20.0)
        : (cardWidth < 250 ? 20.0 : 22.0);

    return InkWell(
      onTap: filterKey == null
          ? null
          : () {
              setState(() {
                // Toggle: tap again to reset to 'all'
                _statusFilter = _statusFilter == filterKey ? 'all' : filterKey;
              });
            },
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: isActive ? 2 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
              color: isActive ? color : AppColors.border,
              width: isActive ? 2 : 1),
        ),
        child: Padding(
          padding: EdgeInsets.all(useColumn ? 14 : 20),
          child: useColumn
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(height: 10),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: AppTextStyles.h3.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: valueFontSize,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              value,
                              style: AppTextStyles.h2.copyWith(
                                fontSize: valueFontSize,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ─── FILTER ROW ───────────────────────────────────────────────────────
  Widget _buildFilterRow(DeviceType device) {
    // Use column layout on mobile OR when content area is narrow (e.g. tablet with chat open)
    final availableWidth = MediaQuery.of(context).size.width;
    final useColumnLayout = device == DeviceType.mobile || availableWidth < 500;

    // Safety: reset filter if current value isn't in available items
    final availableStatuses = _availableStatuses;
    if (!availableStatuses.contains(_statusFilter)) {
      _statusFilter = 'all';
    }

    if (useColumnLayout) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Requests',
              style: AppTextStyles.h3.copyWith(fontSize: 18)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _statusFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true),
                  items: _buildDropdownItems(),
                  onChanged: (v) {
                    setState(() {
                      _statusFilter = v!;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _navigateToUpload,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New'),
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10)),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: Text('Recent Requests',
              style: AppTextStyles.h3.copyWith(fontSize: 18),
              overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 160,
          child: DropdownButtonFormField<String>(
            value: _statusFilter,
            isExpanded: true,
            decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true),
            items: _buildDropdownItems(),
            onChanged: (v) {
              setState(() {
                _statusFilter = v!;
              });
            },
          ),
        ),
      ],
    );
  }

  // ─── REQUESTS LIST ────────────────────────────────────────────────────
  Widget _buildRequestsList(DeviceType device) {
    final filtered = _filteredRequests;
    if (filtered.isEmpty) return _buildEmptyState();
    return Column(
      children: [
        if (device == DeviceType.mobile)
          ..._buildMobileCards(filtered)
        else
          _buildTable(filtered),
        PaginationBar(
          currentPage: _currentPage,
          totalPages: _totalPages,
          totalItems: _totalItems,
          pageSize: _pageSize,
          onPageChanged: (page) => _loadRequests(page: page),
        ),
      ],
    );
  }

  List<Widget> _buildMobileCards(List<Map<String, dynamic>> requests) {
    return requests.map((r) => _buildMobileCard(r)).toList();
  }

  Widget _buildMobileCard(Map<String, dynamic> request) {
    final rawState = request['state']?.toString() ?? 'pending';
    final fapNumber = request['submissionNumber']?.toString() ?? '—';
    final poNumber =
        request['poNumber']?.toString() ?? request['poNo']?.toString() ?? '—';
    final invoiceNumber = request['invoiceNumber']?.toString() ??
        request['invoiceNo']?.toString() ??
        '—';
    final invoiceAmount = request['invoiceAmount'];
    final invoiceAmountStr = invoiceAmount != null
        ? '₹${double.tryParse(invoiceAmount.toString())?.toStringAsFixed(2) ?? '—'}'
        : '—';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FAP number + status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    fapNumber,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E40AF),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(_normalizeStatus(rawState), rawState),
              ],
            ),
            const SizedBox(height: 12),
            // Key-value rows
            _buildCardRow('PO Number', poNumber),
            _buildCardRow('Invoice Number', invoiceNumber),
            _buildCardRow('Invoice Amount', invoiceAmountStr),
            _buildCardRow('Submitted', _formatDate(request['createdAt'])),
            const SizedBox(height: 12),
            // View Details button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.pushNamed(
                    'submission-detail',
                    extra: {
                      'submissionId': request['id'],
                      'token': widget.token,
                      'userName': widget.userName,
                      'poNumber': request['poNumber']?.toString() ??
                          request['poNo']?.toString() ??
                          '',
                    },
                  );
                },
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('View Details'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF111827),
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(List<Map<String, dynamic>> requests) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowColor:
                    WidgetStateProperty.all(const Color(0xFFF9FAFB)),
                headingTextStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                  fontSize: 11,
                  letterSpacing: 0.4,
                ),
                dataTextStyle: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 12,
                ),
                columnSpacing: 20,
                horizontalMargin: 16,
                dataRowMinHeight: 56,
                dataRowMaxHeight: 72,
                dividerThickness: 1,
                columns: const [
                  DataColumn(label: Text('FAP NUMBER')),
                  DataColumn(label: Text('PO NO.')),
                  DataColumn(label: Text('INVOICE NO.')),
                  DataColumn(label: Text('INVOICE AMT')),
                  DataColumn(label: Text('SUBMITTED DATE')),
                  DataColumn(label: Text('STATUS')),
                  DataColumn(label: SizedBox.shrink()),
                ],
                rows: requests.map((r) {
                  final rawState = r['state']?.toString() ?? 'pending';
                  final status = _normalizeStatus(rawState);
                  final fapNumber = r['submissionNumber']?.toString() ?? '—';
                  final poNumber =
                      r['poNumber']?.toString() ?? r['poNo']?.toString() ?? '—';
                  final invoiceNumber = r['invoiceNumber']?.toString() ??
                      r['invoiceNo']?.toString() ??
                      '—';
                  final invoiceAmount = r['invoiceAmount'];
                  final invoiceAmountStr = invoiceAmount != null
                      ? '₹${double.tryParse(invoiceAmount.toString())?.toStringAsFixed(2) ?? '—'}'
                      : '—';
                  return DataRow(cells: [
                    DataCell(Text(fapNumber,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: Color(0xFF111827)))),
                    DataCell(
                        Text(poNumber, style: const TextStyle(fontSize: 12))),
                    DataCell(Text(invoiceNumber,
                        style: const TextStyle(fontSize: 12))),
                    DataCell(Text(invoiceAmountStr,
                        style: const TextStyle(fontSize: 12))),
                    DataCell(Text(_formatDate(r['createdAt']),
                        style: const TextStyle(fontSize: 12))),
                    DataCell(_buildStatusBadge(status, rawState)),
                    DataCell(
                      SizedBox(
                        width: 80,
                        child: Center(
                          child: IconButton(
                            icon: const Icon(Icons.visibility_outlined),
                            color: AppColors.primary,
                            onPressed: () {
                              // Navigate to detailed view page
                              context.pushNamed(
                                'submission-detail',
                                extra: {
                                  'submissionId': r['id'],
                                  'token': widget.token,
                                  'userName': widget.userName,
                                  'poNumber': r['poNumber']?.toString() ?? '',
                                },
                              );
                            },
                            tooltip: 'View Details',
                          ),
                        ),
                      ),
                    ),
                  ]);
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border)),
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.description, size: 64, color: AppColors.textTertiary),
              const SizedBox(height: 16),
              Text('No requests found', style: AppTextStyles.h3),
              const SizedBox(height: 8),
              Text(
                _searchController.text.isNotEmpty || _statusFilter != 'all'
                    ? 'Try adjusting your filters'
                    : 'Create your first request to get started',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                  onPressed: _navigateToUpload,
                  icon: const Icon(Icons.add),
                  label: const Text('Create New Request')),
            ],
          ),
        ),
      ),
    );
  }

  // ─── HELPERS ──────────────────────────────────────────────────────────

  /// Granular status badge used in the DataTable — shows exact backend state label
  Widget _buildStatusBadge(String normalizedStatus, String rawState) {
    Color bgColor, textColor;
    String label;

    final state = rawState.toLowerCase();
    switch (state) {
      case 'approved':
        bgColor = const Color(0xFFD1FAE5);
        textColor = const Color(0xFF065F46);
        label = 'Approved';
        break;
      case 'rejected':
      case 'validationfailed':
        bgColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFF991B1B);
        label = state == 'validationfailed' ? 'Validation Failed' : 'Rejected';
        break;
      case 'rejectedbyasm':
      case 'chrejected':
        bgColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFF991B1B);
        label = 'Rejected by CH';
        break;
      case 'rejectedbyhq':
      case 'rejectedbyra':
      case 'rarejected':
        bgColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFF991B1B);
        label = 'Rejected by RA';
        break;
      case 'validated':
      case 'recommending':
      case 'pendingapproval':
      case 'submitted':
        bgColor = const Color(0xFFDBEAFE);
        textColor = const Color(0xFF1E40AF);
        label = state == 'pendingapproval'
            ? 'Pending with CH'
            : state == 'recommending'
                ? 'Recommending'
                : state == 'submitted'
                    ? 'Submitted'
                    : 'Validated';
        break;
      case 'pendingchapproval':
      case 'pendingwithch':
      case 'pendingch':
        bgColor = const Color(0xFFDBEAFE);
        textColor = const Color(0xFF1E40AF);
        label = 'Pending with CH';
        break;
      case 'pendinghqapproval':
      case 'pendingwithra':
      case 'pendingra':
        bgColor = const Color(0xFFDBEAFE);
        textColor = const Color(0xFF1E40AF);
        label = 'Pending with RA';
        break;
      case 'reuploadrequested':
        bgColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFF991B1B);
        label = 'Re-upload Requested';
        break;
      case 'processingfailed':
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFF92400E);
        label = 'Processing Failed';
        break;
      case 'onhold':
        bgColor = const Color(0xFFF3F4F6);
        textColor = const Color(0xFF374151);
        label = 'On Hold';
        break;
      default:
        // uploaded, extracting, validating, pending → yellow
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFF92400E);
        label = state == 'uploaded'
            ? 'Uploaded'
            : state == 'extracting'
                ? 'Extracting'
                : state == 'validating'
                    ? 'Validating'
                    : 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(
              color: textColor, fontWeight: FontWeight.w600, fontSize: 11)),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final dt = DateTime.parse(date.toString());
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  String _normalizeStatus(String backendState) {
    final state = backendState.toLowerCase();

    if (['uploaded', 'extracting', 'validating'].contains(state))
      return 'pending';
    if (['validated', 'recommending'].contains(state)) return 'pending';
    if (['pendingch', 'pendingchapproval', 'pendingapproval', 'pendingwithch']
        .contains(state)) return 'pending_asm';
    if (['pendingra', 'pendinghqapproval', 'pendingwithra'].contains(state))
      return 'pending_hq';
    if (state == 'approved') return 'approved';
    if (['chrejected', 'rejectedbyasm'].contains(state))
      return 'rejected_by_asm';
    if (['rarejected', 'rejectedbyhq', 'rejectedbyra'].contains(state))
      return 'rejected_by_hq';
    if (['rejected', 'validationfailed', 'reuploadrequested'].contains(state))
      return 'rejected';
    if (state == 'processingfailed') return 'processing_failed';

    return 'pending';
  }
}

// ─── DATA CLASS ───────────────────────────────────────────────────────
class _StatData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String filterKey;
  const _StatData(
      this.label, this.value, this.icon, this.color, this.filterKey);
}
