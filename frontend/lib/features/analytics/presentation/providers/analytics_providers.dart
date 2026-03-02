import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../../data/datasources/analytics_remote_datasource.dart';
import '../../data/repositories/analytics_repository_impl.dart';
import '../../domain/repositories/analytics_repository.dart';
import '../../domain/usecases/get_kpis_usecase.dart';
import '../../domain/usecases/get_state_roi_usecase.dart';
import '../../domain/usecases/get_campaign_breakdown_usecase.dart';
import '../../domain/usecases/export_analytics_usecase.dart';
import 'analytics_notifier.dart';

final analyticsRemoteDataSourceProvider = Provider<AnalyticsRemoteDataSource>(
  (ref) => AnalyticsRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final analyticsRepositoryProvider = Provider<AnalyticsRepository>(
  (ref) => AnalyticsRepositoryImpl(ref.watch(analyticsRemoteDataSourceProvider)),
);

final getKPIsUseCaseProvider = Provider<GetKPIsUseCase>(
  (ref) => GetKPIsUseCase(ref.watch(analyticsRepositoryProvider)),
);

final getStateROIUseCaseProvider = Provider<GetStateROIUseCase>(
  (ref) => GetStateROIUseCase(ref.watch(analyticsRepositoryProvider)),
);

final getCampaignBreakdownUseCaseProvider =
    Provider<GetCampaignBreakdownUseCase>(
  (ref) => GetCampaignBreakdownUseCase(ref.watch(analyticsRepositoryProvider)),
);

final exportAnalyticsUseCaseProvider = Provider<ExportAnalyticsUseCase>(
  (ref) => ExportAnalyticsUseCase(ref.watch(analyticsRepositoryProvider)),
);

final analyticsNotifierProvider =
    StateNotifierProvider<AnalyticsNotifier, AnalyticsState>(
  (ref) => AnalyticsNotifier(
    ref.watch(getKPIsUseCaseProvider),
    ref.watch(getStateROIUseCaseProvider),
    ref.watch(getCampaignBreakdownUseCaseProvider),
    ref.watch(exportAnalyticsUseCaseProvider),
  ),
);
