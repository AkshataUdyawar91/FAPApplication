class AgencyDto {
  final String id;
  final String supplierCode;
  final String supplierName;
  final String createdAt;

  const AgencyDto({
    required this.id,
    required this.supplierCode,
    required this.supplierName,
    required this.createdAt,
  });

  factory AgencyDto.fromJson(Map<String, dynamic> json) => AgencyDto(
        id:           json['id'] as String,
        supplierCode: json['supplierCode'] as String,
        supplierName: json['supplierName'] as String,
        createdAt:    json['createdAt'] as String,
      );
}
