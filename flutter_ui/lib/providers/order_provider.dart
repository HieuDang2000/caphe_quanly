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
    bool clearCurrentOrder = false,
    bool? isLoading,
    String? error,
  }) {
    return OrderState(
      orders: orders ?? this.orders,
      activeOrders: activeOrders ?? this.activeOrders,
      currentOrder: clearCurrentOrder ? null : (currentOrder ?? this.currentOrder),
      cartItems: cartItems ?? this.cartItems,
      selectedTableId: clearSelectedTable ? null : (selectedTableId ?? this.selectedTableId),
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  static bool _optionsMatch(List<dynamic>? a, List<dynamic>? b) {
    final aa = (a ?? []).map((e) => Formatters.toNum(e is Map ? e['id'] : e).toInt()).where((id) => id > 0).toList()..sort();
    final bb = (b ?? []).map((e) => Formatters.toNum(e is Map ? e['id'] : e).toInt()).where((id) => id > 0).toList()..sort();
    if (aa.length != bb.length) return false;
    for (var i = 0; i < aa.length; i++) if (aa[i] != bb[i]) return false;
    return true;
  }

  static bool _notesMatch(String? a, String? b) {
    return (a ?? '').trim() == (b ?? '').trim();
  }

  static int _findCartIndex(List<Map<String, dynamic>> cart, int menuItemId, List<Map<String, dynamic>>? options, String? notes) {
    final optList = options ?? [];
    final noteNorm = (notes ?? '').trim();
    for (var i = 0; i < cart.length; i++) {
      if (cart[i]['menu_item_id'] != menuItemId) continue;
      if (!_optionsMatch(cart[i]['options'] as List?, optList)) continue;
      if (!_notesMatch(cart[i]['notes'] as String?, noteNorm.isEmpty ? null : noteNorm)) continue;
      return i;
    }
    return -1;
  }

  double get cartTotal => cartItems.fold(0, (sum, item) {
    final base = Formatters.toNum(item['price']);
    final opts = item['options'] as List? ?? [];
    final extra = opts.fold<double>(0, (s, o) => s + Formatters.toNum(o is Map ? o['extra_price'] : 0));
    return sum + (base + extra) * Formatters.toNum(item['quantity']);
  });
}

class OrderNotifier extends StateNotifier<OrderState> {
  final ApiClient _api;
  Timer? _pollTimer;

  OrderNotifier(this._api) : super(const OrderState());

  void selectTable(int? tableId) {
    state = state.copyWith(
      selectedTableId: tableId,
      clearSelectedTable: tableId == null,
      clearCurrentOrder: tableId != null,
    );
    if (tableId != null) {
      loadTableActiveOrder(tableId);
    }
  }

  void addToCart(Map<String, dynamic> menuItem, {String? notes, int quantity = 1, List<Map<String, dynamic>>? options}) {
    final opts = options ?? [];
    final existing = OrderState._findCartIndex(state.cartItems, menuItem['id'], opts, notes);
    if (existing >= 0) {
      final updated = List<Map<String, dynamic>>.from(state.cartItems);
      final newQty = Formatters.toNum(updated[existing]['quantity']).toInt() + quantity;
      updated[existing] = {...updated[existing], 'quantity': newQty, if (notes != null) 'notes': notes};
      state = state.copyWith(cartItems: updated);
    } else {
      state = state.copyWith(cartItems: [
        ...state.cartItems,
        {
          'menu_item_id': menuItem['id'],
          'name': menuItem['name'],
          'price': Formatters.toNum(menuItem['price']),
          'quantity': quantity,
          'notes': notes,
          'options': opts,
        },
      ]);
    }
  }

  void removeFromCart(int menuItemId, {List<Map<String, dynamic>>? options, String? notes}) {
    final idx = OrderState._findCartIndex(state.cartItems, menuItemId, options, notes);
    if (idx < 0) return;
    final updated = List<Map<String, dynamic>>.from(state.cartItems)..removeAt(idx);
    state = state.copyWith(cartItems: updated);
  }

  void updateCartQuantity(int menuItemId, int quantity, {List<Map<String, dynamic>>? options, String? notes}) {
    if (quantity <= 0) {
      removeFromCart(menuItemId, options: options, notes: notes);
      return;
    }
    final idx = OrderState._findCartIndex(state.cartItems, menuItemId, options, notes);
    if (idx < 0) return;
    final updated = List<Map<String, dynamic>>.from(state.cartItems);
    updated[idx] = {...updated[idx], 'quantity': quantity};
    state = state.copyWith(cartItems: updated);
  }

  void updateCartItemNote(int menuItemId, String? note, {List<Map<String, dynamic>>? options, String? notes}) {
    final idx = OrderState._findCartIndex(state.cartItems, menuItemId, options, notes);
    if (idx < 0) return;
    final updated = List<Map<String, dynamic>>.from(state.cartItems);
    updated[idx] = {...updated[idx], 'notes': note};
    state = state.copyWith(cartItems: updated);
  }

  void updateCartItemOptions(int menuItemId, List<Map<String, dynamic>>? options, {List<Map<String, dynamic>>? currentOptions, String? currentNotes}) {
    final idx = OrderState._findCartIndex(state.cartItems, menuItemId, currentOptions, currentNotes);
    if (idx < 0) return;
    final updated = List<Map<String, dynamic>>.from(state.cartItems);
    updated[idx] = {...updated[idx], 'options': options ?? []};
    state = state.copyWith(cartItems: updated);
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
        'items': state.cartItems.map((i) {
          final opts = i['options'] as List?;
          return {
            'menu_item_id': i['menu_item_id'],
            'quantity': i['quantity'],
            'notes': i['notes'],
            'options': opts?.map((o) => {
              'id': (o as Map)['id'],
              'name': o['name'],
              'extra_price': o['extra_price'],
            }).toList() ?? [],
          };
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
    if (!mounted) return;
    state = state.copyWith(isLoading: true);
    try {
      final params = <String, dynamic>{};
      if (status != null) params['status'] = status;
      if (date != null) params['date'] = date;
      final res = await _api.get(ApiConfig.orders, queryParameters: params);
      if (!mounted) return;
      final data = res.data is Map ? res.data['data'] : res.data;
      state = state.copyWith(orders: List<Map<String, dynamic>>.from(data), isLoading: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadActiveOrders() async {
    try {
      final res = await _api.get(ApiConfig.activeOrders);
      if (!mounted) return;
      state = state.copyWith(activeOrders: List<Map<String, dynamic>>.from(res.data));
    } catch (_) {}
  }

  Future<void> loadTableActiveOrder(int tableId) async {
    try {
      final res = await _api.get('${ApiConfig.orders}/table/$tableId');
      final list = res.data is List
          ? List<Map<String, dynamic>>.from(res.data)
          : <Map<String, dynamic>>[];
      Map<String, dynamic>? order;
      if (list.isNotEmpty) {
        order = Map<String, dynamic>.from(list.first);
      }
      state = state.copyWith(
        currentOrder: order,
        selectedTableId: tableId,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Xóa đơn hiện tại khỏi state (reset cart bar sau thanh toán toàn bộ).
  void clearCurrentOrder() {
    state = state.copyWith(clearCurrentOrder: true);
  }

  /// Load đơn theo ID và cập nhật currentOrder nếu đúng bàn đang chọn (dùng sau thanh toán một phần).
  Future<void> loadOrderById(int orderId) async {
    try {
      final res = await _api.get('${ApiConfig.orders}/$orderId');
      final order = Map<String, dynamic>.from(res.data);
      final tableId = Formatters.toNum(order['table_id']).toInt();
      if (state.selectedTableId == tableId) {
        state = state.copyWith(currentOrder: order, selectedTableId: tableId);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<Map<String, dynamic>?> saveTableOrderItems(
    int tableId,
    List<Map<String, dynamic>> items, {
    String? notes,
    int? customerId,
  }) async {
    if (items.isEmpty) return null;
    state = state.copyWith(isLoading: true);
    try {
      final payloadItems = items.map((i) {
        final opts = (i['options'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
        return {
          'menu_item_id': i['menu_item_id'],
          'quantity': i['quantity'],
          'notes': i['notes'],
          'options': opts
              .map((o) => {
                    'id': o['id'],
                    'name': o['name'],
                    'extra_price': o['extra_price'],
                  })
              .toList(),
        };
      }).toList();

      final current = state.currentOrder;
      final orderBelongsToTable = current != null &&
          Formatters.toNum(current['table_id']).toInt() == tableId;
      final res = orderBelongsToTable
          ? await _api.put(
              '${ApiConfig.orders}/${current['id']}',
              data: {
                'items': payloadItems,
                if (notes != null) 'notes': notes,
                if (customerId != null) 'customer_id': customerId,
              },
            )
          : await _api.post(
              ApiConfig.orders,
              data: {
                'table_id': tableId,
                'customer_id': customerId,
                'notes': notes,
                'items': payloadItems,
              },
            );

      final order = Map<String, dynamic>.from(res.data);
      state = state.copyWith(
        isLoading: false,
        currentOrder: order,
        selectedTableId: tableId,
      );
      return order;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<void> updateStatus(int orderId, String status, {String? statusFilter, String? date}) async {
    try {
      await _api.put('${ApiConfig.orders}/$orderId/status', data: {'status': status});
      await loadActiveOrders();
      await loadOrders(status: statusFilter, date: date);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> payItems(int orderId, List<int> itemIds, {String? statusFilter, String? date}) async {
    try {
      await _api.put('${ApiConfig.orders}/$orderId/pay-items', data: {
        'item_ids': itemIds,
      });
      await loadActiveOrders();
      await loadOrders(status: statusFilter, date: date);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) loadActiveOrders();
    });
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
