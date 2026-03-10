import '../../../../core/utils/either.dart';
import '../../../../core/error/failures.dart';
import '../../../submission/domain/entities/document_package.dart';
import '../../data/models/approval_action_model.dart';
import '../../data/models/approval_result_model.dart';

abstract class ApprovalRepository {
  Future<Either<Failure, DocumentPackage>> getPackageDetails(String packageId);
  Future<Either<Failure, void>> approvePackage(String packageId);
  Future<Either<Failure, void>> rejectPackage(String packageId, String reason);
  Future<Either<Failure, void>> requestReupload(
    String packageId,
    List<String> fields,
    String reason,
  );
  Future<Either<Failure, List<DocumentPackage>>> getPendingPackages();
  Future<Either<Failure, ApprovalResultModel>> asmApprove(
    String id,
    String comment,
  );
  Future<Either<Failure, ApprovalResultModel>> asmReject(
    String id,
    String comment,
  );
  Future<Either<Failure, ApprovalResultModel>> raApprove(
    String id,
    String comment,
  );
  Future<Either<Failure, ApprovalResultModel>> raReject(
    String id,
    String comment,
  );
  Future<Either<Failure, ApprovalResultModel>> resubmit(
    String id,
    String comment,
  );
  Future<Either<Failure, List<ApprovalActionModel>>> getApprovalHistory(
    String id,
  );
}
