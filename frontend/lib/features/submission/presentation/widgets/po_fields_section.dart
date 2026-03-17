import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';

class POFieldsSection extends StatefulWidget {
  final Map<String, dynamic>? poData;
  final Function(Map<String, String>) onFieldsChanged;

  const POFieldsSection({
    super.key,
    this.poData,
    required this.onFieldsChanged,
  });

  @override
  State<POFieldsSection> createState() => _POFieldsSectionState();
}

class _POFieldsSectionState extends State<POFieldsSection> {
  final _poNumberController = TextEditingController();
  final _poAmountController = TextEditingController();
  final _poDateController = TextEditingController();
  final _vendorNameController = TextEditingController();

  final Map<String, bool> _manuallyEdited = {
    'poNumber': false,
    'poAmount': false,
    'poDate': false,
    'vendorName': false,
  };

  @override
  void initState() {
    super.initState();
    _populateFields();
    
    // Add listeners to track manual edits
    _poNumberController.addListener(() => _onFieldChanged('poNumber'));
    _poAmountController.addListener(() => _onFieldChanged('poAmount'));
    _poDateController.addListener(() => _onFieldChanged('poDate'));
    _vendorNameController.addListener(() => _onFieldChanged('vendorName'));
  }

  @override
  void didUpdateWidget(POFieldsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.poData != oldWidget.poData) {
      _populateFields();
    }
  }

  void _populateFields() {
    if (widget.poData == null) return;

    print('POFieldsSection: Populating fields with data: ${widget.poData}');

    // Only populate if not manually edited
    if (!_manuallyEdited['poNumber']! && widget.poData!['poNumber'] != null) {
      _poNumberController.text = widget.poData!['poNumber'].toString();
      print('POFieldsSection: Set poNumber to ${_poNumberController.text}');
    }
    if (!_manuallyEdited['poAmount']! && widget.poData!['totalAmount'] != null) {
      final amountStr = widget.poData!['totalAmount'].toString();
      final amount = double.tryParse(amountStr);
      if (amount != null) {
        _poAmountController.text = _formatCurrency(amount);
        print('POFieldsSection: Set poAmount to ${_poAmountController.text}');
      }
    }
    if (!_manuallyEdited['poDate']! && widget.poData!['date'] != null) {
      final dateStr = widget.poData!['date'].toString();
      // Try parsing ISO 8601 format first (from backend)
      DateTime? date = DateTime.tryParse(dateStr);
      if (date != null) {
        _poDateController.text = _formatDate(date);
        print('POFieldsSection: Set poDate to ${_poDateController.text}');
      }
    }
    if (!_manuallyEdited['vendorName']! && widget.poData!['vendorName'] != null) {
      _vendorNameController.text = widget.poData!['vendorName'].toString();
      print('POFieldsSection: Set vendorName to ${_vendorNameController.text}');
    }
  }

  void _onFieldChanged(String fieldName) {
    _manuallyEdited[fieldName] = true;
    _notifyParent();
  }

  void _notifyParent() {
    widget.onFieldsChanged({
      'poNumber': _poNumberController.text,
      'poAmount': _poAmountController.text,
      'poDate': _poDateController.text,
      'vendorName': _vendorNameController.text,
    });
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      symbol: '₹ ',
      decimalDigits: 2,
      locale: 'en_IN',
    );
    return formatter.format(amount);
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd-MM-yyyy').format(date);
  }

  @override
  void dispose() {
    _poNumberController.dispose();
    _poAmountController.dispose();
    _poDateController.dispose();
    _vendorNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 600;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: isDesktop ? _buildGridLayout() : _buildStackLayout(),
      ),
    );
  }

  Widget _buildGridLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _poNumberController,
                label: 'PO Number',
                placeholder: 'Enter PO number',
                icon: Icons.numbers,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                controller: _poAmountController,
                label: 'PO Amount (₹)',
                placeholder: 'Enter amount',
                icon: Icons.currency_rupee,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildDateField(
                controller: _poDateController,
                label: 'PO Date',
                placeholder: 'dd-mm-yyyy',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                controller: _vendorNameController,
                label: 'Vendor Name',
                placeholder: 'Enter vendor name',
                icon: Icons.business,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStackLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          controller: _poNumberController,
          label: 'PO Number',
          placeholder: 'Enter PO number',
          icon: Icons.numbers,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _poAmountController,
          label: 'PO Amount (₹)',
          placeholder: 'Enter amount',
          icon: Icons.currency_rupee,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        _buildDateField(
          controller: _poDateController,
          label: 'PO Date',
          placeholder: 'dd-mm-yyyy',
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _vendorNameController,
          label: 'Vendor Name',
          placeholder: 'Enter vendor name',
          icon: Icons.business,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String placeholder,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
            prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    required String placeholder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: true,
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
            prefixIcon: const Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
            suffixIcon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          style: const TextStyle(fontSize: 16),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: AppColors.primary,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (date != null) {
              controller.text = _formatDate(date);
              _onFieldChanged('poDate');
            }
          },
        ),
      ],
    );
  }
}
