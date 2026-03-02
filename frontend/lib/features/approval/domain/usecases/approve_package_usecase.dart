import '../../../../core/utils/either.dart';
import '../../../../core/error/failures.dart';
import '../repositories/approval_repository.dart';

class ApprovePackageUseCase {
  final ApprovalRepository repository;

  const ApprovePackageUseCase(this.repository);

  Future<Either<Failure, void>> call(String packageId) {
    return repository.approvePackage(packageId);
  }
}
