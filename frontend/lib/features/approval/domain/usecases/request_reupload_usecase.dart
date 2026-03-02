import '../../../../core/utils/either.dart';
import '../../../../core/error/failures.dart';
import '../repositories/approval_repository.dart';

class RequestReuploadUseCase {
  final ApprovalRepository repository;

  const RequestReuploadUseCase(this.repository);

  Future<Either<Failure, void>> call(
    String packageId,
    List<String> fields,
    String reason,
  ) {
    return repository.requestReupload(packageId, fields, reason);
  }
}
