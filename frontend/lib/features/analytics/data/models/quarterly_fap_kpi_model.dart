/// Model for quarterly FAP (Final Approved Payment) KPI data
class QuarterlyFapKpiModel {
  final String quarter;
  final int year;
  final double fapAmount;
  final int fapCount;

  const QuarterlyFapKpiModel({
    required this.quarter,
    required this.year,
    required this.fapAmount,
    required this.fapCount,
  });

  factory QuarterlyFapKpiModel.fromJson(Map<String, dynamic> json) {
    return QuarterlyFapKpiModel(
      quarter: json['quarter'] as String,
      year: json['year'] as int,
      fapAmount: (json['fapAmount'] as num).toDouble(),
      fapCount: json['fapCount'] as int,
    );
  }
}
