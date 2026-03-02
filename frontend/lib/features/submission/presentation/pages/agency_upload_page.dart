import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

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

  Future<void> _pickFile(Function(PlatformFile?) setter) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

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
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _photos.addAll(result.files);
        });
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
        setState(() {
          _additionalDocs.addAll(result.files);
        });
      }
    } catch (e) {
      _showError('Failed to pick documents');
    }
  }

  void _handleNext() {
    if (_currentStep == 1 && _purchaseOrder == null) {
      _showError('Please upload Purchase Order');
      return;
    }
    if (_currentStep == 2 && _invoice == null) {
      _showError('Please upload Invoice');
      return;
    }
    if (_currentStep == 3 && (_photos.isEmpty || _costSummary == null)) {
      _showError('Please upload event photos and cost summary');
      return;
    }

    if (_currentStep < 4) {
      setState(() {
        _currentStep++;
      });
    }
  }

  void _handleBack() {
    if (_currentStep > 1) {
      setState(() {
        _currentStep--;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (_purchaseOrder == null || _invoice == null || _costSummary == null || _photos.isEmpty) {
      _showError('Please complete all required steps');
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      String? packageId;
      
      // Upload Purchase Order first
      if (_purchaseOrder?.bytes != null) {
        final poFormData = FormData.fromMap({
          'file': MultipartFile.fromBytes(_purchaseOrder!.bytes!, filename: _purchaseOrder!.name),
          'documentType': 'PO',
        });
        
        final poResponse = await _dio.post(
          '/documents/upload',
          data: poFormData,
          options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
        );
        
        if (poResponse.statusCode == 200) {
          packageId = poResponse.data['packageId']?.toString();
        }
      }
      
      // Upload other documents with packageId
      if (packageId != null) {
        if (_invoice?.bytes != null) {
          final formData = FormData.fromMap({
            'file': MultipartFile.fromBytes(_invoice!.bytes!, filename: _invoice!.name),
            'documentType': 'Invoice',
            'packageId': packageId,
          });
          await _dio.post('/documents/upload', data: formData,
              options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}));
        }
        
        if (_costSummary?.bytes != null) {
          final formData = FormData.fromMap({
            'file': MultipartFile.fromBytes(_costSummary!.bytes!, filename: _costSummary!.name),
            'documentType': 'CostSummary',
            'packageId': packageId,
          });
          await _dio.post('/documents/upload', data: formData,
              options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}));
        }
        
        for (var photo in _photos) {
          if (photo.bytes != null) {
            final formData = FormData.fromMap({
              'file': MultipartFile.fromBytes(photo.bytes!, filename: photo.name),
              'documentType': 'Photo',
              'packageId': packageId,
            });
            await _dio.post('/documents/upload', data: formData,
                options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}));
          }
        }
        
        for (var doc in _additionalDocs) {
          if (doc.bytes != null) {
            final formData = FormData.fromMap({
              'file': MultipartFile.fromBytes(doc.bytes!, filename: doc.name),
              'documentType': 'AdditionalDocument',
              'packageId': packageId,
            });
            await _dio.post('/documents/upload', data: formData,
                options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}));
          }
        }
      }

      if (mounted) {
        _showSuccess('Documents submitted successfully!');
        Navigator.pushReplacementNamed(
          context,
          '/agency/dashboard',
          arguments: {
            'token': widget.token,
            'userName': widget.userName,
          },
        );
      }
    } catch (e) {
      _showError('Failed to submit documents: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.rejectedText,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.approvedText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        _buildProgressCard(),
                        const SizedBox(height: 24),
                        _buildStepContent(),
                        const SizedBox(height: 24),
                        _buildActionButtons(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E3A8A), Color(0xFF1E40AF)],
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.business, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Bajaj',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.white.withOpacity(0.2)),
          _buildNavItem(Icons.dashboard, 'Dashboard', false, () {
            Navigator.pushReplacementNamed(
              context,
              '/agency/dashboard',
              arguments: {
                'token': widget.token,
                'userName': widget.userName,
              },
            );
          }),
          _buildNavItem(Icons.upload_file, 'Upload', true, () {}),
          _buildNavItem(Icons.notifications, 'Notifications', false, () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Notifications coming soon')),
            );
          }),
          _buildNavItem(Icons.settings, 'Settings', false, () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Settings coming soon')),
            );
          }),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Text(
                    widget.userName[0].toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF1E3A8A),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.userName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Agency',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pushReplacementNamed(context, '/'),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Logout'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withOpacity(0.5)),
              ),
            ),
          ),
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
        title: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        dense: true,
        onTap: onTap,
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create New Request',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete all steps to submit your documents for AI validation and ASM approval',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step $_currentStep of 4',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '${_progressPercentage.round()}% Complete',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _progressPercentage / 100,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 32),
          Row(
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
                      child: Column(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: isComplete || isCurrent
                                  ? AppColors.primary
                                  : const Color(0xFFE5E7EB),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              step['icon'] as IconData,
                              color: isComplete || isCurrent
                                  ? Colors.white
                                  : const Color(0xFF9CA3AF),
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            step['title'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                              color: isCurrent ? AppColors.primary : AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                    if (index < _steps.length - 1)
                      Container(
                        width: 40,
                        height: 2,
                        color: isComplete ? AppColors.primary : const Color(0xFFE5E7EB),
                        margin: const EdgeInsets.only(bottom: 40),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 1:
        return _buildFileUploadCard(
          'Upload Purchase Order',
          'Upload the official Purchase Order document (PDF only)',
          Icons.description,
          _purchaseOrder,
          () => _pickFile((file) => _purchaseOrder = file),
          () => setState(() => _purchaseOrder = null),
        );
      case 2:
        return _buildFileUploadCard(
          'Upload Invoice',
          'Upload the invoice for reimbursement (PDF only)',
          Icons.receipt,
          _invoice,
          () => _pickFile((file) => _invoice = file),
          () => setState(() => _invoice = null),
        );
      case 3:
        return _buildPhotosAndCostSummaryStep();
      case 4:
        return _buildAdditionalDocsStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildFileUploadCard(
    String title,
    String subtitle,
    IconData icon,
    PlatformFile? file,
    VoidCallback onPick,
    VoidCallback onRemove,
  ) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppColors.primary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          if (file == null)
            InkWell(
              onTap: onPick,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary, width: 2),
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.primary.withOpacity(0.05),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_upload_outlined,
                        size: 64,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Click to upload',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'PDF format only',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.approvedBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.approvedBorder),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.approvedText.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: AppColors.approvedText,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.approvedText,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(file.size / 1024).toStringAsFixed(1)} KB',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.approvedText.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.close, color: AppColors.rejectedText),
                    tooltip: 'Remove file',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPhotosAndCostSummaryStep() {
    return Column(
      children: [
        // Photos Section
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.photo_library, color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Upload Event Photos',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Upload photos from the marketing event',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _pickPhotos,
                icon: const Icon(Icons.add_photo_alternate),
                label: Text(_photos.isEmpty ? 'Select Photos' : 'Add More Photos'),
              ),
              if (_photos.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  '${_photos.length} photo${_photos.length > 1 ? 's' : ''} selected',
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _photos.asMap().entries.map((entry) {
                    return Chip(
                      label: Text(entry.value.name),
                      onDeleted: () => setState(() => _photos.removeAt(entry.key)),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Cost Summary Section
        _buildFileUploadCard(
          'Upload Cost Summary',
          'Upload the cost summary document (PDF only)',
          Icons.receipt_long,
          _costSummary,
          () => _pickFile((file) => _costSummary = file),
          () => setState(() => _costSummary = null),
        ),
      ],
    );
  }

  Widget _buildAdditionalDocsStep() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.upload_file, color: AppColors.primary, size: 28),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Additional Documents',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Upload any additional supporting documents (Optional)',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _pickAdditionalDocs,
            icon: const Icon(Icons.attach_file),
            label: Text(_additionalDocs.isEmpty ? 'Select Documents' : 'Add More Documents'),
          ),
          if (_additionalDocs.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              '${_additionalDocs.length} document${_additionalDocs.length > 1 ? 's' : ''} selected',
              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ...(_additionalDocs.asMap().entries.map((entry) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.insert_drive_file, color: AppColors.primary),
                  title: Text(entry.value.name),
                  subtitle: Text('${(entry.value.size / 1024).toStringAsFixed(1)} KB'),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, color: AppColors.rejectedText),
                    onPressed: () => setState(() => _additionalDocs.removeAt(entry.key)),
                  ),
                ),
              );
            })),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: _currentStep == 1 ? null : _handleBack,
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Back'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        ),
        const SizedBox(width: 16),
        OutlinedButton(
          onPressed: () => Navigator.pushReplacementNamed(
            context,
            '/agency/dashboard',
            arguments: {
              'token': widget.token,
              'userName': widget.userName,
            },
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
          child: const Text('Cancel'),
        ),
        const Spacer(),
        if (_currentStep < 4)
          ElevatedButton.icon(
            onPressed: _handleNext,
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('Next Step'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          )
        else
          ElevatedButton.icon(
            onPressed: _isUploading ? null : _handleSubmit,
            icon: _isUploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.check, size: 18),
            label: Text(_isUploading ? 'Submitting...' : 'Submit for Review'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.approvedText,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
      ],
    );
  }
}
