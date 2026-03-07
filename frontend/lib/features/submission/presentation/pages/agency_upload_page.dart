import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/responsive/responsive.dart';

class AgencyUploadPage extends StatefulWidget {
  final String token;
  final String userName;

  const AgencyUploadPage({
    super.key,
    required this.token,
    required this.userName,
  });

  @override
  State<AgencyUploadPage> createState() => _AgencyUploadPageState();
}

class _AgencyUploadPageState extends State<AgencyUploadPage> {
  final _dio = Dio(BaseOptions(baseUrl: 'http://localhost:5000/api'));

  int _currentStep = 1;
  bool _isUploading = false;

  PlatformFile? _purchaseOrder;
  PlatformFile? _invoice;
  PlatformFile? _costSummary;
  List<PlatformFile> _photos = [];
  List<PlatformFile> _additionalDocs = [];

  final List<Map<String, dynamic>> _steps = [
    {'number': 1, 'title': 'Purchase Order', 'icon': Icons.description},
    {'number': 2, 'title': 'Invoice', 'icon': Icons.receipt},
    {'number': 3, 'title': 'Photos & Cost Summary', 'icon': Icons.photo_library},
    {'number': 4, 'title': 'Additional Documents', 'icon': Icons.upload_file},
  ];

  double get _progressPercentage => (_currentStep / 4) * 100;

  // ─── FILE PICKERS ────────────────────────────────────────────────────
  Future<void> _pickFile(Function(PlatformFile?) setter) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);

      if (result != null && result.files.isNotEmpty) {
        setter(result.files.first);
        setState(() {});
      }
    } catch (e) {
      _showError('Failed to pick file');
    }
  }

  Future<void> _pickPhotos() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
      if (result != null && result.files.isNotEmpty) {
        setState(() => _photos.addAll(result.files));
      }
    } catch (e) {
      _showError('Failed to pick photos');
    }
  }

  Future<void> _pickAdditionalDocs() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() => _additionalDocs.addAll(result.files));
      }
    } catch (e) {
      _showError('Failed to pick documents');
    }
  }

  // ─── NAVIGATION ──────────────────────────────────────────────────────
  void _handleNext() {
    if (_currentStep == 1 && _purchaseOrder == null) { _showError('Please upload Purchase Order'); return; }
    if (_currentStep == 2 && _invoice == null) { _showError('Please upload Invoice'); return; }
    if (_currentStep == 3 && (_photos.isEmpty || _costSummary == null)) { _showError('Please upload event photos and cost summary'); return; }
    if (_currentStep < 4) setState(() => _currentStep++);
  }

  void _handleBack() {
    if (_currentStep > 1) setState(() => _currentStep--);
  }

  void _navigateToDashboard() {
    Navigator.pushReplacementNamed(context, '/agency/dashboard', arguments: {
      'token': widget.token,
      'userName': widget.userName,
    });
  }


  Future<void> _handleSubmit() async {
    if (_purchaseOrder == null || _invoice == null || _costSummary == null || _photos.isEmpty) {
      _showError('Please complete all required steps');
      return;
    }
    setState(() => _isUploading = true);
    try {
      String? packageId;
      if (_purchaseOrder?.bytes != null) {
        final poResponse = await _dio.post('/documents/upload',
            data: FormData.fromMap({
              'file': MultipartFile.fromBytes(_purchaseOrder!.bytes!, filename: _purchaseOrder!.name),
              'documentType': 'PO',
            }),
            options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}));
        if (poResponse.statusCode == 200) packageId = poResponse.data['packageId']?.toString();
      }
      if (packageId != null) {
        Future<void> upload(PlatformFile? f, String type) async {
          if (f?.bytes == null) return;
          await _dio.post('/documents/upload',
              data: FormData.fromMap({'file': MultipartFile.fromBytes(f!.bytes!, filename: f.name), 'documentType': type, 'packageId': packageId}),
              options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}));
        }
        await upload(_invoice, 'Invoice');
        await upload(_costSummary, 'CostSummary');
        for (final p in _photos) await upload(p, 'Photo');
        for (final d in _additionalDocs) await upload(d, 'AdditionalDocument');
        _showSuccess('Documents uploaded. Starting AI processing...');
        final submitResponse = await _dio.post('/submissions/$packageId/process-now',
            options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}));
        if (submitResponse.statusCode == 200 && submitResponse.data['success'] == true) {
          _showSuccess('Documents processed successfully! Package is ready for review.');
        } else {
          _showError('Processing completed with issues. Check package status.');
        }
      }
      if (mounted) _navigateToDashboard();
    } catch (e) {
      _showError('Failed to submit documents: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.rejectedText));

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.approvedText));


  // ─── BUILD ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final device = getDeviceType(width);
        final isMobile = device == DeviceType.mobile;
        final isTablet = device == DeviceType.tablet;

        return Scaffold(
          appBar: isMobile
              ? AppBar(
                  backgroundColor: const Color(0xFF1E3A8A),
                  title: const Text('Create New Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  iconTheme: const IconThemeData(color: Colors.white),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _navigateToDashboard,
                  ),
                )
              : null,
          drawer: isMobile ? _buildDrawer() : null,
          body: Row(
            children: [
              if (!isMobile) _buildSidebar(isTablet),
              Expanded(
                child: Column(
                  children: [
                    if (!isMobile) _buildHeader(device),
                    Flexible(
                      child: _buildContentArea(device, width),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── CONTENT AREA (no-scroll layout) ────────────────────────────────
  Widget _buildContentArea(DeviceType device, double width) {
    final pad = responsiveValue<double>(width, mobile: 10, tablet: 14, desktop: 16);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: pad, vertical: pad * 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildProgressCard(device),
          const SizedBox(height: 10),
          Expanded(child: _buildStepContent(device)),
          const SizedBox(height: 6),
          _buildActionButtons(device),
        ],
      ),
    );
  }


  // ─── DRAWER (mobile) ─────────────────────────────────────────────────
  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E3A8A), Color(0xFF1E40AF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.business, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Text('Bajaj', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.white.withOpacity(0.2)),
              _buildNavItem(Icons.dashboard, 'Dashboard', false, () { Navigator.pop(context); _navigateToDashboard(); }),
              _buildNavItem(Icons.upload_file, 'Upload', true, () => Navigator.pop(context)),
              _buildNavItem(Icons.notifications, 'Notifications', false, () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifications coming soon')));
              }),
              _buildNavItem(Icons.settings, 'Settings', false, () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings coming soon')));
              }),
              const Spacer(),
              _buildUserInfo(),
              _buildLogoutButton(),
            ],
          ),
        ),
      ),
    );
  }


  // ─── SIDEBAR (tablet/desktop) ─────────────────────────────────────────
  Widget _buildSidebar(bool collapsed) {
    return Container(
      width: collapsed ? 72.0 : 250.0,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E3A8A), Color(0xFF1E40AF)],
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(collapsed ? 16 : 24),
            child: collapsed
                ? Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.business, color: Colors.white, size: 24),
                  )
                : Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.business, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Text('Bajaj', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  ]),
          ),
          Divider(height: 1, color: Colors.white.withOpacity(0.2)),
          if (collapsed) ...[
            _buildCollapsedNavItem(Icons.dashboard, 'Dashboard', false, _navigateToDashboard),
            _buildCollapsedNavItem(Icons.upload_file, 'Upload', true, () {}),
            _buildCollapsedNavItem(Icons.notifications, 'Notifications', false, () =>
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifications coming soon')))),
            _buildCollapsedNavItem(Icons.settings, 'Settings', false, () =>
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings coming soon')))),
          ] else ...[
            _buildNavItem(Icons.dashboard, 'Dashboard', false, _navigateToDashboard),
            _buildNavItem(Icons.upload_file, 'Upload', true, () {}),
            _buildNavItem(Icons.notifications, 'Notifications', false, () =>
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifications coming soon')))),
            _buildNavItem(Icons.settings, 'Settings', false, () =>
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings coming soon')))),
          ],
          const Spacer(),
          if (!collapsed) _buildUserInfo(),
          _buildLogoutButton(collapsed: collapsed),
        ],
      ),
    );
  }


  Widget _buildNavItem(IconData icon, String label, bool isActive, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? Colors.white.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white, size: 20),
        title: Text(label, style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: isActive ? FontWeight.w600 : FontWeight.normal)),
        dense: true,
        onTap: onTap,
      ),
    );
  }

  Widget _buildCollapsedNavItem(IconData icon, String tooltip, bool isActive, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: IconButton(icon: Icon(icon, color: Colors.white, size: 20), onPressed: onTap),
      ),
    );
  }

  Widget _buildUserInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white,
            radius: 16,
            child: Text(widget.userName[0].toUpperCase(), style: const TextStyle(color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.userName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white), overflow: TextOverflow.ellipsis),
                Text('Agency', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildLogoutButton({bool collapsed = false}) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: collapsed
          ? Tooltip(
              message: 'Logout',
              child: IconButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/'),
                icon: const Icon(Icons.logout, size: 18, color: Colors.white),
              ),
            )
          : OutlinedButton.icon(
              onPressed: () => Navigator.pushReplacementNamed(context, '/'),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Logout'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.white.withOpacity(0.5))),
            ),
    );
  }

  // ─── HEADER (tablet/desktop) ──────────────────────────────────────────
  Widget _buildHeader(DeviceType device) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: device == DeviceType.desktop ? 16 : 14,
        vertical: 10,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: const Text('Create New Request', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
    );
  }

  // ─── PROGRESS CARD (clean & spacious) ─────────────────────────────────
  Widget _buildProgressCard(DeviceType device) {
    final isMobile = device == DeviceType.mobile;

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withOpacity(0.5), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step $_currentStep of 4',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_progressPercentage.round()}%',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _progressPercentage / 100,
              minHeight: 6,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 12),
          isMobile ? _buildMobileProgressLayout() : _buildDesktopProgressLayout(),
        ],
      ),
    );
  }


  Widget _buildMobileProgressLayout() {
    return Row(
      children: _steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        final stepNumber = step['number'] as int;
        final isComplete = _currentStep > stepNumber;
        final isCurrent = _currentStep == stepNumber;
        
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: isComplete ? () => setState(() => _currentStep = stepNumber) : null,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isComplete || isCurrent ? AppColors.primary : const Color(0xFFF3F4F6),
                          shape: BoxShape.circle,
                          border: isCurrent ? Border.all(color: AppColors.primary, width: 2) : null,
                        ),
                        child: Center(
                          child: isComplete
                              ? const Icon(Icons.check, color: Colors.white, size: 14)
                              : Text(
                                  '$stepNumber',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isCurrent ? Colors.white : const Color(0xFF9CA3AF),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        step['title'] as String,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                          color: isCurrent ? AppColors.primary : AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              if (index < _steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 20, left: 2, right: 2),
                    color: isComplete ? AppColors.primary : const Color(0xFFE5E7EB),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }


  Widget _buildDesktopProgressLayout() {
    return Row(
      children: _steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        final stepNumber = step['number'] as int;
        final isComplete = _currentStep > stepNumber;
        final isCurrent = _currentStep == stepNumber;
        
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: isComplete ? () => setState(() => _currentStep = stepNumber) : null,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isComplete || isCurrent ? AppColors.primary : const Color(0xFFF3F4F6),
                          shape: BoxShape.circle,
                          border: isCurrent ? Border.all(color: AppColors.primary, width: 2) : null,
                        ),
                        child: Center(
                          child: isComplete
                              ? const Icon(Icons.check, color: Colors.white, size: 16)
                              : Text(
                                  '$stepNumber',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isCurrent ? Colors.white : const Color(0xFF9CA3AF),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        step['title'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                          color: isCurrent ? AppColors.primary : AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              if (index < _steps.length - 1)
                Expanded(
                  flex: 1,
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 24),
                    color: isComplete ? AppColors.primary : const Color(0xFFE5E7EB),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }


  // ─── STEP CONTENT ─────────────────────────────────────────────────────
  Widget _buildStepContent(DeviceType device) {
    Widget content;
    switch (_currentStep) {
      case 1:
        content = _buildFileUploadCard('Upload Purchase Order', 'Upload the official Purchase Order document (PDF only)',
            Icons.description, _purchaseOrder, () => _pickFile((f) => _purchaseOrder = f), () => setState(() => _purchaseOrder = null), device);
        break;
      case 2:
        content = _buildFileUploadCard('Upload Invoice', 'Upload the invoice for reimbursement (PDF only)',
            Icons.receipt, _invoice, () => _pickFile((f) => _invoice = f), () => setState(() => _invoice = null), device);
        break;
      case 3:
        content = _buildPhotosAndCostSummaryStep(device);
        break;
      case 4:
        content = _buildAdditionalDocsStep(device);
        break;
      default:
        content = const SizedBox();
    }
    
    return SingleChildScrollView(
      child: content,
    );
  }

  Widget _buildFileUploadCard(String title, String subtitle, IconData icon, PlatformFile? file,
      VoidCallback onPick, VoidCallback onRemove, DeviceType device) {
    final pad = device == DeviceType.mobile ? 20.0 : 24.0;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withOpacity(0.5), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (file == null)
            InkWell(
              onTap: onPick,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                height: device == DeviceType.mobile ? 120 : 140,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.03),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2, style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_upload_outlined, size: 48, color: AppColors.primary.withOpacity(0.6)),
                    const SizedBox(height: 12),
                    const Text('Click to upload', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
                    const SizedBox(height: 4),
                    Text('PDF format only', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.approvedBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.approvedBorder, width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.check_circle, color: AppColors.approvedText, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(file.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.approvedText), overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text('${(file.size / 1024).toStringAsFixed(1)} KB', style: TextStyle(fontSize: 12, color: AppColors.approvedText.withOpacity(0.7))),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.close, color: AppColors.rejectedText, size: 24),
                    tooltip: 'Remove file',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPhotosAndCostSummaryStep(DeviceType device) {
    final pad = device == DeviceType.mobile ? 10.0 : 14.0;
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(pad),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                    child: const Icon(Icons.photo_library, color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Upload Event Photos', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        Text('Upload photos from the marketing event', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _pickPhotos,
                icon: const Icon(Icons.add_photo_alternate, size: 16),
                label: Text(_photos.isEmpty ? 'Select Photos' : 'Add More Photos', style: const TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              ),
              if (_photos.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('${_photos.length} photo${_photos.length > 1 ? 's' : ''} selected', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600, fontSize: 11)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: _photos.asMap().entries.map((e) => Chip(
                    label: Text(e.value.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10)),
                    onDeleted: () => setState(() => _photos.removeAt(e.key)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                  )).toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        _buildFileUploadCard('Upload Cost Summary', 'Upload the cost summary document (PDF only)',
            Icons.receipt_long, _costSummary, () => _pickFile((f) => _costSummary = f), () => setState(() => _costSummary = null), device),
      ],
    );
  }


  Widget _buildAdditionalDocsStep(DeviceType device) {
    final pad = device == DeviceType.mobile ? 10.0 : 14.0;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.upload_file, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Additional Documents', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    Text('Upload any additional supporting documents (Optional)', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _pickAdditionalDocs,
            icon: const Icon(Icons.attach_file, size: 16),
            label: Text(_additionalDocs.isEmpty ? 'Select Documents' : 'Add More Documents', style: const TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
          ),
          if (_additionalDocs.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('${_additionalDocs.length} document${_additionalDocs.length > 1 ? 's' : ''} selected', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600, fontSize: 11)),
            const SizedBox(height: 6),
            ..._additionalDocs.asMap().entries.map((e) => Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file, color: AppColors.primary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.value.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                        Text('${(e.value.size / 1024).toStringAsFixed(1)} KB', style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _additionalDocs.removeAt(e.key)),
                    child: const Icon(Icons.close, color: AppColors.rejectedText, size: 16),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }


  // ─── ACTION BUTTONS ───────────────────────────────────────────────────
  Widget _buildActionButtons(DeviceType device) {
    final isMobile = device == DeviceType.mobile;

    final backBtn = OutlinedButton.icon(
      onPressed: _currentStep == 1 ? null : _handleBack,
      icon: const Icon(Icons.arrow_back_rounded, size: 18),
      label: const Text('Back', style: TextStyle(fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: BorderSide(color: AppColors.primary.withOpacity(0.3), width: 1.5),
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    final cancelBtn = OutlinedButton(
      onPressed: _navigateToDashboard,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        side: BorderSide(color: AppColors.border, width: 1.5),
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
    );

    final nextBtn = _currentStep < 4
        ? ElevatedButton.icon(
            onPressed: _handleNext,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const Text('Next Step', style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 28, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 4,
              shadowColor: AppColors.primary.withOpacity(0.4),
            ),
          )
        : ElevatedButton.icon(
            onPressed: _isUploading ? null : _handleSubmit,
            icon: _isUploading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                : const Icon(Icons.check_circle_rounded, size: 20),
            label: Text(_isUploading ? 'Submitting...' : 'Submit for Review', style: const TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.approvedText,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 28, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 4,
              shadowColor: AppColors.approvedText.withOpacity(0.4),
            ),
          );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          nextBtn,
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: backBtn),
              const SizedBox(width: 10),
              Expanded(child: cancelBtn),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        backBtn,
        const SizedBox(width: 12),
        cancelBtn,
        const Spacer(),
        nextBtn,
      ],
    );
  }
}
