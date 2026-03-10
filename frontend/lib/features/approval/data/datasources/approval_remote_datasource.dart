import 'package:dio/dio.dart';
import '../../../submission/data/models/document_package_model.dart';
import '../models/approval_action_model.dart';
import '../models/approval_result_model.dart';
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
  Future<ApprovalResultModel> asmApprove(String id, String comment);
  Future<ApprovalResultModel> asmReject(String id, String comment);
  Future<ApprovalResultModel> raApprove(String id, String comment);
  Future<ApprovalResultModel> raReject(String id, String comment);
  Future<ApprovalResultModel> resubmit(String id, String comment);
  Future<List<ApprovalActionModel>> getApprovalHistory(String id);
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
      String packageId) async {
    final response =
        await dio.get('/submissions/$packageId/validation-report');
    return EnhancedValidationReportModel.fromJson(
        response.data as Map<String, dynamic>);
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

  @override
  Future<ApprovalResultModel> asmApprove(String id, String comment) async {
    final response = await dio.patch(
      '/submissions/$id/asm-approve',
      data: {'comment': comment},
    );
    return ApprovalResultModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  @override
  Future<ApprovalResultModel> asmReject(String id, String comment) async {
    final response = await dio.patch(
      '/submissions/$id/asm-reject',
      data: {'comment': comment},
    );
    return ApprovalResultModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  @override
  Future<ApprovalResultModel> raApprove(String id, String comment) async {
    final response = await dio.patch(
      '/submissions/$id/hq-approve',
      data: {'comment': comment},
    );
    return ApprovalResultModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  @override
  Future<ApprovalResultModel> raReject(String id, String comment) async {
    final response = await dio.patch(
      '/submissions/$id/hq-reject',
      data: {'comment': comment},
    );
    return ApprovalResultModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  @override
  Future<ApprovalResultModel> resubmit(String id, String comment) async {
    final response = await dio.patch(
      '/submissions/$id/resubmit',
      data: {'comment': comment},
    );
    return ApprovalResultModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  @override
  Future<List<ApprovalActionModel>> getApprovalHistory(String id) async {
    final response = await dio.get('/submissions/$id/approval-history');
    final data = response.data as List<dynamic>;
    return data
        .map(
          (e) => ApprovalActionModel.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }
}
