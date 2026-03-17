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

  /// Returns the current calendar quarter string (Q1-Q4).
  static String currentQuarter() {
    final month = DateTime.now().month;
    if (month <= 3) return 'Q1';
    if (month <= 6) return 'Q2';
    if (month <= 9) return 'Q3';
    return 'Q4';
  }

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
              DropdownMenuItem(value: 'Q1', child: Text('Q1')),
              DropdownMenuItem(value: 'Q2', child: Text('Q2')),
              DropdownMenuItem(value: 'Q3', child: Text('Q3')),
              DropdownMenuItem(value: 'Q4', child: Text('Q4')),
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
                .map((y) => DropdownMenuItem(value: y, child: Text(y.toString())))
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
