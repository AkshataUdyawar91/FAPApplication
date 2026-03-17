import 'package:equatable/equatable.dart';

/// A dealer result from state-based dealer typeahead search.
class DealerResult extends Equatable {
  final String dealerCode;
  final String dealerName;
  final String? city;
  final String state;

  const DealerResult({
    required this.dealerCode,
    required this.dealerName,
    this.city,
    required this.state,
  });

  @override
  List<Object?> get props => [dealerCode, dealerName, city, state];
}
