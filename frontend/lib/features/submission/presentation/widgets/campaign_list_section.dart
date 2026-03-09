import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';

/// Data class for an invoice (child of campaign)
class InvoiceItemData {
  final String id;
  PlatformFile? file;
  String invoiceNumber;
  String invoiceDate;
  String totalAmount;
  String gstNumber;

  InvoiceItemData({
    required this.id,
    this.file,
    this.invoiceNumber = '',
    this.invoiceDate = '',
    this.totalAmount = '',
    this.gstNumber = '',
  });
}

/// Data class for a campaign (parent of invoices)
class CampaignItemData {
  final String id;
  String campaignName;
  String startDate;
  String endDate;
  String workingDays;
  String dealershipName;
  String dealershipAddress;
  PlatformFile? costSummaryFile;
  PlatformFile? activitySummaryFile;
  List<PlatformFile> photos;
  List<InvoiceItemData> invoices;

  CampaignItemData({
    required this.id,
    this.campaignName = '',
    this.startDate = '',
    this.endDate = '',
    this.workingDays = '',
    this.dealershipName = '',
    this.dealershipAddress = '',
    this.costSummaryFile,
    this.activitySummaryFile,
    List<PlatformFile>? photos,
    List<InvoiceItemData>? invoices,
  }) : photos = photos ?? [],
       invoices = invoices ?? [InvoiceItemData(id: '${id}_invoice_1')];

  static const int maxPhotos = 50;
}

/// Widget for managing campaigns with invoices, photos, and documents
class CampaignListSection extends StatefulWidget {
  final List<CampaignItemData> campaigns;
  final Function(List<CampaignItemData>) onCampaignsChanged;

  const CampaignListSection({
    super.key,
    required this.campaigns,
    required this.onCampaignsChanged,
  });

  @override
  State<CampaignListSection> createState() => _CampaignListSectionState();
}

class _CampaignListSectionState extends State<CampaignListSection> {
  late List<CampaignItemData> _campaigns;
  int _expandedCampaignIndex = 0;

  @override
  void initState() {
    super.initState();
    _campaigns = widget.campaigns.isEmpty 
        ? [CampaignItemData(id: 'campaign_1')]
        : widget.campaigns;
  }

  void _addCampaign() {
    setState(() {
      _campaigns.add(CampaignItemData(id: 'campaign_${_campaigns.length + 1}'));
      _expandedCampaignIndex = _campaigns.length - 1;
    });
    widget.onCampaignsChanged(_campaigns);
  }

  void _removeCampaign(int index) {
    if (_campaigns.length > 1) {
      setState(() {
        _campaigns.removeAt(index);
        if (_expandedCampaignIndex >= _campaigns.length) {
          _expandedCampaignIndex = _campaigns.length - 1;
        }
      });
      widget.onCampaignsChanged(_campaigns);
    }
  }

  void _addInvoice(int campaignIndex) {
    setState(() {
      final campaign = _campaigns[campaignIndex];
      campaign.invoices.add(InvoiceItemData(
        id: '${campaign.id}_invoice_${campaign.invoices.length + 1}',
      ));
    });
    widget.onCampaignsChanged(_campaigns);
  }

  void _removeInvoice(int campaignIndex, int invoiceIndex) {
    if (_campaigns[campaignIndex].invoices.length > 1) {
      setState(() {
        _campaigns[campaignIndex].invoices.removeAt(invoiceIndex);
      });
      widget.onCampaignsChanged(_campaigns);
    }
  }


  Future<void> _pickInvoiceFile(int campaignIndex, int invoiceIndex) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() => _campaigns[campaignIndex].invoices[invoiceIndex].file = result.files.first);
        widget.onCampaignsChanged(_campaigns);
      }
    } catch (e) {
      debugPrint('Error picking invoice file: $e');
    }
  }

  Future<void> _pickCostSummaryFile(int campaignIndex) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'xlsx', 'xls'],
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() => _campaigns[campaignIndex].costSummaryFile = result.files.first);
        widget.onCampaignsChanged(_campaigns);
      }
    } catch (e) {
      debugPrint('Error picking cost summary file: $e');
    }
  }

  Future<void> _pickActivitySummaryFile(int campaignIndex) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'xlsx', 'xls'],
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() => _campaigns[campaignIndex].activitySummaryFile = result.files.first);
        widget.onCampaignsChanged(_campaigns);
      }
    } catch (e) {
      debugPrint('Error picking activity summary file: $e');
    }
  }

  Future<void> _pickPhotos(int campaignIndex) async {
    final campaign = _campaigns[campaignIndex];
    final remainingSlots = CampaignItemData.maxPhotos - campaign.photos.length;
    
    if (remainingSlots <= 0) {
      _showError('Maximum ${CampaignItemData.maxPhotos} photos allowed per campaign');
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final filesToAdd = result.files.take(remainingSlots).toList();
        if (result.files.length > remainingSlots) {
          _showError('Only $remainingSlots more photos can be added. Maximum is ${CampaignItemData.maxPhotos}.');
        }
        setState(() => campaign.photos.addAll(filesToAdd));
        widget.onCampaignsChanged(_campaigns);
      }
    } catch (e) {
      debugPrint('Error picking photos: $e');
    }
  }

  void _removePhoto(int campaignIndex, int photoIndex) {
    setState(() => _campaigns[campaignIndex].photos.removeAt(photoIndex));
    widget.onCampaignsChanged(_campaigns);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.rejectedText),
    );
  }

  void _calculateWorkingDays(CampaignItemData campaign) {
    if (campaign.startDate.isEmpty || campaign.endDate.isEmpty) return;
    try {
      final startParts = campaign.startDate.split('-');
      final endParts = campaign.endDate.split('-');
      if (startParts.length == 3 && endParts.length == 3) {
        final start = DateTime(int.parse(startParts[2]), int.parse(startParts[1]), int.parse(startParts[0]));
        final end = DateTime(int.parse(endParts[2]), int.parse(endParts[1]), int.parse(endParts[0]));
        int days = 0;
        for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
          if (d.weekday != DateTime.saturday && d.weekday != DateTime.sunday) days++;
        }
        setState(() => campaign.workingDays = days.toString());
        widget.onCampaignsChanged(_campaigns);
      }
    } catch (e) {
      debugPrint('Error calculating working days: $e');
    }
  }

  Future<void> _selectDate(BuildContext context, String currentValue, Function(String) onSelected) async {
    DateTime initialDate = DateTime.now();
    if (currentValue.isNotEmpty) {
      try {
        final parts = currentValue.split('-');
        if (parts.length == 3) {
          initialDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        }
      } catch (_) {}
    }

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );
    
    if (date != null) {
      onSelected(DateFormat('dd-MM-yyyy').format(date));
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
                  child: const Icon(Icons.campaign, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text('Campaigns (${_campaigns.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _addCampaign,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Campaign'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Campaign list
        ...List.generate(_campaigns.length, (i) => _buildCampaignCard(_campaigns[i], i, _expandedCampaignIndex == i)),
      ],
    );
  }


  Widget _buildCampaignCard(CampaignItemData campaign, int index, bool isExpanded) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isExpanded ? AppColors.primary : AppColors.border, width: isExpanded ? 2 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          // Header - No numbered "Campaign 1" header, just show campaign name or generic label
          InkWell(
            onTap: () => setState(() => _expandedCampaignIndex = isExpanded ? -1 : index),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: campaign.campaignName.isNotEmpty ? AppColors.approvedBackground : AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        campaign.campaignName.isNotEmpty ? Icons.check : Icons.campaign,
                        color: campaign.campaignName.isNotEmpty ? AppColors.approvedText : AppColors.primary,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          campaign.campaignName.isNotEmpty ? campaign.campaignName : 'New Campaign',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        Text(
                          '${campaign.invoices.length} invoice${campaign.invoices.length > 1 ? 's' : ''} • ${campaign.photos.length} photo${campaign.photos.length != 1 ? 's' : ''}',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (_campaigns.length > 1)
                    IconButton(
                      onPressed: () => _removeCampaign(index),
                      icon: const Icon(Icons.delete_outline, color: AppColors.rejectedText, size: 20),
                    ),
                  Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: AppColors.textSecondary),
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
                  // Campaign Name Field (NEW - Required)
                  _buildCampaignNameField(campaign),
                  const SizedBox(height: 16),
                  // Activity Duration
                  _buildActivityDurationSection(campaign),
                  const SizedBox(height: 16),
                  // Dealership Details (GPS removed)
                  _buildDealershipSection(campaign),
                  const SizedBox(height: 16),
                  // Invoices Section (child of campaign)
                  _buildInvoicesSection(campaign, index),
                  const SizedBox(height: 16),
                  // Photos Section
                  _buildPhotosSection(campaign, index),
                  const SizedBox(height: 16),
                  // Cost Summary
                  _buildCostSummarySection(campaign, index),
                  const SizedBox(height: 16),
                  // Activity Summary
                  _buildActivitySummarySection(campaign, index),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCampaignNameField(CampaignItemData campaign) {
    return _buildSectionCard(
      'Campaign Name',
      Icons.badge,
      TextField(
        controller: TextEditingController(text: campaign.campaignName),
        onChanged: (v) {
          campaign.campaignName = v;
          widget.onCampaignsChanged(_campaigns);
        },
        decoration: const InputDecoration(
          hintText: 'Enter campaign name',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildActivityDurationSection(CampaignItemData campaign) {
    return _buildSectionCard(
      'Activity Duration',
      Icons.date_range,
      Row(
        children: [
          Expanded(child: _buildDatePickerField('Start Date', campaign.startDate, (v) {
            campaign.startDate = v;
            _calculateWorkingDays(campaign);
            widget.onCampaignsChanged(_campaigns);
          })),
          const SizedBox(width: 12),
          Expanded(child: _buildDatePickerField('End Date', campaign.endDate, (v) {
            campaign.endDate = v;
            _calculateWorkingDays(campaign);
            widget.onCampaignsChanged(_campaigns);
          })),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: TextField(
              controller: TextEditingController(text: campaign.workingDays.isNotEmpty ? '${campaign.workingDays} days' : 'Auto-calculated'),
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Working Days',
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              style: TextStyle(fontSize: 14, color: campaign.workingDays.isEmpty ? AppColors.textSecondary : AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePickerField(String label, String value, Function(String) onChanged) {
    return GestureDetector(
      onTap: () => _selectDate(context, value, onChanged),
      child: AbsorbPointer(
        child: TextField(
          controller: TextEditingController(text: value),
          decoration: InputDecoration(
            labelText: label,
            hintText: 'dd-mm-yyyy',
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
            suffixIcon: const Icon(Icons.calendar_today, size: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildDealershipSection(CampaignItemData campaign) {
    // GPS Location field and Capture GPS button REMOVED
    return _buildSectionCard(
      'Dealership Details',
      Icons.store,
      Column(
        children: [
          TextField(
            controller: TextEditingController(text: campaign.dealershipName),
            onChanged: (v) {
              campaign.dealershipName = v;
              widget.onCampaignsChanged(_campaigns);
            },
            decoration: const InputDecoration(
              labelText: 'Dealership/Dealer Name',
              hintText: 'Enter dealership name',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: TextEditingController(text: campaign.dealershipAddress),
            onChanged: (v) {
              campaign.dealershipAddress = v;
              widget.onCampaignsChanged(_campaigns);
            },
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Full Address',
              hintText: 'Full address...',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
          ),
          // GPS Location field REMOVED per Requirement 24
        ],
      ),
    );
  }


  Widget _buildInvoicesSection(CampaignItemData campaign, int campaignIndex) {
    return _buildSectionCard(
      'Invoices (${campaign.invoices.length})',
      Icons.receipt_long,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...List.generate(campaign.invoices.length, (i) => _buildInvoiceItem(campaign.invoices[i], campaignIndex, i)),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _addInvoice(campaignIndex),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Invoice'),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceItem(InvoiceItemData invoice, int campaignIndex, int invoiceIndex) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  invoice.invoiceNumber.isNotEmpty ? 'Invoice #${invoice.invoiceNumber}' : 'Invoice ${invoiceIndex + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                ),
              ),
              if (_campaigns[campaignIndex].invoices.length > 1)
                IconButton(
                  onPressed: () => _removeInvoice(campaignIndex, invoiceIndex),
                  icon: const Icon(Icons.close, size: 16, color: AppColors.rejectedText),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Invoice file upload
          if (invoice.file == null)
            InkWell(
              onTap: () => _pickInvoiceFile(campaignIndex, invoiceIndex),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_upload_outlined, color: AppColors.primary.withOpacity(0.6), size: 18),
                    const SizedBox(width: 8),
                    const Text('Upload Invoice (PDF)', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.approvedBackground,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.approvedBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.approvedText, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(invoice.file!.name, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                  InkWell(
                    onTap: () {
                      setState(() => invoice.file = null);
                      widget.onCampaignsChanged(_campaigns);
                    },
                    child: const Icon(Icons.close, size: 14),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          // Invoice fields
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSmallField('Invoice No.', invoice.invoiceNumber, (v) {
                invoice.invoiceNumber = v;
                widget.onCampaignsChanged(_campaigns);
              }),
              _buildSmallField('Date', invoice.invoiceDate, (v) {
                invoice.invoiceDate = v;
                widget.onCampaignsChanged(_campaigns);
              }, hint: 'dd-mm-yyyy'),
              _buildSmallField('Amount (₹)', invoice.totalAmount, (v) {
                invoice.totalAmount = v;
                widget.onCampaignsChanged(_campaigns);
              }),
              _buildSmallField('GST No.', invoice.gstNumber, (v) {
                invoice.gstNumber = v;
                widget.onCampaignsChanged(_campaigns);
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallField(String label, String value, Function(String) onChanged, {String? hint}) {
    return SizedBox(
      width: 140,
      child: TextField(
        controller: TextEditingController(text: value),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          isDense: true,
        ),
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _buildPhotosSection(CampaignItemData campaign, int campaignIndex) {
    final photoCount = campaign.photos.length;
    final canAddMore = photoCount < CampaignItemData.maxPhotos;
    
    return _buildSectionCard(
      'Photos ($photoCount/${CampaignItemData.maxPhotos})',
      Icons.photo_library,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (campaign.photos.isEmpty)
            InkWell(
              onTap: canAddMore ? () => _pickPhotos(campaignIndex) : null,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                  color: AppColors.primary.withOpacity(0.02),
                ),
                child: Column(
                  children: [
                    Icon(Icons.add_a_photo, size: 28, color: AppColors.primary.withOpacity(0.6)),
                    const SizedBox(height: 8),
                    const Text('Upload photos', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text('Max ${CampaignItemData.maxPhotos} photos per campaign', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(campaign.photos.length, (photoIndex) {
                    final photo = campaign.photos[photoIndex];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.approvedBackground,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.approvedBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.image, size: 14, color: AppColors.approvedText),
                          const SizedBox(width: 4),
                          Text(
                            photo.name.length > 15 ? '${photo.name.substring(0, 15)}...' : photo.name,
                            style: const TextStyle(fontSize: 11),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => _removePhoto(campaignIndex, photoIndex),
                            child: const Icon(Icons.close, size: 12, color: AppColors.rejectedText),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                if (canAddMore)
                  TextButton.icon(
                    onPressed: () => _pickPhotos(campaignIndex),
                    icon: const Icon(Icons.add_photo_alternate, size: 14),
                    label: Text('Add More (${CampaignItemData.maxPhotos - photoCount} remaining)'),
                  )
                else
                  Text(
                    'Maximum ${CampaignItemData.maxPhotos} photos reached',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCostSummarySection(CampaignItemData campaign, int campaignIndex) {
    return _buildSectionCard(
      'Cost Summary',
      Icons.receipt,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upload itemized costs with quantities, rates, and totals (Excel/PDF)',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          if (campaign.costSummaryFile == null)
            InkWell(
              onTap: () => _pickCostSummaryFile(campaignIndex),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                  color: AppColors.primary.withOpacity(0.02),
                ),
                child: Column(
                  children: [
                    Icon(Icons.cloud_upload_outlined, size: 28, color: AppColors.primary.withOpacity(0.6)),
                    const SizedBox(height: 8),
                    const Text('Click to upload', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500)),
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
                  const Icon(Icons.check_circle, color: AppColors.approvedText, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      campaign.costSummaryFile!.name,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() => campaign.costSummaryFile = null);
                      widget.onCampaignsChanged(_campaigns);
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
    );
  }

  Widget _buildActivitySummarySection(CampaignItemData campaign, int campaignIndex) {
    return _buildSectionCard(
      'Activity Summary',
      Icons.summarize,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upload activity summary document (Excel/PDF)',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          if (campaign.activitySummaryFile == null)
            InkWell(
              onTap: () => _pickActivitySummaryFile(campaignIndex),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                  color: AppColors.primary.withOpacity(0.02),
                ),
                child: Column(
                  children: [
                    Icon(Icons.cloud_upload_outlined, size: 28, color: AppColors.primary.withOpacity(0.6)),
                    const SizedBox(height: 8),
                    const Text('Click to upload', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500)),
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
                  const Icon(Icons.check_circle, color: AppColors.approvedText, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      campaign.activitySummaryFile!.name,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() => campaign.activitySummaryFile = null);
                      widget.onCampaignsChanged(_campaigns);
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
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }
}
