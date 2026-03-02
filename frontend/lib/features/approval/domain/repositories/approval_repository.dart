import '../../../../core/utils/either.dart';
import '../../../../core/error/failures.dart';
import '../../../submission/domain/entities/document_package.dart';

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
}
