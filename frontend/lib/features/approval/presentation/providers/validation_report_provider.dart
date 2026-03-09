import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/approval_remote_datasource.dart';
import '../../data/models/enhanced_validation_report_model.dart';
import '../../../../core/network/dio_client.dart';

/// Provider for validation report state
final validationReportProvider = StateNotifierProvider.family<
    ValidationReportNotifier,
    AsyncValue<EnhancedValidationReportModel>,
    String>((ref, packageId) {
  final dio = ref.watch(dioProvider);
  final dataSource = ApprovalRemoteDataSourceImpl(dio);
  return ValidationReportNotifier(dataSource, packageId);
});

/// Notifier for validation report
class ValidationReportNotifier
    extends StateNotifier<AsyncValue<EnhancedValidationReportModel>> {
  final ApprovalRemoteDataSource _dataSource;
  final String _packageId;

  ValidationReportNotifier(this._dataSource, this._packageId)
      : super(const AsyncValue.loading()) {
    loadReport();
  }

  Future<void> loadReport() async {
    state = const AsyncValue.loading();
    try {
      final report = await _dataSource.getValidationReport(_packageId);
      state = AsyncValue.data(report);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> refresh() async {
    await loadReport();
  }
}
