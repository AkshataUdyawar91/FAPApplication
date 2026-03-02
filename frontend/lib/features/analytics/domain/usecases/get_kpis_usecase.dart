import '../../../../core/utils/either.dart';
import '../../../../core/error/failures.dart';
import '../entities/kpi_dashboard.dart';
import '../repositories/analytics_repository.dart';

class GetKPIsUseCase {
  final AnalyticsRepository repository;

  const GetKPIsUseCase(this.repository);

  Future<Either<Failure, KPIDashboard>> call() {
    return repository.getKPIs();
  }
}
