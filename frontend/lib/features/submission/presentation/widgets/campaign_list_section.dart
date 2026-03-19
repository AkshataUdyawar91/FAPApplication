import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';

/// Extraction status for UI feedback
enum ExtractionStatus { none, extracting, success, failed }

/// Data class for an invoice (child of campaign)
class InvoiceItemData {
  final String id;
  PlatformFile? file;
  String invoiceNumber;
  String invoiceDate;
  String totalAmount;
  String gstNumber;
  bool isExtracting;
  ExtractionStatus extractionStatus;
  String? extractionError;
  String? existingFileName;

  // Controllers so programmatic updates (extraction) reflect in the UI
  late final TextEditingController invoiceNumberController;
  late final TextEditingController invoiceDateController;
  late final TextEditingController totalAmountController;
  late final TextEditingController gstNumberController;

  InvoiceItemData({
    required this.id,
    this.file,
    this.invoiceNumber = '',
    this.invoiceDate = '',
    this.totalAmount = '',
    this.gstNumber = '',
    this.isExtracting = false,
    this.extractionStatus = ExtractionStatus.none,
    this.extractionError,
    this.existingFileName,
  }) {
    invoiceNumberController = TextEditingController(text: invoiceNumber);
    invoiceDateController = TextEditingController(text: invoiceDate);
    totalAmountController = TextEditingController(text: totalAmount);
    gstNumberController = TextEditingController(text: gstNumber);
  }

  /// Dispose controllers when this invoice is removed
  void dispose() {
    invoiceNumberController.dispose();
    invoiceDateController.dispose();
    totalAmountController.dispose();
    gstNumberController.dispose();
  }
}

/// Data class for a team/campaign
class CampaignItemData {
  final String id;
  String campaignName;   // used as "Dealer Code" in the new UI
  String startDate;
  String endDate;
  String workingDays;
  String dealershipName;
  String dealershipAddress; // used as "City" in the new UI
  PlatformFile? costSummaryFile;
  PlatformFile? activitySummaryFile;
  List<PlatformFile> photos;
  List<InvoiceItemData> invoices;
  String? existingCostSummaryFileName;
  String? existingActivitySummaryFileName;
  List<String>? existingPhotoFileNames;

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
    this.existingCostSummaryFileName,
    this.existingActivitySummaryFileName,
    this.existingPhotoFileNames,
  })  : photos = photos ?? [],
        invoices = invoices ?? [InvoiceItemData(id: '${id}_invoice_1')];

  static const int maxPhotos = 50;
}

class CampaignListSection extends StatefulWidget {
  final List<CampaignItemData> campaigns;
  final Function(List<CampaignItemData>) onCampaignsChanged;
  final String? token;
  final String? packageId;

  const CampaignListSection({
    super.key,
    required this.campaigns,
    required this.onCampaignsChanged,
    this.token,
    this.packageId,
  });

  @override
  State<CampaignListSection> createState() => _CampaignListSectionState();
}

class _CampaignListSectionState extends State<CampaignListSection> {
  late List<CampaignItemData> _campaigns;

  // Controllers keyed by "campaignId_fieldName" so they survive setState rebuilds
  final Map<String, TextEditingController> _controllers = {};

  TextEditingController _ctrl(String campaignId, String field, String initialValue) {
    final key = '${campaignId}_$field';
    if (!_controllers.containsKey(key)) {
      _controllers[key] = TextEditingController(text: initialValue);
    }
    return _controllers[key]!;
  }

  void _disposeControllersForCampaign(String campaignId) {
    final keys = _controllers.keys.where((k) => k.startsWith('${campaignId}_')).toList();
    for (final k in keys) {
      _controllers.remove(k)?.dispose();
    }
  }

  @override
  void initState() {
    super.initState();
    _campaigns = widget.campaigns.isEmpty
        ? [CampaignItemData(id: 'campaign_1')]
        : widget.campaigns;
    // Sync the default team back to the parent so validation sees it
    if (widget.campaigns.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onCampaignsChanged(_campaigns);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ─── Mutations ───────────────────────────────────────────────────────

  void _addCampaign() {
    setState(() => _campaigns.add(CampaignItemData(id: 'campaign_${_campaigns.length + 1}')));
    widget.onCampaignsChanged(_campaigns);
  }

  Future<void> _removeCampaign(int index) async {
    if (_campaigns.length <= 1) return;
    final name = _campaigns[index].dealershipName.isNotEmpty
        ? _campaigns[index].dealershipName
        : 'Team ${index + 1}';
    final confirmed = await _confirm('Delete Team', 'Delete "$name"?');
    if (!confirmed || !mounted) return;
    final removed = _campaigns[index];
    setState(() => _campaigns.removeAt(index));
    _disposeControllersForCampaign(removed.id);
    widget.onCampaignsChanged(_campaigns);
  }

  Future<void> _pickPhotos(int campaignIndex) async {
    final campaign = _campaigns[campaignIndex];
    final existing = campaign.existingPhotoFileNames?.length ?? 0;
    final remaining = CampaignItemData.maxPhotos - campaign.photos.length - existing;
    if (remaining <= 0) { _showError('Maximum ${CampaignItemData.maxPhotos} photos reached'); return; }
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
      if (result != null && result.files.isNotEmpty) {
        final toAdd = result.files.take(remaining).toList();
        setState(() => campaign.photos.addAll(toAdd));
        widget.onCampaignsChanged(_campaigns);
      }
    } catch (e) { debugPrint('Error picking photos: $e'); }
  }

  Future<void> _removePhoto(int campaignIndex, int photoIndex) async {
    final confirmed = await _confirm('Delete Photo', 'Delete "${_campaigns[campaignIndex].photos[photoIndex].name}"?');
    if (!confirmed || !mounted) return;
    setState(() => _campaigns[campaignIndex].photos.removeAt(photoIndex));
    widget.onCampaignsChanged(_campaigns);
  }

  void _calculateWorkingDays(CampaignItemData campaign) {
    if (campaign.startDate.isEmpty || campaign.endDate.isEmpty) return;
    try {
      final s = _parseDate(campaign.startDate);
      final e = _parseDate(campaign.endDate);
      if (s == null || e == null) return;
      int days = 0;
      for (var d = s; !d.isAfter(e); d = d.add(const Duration(days: 1))) {
        if (d.weekday != DateTime.saturday && d.weekday != DateTime.sunday) days++;
      }
      setState(() => campaign.workingDays = days.toString());
      widget.onCampaignsChanged(_campaigns);
    } catch (e) { debugPrint('Error calculating working days: $e'); }
  }

  DateTime? _parseDate(String value) {
    if (value.isEmpty) return null;
    try {
      final p = value.split('-');
      if (p.length == 3) return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
    } catch (_) {}
    return null;
  }

  Future<void> _selectDate(String current, Function(String) onSelected, {DateTime? minDate}) async {
    final first = minDate ?? DateTime(2020);
    DateTime initial = DateTime.now();
    final parsed = _parseDate(current);
    if (parsed != null) initial = parsed;
    if (initial.isBefore(first)) initial = first;

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (date != null) onSelected(DateFormat('dd-MM-yyyy').format(date));
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        content: Text(message, style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rejectedText, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.rejectedText));

  // ─── BUILD ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final totalPhotos = _campaigns.fold<int>(
        0, (sum, c) => sum + c.photos.length + (c.existingPhotoFileNames?.length ?? 0));
    final totalMax = _campaigns.length * CampaignItemData.maxPhotos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Teams', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                  const SizedBox(height: 2),
                  const Text('Add each team that executed the activation.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                    '${_campaigns.length} team${_campaigns.length != 1 ? 's' : ''} added — $totalPhotos / $totalMax photos uploaded',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: _addCampaign,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('+ Add Team', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...List.generate(_campaigns.length, (i) => _buildTeamCard(_campaigns[i], i)),
      ],
    );
  }

  Widget _buildTeamCard(CampaignItemData campaign, int index) {
    final photoCount = campaign.photos.length + (campaign.existingPhotoFileNames?.length ?? 0);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Team header
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  child: Center(child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    campaign.dealershipName.isNotEmpty
                        ? 'Team ${index + 1} — ${campaign.dealershipName}'
                        : 'Team ${index + 1}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                  ),
                ),
                if (campaign.dealershipAddress.isNotEmpty)
                  Text('(${campaign.dealershipAddress})', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                if (_campaigns.length > 1) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => _removeCampaign(index),
                    style: TextButton.styleFrom(foregroundColor: AppColors.rejectedText, padding: EdgeInsets.zero),
                    child: const Text('Remove', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),

            // Fields grid
            LayoutBuilder(builder: (ctx, constraints) {
              final narrow = constraints.maxWidth < 500;
              if (narrow) {
                return Column(children: [
                  _teamField('Dealership Name', campaign.id, 'dealershipName', campaign.dealershipName, (v) { campaign.dealershipName = v; widget.onCampaignsChanged(_campaigns); }, required: true),
                  const SizedBox(height: 12),
                  _teamField('Dealer Code', campaign.id, 'campaignName', campaign.campaignName, (v) { campaign.campaignName = v; widget.onCampaignsChanged(_campaigns); }, required: true),
                  const SizedBox(height: 12),
                  _teamField('City', campaign.id, 'dealershipAddress', campaign.dealershipAddress, (v) { campaign.dealershipAddress = v; widget.onCampaignsChanged(_campaigns); }, required: true),
                  const SizedBox(height: 12),
                  _teamDateField('Start Date', campaign.startDate, (v) { setState(() { campaign.startDate = v; _calculateWorkingDays(campaign); }); }, required: true),
                  const SizedBox(height: 12),
                  _teamDateField('End Date', campaign.endDate, (v) { setState(() { campaign.endDate = v; _calculateWorkingDays(campaign); }); }, required: true, minDate: _parseDate(campaign.startDate)),
                  const SizedBox(height: 12),
                  _teamReadonly('Working Days', campaign.workingDays.isNotEmpty ? campaign.workingDays : '—'),
                ]);
              }
              return Column(children: [
                Row(children: [
                  Expanded(child: _teamField('Dealership Name', campaign.id, 'dealershipName', campaign.dealershipName, (v) { campaign.dealershipName = v; widget.onCampaignsChanged(_campaigns); }, required: true)),
                  const SizedBox(width: 16),
                  Expanded(child: _teamField('Dealer Code', campaign.id, 'campaignName', campaign.campaignName, (v) { campaign.campaignName = v; widget.onCampaignsChanged(_campaigns); }, required: true)),
                  const SizedBox(width: 16),
                  Expanded(child: _teamField('City', campaign.id, 'dealershipAddress', campaign.dealershipAddress, (v) { campaign.dealershipAddress = v; widget.onCampaignsChanged(_campaigns); }, required: true)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _teamDateField('Start Date', campaign.startDate, (v) { setState(() { campaign.startDate = v; _calculateWorkingDays(campaign); }); }, required: true)),
                  const SizedBox(width: 16),
                  Expanded(child: _teamDateField('End Date', campaign.endDate, (v) { setState(() { campaign.endDate = v; _calculateWorkingDays(campaign); }); }, required: true, minDate: _parseDate(campaign.startDate))),
                  const SizedBox(width: 16),
                  Expanded(child: _teamReadonly('Working Days', campaign.workingDays.isNotEmpty ? campaign.workingDays : '—')),
                ]),
              ]);
            }),
            const SizedBox(height: 16),

            // State note
            RichText(text: const TextSpan(
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              children: [
                TextSpan(text: 'State: '),
                TextSpan(text: 'Maharashtra', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                TextSpan(text: '  (all teams share the activation state)'),
              ],
            )),
            const SizedBox(height: 16),

            // Photos
            _buildPhotosSection(campaign, index, photoCount),
          ],
        ),
      ),
    );
  }

  // ─── Field helpers ────────────────────────────────────────────────────

  Widget _teamField(String label, String campaignId, String field, String value, Function(String) onChanged, {bool required = false}) {
    final controller = _ctrl(campaignId, field, value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
          if (required) const Text(' *', style: TextStyle(color: Colors.red, fontSize: 13)),
        ]),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _teamDateField(String label, String value, Function(String) onChanged, {bool required = false, DateTime? minDate}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
          if (required) const Text(' *', style: TextStyle(color: Colors.red, fontSize: 13)),
        ]),
        const SizedBox(height: 6),
        TextFormField(
          readOnly: true,
          controller: TextEditingController(text: value),
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'dd-mm-yyyy',
            hintStyle: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
            suffixIcon: const Icon(Icons.calendar_today, color: AppColors.primary, size: 18),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
            isDense: true,
          ),
          onTap: () => _selectDate(value, onChanged, minDate: minDate),
        ),
      ],
    );
  }

  Widget _teamReadonly(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(value, style: const TextStyle(fontSize: 14, color: Color(0xFF374151))),
        ),
      ],
    );
  }

  // ─── Photos section ───────────────────────────────────────────────────

  Widget _buildPhotosSection(CampaignItemData campaign, int campaignIndex, int totalCount) {
    final max = CampaignItemData.maxPhotos;
    final canAdd = totalCount < max;
    final existingNames = campaign.existingPhotoFileNames ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Photos ($totalCount / $max)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...existingNames.map((name) => _photoTile(name, onRemove: null)),
            ...List.generate(campaign.photos.length, (i) => _photoTile(
              campaign.photos[i].name,
              onRemove: () => _removePhoto(campaignIndex, i),
            )),
            if (canAdd) _addPhotoTile(() => _pickPhotos(campaignIndex)),
          ],
        ),
      ],
    );
  }

  Widget _photoTile(String name, {required VoidCallback? onRemove}) {
    final display = name.length > 12 ? '${name.substring(0, 12)}...' : name;
    return Container(
      width: 110,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.image, size: 14, color: Color(0xFF16A34A)),
            const Spacer(),
            if (onRemove != null)
              GestureDetector(onTap: onRemove, child: const Icon(Icons.close, size: 14, color: AppColors.rejectedText)),
          ]),
          const SizedBox(height: 4),
          Text(display, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF15803D))),
          const SizedBox(height: 2),
          const Text('Uploaded', style: TextStyle(fontSize: 10, color: Color(0xFF16A34A))),
        ],
      ),
    );
  }

  Widget _addPhotoTile(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate, size: 22, color: AppColors.primary.withValues(alpha: 0.6)),
            const SizedBox(height: 4),
            const Text('+ Add Photo', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
