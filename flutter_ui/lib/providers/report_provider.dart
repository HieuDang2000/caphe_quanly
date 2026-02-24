import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../config/api_config.dart';

class ReportState {
  final Map<String, dynamic>? salesData;
  final List<Map<String, dynamic>> topItems;
  final List<Map<String, dynamic>> categoryRevenue;
  final List<Map<String, dynamic>> tableUsage;
  final Map<String, dynamic>? dailySummary;
  final bool isLoading;
  final String? error;

  const ReportState({
    this.salesData,
    this.topItems = const [],
    this.categoryRevenue = const [],
    this.tableUsage = const [],
    this.dailySummary,
    this.isLoading = false,
    this.error,
  });

  ReportState copyWith({
    Map<String, dynamic>? salesData,
    List<Map<String, dynamic>>? topItems,
    List<Map<String, dynamic>>? categoryRevenue,
    List<Map<String, dynamic>>? tableUsage,
    Map<String, dynamic>? dailySummary,
    bool? isLoading,
    String? error,
  }) {
    return ReportState(
      salesData: salesData ?? this.salesData,
      topItems: topItems ?? this.topItems,
      categoryRevenue: categoryRevenue ?? this.categoryRevenue,
      tableUsage: tableUsage ?? this.tableUsage,
      dailySummary: dailySummary ?? this.dailySummary,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ReportNotifier extends StateNotifier<ReportState> {
  final ApiClient _api;
  ReportNotifier(this._api) : super(const ReportState());

  Future<void> loadAll({String? from, String? to}) async {
    state = state.copyWith(isLoading: true);
    try {
      final params = <String, dynamic>{};
      if (from != null) params['from'] = from;
      if (to != null) params['to'] = to;

      final results = await Future.wait([
        _api.get('${ApiConfig.reports}/sales', queryParameters: params),
        _api.get('${ApiConfig.reports}/top-items', queryParameters: params),
        _api.get('${ApiConfig.reports}/category-revenue', queryParameters: params),
        _api.get('${ApiConfig.reports}/table-usage', queryParameters: params),
        _api.get('${ApiConfig.reports}/daily-summary'),
      ]);

      state = ReportState(
        salesData: Map<String, dynamic>.from(results[0].data),
        topItems: List<Map<String, dynamic>>.from(results[1].data),
        categoryRevenue: List<Map<String, dynamic>>.from(results[2].data),
        tableUsage: List<Map<String, dynamic>>.from(results[3].data),
        dailySummary: Map<String, dynamic>.from(results[4].data),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final reportProvider = StateNotifierProvider<ReportNotifier, ReportState>((ref) {
  return ReportNotifier(ref.watch(apiClientProvider));
});
