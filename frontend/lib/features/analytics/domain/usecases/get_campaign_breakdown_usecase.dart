import '../../../../core/utils/either.dart';
import '../../../../core/error/failures.dart';
import '../entities/campaign_breakdown.dart';
import '../repositories/analytics_repository.dart';

class GetCampaignBreakdownUseCase {
  final AnalyticsRepository repository;

  const GetCampaignBreakdownUseCase(this.repository);

  Future<Either<Failure, List<CampaignBreakdown>>> call() {
    return repository.getCampaignBreakdown();
  }
}
