import 'package:equatable/equatable.dart';

/// A purchase order result from search/filter queries.
class POSearchResult extends Equatable {
  final String id;
  final String poNumber;
  final DateTime poDate;
  final String vendorName;
  final double totalAmount;
  final double remainingBalance;
  final String poStatus;

  const POSearchResult({
    required this.id,
    required this.poNumber,
    required this.poDate,
    required this.vendorName,
    required this.totalAmount,
    required this.remainingBalance,
    required this.poStatus,
  });

  @override
  List<Object?> get props => [
        id,
        poNumber,
        poDate,
        vendorName,
        totalAmount,
        remainingBalance,
        poStatus,
      ];
}
