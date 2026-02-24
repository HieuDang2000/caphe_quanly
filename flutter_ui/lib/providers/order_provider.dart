import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../core/utils/formatters.dart';
import '../config/api_config.dart';

class OrderState {
  final List<Map<String, dynamic>> orders;
  final List<Map<String, dynamic>> activeOrders;
  final Map<String, dynamic>? currentOrder;
  final List<Map<String, dynamic>> cartItems;
  final int? selectedTableId;
  final bool isLoading;
  final String? error;

  const OrderState({
    this.orders = const [],
    this.activeOrders = const [],
    this.currentOrder,
    this.cartItems = const [],
    this.selectedTableId,
    this.isLoading = false,
    this.error,
  });

  OrderState copyWith({
    List<Map<String, dynamic>>? orders,
    List<Map<String, dynamic>>? activeOrders,
    Map<String, dynamic>? currentOrder,
    List<Map<String, dynamic>>? cartItems,
    int? selectedTableId,
    bool clearSelectedTable = false,
    bool? isLoading,
    String? error,
  }) {
    return OrderState(
      orders: orders ?? this.orders,
      activeOrders: activeOrders ?? this.activeOrders,
      currentOrder: currentOrder ?? this.currentOrder,
      cartItems: cartItems ?? this.cartItems,
      selectedTableId: clearSelectedTable ? null : (selectedTableId ?? this.selectedTableId),
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  double get cartTotal => cartItems.fold(0, (sum, item) => sum + Formatters.toNum(item['price']) * (item['quantity'] as num));
}

class OrderNotifier extends StateNotifier<OrderState> {
  final ApiClient _api;
  Timer? _pollTimer;

  OrderNotifier(this._api) : super(const OrderState());

  void selectTable(int? tableId) {
    state = state.copyWith(
      selectedTableId: tableId,
      clearSelectedTable: tableId == null,
    );
  }

  void addToCart(Map<String, dynamic> menuItem, {String? notes}) {
    final existing = state.cartItems.indexWhere((i) => i['menu_item_id'] == menuItem['id']);
    if (existing >= 0) {
      final updated = List<Map<String, dynamic>>.from(state.cartItems);
      updated[existing] = {...updated[existing], 'quantity': (updated[existing]['quantity'] as int) + 1};
      state = state.copyWith(cartItems: updated);
    } else {
      state = state.copyWith(cartItems: [
        ...state.cartItems,
        {
          'menu_item_id': menuItem['id'],
          'name': menuItem['name'],
          'price': Formatters.toNum(menuItem['price']),
          'quantity': 1,
          'notes': notes,
        },
      ]);
    }
  }

  void removeFromCart(int menuItemId) {
    state = state.copyWith(cartItems: state.cartItems.where((i) => i['menu_item_id'] != menuItemId).toList());
  }

  void updateCartQuantity(int menuItemId, int quantity) {
    if (quantity <= 0) {
      removeFromCart(menuItemId);
      return;
    }
    state = state.copyWith(
      cartItems: state.cartItems.map((i) {
        if (i['menu_item_id'] == menuItemId) return {...i, 'quantity': quantity};
        return i;
      }).toList(),
    );
  }

  void clearCart() {
    state = state.copyWith(cartItems: [], selectedTableId: null);
  }

  Future<Map<String, dynamic>?> submitOrder({String? notes, int? customerId}) async {
    if (state.cartItems.isEmpty) return null;
    state = state.copyWith(isLoading: true);
    try {
      final data = {
        'table_id': state.selectedTableId,
        'customer_id': customerId,
        'notes': notes,
        'items': state.cartItems.map((i) => {
          'menu_item_id': i['menu_item_id'],
          'quantity': i['quantity'],
          'notes': i['notes'],
        }).toList(),
      };
      final res = await _api.post(ApiConfig.orders, data: data);
      final order = Map<String, dynamic>.from(res.data);
      clearCart();
      state = state.copyWith(isLoading: false, currentOrder: order);
      return order;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<void> loadOrders({String? status, String? date}) async {
    state = state.copyWith(isLoading: true);
    try {
      final params = <String, dynamic>{};
      if (status != null) params['status'] = status;
      if (date != null) params['date'] = date;
      final res = await _api.get(ApiConfig.orders, queryParameters: params);
      final data = res.data is Map ? res.data['data'] : res.data;
      state = state.copyWith(orders: List<Map<String, dynamic>>.from(data), isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadActiveOrders() async {
    try {
      final res = await _api.get(ApiConfig.activeOrders);
      state = state.copyWith(activeOrders: List<Map<String, dynamic>>.from(res.data));
    } catch (_) {}
  }

  Future<void> updateStatus(int orderId, String status) async {
    try {
      await _api.put('${ApiConfig.orders}/$orderId/status', data: {'status': status});
      await loadActiveOrders();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => loadActiveOrders());
    loadActiveOrders();
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

final orderProvider = StateNotifierProvider<OrderNotifier, OrderState>((ref) {
  return OrderNotifier(ref.watch(apiClientProvider));
});
