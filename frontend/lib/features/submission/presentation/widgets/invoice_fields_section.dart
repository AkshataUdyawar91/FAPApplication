import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';

class InvoiceFieldsSection extends StatefulWidget {
  final Map<String, dynamic>? invoiceData;
  final String? poNumberFromPO;
  final Function(Map<String, String>) onFieldsChanged;

  const InvoiceFieldsSection({
    super.key,
    this.invoiceData,
    this.poNumberFromPO,
    required this.onFieldsChanged,
  });

  @override
  State<InvoiceFieldsSection> createState() => _InvoiceFieldsSectionState();
}

class _InvoiceFieldsSectionState extends State<InvoiceFieldsSection> {
  final _invoiceNoController = TextEditingController();
  final _invoiceDateController = TextEditingController();
  final _invoiceAmountController = TextEditingController();
  final _gstinController = TextEditingController();
  final _vendorNameController = TextEditingController();

  final Map<String, bool> _manuallyEdited = {
    'invoiceNo': false,
    'invoiceDate': false,
    'invoiceAmount': false,
    'gstin': false,
    'vendorName': false,
  };

  @override
  void initState() {
    super.initState();
    _populateFields();
    
    // Add listeners to track manual edits
    _invoiceNoController.addListener(() => _onFieldChanged('invoiceNo'));
    _invoiceDateController.addListener(() => _onFieldChanged('invoiceDate'));
    _invoiceAmountController.addListener(() => _onFieldChanged('invoiceAmount'));
    _gstinController.addListener(() => _onFieldChanged('gstin'));
    _vendorNameController.addListener(() => _onFieldChanged('vendorName'));
  }

  @override
  void didUpdateWidget(InvoiceFieldsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.invoiceData != oldWidget.invoiceData) {
      _populateFields();
    }
  }

  void _populateFields() {
    if (widget.invoiceData == null) return;

    print('InvoiceFieldsSection: Populating fields with data: ${widget.invoiceData}');

    // Only populate if not manually edited
    if (!_manuallyEdited['invoiceNo']! && widget.invoiceData!['invoiceNumber'] != null) {
      _invoiceNoController.text = widget.invoiceData!['invoiceNumber'].toString();
      print('InvoiceFieldsSection: Set invoiceNo to ${_invoiceNoController.text}');
    }
    if (!_manuallyEdited['invoiceDate']! && widget.invoiceData!['date'] != null) {
      final dateStr = widget.invoiceData!['date'].toString();
      // Try parsing ISO 8601 format first (from backend)
      DateTime? date = DateTime.tryParse(dateStr);
      if (date != null) {
        _invoiceDateController.text = _formatDate(date);
        print('InvoiceFieldsSection: Set invoiceDate to ${_invoiceDateController.text}');
      }
    }
    if (!_manuallyEdited['invoiceAmount']! && widget.invoiceData!['totalAmount'] != null) {
      final amountStr = widget.invoiceData!['totalAmount'].toString();
      final amount = double.tryParse(amountStr);
      if (amount != null) {
        _invoiceAmountController.text = _formatCurrency(amount);
        print('InvoiceFieldsSection: Set invoiceAmount to ${_invoiceAmountController.text}');
      }
    }
    if (!_manuallyEdited['gstin']! && widget.invoiceData!['gstin'] != null) {
      _gstinController.text = widget.invoiceData!['gstin'].toString();
      print('InvoiceFieldsSection: Set gstin to ${_gstinController.text}');
    }
    if (!_manuallyEdited['vendorName']! && widget.invoiceData!['vendorName'] != null) {
      _vendorNameController.text = widget.invoiceData!['vendorName'].toString();
      print('InvoiceFieldsSection: Set vendorName to ${_vendorNameController.text}');
    }
  }

  void _onFieldChanged(String fieldName) {
    _manuallyEdited[fieldName] = true;
    _notifyParent();
  }

  void _notifyParent() {
    widget.onFieldsChanged({
      'invoiceNo': _invoiceNoController.text,
      'invoiceDate': _invoiceDateController.text,
      'invoiceAmount': _invoiceAmountController.text,
      'gstin': _gstinController.text,
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
    _invoiceNoController.dispose();
    _invoiceDateController.dispose();
    _invoiceAmountController.dispose();
    _gstinController.dispose();
    _vendorNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 600;

    return Column(
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.border.withOpacity(0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: isDesktop ? _buildGridLayout() : _buildStackLayout(),
          ),
        ),
        // Show cross-validation section if both PO and Invoice data available
        if (widget.invoiceData != null && widget.poNumberFromPO != null) ...[
          const SizedBox(height: 16),
          _buildCrossValidationSection(),
        ],
      ],
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
                controller: _invoiceNoController,
                label: 'Invoice No',
                placeholder: 'Enter invoice number',
                icon: Icons.receipt,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDateField(
                controller: _invoiceDateController,
                label: 'Invoice Date',
                placeholder: 'dd-mm-yyyy',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _invoiceAmountController,
                label: 'Invoice Amount (₹)',
                placeholder: 'Enter amount',
                icon: Icons.currency_rupee,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                controller: _gstinController,
                label: 'GSTIN',
                placeholder: 'Enter GSTIN',
                icon: Icons.account_balance,
                maxLength: 15,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _vendorNameController,
          label: 'Vendor Name',
          placeholder: 'Enter vendor name',
          icon: Icons.business,
        ),
      ],
    );
  }

  Widget _buildStackLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          controller: _invoiceNoController,
          label: 'Invoice No',
          placeholder: 'Enter invoice number',
          icon: Icons.receipt,
        ),
        const SizedBox(height: 12),
        _buildDateField(
          controller: _invoiceDateController,
          label: 'Invoice Date',
          placeholder: 'dd-mm-yyyy',
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _invoiceAmountController,
          label: 'Invoice Amount (₹)',
          placeholder: 'Enter amount',
          icon: Icons.currency_rupee,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _gstinController,
          label: 'GSTIN',
          placeholder: 'Enter GSTIN',
          icon: Icons.account_balance,
          maxLength: 15,
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
    int? maxLength,
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
          maxLength: maxLength,
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
            counterText: '',
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
              _onFieldChanged('invoiceDate');
            }
          },
        ),
      ],
    );
  }

  Widget _buildCrossValidationSection() {
    final poFromInvoice = widget.invoiceData?['poReference']?.toString() ?? '';
    final poFromPODoc = widget.poNumberFromPO ?? '';
    
    final isMatch = poFromInvoice.isNotEmpty && 
                    poFromPODoc.isNotEmpty && 
                    poFromInvoice == poFromPODoc;
    
    final hasMismatch = poFromInvoice.isNotEmpty && 
                        poFromPODoc.isNotEmpty && 
                        poFromInvoice != poFromPODoc;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cross-Validation with PO Document',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 600;
                
                if (isDesktop) {
                  return Row(
                    children: [
                      Expanded(
                        child: _buildReadOnlyField(
                          'PO Number (from Invoice)',
                          poFromInvoice.isEmpty ? '-' : poFromInvoice,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildReadOnlyField(
                          'PO Number (from PO Document)',
                          poFromPODoc.isEmpty ? '-' : poFromPODoc,
                        ),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildReadOnlyField(
                        'PO Number (from Invoice)',
                        poFromInvoice.isEmpty ? '-' : poFromInvoice,
                      ),
                      const SizedBox(height: 12),
                      _buildReadOnlyField(
                        'PO Number (from PO Document)',
                        poFromPODoc.isEmpty ? '-' : poFromPODoc,
                      ),
                    ],
                  );
                }
              },
            ),
            if (isMatch || hasMismatch) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    isMatch ? Icons.check_circle : Icons.warning,
                    color: isMatch ? Colors.green : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isMatch 
                        ? 'PO numbers match' 
                        : 'PO numbers do not match. Please verify.',
                      style: TextStyle(
                        color: isMatch ? Colors.green : Colors.red,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
