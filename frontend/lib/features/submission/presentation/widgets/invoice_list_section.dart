import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_colors.dart';

/// Data class for an invoice with its campaigns
class InvoiceData {
  final String id;
  PlatformFile? file;
  String invoiceNumber;
  String invoiceDate;
  String totalAmount;
  String gstNumber;
  String vendorName;
  List<CampaignData> campaigns;
  bool isExtracting;

  InvoiceData({
    required this.id,
    this.file,
    this.invoiceNumber = '',
    this.invoiceDate = '',
    this.totalAmount = '',
    this.gstNumber = '',
    this.vendorName = '',
    List<CampaignData>? campaigns,
    this.isExtracting = false,
  }) : campaigns = campaigns ?? [CampaignData(id: '${id}_campaign_1')];
}

/// Data class for a campaign with its photos
class CampaignData {
  final String id;
  String campaignName;
  String startDate;
  String endDate;
  String workingDays;
  String dealershipName;
  String dealershipAddress;
  String gpsLocation;
  String state;
  String totalCost;
  PlatformFile? costSummaryFile;
  List<PlatformFile> photos;
  List<TeamMemberData> teams;

  CampaignData({
    required this.id,
    this.campaignName = '',
    this.startDate = '',
    this.endDate = '',
    this.workingDays = '',
    this.dealershipName = '',
    this.dealershipAddress = '',
    this.gpsLocation = '',
    this.state = '',
    this.totalCost = '',
    this.costSummaryFile,
    List<PlatformFile>? photos,
    List<TeamMemberData>? teams,
  })  : photos = photos ?? [],
        teams = teams ?? [];
}

/// Data class for team members
class TeamMemberData {
  String teamName;
  String memberCount;
  String role;

  TeamMemberData({
    this.teamName = '',
    this.memberCount = '',
    this.role = '',
  });
}

/// Widget for managing multiple invoices with campaigns and photos
class InvoiceListSection extends StatefulWidget {
  final List<InvoiceData> invoices;
  final Function(List<InvoiceData>) onInvoicesChanged;
  final String? token;
  final String? packageId;

  const InvoiceListSection({
    super.key,
    required this.invoices,
    required this.onInvoicesChanged,
    this.token,
    this.packageId,
  });

  @override
  State<InvoiceListSection> createState() => _InvoiceListSectionState();
}

class _InvoiceListSectionState extends State<InvoiceListSection> {
  late List<InvoiceData> _invoices;
  int _expandedInvoiceIndex = 0;

  @override
  void initState() {
    super.initState();
    _invoices = widget.invoices.isEmpty
        ? [InvoiceData(id: 'invoice_1')]
        : widget.invoices;
  }

  void _addInvoice() {
    setState(() {
      _invoices.add(InvoiceData(id: 'invoice_${_invoices.length + 1}'));
      _expandedInvoiceIndex = _invoices.length - 1;
    });
    widget.onInvoicesChanged(_invoices);
  }

  void _removeInvoice(int index) {
    if (_invoices.length > 1) {
      setState(() {
        _invoices.removeAt(index);
        if (_expandedInvoiceIndex >= _invoices.length) {
          _expandedInvoiceIndex = _invoices.length - 1;
        }
      });
      widget.onInvoicesChanged(_invoices);
    }
  }

  void _addCampaign(int invoiceIndex) {
    setState(() {
      final invoice = _invoices[invoiceIndex];
      invoice.campaigns.add(
        CampaignData(
          id: '${invoice.id}_campaign_${invoice.campaigns.length + 1}',
        ),
      );
    });
    widget.onInvoicesChanged(_invoices);
  }

  void _removeCampaign(int invoiceIndex, int campaignIndex) {
    if (_invoices[invoiceIndex].campaigns.length > 1) {
      setState(() {
        _invoices[invoiceIndex].campaigns.removeAt(campaignIndex);
      });
      widget.onInvoicesChanged(_invoices);
    }
  }

  Future<void> _pickInvoiceFile(int index) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() => _invoices[index].file = result.files.first);
        widget.onInvoicesChanged(_invoices);

        // Auto-upload invoice file if packageId is available
        if (widget.packageId != null && widget.packageId!.isNotEmpty) {
          await _uploadInvoiceFile(index);
        }
      }
    } catch (e) {
      debugPrint('Error picking invoice file: $e');
    }
  }

  Future<void> _uploadInvoiceFile(int index) async {
    final invoice = _invoices[index];
    if (invoice.file == null) return;

    try {
      debugPrint(
          'Auto-uploading and extracting invoice file: ${invoice.file!.name}');

      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:5000/api'));
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          invoice.file!.path!,
          filename: invoice.file!.name,
        ),
        'documentType': 'invoice',
        'packageId': widget.packageId, // Include packageId to save to DB
      });

      final response = await dio.post(
        '/documents/extract', // Use extract API instead of upload
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
      );

      if (response.statusCode == 200) {
        final extractedData = response.data['extractedData'];
        final documentId = response.data['documentId'];

        debugPrint('Invoice extracted and saved: $documentId');

        // Auto-populate fields with extracted data (no polling needed!)
        if (mounted && extractedData != null) {
          setState(() {
            _invoices[index].invoiceNumber =
                extractedData['invoiceNumber'] ?? '';
            _invoices[index].invoiceDate = extractedData['invoiceDate'] ?? '';
            _invoices[index].totalAmount =
                extractedData['totalAmount']?.toString() ?? '';
            _invoices[index].gstNumber = extractedData['gstNumber'] ?? '';
            _invoices[index].vendorName = extractedData['vendorName'] ?? '';
          });
          widget.onInvoicesChanged(_invoices);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Invoice uploaded and data extracted successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error uploading invoice: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pollInvoiceExtraction(String documentId, int index) async {
    // Poll every 2 seconds for up to 30 seconds
    for (int i = 0; i < 15; i++) {
      await Future.delayed(const Duration(seconds: 2));

      try {
        final dio = Dio(BaseOptions(baseUrl: 'http://localhost:5000/api'));
        final response = await dio.get(
          '/invoices/$documentId',
          options:
              Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
        );

        if (response.data['extractedData'] != null ||
            response.data['invoiceNumber'] != null) {
          // Processing complete - update UI with extracted data
          if (mounted) {
            setState(() {
              _invoices[index].invoiceNumber =
                  response.data['invoiceNumber'] ?? '';
              _invoices[index].invoiceDate = response.data['invoiceDate'] ?? '';
              _invoices[index].totalAmount =
                  response.data['totalAmount']?.toString() ?? '';
              _invoices[index].gstNumber = response.data['gstNumber'] ?? '';
            });
            widget.onInvoicesChanged(_invoices);

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Invoice data extracted successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
          break;
        }
      } catch (e) {
        debugPrint('Error polling invoice extraction: $e');
        // Continue polling
      }
    }
  }

  Future<void> _pickCostSummaryFile(int invoiceIndex, int campaignIndex) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'xlsx', 'xls'],
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() => _invoices[invoiceIndex]
            .campaigns[campaignIndex]
            .costSummaryFile = result.files.first);
        widget.onInvoicesChanged(_invoices);

        // Auto-upload cost summary file if packageId is available
        if (widget.packageId != null && widget.packageId!.isNotEmpty) {
          await _uploadCostSummaryFile(invoiceIndex, campaignIndex);
        }
      }
    } catch (e) {
      debugPrint('Error picking cost summary file: $e');
    }
  }

  Future<void> _uploadCostSummaryFile(
      int invoiceIndex, int campaignIndex) async {
    final campaign = _invoices[invoiceIndex].campaigns[campaignIndex];
    if (campaign.costSummaryFile == null) return;

    try {
      debugPrint(
          'Auto-uploading and extracting cost summary file: ${campaign.costSummaryFile!.name}');

      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:5000/api'));
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          campaign.costSummaryFile!.path!,
          filename: campaign.costSummaryFile!.name,
        ),
        'documentType': 'costsummary',
        'packageId': widget.packageId, // Include packageId to save to DB
      });

      final response = await dio.post(
        '/documents/extract', // Use extract API
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
      );

      if (response.statusCode == 200) {
        final extractedData = response.data['extractedData'];
        final documentId = response.data['documentId'];

        debugPrint('Cost summary extracted and saved: $documentId');

        // Auto-populate fields with extracted data
        if (mounted && extractedData != null) {
          setState(() {
            campaign.totalCost = extractedData['totalCost']?.toString() ?? '';
            campaign.state = extractedData['placeOfSupply'] ?? '';
          });
          widget.onInvoicesChanged(_invoices);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Cost summary uploaded and data extracted successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error uploading cost summary: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cost summary upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickPhotos(int invoiceIndex, int campaignIndex) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() => _invoices[invoiceIndex]
            .campaigns[campaignIndex]
            .photos
            .addAll(result.files));
        widget.onInvoicesChanged(_invoices);
      }
    } catch (e) {
      debugPrint('Error picking photos: $e');
    }
  }

  void _removePhoto(int invoiceIndex, int campaignIndex, int photoIndex) {
    setState(() => _invoices[invoiceIndex]
        .campaigns[campaignIndex]
        .photos
        .removeAt(photoIndex));
    widget.onInvoicesChanged(_invoices);
  }

  void _calculateWorkingDays(CampaignData campaign) {
    if (campaign.startDate.isEmpty || campaign.endDate.isEmpty) return;
    try {
      final startParts = campaign.startDate.split('-');
      final endParts = campaign.endDate.split('-');
      if (startParts.length == 3 && endParts.length == 3) {
        final start = DateTime(int.parse(startParts[2]),
            int.parse(startParts[1]), int.parse(startParts[0]));
        final end = DateTime(int.parse(endParts[2]), int.parse(endParts[1]),
            int.parse(endParts[0]));
        int days = 0;
        for (var d = start;
            !d.isAfter(end);
            d = d.add(const Duration(days: 1))) {
          if (d.weekday != DateTime.saturday && d.weekday != DateTime.sunday)
            days++;
        }
        setState(() => campaign.workingDays = days.toString());
        widget.onInvoicesChanged(_invoices);
      }
    } catch (e) {
      debugPrint('Error calculating working days: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.receipt_long,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text('Invoices (${_invoices.length})',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _addInvoice,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Invoice'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Invoice list
        ...List.generate(
            _invoices.length,
            (i) =>
                _buildInvoiceCard(_invoices[i], i, _expandedInvoiceIndex == i)),
      ],
    );
  }

  Widget _buildInvoiceCard(InvoiceData invoice, int index, bool isExpanded) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isExpanded ? AppColors.primary : AppColors.border,
            width: isExpanded ? 2 : 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () =>
                setState(() => _expandedInvoiceIndex = isExpanded ? -1 : index),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: invoice.file != null
                          ? AppColors.approvedBackground
                          : AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: invoice.file != null
                          ? const Icon(Icons.check,
                              color: AppColors.approvedText, size: 18)
                          : Text('${index + 1}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invoice.invoiceNumber.isNotEmpty
                              ? 'Invoice #${invoice.invoiceNumber}'
                              : 'Invoice ${index + 1}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        if (invoice.file != null)
                          Text(invoice.file!.name,
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary),
                              overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Text(
                    '${invoice.campaigns.length} campaign${invoice.campaigns.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  if (_invoices.length > 1)
                    IconButton(
                        onPressed: () => _removeInvoice(index),
                        icon: const Icon(Icons.delete_outline,
                            color: AppColors.rejectedText, size: 20)),
                  Icon(isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.textSecondary),
                ],
              ),
            ),
          ),

          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInvoiceFileUpload(invoice, index),
                  const SizedBox(height: 16),
                  _buildInvoiceFields(invoice),
                  const SizedBox(height: 20),
                  _buildCampaignsSection(invoice, index),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInvoiceFileUpload(InvoiceData invoice, int index) {
    if (invoice.file == null) {
      return InkWell(
        onTap: () => _pickInvoiceFile(index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(8),
            color: AppColors.primary.withOpacity(0.02),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_upload_outlined,
                  color: AppColors.primary.withOpacity(0.6)),
              const SizedBox(width: 8),
              const Text('Click to upload Invoice (PDF)',
                  style: TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppColors.approvedBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.approvedBorder)),
      child: Row(
        children: [
          const Icon(Icons.check_circle,
              color: AppColors.approvedText, size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Text(invoice.file!.name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis)),
          IconButton(
            onPressed: () {
              setState(() => invoice.file = null);
              widget.onInvoicesChanged(_invoices);
            },
            icon: const Icon(Icons.close, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceFields(InvoiceData invoice) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildField('Invoice No.', invoice.invoiceNumber, (v) {
          invoice.invoiceNumber = v;
          widget.onInvoicesChanged(_invoices);
        }),
        _buildField('Invoice Date', invoice.invoiceDate, (v) {
          invoice.invoiceDate = v;
          widget.onInvoicesChanged(_invoices);
        }, hint: 'dd-mm-yyyy'),
        _buildField('Amount (₹)', invoice.totalAmount, (v) {
          invoice.totalAmount = v;
          widget.onInvoicesChanged(_invoices);
        }),
        _buildField('GST Number', invoice.gstNumber, (v) {
          invoice.gstNumber = v;
          widget.onInvoicesChanged(_invoices);
        }),
      ],
    );
  }

  Widget _buildField(String label, String value, Function(String) onChanged,
      {String? hint, double width = 180, bool readOnly = false}) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: TextEditingController(text: value),
        onChanged: onChanged,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
          filled: readOnly,
          fillColor: readOnly ? Colors.grey.shade100 : null,
        ),
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  Widget _buildCampaignsSection(InvoiceData invoice, int invoiceIndex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Campaigns',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary)),
            TextButton.icon(
              onPressed: () => _addCampaign(invoiceIndex),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Campaign'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(invoice.campaigns.length,
            (i) => _buildCampaignCard(invoice.campaigns[i], invoiceIndex, i)),
      ],
    );
  }

  Widget _buildCampaignCard(
      CampaignData campaign, int invoiceIndex, int campaignIndex) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Campaign header
          Row(
            children: [
              const Icon(Icons.campaign, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  campaign.campaignName.isNotEmpty
                      ? campaign.campaignName
                      : 'Campaign ${campaignIndex + 1}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              if (_invoices[invoiceIndex].campaigns.length > 1)
                IconButton(
                  onPressed: () => _removeCampaign(invoiceIndex, campaignIndex),
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.rejectedText, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Activity Duration Section
          _buildSectionCard(
            'Activity Duration',
            Icons.date_range,
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildDateField('Start Date', campaign.startDate,
                          (v) {
                        campaign.startDate = v;
                        _calculateWorkingDays(campaign);
                      }),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDateField('End Date', campaign.endDate, (v) {
                        campaign.endDate = v;
                        _calculateWorkingDays(campaign);
                      }),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: TextEditingController(
                            text: campaign.workingDays.isNotEmpty
                                ? campaign.workingDays
                                : 'Auto-calculated'),
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Working Days',
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.grey.shade100,
                        ),
                        style: TextStyle(
                            fontSize: 14,
                            color: campaign.workingDays.isEmpty
                                ? AppColors.textSecondary
                                : AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Dealership Details Section
          _buildSectionCard(
            'Dealership Details',
            Icons.store,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller:
                      TextEditingController(text: campaign.dealershipName),
                  onChanged: (v) {
                    campaign.dealershipName = v;
                    widget.onInvoicesChanged(_invoices);
                  },
                  decoration: const InputDecoration(
                    labelText: 'Dealership/Dealer Name',
                    hintText: 'Enter dealership name',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller:
                      TextEditingController(text: campaign.dealershipAddress),
                  onChanged: (v) {
                    campaign.dealershipAddress = v;
                    widget.onInvoicesChanged(_invoices);
                  },
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Full Address',
                    hintText: 'Full address...',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller:
                            TextEditingController(text: campaign.gpsLocation),
                        onChanged: (v) {
                          campaign.gpsLocation = v;
                          widget.onInvoicesChanged(_invoices);
                        },
                        decoration: const InputDecoration(
                          labelText: 'GPS Location',
                          hintText: 'Click to capture location',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          isDense: true,
                          suffixIcon: Icon(Icons.location_on,
                              color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Capture GPS - for now just show a placeholder
                        setState(() =>
                            campaign.gpsLocation = '28.6139° N, 77.2090° E');
                        widget.onInvoicesChanged(_invoices);
                      },
                      icon: const Icon(Icons.gps_fixed, size: 16),
                      label: const Text('Capture GPS'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Team Photos Section
          _buildSectionCard(
            'Team Photos',
            Icons.photo_library,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (campaign.photos.isEmpty)
                  InkWell(
                    onTap: () => _pickPhotos(invoiceIndex, campaignIndex),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: AppColors.primary.withOpacity(0.3),
                            style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(8),
                        color: AppColors.primary.withOpacity(0.02),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.add_a_photo,
                              size: 32,
                              color: AppColors.primary.withOpacity(0.6)),
                          const SizedBox(height: 8),
                          const Text('Upload team photos',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          const Text('PNG, JPG, JPEG only (max. 10MB)',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            List.generate(campaign.photos.length, (photoIndex) {
                          final photo = campaign.photos[photoIndex];
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.approvedBackground,
                              borderRadius: BorderRadius.circular(6),
                              border:
                                  Border.all(color: AppColors.approvedBorder),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.image,
                                    size: 16, color: AppColors.approvedText),
                                const SizedBox(width: 6),
                                Text(
                                  photo.name.length > 20
                                      ? '${photo.name.substring(0, 20)}...'
                                      : photo.name,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () => _removePhoto(
                                      invoiceIndex, campaignIndex, photoIndex),
                                  child: const Icon(Icons.close,
                                      size: 14, color: AppColors.rejectedText),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () =>
                            _pickPhotos(invoiceIndex, campaignIndex),
                        icon: const Icon(Icons.add_photo_alternate, size: 16),
                        label: const Text('Add More Photos'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Cost Summary Section
          _buildSectionCard(
            'Cost Summary',
            Icons.receipt,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Upload itemized costs with quantities, rates, and totals (Excel/PDF)',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                if (campaign.costSummaryFile == null)
                  InkWell(
                    onTap: () =>
                        _pickCostSummaryFile(invoiceIndex, campaignIndex),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: AppColors.primary.withOpacity(0.3),
                            style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(8),
                        color: AppColors.primary.withOpacity(0.02),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.cloud_upload_outlined,
                              size: 28,
                              color: AppColors.primary.withOpacity(0.6)),
                          const SizedBox(height: 8),
                          const Text('Click to upload',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.approvedBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.approvedBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: AppColors.approvedText, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(campaign.costSummaryFile!.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis)),
                        IconButton(
                          onPressed: () {
                            setState(() => campaign.costSummaryFile = null);
                            widget.onInvoicesChanged(_invoices);
                          },
                          icon: const Icon(Icons.close, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, IconData icon, Widget content) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  Widget _buildDateField(
      String label, String value, Function(String) onChanged) {
    return TextField(
      controller: TextEditingController(text: value),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: 'dd-mm-yyyy',
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
        suffixIcon: const Icon(Icons.calendar_today, size: 18),
      ),
      style: const TextStyle(fontSize: 14),
    );
  }
}
