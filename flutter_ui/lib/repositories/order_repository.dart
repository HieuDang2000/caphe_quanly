import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/api_config.dart';
import '../core/database/local_database.dart';
import '../core/network/api_client.dart';

class OrderRepository {
  final ApiClient _api;
  final LocalDatabase _db;

  OrderRepository(this._api, this._db);

  // ---------------------------------------------------------------------------
  // Read – orders list
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getOrders({
    String? status,
    String? date,
    bool forceRefresh = false,
  }) async {
    final local = await _queryLocalOrders(status: status, date: date);
    if (local.isNotEmpty && !forceRefresh) {
      // Fire-and-forget refresh; UI dùng dữ liệu cache ngay lập tức.
      _refreshOrders(status: status, date: date);
      return Future.wait(local.map(_attachItems));
    }
    try {
      return await _refreshOrders(status: status, date: date);
    } catch (e) {
      if (local.isNotEmpty) return Future.wait(local.map(_attachItems));
      rethrow;
    }
  }

  /// Trả về [utcStart, utcEnd] ISO string cho ngày YYYY-MM-DD theo giờ VN (UTC+7).
  static List<String> _vietnamDateToUtcBounds(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length != 3) return [];
    final y = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 1;
    final d = int.tryParse(parts[2]) ?? 1;
    // 00:00 VN = UTC cùng ngày - 7h; 24:00 VN = UTC ngày sau - 7h
    final startUtc = DateTime.utc(y, m, d).subtract(const Duration(hours: 7));
    final endUtc = startUtc.add(const Duration(days: 1));
    return [
      startUtc.toIso8601String(),
      endUtc.toIso8601String(),
    ];
  }

  Future<List<Map<String, dynamic>>> _queryLocalOrders({String? status, String? date}) async {
    String? where;
    List<Object?> whereArgs = [];
    if (status != null) {
      where = 'status = ?';
      whereArgs.add(status);
    }
    if (date != null) {
      final bounds = _vietnamDateToUtcBounds(date);
      if (bounds.length == 2) {
        if (where != null) {
          where = '$where AND created_at >= ? AND created_at < ?';
        } else {
          where = 'created_at >= ? AND created_at < ?';
        }
        whereArgs.addAll(bounds);
      }
    }
    if (where != null) {
      return _db.queryWhere('orders',
          where: where, whereArgs: whereArgs, orderBy: 'id DESC');
    }
    return _db.queryAll('orders', orderBy: 'id DESC');
  }

  Future<List<Map<String, dynamic>>> _refreshOrders({
    String? status,
    String? date,
  }) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    if (date != null) params['date'] = date;
    final res = await _api.get(ApiConfig.orders, queryParameters: params);
    final raw = res.data is Map ? res.data['data'] : res.data;
    final data = List<Map<String, dynamic>>.from(raw);
    await _cacheOrdersWithItems(data);
    await _db.setSyncTime('orders', DateTime.now());
    return data;
  }

  // ---------------------------------------------------------------------------
  // Read – active orders / active tables
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getActiveOrderTables({bool forceRefresh = false}) async {
    // Active-tables is a lightweight endpoint; always prefer API when possible.
    try {
      final res = await _api.get(ApiConfig.activeOrderTables);
      final data = List<Map<String, dynamic>>.from(res.data);
      // Cache the orders embedded in each entry
      for (final entry in data) {
        final order = entry['order'];
        if (order is Map<String, dynamic>) {
          await _cacheOrdersWithItems([order]);
        }
      }
      return data;
    } catch (e) {
      // Fallback: return active orders from local
      final local = await _db.queryWhere('orders',
          where: "status IN ('pending','in_progress')",
          whereArgs: [],
          orderBy: 'id DESC');
      return local;
    }
  }

  // ---------------------------------------------------------------------------
  // Read – single order / table order
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> getOrderById(int id, {bool forceRefresh = false}) async {
    final local = await _db.queryById('orders', id);
    if (local != null && !forceRefresh) {
      _refreshOrderById(id);
      return _attachItems(local);
    }
    try {
      return await _refreshOrderById(id);
    } catch (e) {
      if (local != null) return _attachItems(local);
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _refreshOrderById(int id) async {
    final res = await _api.get('${ApiConfig.orders}/$id');
    final order = Map<String, dynamic>.from(res.data);
    await _cacheOrdersWithItems([order]);
    return order;
  }

  Future<List<Map<String, dynamic>>> getTableOrders(int tableId) async {
    try {
      final res = await _api.get('${ApiConfig.orders}/table/$tableId');
      final data = res.data is List
          ? List<Map<String, dynamic>>.from(res.data)
          : <Map<String, dynamic>>[];
      await _cacheOrdersWithItems(data);
      return data;
    } catch (e) {
      final local = await _db.queryWhere('orders',
          where: "table_id = ? AND status IN ('pending','in_progress')",
          whereArgs: [tableId],
          orderBy: 'id DESC');
      final result = <Map<String, dynamic>>[];
      for (final o in local) {
        result.add(await _attachItems(o));
      }
      return result;
    }
  }

  // ---------------------------------------------------------------------------
  // Write operations (require online)
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> data) async {
    final res = await _api.post(ApiConfig.orders, data: data);
    final order = Map<String, dynamic>.from(res.data);
    await _cacheOrdersWithItems([order]);
    return order;
  }

  Future<Map<String, dynamic>> updateOrder(int id, Map<String, dynamic> data) async {
    final res = await _api.put('${ApiConfig.orders}/$id', data: data);
    final order = Map<String, dynamic>.from(res.data);
    await _cacheOrdersWithItems([order]);
    return order;
  }

  Future<void> updateStatus(int orderId, String status) async {
    await _api.put('${ApiConfig.orders}/$orderId/status',
        data: {'status': status});
    // Update local cache
    final existing = await _db.queryById('orders', orderId);
    if (existing != null) {
      await _db.upsert('orders', {...existing, 'status': status});
    }
  }

  Future<void> payItems(int orderId, List<int> itemIds) async {
    await _api.put('${ApiConfig.orders}/$orderId/pay-items',
        data: {'item_ids': itemIds});
    // Update local cache
    for (final itemId in itemIds) {
      final item = await _db.queryById('order_items', itemId);
      if (item != null) {
        await _db.upsert('order_items', {...item, 'is_paid': true});
      }
    }
  }

  Future<void> payItemsWithQuantities(int orderId, List<Map<String, dynamic>> items) async {
    await _api.put('${ApiConfig.orders}/$orderId/pay-items', data: {
      'items': items,
    });
  }

  Future<void> mergeTables(int sourceTableId, int targetTableId) async {
    await _api.post(
      ApiConfig.mergeTables,
      data: {
        'source_table_id': sourceTableId,
        'target_table_id': targetTableId,
      },
    );
  }

  Future<void> moveTable(
    int sourceTableId,
    int targetTableId, {
    int? orderId,
  }) async {
    await _api.post(
      ApiConfig.moveTable,
      data: {
        'source_table_id': sourceTableId,
        'target_table_id': targetTableId,
        if (orderId != null) 'order_id': orderId,
      },
    );
  }

  Future<void> clearTableOrders(int tableId) async {
    await _api.delete('${ApiConfig.orders}/table/$tableId');
  }

  // ---------------------------------------------------------------------------
  // Cache helpers
  // ---------------------------------------------------------------------------

  Future<void> _cacheOrdersWithItems(List<Map<String, dynamic>> orders) async {
    for (final order in orders) {
      await _db.upsert('orders', order);
      final orderId = order['id'];
      final items = order['items'];
      if (orderId == null || items is! List) continue;

      // Xóa toàn bộ item cũ của đơn này trước khi ghi lại payload mới từ API
      final db = await _db.database;
      await db.delete('order_items',
          where: 'order_id = ?', whereArgs: [orderId]);

      final rows = <Map<String, dynamic>>[];
      for (final raw in items) {
        if (raw is! Map<String, dynamic>) continue;
        final map = Map<String, dynamic>.from(raw);
        // Đảm bảo lưu khóa ngoại order_id
        map['order_id'] = orderId;
        rows.add(map);
      }
      if (rows.isNotEmpty) {
        await _db.upsertBatch('order_items', rows);
      }
    }
  }

  Future<Map<String, dynamic>> _attachItems(Map<String, dynamic> order) async {
    final id = order['id'];
    if (id == null) return order;

    final rawItems = await _db.queryWhere(
      'order_items',
      where: 'order_id = ?',
      whereArgs: [id],
    );

    final items = <Map<String, dynamic>>[];
    for (final item in rawItems) {
      final menuId = item['menu_item_id'];
      Map<String, dynamic>? menu;
      if (menuId != null) {
        final menuRow = await _db.queryById('menu_items', menuId as int);
        if (menuRow != null) {
          menu = {
            'id': menuRow['id'],
            'name': menuRow['name'],
            'price': menuRow['price'],
          };
        }
      }
      items.add({
        ...item,
        if (menu != null) 'menu_item': menu,
      });
    }

    Map<String, dynamic>? table;
    final tableId = order['table_id'];
    if (tableId != null) {
      final tables = await _db.queryWhere(
        'layout_objects',
        where: 'id = ?',
        whereArgs: [tableId],
      );
      if (tables.isNotEmpty) {
        final t = tables.first;
        table = {
          'id': t['id'],
          'name': t['name'],
        };
      }
    }

    return {
      ...order,
      'items': items,
      if (table != null) 'table': table,
    };
  }
}

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository(
    ref.watch(apiClientProvider),
    ref.watch(localDatabaseProvider),
  );
});
