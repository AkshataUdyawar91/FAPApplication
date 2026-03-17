import '../../domain/entities/po_search_result.dart';

/// Data model for POSearchResult with JSON serialization.
class POSearchResultModel extends POSearchResult {
  const POSearchResultModel({
    required super.id,
    required super.poNumber,
    required super.poDate,
    required super.vendorName,
    required super.totalAmount,
    required super.remainingBalance,
    required super.poStatus,
  });

  factory POSearchResultModel.fromJson(Map<String, dynamic> json) {
    return POSearchResultModel(
      id: json['id'] as String,
      poNumber: json['poNumber'] as String,
      poDate: DateTime.parse(json['poDate'] as String),
      vendorName: json['vendorName'] as String,
      totalAmount: (json['totalAmount'] as num).toDouble(),
      remainingBalance: (json['remainingBalance'] as num?)?.toDouble() ?? 0.0,
      poStatus: json['poStatus'] as String? ?? 'Unknown',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'poNumber': poNumber,
      'poDate': poDate.toIso8601String(),
      'vendorName': vendorName,
      'totalAmount': totalAmount,
      'remainingBalance': remainingBalance,
      'poStatus': poStatus,
    };
  }
}
