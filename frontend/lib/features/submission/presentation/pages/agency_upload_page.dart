import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../core/widgets/app_sidebar.dart';
import '../../../../core/widgets/app_drawer.dart';
import '../../../../core/widgets/chat_side_panel.dart';
import '../../../../core/widgets/chat_end_drawer.dart';
import '../../../../core/widgets/nav_item.dart';
import '../widgets/po_fields_section.dart';
import '../widgets/campaign_list_section.dart';

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
  bool _isExtractingPO = false;
  bool _isChatOpen = false;
  bool _isSidebarCollapsed = true;

  String? _currentPackageId;
  PlatformFile? _purchaseOrder;
  List<PlatformFile> _additionalDocs = [];
  Map<String, dynamic>? _poData;
  Map<String, String> _poFields = {};
  List<CampaignItemData> _campaigns = [];

  final List<Map<String, dynamic>> _steps = [
    {'number': 1, 'title': 'Purchase Order', 'icon': Icons.description},
    {'number': 2, 'title': 'Campaigns', 'icon': Icons.campaign},
    {'number': 3, 'title': 'Additional Documents', 'icon': Icons.upload_file},
  ];

  double get _progressPercentage => (_currentStep / 3) * 100;

  // ─── FILE PICKERS ────────────────────────────────────────────────────
  Future<void> _pickFile(Function(PlatformFile?) setter, {bool isPO = false}) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      if (result != null && result.files.isNotEmpty) {
        setter(result.files.first);
        setState(() {});
        if (isPO) {
          await _uploadAndExtractPO(result.files.first);
        }
      }
    } catch (e) {
      _showError('Failed to pick file');
    }
  }

  Future<void> _uploadAndExtractPO(PlatformFile file) async {
    if (file.bytes == null) return;
    setState(() => _isExtractingPO = true);
    try {
      final uploadResponse = await _dio.post(
        '/documents/upload',
        data: FormData.fromMap({
          'file': MultipartFile.fromBytes(file.bytes!, filename: file.name),
          'documentType': 'PO',
        }),
        options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
      );
      if (uploadResponse.statusCode == 200) {
        final packageId = uploadResponse.data['packageId']?.toString();
        final documentId = uploadResponse.data['documentId']?.toString();
        if (packageId != null) {
          _currentPackageId = packageId;
          if (documentId != null) {
            await _pollForPOExtraction(packageId, documentId);
          }
        }
      }
    } catch (e) {
      debugPrint('Error uploading/extracting PO: $e');
      _showError('Failed to extract PO data. You can enter details manually.');
    } finally {
      if (mounted) setState(() => _isExtractingPO = false);
    }
  }

  Future<void> _pollForPOExtraction(String packageId, String documentId) async {
    const maxAttempts = 25;
    const delayBetweenAttempts = Duration(seconds: 2);
    
    print('PO polling started: packageId=$packageId, documentId=$documentId');
    
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      await Future.delayed(delayBetweenAttempts);
      if (!mounted) {
        print('PO polling stopped: widget disposed at attempt $attempt');
        return;
      }
      
      try {
        final response = await _dio.get(
          '/submissions/$packageId',
          options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
        );
        
        if (!mounted) return;
        
        if (response.statusCode == 200 && response.data != null) {
          final documents = response.data['documents'] as List?;
          if (documents != null) {
            final poDoc = documents.firstWhere(
              (doc) => doc['type']?.toString().toLowerCase() == 'po',
              orElse: () => null,
            );
            
            if (poDoc == null) {
              print('PO poll attempt $attempt: PO doc not found in ${documents.length} docs');
            } else if (poDoc['extractedData'] == null) {
              print('PO poll attempt $attempt: doc found but extractedData is null');
            }
            
            if (poDoc != null) {
              var extractedData = poDoc['extractedData'];
              if (extractedData != null) {
                if (extractedData is String && extractedData.isNotEmpty) {
                  extractedData = _parseJsonString(extractedData);
                }
                if (extractedData is Map) {
                  final poNumber = extractedData['PONumber'] ?? extractedData['poNumber'];
                  final totalAmount = extractedData['TotalAmount'] ?? extractedData['totalAmount'];
                  final vendorName = extractedData['VendorName'] ?? extractedData['vendorName'];
                  final date = extractedData['PODate'] ?? extractedData['poDate'] ?? extractedData['Date'] ?? extractedData['date'];
                  if (poNumber != null || totalAmount != null || vendorName != null || date != null) {
                    if (!mounted) return;
                    setState(() {
                      _poData = {
                        'poNumber': poNumber,
                        'totalAmount': totalAmount,
                        'date': date,
                        'vendorName': vendorName,
                      };
                    });
                    print('PO extraction successful: $_poData');
                    return; // Success - exit polling
                  } else {
                    print('PO extraction attempt $attempt: No meaningful data found in extractedData');
                  }
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Polling attempt $attempt failed: $e');
      }
    }
  }

  Map<String, dynamic> _parseJsonString(String jsonString) {
    try {
      if (jsonString.isEmpty) return {};
      final decoded = jsonDecode(jsonString);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return {};
    } catch (e) {
      debugPrint('JSON parse error: $e');
      return {};
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
    if (_currentStep == 2) {
      if (_campaigns.isEmpty) { _showError('Please add at least one campaign'); return; }
      final hasValidCampaign = _campaigns.any((camp) =>
        camp.campaignName.isNotEmpty &&
        camp.invoices.any((inv) => inv.file != null) &&
        camp.photos.isNotEmpty &&
        camp.costSummaryFile != null);
      if (!hasValidCampaign) { _showError('Please complete at least one campaign with name, invoice, photos, and cost summary'); return; }
    }
    if (_currentStep < 3) setState(() => _currentStep++);
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
    if (_purchaseOrder == null) { _showError('Please upload Purchase Order'); return; }
    if (_campaigns.isEmpty || !_campaigns.any((camp) => camp.invoices.any((inv) => inv.file != null))) {
      _showError('Please add at least one campaign with invoice'); return;
    }
    setState(() => _isUploading = true);
    try {
      String? packageId = _currentPackageId;
      if (packageId == null && _purchaseOrder?.bytes != null) {
        final poResponse = await _dio.post('/documents/upload',
            data: FormData.fromMap({
              'file': MultipartFile.fromBytes(_purchaseOrder!.bytes!, filename: _purchaseOrder!.name),
              'documentType': 'PO',
            }),
            options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}));
        if (poResponse.statusCode == 200) {
          packageId = poResponse.data['packageId']?.toString();
        }
      }
      if (packageId == null) { _showError('Failed to create package'); return; }
      _showSuccess('Uploading campaigns and documents...');

      for (final campaign in _campaigns) {
        final campaignResponse = await _dio.post(
          '/hierarchical/$packageId/campaigns',
          data: {
            'campaignName': campaign.campaignName,
            'startDate': campaign.startDate.isNotEmpty ? _parseDate(campaign.startDate)?.toIso8601String() : null,
            'endDate': campaign.endDate.isNotEmpty ? _parseDate(campaign.endDate)?.toIso8601String() : null,
            'workingDays': campaign.workingDays.isNotEmpty ? int.tryParse(campaign.workingDays) : null,
            'dealershipName': campaign.dealershipName,
            'dealershipAddress': campaign.dealershipAddress,
          },
          options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
        );
        final campaignId = campaignResponse.data['campaignId']?.toString();
        if (campaignId == null) { debugPrint('Failed to create campaign: ${campaign.campaignName}'); continue; }

        for (final invoice in campaign.invoices) {
          if (invoice.file?.bytes != null) {
            await _dio.post(
              '/hierarchical/$packageId/campaigns/$campaignId/invoices',
              data: FormData.fromMap({
                'file': MultipartFile.fromBytes(invoice.file!.bytes!, filename: invoice.file!.name),
                'invoiceNumber': invoice.invoiceNumber,
                'invoiceDate': invoice.invoiceDate.isNotEmpty ? _parseDate(invoice.invoiceDate)?.toIso8601String() : null,
                'totalAmount': invoice.totalAmount.isNotEmpty ? double.tryParse(invoice.totalAmount) : null,
                'gstNumber': invoice.gstNumber,
              }),
              options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
            );
          }
        }

        if (campaign.photos.isNotEmpty) {
          final photoFiles = campaign.photos
              .where((p) => p.bytes != null)
              .map((p) => MultipartFile.fromBytes(p.bytes!, filename: p.name))
              .toList();
          if (photoFiles.isNotEmpty) {
            await _dio.post(
              '/hierarchical/$packageId/campaigns/$campaignId/photos',
              data: FormData.fromMap({'files': photoFiles}),
              options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
            );
          }
        }

        if (campaign.costSummaryFile?.bytes != null) {
          await _dio.post(
            '/hierarchical/$packageId/campaigns/$campaignId/cost-summary',
            data: FormData.fromMap({
              'file': MultipartFile.fromBytes(campaign.costSummaryFile!.bytes!, filename: campaign.costSummaryFile!.name),
            }),
            options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
          );
        }

        if (campaign.activitySummaryFile?.bytes != null) {
          await _dio.post(
            '/hierarchical/$packageId/campaigns/$campaignId/activity-summary',
            data: FormData.fromMap({
              'file': MultipartFile.fromBytes(campaign.activitySummaryFile!.bytes!, filename: campaign.activitySummaryFile!.name),
            }),
            options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
          );
        }
      }

      final enquiryDoc = _additionalDocs.isNotEmpty ? _additionalDocs.first : null;
      if (enquiryDoc?.bytes != null) {
        await _dio.post(
          '/hierarchical/$packageId/enquiry-doc',
          data: FormData.fromMap({
            'file': MultipartFile.fromBytes(enquiryDoc!.bytes!, filename: enquiryDoc.name),
          }),
          options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
        );
      }

      for (int i = 1; i < _additionalDocs.length; i++) {
        final doc = _additionalDocs[i];
        if (doc.bytes != null) {
          await _dio.post('/documents/upload',
              data: FormData.fromMap({
                'file': MultipartFile.fromBytes(doc.bytes!, filename: doc.name),
                'documentType': 'AdditionalDocument',
                'packageId': packageId,
              }),
              options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}));
        }
      }

      _showSuccess('Submission complete! Processing in background...');
      await _dio.post('/submissions/$packageId/process-async',
          options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}));
      if (mounted) _navigateToDashboard();
    } catch (e) {
      _showError('Failed to submit: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  DateTime? _parseDate(String dateStr) {
    try {
      if (dateStr.isEmpty) return null;
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      }
      return null;
    } catch (e) { return null; }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.rejectedText));

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.approvedText));

  // ─── SHARED NAV ITEMS ────────────────────────────────────────────────
  List<NavItem> _getNavItems(BuildContext context) {
    return [
      NavItem(icon: Icons.dashboard, label: 'Dashboard', onTap: _navigateToDashboard),
      NavItem(icon: Icons.upload_file, label: 'Upload', isActive: true, onTap: () {}),
      NavItem(icon: Icons.notifications, label: 'Notifications', onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifications coming soon')));
      }),
      NavItem(icon: Icons.settings, label: 'Settings', onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings coming soon')));
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
          CircleAvatar(
            backgroundColor: Colors.white,
            radius: 18,
            child: Text(
              widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : '?',
              style: const TextStyle(color: Color(0xFF003087), fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.userName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 2),
              Text('Agency', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
            ],
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
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
                  title: const Text('Create New Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  iconTheme: const IconThemeData(color: Colors.white),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _navigateToDashboard,
                  ),
                  actions: [
                    Builder(
                      builder: (ctx) => IconButton(
                        icon: const Icon(Icons.menu),
                        onPressed: () => Scaffold.of(ctx).openDrawer(),
                      ),
                    ),
                  ],
                )
              : null,
          drawer: isMobile
              ? AppDrawer(
                  userName: widget.userName,
                  userRole: 'Agency',
                  navItems: _getNavItems(context),
                  onLogout: () => Navigator.pushReplacementNamed(context, '/'),
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
                        onLogout: () => Navigator.pushReplacementNamed(context, '/'),
                        isCollapsed: _isSidebarCollapsed,
                        onToggleCollapse: () => setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
                      ),
                    Expanded(
                      child: Column(
                        children: [
                          if (!isMobile) _buildHeader(device),
                          Expanded(child: _buildContentArea(device, width)),
                        ],
                      ),
                    ),
                    if (_isChatOpen && !isMobile)
                      ChatSidePanel(
                        token: widget.token,
                        deviceType: device,
                        onClose: () => setState(() => _isChatOpen = false),
                      ),
                  ],
                ),
              ),
            ],
          ),
          endDrawer: isMobile ? ChatEndDrawer(token: widget.token) : null,
          floatingActionButton: (_isChatOpen && !isMobile)
              ? null
              : Builder(
                  builder: (scaffoldContext) => Padding(
                    padding: const EdgeInsets.only(bottom: 16, right: 4),
                    child: FloatingActionButton(
                      onPressed: () {
                        if (isMobile) {
                          Scaffold.of(scaffoldContext).openEndDrawer();
                        } else {
                          setState(() => _isChatOpen = !_isChatOpen);
                        }
                      },
                      backgroundColor: AppColors.primary,
                      child: const Icon(Icons.smart_toy, color: Colors.white),
                    ),
                  ),
                ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        );
      },
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

  // ─── CONTENT AREA ────────────────────────────────────────────────────
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

  // ─── PROGRESS CARD ────────────────────────────────────────────────────
  Widget _buildProgressCard(DeviceType device) {
    final isMobile = device == DeviceType.mobile;
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withOpacity(0.5), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Step $_currentStep of 3', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                child: Text('${_progressPercentage.round()}%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
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
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
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
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: isComplete || isCurrent ? AppColors.primary : const Color(0xFFF3F4F6),
                          shape: BoxShape.circle,
                          border: isCurrent ? Border.all(color: AppColors.primary, width: 2) : null,
                        ),
                        child: Center(
                          child: isComplete
                              ? const Icon(Icons.check, color: Colors.white, size: 14)
                              : Text('$stepNumber', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isCurrent ? Colors.white : const Color(0xFF9CA3AF))),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(step['title'] as String, style: TextStyle(fontSize: 9, fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500, color: isCurrent ? AppColors.primary : AppColors.textSecondary), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ),
              if (index < _steps.length - 1)
                Expanded(child: Container(height: 2, margin: const EdgeInsets.only(bottom: 20, left: 2, right: 2), color: isComplete ? AppColors.primary : const Color(0xFFE5E7EB))),
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
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: isComplete || isCurrent ? AppColors.primary : const Color(0xFFF3F4F6),
                          shape: BoxShape.circle,
                          border: isCurrent ? Border.all(color: AppColors.primary, width: 2) : null,
                        ),
                        child: Center(
                          child: isComplete
                              ? const Icon(Icons.check, color: Colors.white, size: 16)
                              : Text('$stepNumber', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isCurrent ? Colors.white : const Color(0xFF9CA3AF))),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(step['title'] as String, style: TextStyle(fontSize: 11, fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500, color: isCurrent ? AppColors.primary : AppColors.textSecondary), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ),
              if (index < _steps.length - 1)
                Expanded(flex: 1, child: Container(height: 2, margin: const EdgeInsets.only(bottom: 24), color: isComplete ? AppColors.primary : const Color(0xFFE5E7EB))),
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
        content = Column(
          children: [
            _buildFileUploadCard(
              'Upload Purchase Order',
              'Upload the official Purchase Order document (PDF only)',
              Icons.description,
              _purchaseOrder,
              () => _pickFile((f) => _purchaseOrder = f, isPO: true),
              () => setState(() { _purchaseOrder = null; _poData = null; _poFields = {}; }),
              device,
            ),
            const SizedBox(height: 16),
            if (_isExtractingPO)
              _buildExtractionLoadingCard('Extracting PO details...', 'AI is analyzing your Purchase Order document')
            else
              POFieldsSection(
                poData: _poData,
                onFieldsChanged: (fields) => setState(() => _poFields = fields),
              ),
          ],
        );
        break;
      case 2:
        content = CampaignListSection(
          campaigns: _campaigns,
          onCampaignsChanged: (campaigns) {
            setState(() => _campaigns = campaigns);
          },
          token: widget.token,
          packageId: _currentPackageId,
        );
        break;
      case 3:
        content = _buildAdditionalDocsStep(device);
        break;
      default:
        content = const SizedBox();
    }
    return SingleChildScrollView(child: content);
  }

  Widget _buildExtractionLoadingCard(String title, String subtitle) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 48, height: 48, child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary))),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primary)),
            const SizedBox(height: 8),
            Text(subtitle, style: TextStyle(fontSize: 14, color: AppColors.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text('Fields will auto-populate when extraction completes.\nYou can also enter details manually.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withOpacity(0.8)), textAlign: TextAlign.center),
          ],
        ),
      ),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
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
                  border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
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
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
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
                  IconButton(onPressed: onRemove, icon: const Icon(Icons.close, color: AppColors.rejectedText, size: 24), tooltip: 'Remove file'),
                ],
              ),
            ),
        ],
      ),
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

    final nextBtn = _currentStep < 3
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
