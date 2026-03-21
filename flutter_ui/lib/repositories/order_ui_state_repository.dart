import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/local_database.dart';

class OrderUiState {
  final List<Map<String, dynamic>> cartItems;
  final int? selectedTableId;
  final String? statusFilter;
  final String? selectedDate;

  const OrderUiState({
    this.cartItems = const [],
    this.selectedTableId,
    this.statusFilter,
    this.selectedDate,
  });

  OrderUiState copyWith({
    List<Map<String, dynamic>>? cartItems,
    int? selectedTableId,
    bool clearSelectedTable = false,
    String? statusFilter,
    bool clearStatusFilter = false,
    String? selectedDate,
    bool clearSelectedDate = false,
  }) {
    return OrderUiState(
      cartItems: cartItems ?? this.cartItems,
      selectedTableId: clearSelectedTable ? null : (selectedTableId ?? this.selectedTableId),
      statusFilter: clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      selectedDate: clearSelectedDate ? null : (selectedDate ?? this.selectedDate),
    );
  }

  factory OrderUiState.fromJson(Map<String, dynamic> json) {
    final rawCart = json['cartItems'] as List? ?? const [];
    final cart = rawCart
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    return OrderUiState(
      cartItems: cart,
      selectedTableId: json['selectedTableId'] is num ? (json['selectedTableId'] as num).toInt() : null,
      statusFilter: json['statusFilter'] as String?,
      selectedDate: json['selectedDate'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cartItems': cartItems,
      'selectedTableId': selectedTableId,
      'statusFilter': statusFilter,
      'selectedDate': selectedDate,
    };
  }
}

class OrderUiStateRepository {
  OrderUiStateRepository(this._db);

  final LocalDatabase _db;

  static const String _table = 'app_settings';
  static const String _key = 'order_ui_state';

  Future<OrderUiState?> load() async {
    final rows = await _db.queryWhere(
      _table,
      where: 'key = ?',
      whereArgs: [_key],
    );
    if (rows.isEmpty) return null;
    final raw = rows.first['value'];
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) {
      return OrderUiState.fromJson(raw);
    }
    if (raw is Map) {
      return OrderUiState.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }

  Future<void> save(OrderUiState state) async {
    await _db.upsert(_table, {
      'key': _key,
      'value': state.toJson(),
    });
  }

  Future<void> clear() async {
    await _db.upsert(_table, {
      'key': _key,
      'value': null,
    });
  }
}

final orderUiStateRepositoryProvider = Provider<OrderUiStateRepository>((ref) {
  return OrderUiStateRepository(ref.watch(localDatabaseProvider));
});

