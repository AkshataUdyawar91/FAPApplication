import 'package:flutter/material.dart';

/// A row of two dropdowns for quarter and year filtering.
/// Defaults to current quarter and current year.
class QuarterYearFilter extends StatelessWidget {
  final String selectedQuarter;
  final int selectedYear;
  final ValueChanged<String> onQuarterChanged;
  final ValueChanged<int> onYearChanged;
  final List<int> availableYears;

  const QuarterYearFilter({
    super.key,
    required this.selectedQuarter,
    required this.selectedYear,
    required this.onQuarterChanged,
    required this.onYearChanged,
    required this.availableYears,
  });

  /// Returns the current Indian fiscal quarter string (Q1-Q4).
  /// Q1 = Apr-Jun, Q2 = Jul-Sep, Q3 = Oct-Dec, Q4 = Jan-Mar.
  static String currentQuarter() {
    final month = DateTime.now().month;
    if (month >= 4 && month <= 6) return 'Q1';
    if (month >= 7 && month <= 9) return 'Q2';
    if (month >= 10 && month <= 12) return 'Q3';
    return 'Q4';
  }

  /// Returns the fiscal year for a given date.
  /// Indian FY runs Apr-Mar: Apr 2025 → FY 2025, Jan 2026 → FY 2025.
  static int fiscalYear(DateTime date) {
    return date.month >= 4 ? date.year : date.year - 1;
  }

  /// Returns the current fiscal year.
  static int currentFiscalYear() => fiscalYear(DateTime.now());

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: DropdownButtonFormField<String>(
            initialValue: selectedQuarter,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Quarter',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: 'All', child: Text('All')),
              DropdownMenuItem(value: 'Q1', child: Text('Q1 (Apr-Jun)')),
              DropdownMenuItem(value: 'Q2', child: Text('Q2 (Jul-Sep)')),
              DropdownMenuItem(value: 'Q3', child: Text('Q3 (Oct-Dec)')),
              DropdownMenuItem(value: 'Q4', child: Text('Q4 (Jan-Mar)')),
            ],
            onChanged: (v) {
              if (v != null) onQuarterChanged(v);
            },
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 120,
          child: DropdownButtonFormField<int>(
            initialValue: selectedYear,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Year',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            items: availableYears
                .map((y) => DropdownMenuItem(value: y, child: Text('FY ${y.toString().substring(2)}-${(y + 1).toString().substring(2)}')))
                .toList(),
            onChanged: (v) {
              if (v != null) onYearChanged(v);
            },
          ),
        ),
      ],
    );
  }
}
