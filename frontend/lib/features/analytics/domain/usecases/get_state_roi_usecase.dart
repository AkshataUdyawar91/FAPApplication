import '../../../../core/utils/either.dart';
import '../../../../core/error/failures.dart';
import '../entities/state_roi.dart';
import '../repositories/analytics_repository.dart';

class GetStateROIUseCase {
  final AnalyticsRepository repository;

  const GetStateROIUseCase(this.repository);

  Future<Either<Failure, List<StateROI>>> call() {
    return repository.getStateROI();
  }
}
