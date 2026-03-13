import '../../domain/entities/dealer_result.dart';

/// Data model for DealerResult with JSON serialization.
class DealerResultModel extends DealerResult {
  const DealerResultModel({
    required super.dealerCode,
    required super.dealerName,
    super.city,
    required super.state,
  });

  factory DealerResultModel.fromJson(Map<String, dynamic> json) {
    return DealerResultModel(
      dealerCode: json['dealerCode'] as String,
      dealerName: json['dealerName'] as String,
      city: json['city'] as String?,
      state: json['state'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dealerCode': dealerCode,
      'dealerName': dealerName,
      if (city != null) 'city': city,
      'state': state,
    };
  }
}
