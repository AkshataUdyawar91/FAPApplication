import '../../../../core/utils/either.dart';
import '../../../../core/error/failures.dart';
import '../repositories/approval_repository.dart';

class RejectPackageUseCase {
  final ApprovalRepository repository;

  const RejectPackageUseCase(this.repository);

  Future<Either<Failure, void>> call(String packageId, String reason) {
    return repository.rejectPackage(packageId, reason);
  }
}
