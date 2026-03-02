import '../../../../core/utils/either.dart';
import '../../../../core/error/failures.dart';
import '../entities/kpi_dashboard.dart';
import '../entities/state_roi.dart';
import '../entities/campaign_breakdown.dart';

abstract class AnalyticsRepository {
  Future<Either<Failure, KPIDashboard>> getKPIs();
  Future<Either<Failure, List<StateROI>>> getStateROI();
  Future<Either<Failure, List<CampaignBreakdown>>> getCampaignBreakdown();
  Future<Either<Failure, String>> exportAnalytics();
}
