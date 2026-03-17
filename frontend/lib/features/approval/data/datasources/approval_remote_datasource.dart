import 'package:dio/dio.dart';
import '../../../submission/data/models/document_package_model.dart';
import '../models/enhanced_validation_report_model.dart';

abstract class ApprovalRemoteDataSource {
  Future<DocumentPackageModel> getPackageDetails(String packageId);
  Future<EnhancedValidationReportModel> getValidationReport(String packageId);
  Future<void> approvePackage(String packageId);
  Future<void> rejectPackage(String packageId, String reason);
  Future<void> requestReupload(
    String packageId,
    List<String> fields,
    String reason,
  );
  Future<List<DocumentPackageModel>> getPendingPackages();
}

class ApprovalRemoteDataSourceImpl implements ApprovalRemoteDataSource {
  final Dio dio;

  const ApprovalRemoteDataSourceImpl(this.dio);

  @override
  Future<DocumentPackageModel> getPackageDetails(String packageId) async {
    final response = await dio.get('/submissions/$packageId');
    return DocumentPackageModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<EnhancedValidationReportModel> getValidationReport(
      String packageId,) async {
    final response =
        await dio.get('/submissions/$packageId/validation-report');
    return EnhancedValidationReportModel.fromJson(
        response.data as Map<String, dynamic>,);
  }

  @override
  Future<void> approvePackage(String packageId) async {
    await dio.patch('/submissions/$packageId/approve');
  }

  @override
  Future<void> rejectPackage(String packageId, String reason) async {
    await dio.patch(
      '/submissions/$packageId/reject',
      data: {'reason': reason},
    );
  }

  @override
  Future<void> requestReupload(
    String packageId,
    List<String> fields,
    String reason,
  ) async {
    await dio.patch(
      '/submissions/$packageId/request-reupload',
      data: {
        'fields': fields,
        'reason': reason,
      },
    );
  }

  @override
  Future<List<DocumentPackageModel>> getPendingPackages() async {
    final response = await dio.get(
      '/submissions',
      queryParameters: {'state': 'PENDING_APPROVAL'},
    );
    final data = response.data as List<dynamic>;
    return data
        .map((e) => DocumentPackageModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
