import 'package:dio/dio.dart';
import '../models/kpi_dashboard_model.dart';
import '../models/state_roi_model.dart';
import '../models/campaign_breakdown_model.dart';
import '../models/quarterly_fap_kpi_model.dart';

abstract class AnalyticsRemoteDataSource {
  Future<KPIDashboardModel> getKPIs();
  Future<List<StateROIModel>> getStateROI();
  Future<List<CampaignBreakdownModel>> getCampaignBreakdown();
  Future<String> exportAnalytics();
  Future<QuarterlyFapKpiModel> getQuarterlyFapKpis(String quarter, int year);
}

class AnalyticsRemoteDataSourceImpl implements AnalyticsRemoteDataSource {
  final Dio dio;

  const AnalyticsRemoteDataSourceImpl(this.dio);

  @override
  Future<KPIDashboardModel> getKPIs() async {
    final response = await dio.get('/api/analytics/kpis');
    return KPIDashboardModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<StateROIModel>> getStateROI() async {
    final response = await dio.get('/api/analytics/state-roi');
    final data = response.data as List<dynamic>;
    return data
        .map((e) => StateROIModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<CampaignBreakdownModel>> getCampaignBreakdown() async {
    final response = await dio.get('/api/analytics/campaign-breakdown');
    final data = response.data as List<dynamic>;
    return data
        .map((e) => CampaignBreakdownModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<String> exportAnalytics() async {
    final response = await dio.post(
      '/api/analytics/export',
      options: Options(responseType: ResponseType.bytes),
    );
    // Return base64 encoded file data or file path
    return response.data.toString();
  }

  @override
  Future<QuarterlyFapKpiModel> getQuarterlyFapKpis(String quarter, int year) async {
    final response = await dio.get(
      '/api/analytics/quarterly-fap',
      queryParameters: {'quarter': quarter, 'year': year},
    );
    return QuarterlyFapKpiModel.fromJson(response.data as Map<String, dynamic>);
  }
}
