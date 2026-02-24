import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api_config.dart';
import '../core/network/api_client.dart';

class OrderHistoryState {
  final List<Map<String, dynamic>> activities;
  final bool isLoading;
  final String? error;

  const OrderHistoryState({
    this.activities = const [],
    this.isLoading = false,
    this.error,
  });

  OrderHistoryState copyWith({List<Map<String, dynamic>>? activities, bool? isLoading, String? error}) {
    return OrderHistoryState(
      activities: activities ?? this.activities,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class OrderHistoryNotifier extends StateNotifier<OrderHistoryState> {
  final ApiClient _api;

  OrderHistoryNotifier(this._api) : super(const OrderHistoryState());

  Future<void> loadActivities({String? date, String? action}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final params = <String, dynamic>{};
      if (date != null) params['date'] = date;
      if (action != null && action.isNotEmpty) params['action'] = action;
      final res = await _api.get(ApiConfig.orderActivities, queryParameters: params);
      final data = res.data is Map ? res.data['data'] : res.data;
      state = state.copyWith(activities: List<Map<String, dynamic>>.from(data ?? []), isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final orderHistoryProvider = StateNotifierProvider<OrderHistoryNotifier, OrderHistoryState>((ref) {
  return OrderHistoryNotifier(ref.watch(apiClientProvider));
});
