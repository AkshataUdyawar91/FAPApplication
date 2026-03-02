import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/document_package.dart';
import '../repositories/document_repository.dart';

/// Use case for getting submissions
class GetSubmissionsUseCase {
  final DocumentRepository repository;

  const GetSubmissionsUseCase(this.repository);

  Future<Either<Failure, List<DocumentPackage>>> call({
    String? state,
    int page = 1,
    int pageSize = 20,
  }) async {
    return await repository.getSubmissions(
      state: state,
      page: page,
      pageSize: pageSize,
    );
  }
}
