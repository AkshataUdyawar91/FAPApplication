import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/kpi_dashboard.dart';
import '../../domain/entities/state_roi.dart';
import '../../domain/entities/campaign_breakdown.dart';
import '../../domain/usecases/get_kpis_usecase.dart';
import '../../domain/usecases/get_state_roi_usecase.dart';
import '../../domain/usecases/get_campaign_breakdown_usecase.dart';
import '../../domain/usecases/export_analytics_usecase.dart';

class AnalyticsState extends Equatable {
  final bool isLoading;
  final String? error;
  final KPIDashboard? kpiDashboard;
  final List<StateROI> stateROI;
  final List<CampaignBreakdown> campaignBreakdown;
  final bool exportSuccess;

  const AnalyticsState({
    this.isLoading = false,
    this.error,
    this.kpiDashboard,
    this.stateROI = const [],
    this.campaignBreakdown = const [],
    this.exportSuccess = false,
  });

  AnalyticsState copyWith({
    bool? isLoading,
    String? error,
    KPIDashboard? kpiDashboard,
    List<StateROI>? stateROI,
    List<CampaignBreakdown>? campaignBreakdown,
    bool? exportSuccess,
  }) {
    return AnalyticsState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      kpiDashboard: kpiDashboard ?? this.kpiDashboard,
      stateROI: stateROI ?? this.stateROI,
      campaignBreakdown: campaignBreakdown ?? this.campaignBreakdown,
      exportSuccess: exportSuccess ?? this.exportSuccess,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        error,
        kpiDashboard,
        stateROI,
        campaignBreakdown,
        exportSuccess,
      ];
}

class AnalyticsNotifier extends StateNotifier<AnalyticsState> {
  final GetKPIsUseCase getKPIsUseCase;
  final GetStateROIUseCase getStateROIUseCase;
  final GetCampaignBreakdownUseCase getCampaignBreakdownUseCase;
  final ExportAnalyticsUseCase exportAnalyticsUseCase;

  AnalyticsNotifier(
    this.getKPIsUseCase,
    this.getStateROIUseCase,
    this.getCampaignBreakdownUseCase,
    this.exportAnalyticsUseCase,
  ) : super(const AnalyticsState());

  Future<void> loadAllAnalytics() async {
    state = state.copyWith(isLoading: true, error: null);

    await Future.wait([
      _loadKPIs(),
      _loadStateROI(),
      _loadCampaignBreakdown(),
    ]);

    state = state.copyWith(isLoading: false);
  }

  Future<void> _loadKPIs() async {
    final result = await getKPIsUseCase();

    result.fold(
      (failure) => state = state.copyWith(error: failure.message),
      (kpis) => state = state.copyWith(kpiDashboard: kpis),
    );
  }

  Future<void> _loadStateROI() async {
    final result = await getStateROIUseCase();

    result.fold(
      (failure) => state = state.copyWith(error: failure.message),
      (stateROI) => state = state.copyWith(stateROI: stateROI),
    );
  }

  Future<void> _loadCampaignBreakdown() async {
    final result = await getCampaignBreakdownUseCase();

    result.fold(
      (failure) => state = state.copyWith(error: failure.message),
      (campaigns) => state = state.copyWith(campaignBreakdown: campaigns),
    );
  }

  Future<void> exportToExcel() async {
    state = state.copyWith(isLoading: true, error: null, exportSuccess: false);

    final result = await exportAnalyticsUseCase();

    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        error: failure.message,
        exportSuccess: false,
      ),
      (_) => state = state.copyWith(
        isLoading: false,
        exportSuccess: true,
      ),
    );
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  void resetExportSuccess() {
    state = state.copyWith(exportSuccess: false);
  }
}
