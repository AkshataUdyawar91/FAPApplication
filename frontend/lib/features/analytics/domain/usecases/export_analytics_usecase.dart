import '../../../../core/utils/either.dart';
import '../../../../core/error/failures.dart';
import '../repositories/analytics_repository.dart';

class ExportAnalyticsUseCase {
  final AnalyticsRepository repository;

  const ExportAnalyticsUseCase(this.repository);

  Future<Either<Failure, String>> call() {
    return repository.exportAnalytics();
  }
}
