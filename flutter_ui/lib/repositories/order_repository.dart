import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/database/local_database.dart';

class OrderRepository {
  final LocalDatabase _db;

  OrderRepository(this._db);

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _appendHistory(String history, String entry) {
    if (entry.isEmpty) return history;
    if (history.isEmpty) return entry;
    return '$history;$entry';
  }

  static String _generateOrderNumber() {
    final now = DateTime.now();
    String pad2(int n) => n.toString().padLeft(2, '0');
    final date = '${now.year}${pad2(now.month)}${pad2(now.day)}';
    final time = '${pad2(now.hour)}${pad2(now.minute)}${pad2(now.second)}';
    return 'ORD-$date-$time';
  }

  static List<String> _vietnamDateToUtcBounds(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length != 3) return [];
    final y = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 1;
    final d = int.tryParse(parts[2]) ?? 1;
    final startUtc = DateTime.utc(y, m, d).subtract(const Duration(hours: 7));
    final endUtc = startUtc.add(const Duration(days: 1));
    return [startUtc.toIso8601String(), endUtc.toIso8601String()];
  }

  Future<int?> _currentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_id');
  }

  // ---------------------------------------------------------------------------
  // Read – orders list
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getOrders({
    String? status,
    String? date,
    bool? discrepancy,
    bool? deletedItem,
    bool forceRefresh = false,
  }) async {
    final local = await _queryLocalOrders(
        status: status, date: date, discrepancy: discrepancy, deletedItem: deletedItem);
    return Future.wait(local.map(_attachItems));
  }

  Future<List<Map<String, dynamic>>> _queryLocalOrders({
    String? status,
    String? date,
    bool? discrepancy,
    bool? deletedItem,
  }) async {
    String? where;
    List<Object?> whereArgs = [];
    if (status != null) {
      where = 'status = ?';
      whereArgs.add(status);
    }
    if (date != null) {
      final bounds = _vietnamDateToUtcBounds(date);
      if (bounds.length == 2) {
        where = where != null
            ? '$where AND created_at >= ? AND created_at < ?'
            : 'created_at >= ? AND created_at < ?';
        whereArgs.addAll(bounds);
      }
    }
    if (discrepancy == true) {
      // Chỉ so sánh các đơn đã có highest_total > 0
      const cond =
          'highest_total IS NOT NULL AND highest_total != 0 AND (COALESCE(total_all, 0) - highest_total) != 0';
      where = where != null ? '$where AND $cond' : cond;
    }
    if (deletedItem == true) {
      const cond = 'is_deleted_item = 1';
      where = where != null ? '$where AND $cond' : cond;
    }
    if (where != null) {
      return _db.queryWhere('orders',
          where: where, whereArgs: whereArgs, orderBy: 'id DESC');
    }
    return _db.queryAll('orders', orderBy: 'id DESC');
  }

  // ---------------------------------------------------------------------------
  // Read – active orders / active tables
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> _findActiveOrderForTable(int tableId) async {
    final list = await _db.queryWhere(
      'orders',
      where: "table_id = ? AND status IN ('pending','in_progress')",
      whereArgs: [tableId],
      orderBy: 'created_at DESC',
    );
    if (list.isEmpty) return null;
    return list.first;
  }

  Future<List<Map<String, dynamic>>> getActiveOrderTables({bool forceRefresh = false}) async {
    final local = await _db.queryWhere('orders',
        where: "status IN ('pending','in_progress')",
        whereArgs: [],
        orderBy: 'id DESC');
    return local;
  }

  // ---------------------------------------------------------------------------
  // Read – single order / table orders
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> getOrderById(int id, {bool forceRefresh = false}) async {
    final local = await _db.queryById('orders', id);
    if (local == null) return null;
    return _attachItems(local);
  }

  Future<List<Map<String, dynamic>>> getTableOrders(int tableId) async {
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

  // ---------------------------------------------------------------------------
  // Write – Create
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> data) async {
    final now = DateTime.now().toIso8601String();
    final orderNumber = _generateOrderNumber();
    final userId = await _currentUserId();

    final rawItems = data['items'] as List? ?? [];
    double subtotal = 0;
    final orderItemsData = <Map<String, dynamic>>[];

    for (final raw in rawItems) {
      final menuItemId = raw['menu_item_id'];
      if (menuItemId == null) continue;
      final qty = (raw['quantity'] as num?)?.toInt() ?? 1;
      final notes = raw['notes'];
      final options = raw['options'] as List? ?? [];

      final menuItem = await _db.queryById('menu_items', menuItemId as int);
      if (menuItem == null) continue;

      double unitPrice = (menuItem['price'] as num?)?.toDouble() ?? 0;
      for (final opt in options) {
        if (opt is Map) unitPrice += ((opt['extra_price'] as num?)?.toDouble() ?? 0);
      }
      final itemSubtotal = unitPrice * qty;
      subtotal += itemSubtotal;

      orderItemsData.add({
        'menu_item_id': menuItemId,
        'quantity': qty,
        'unit_price': unitPrice,
        'subtotal': itemSubtotal,
        'notes': notes,
        'options': options,
        'is_paid': false,
        'created_at': now,
        'updated_at': now,
      });
    }

    final discount = (data['discount'] as num?)?.toDouble() ?? 0.0;
    final total = subtotal - discount;

    final orderData = {
      'order_number': orderNumber,
      'user_id': userId,
      'customer_id': data['customer_id'],
      'table_id': data['table_id'],
      'status': 'pending',
      'subtotal': subtotal,
      'tax': 0.0,
      'discount': discount,
      'total': total < 0 ? 0.0 : total,
      'total_all': subtotal,
      'notes': data['notes'],
      'order_history': 'Tạo đơn hàng',
      'is_deleted_item': false,
      'created_at': now,
      'updated_at': now,
    };

    await _db.upsert('orders', orderData);

    final db = await _db.database;
    final rows = await db.query('orders',
        where: 'order_number = ?', whereArgs: [orderNumber], limit: 1);
    if (rows.isEmpty) throw Exception('Lỗi tạo đơn hàng');

    final orderId = rows.first['id'] as int;
    final itemsWithId = orderItemsData
        .map((item) => {...item, 'order_id': orderId})
        .toList();

    if (itemsWithId.isNotEmpty) {
      await _db.upsertBatch('order_items', itemsWithId);
    }

    final order = await _db.queryById('orders', orderId);
    return await _attachItems(order!);
  }

  // ---------------------------------------------------------------------------
  // Write – Update
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> updateOrder(int id, Map<String, dynamic> data) async {
    final existing = await _db.queryById('orders', id);
    if (existing == null) throw Exception('Không tìm thấy đơn hàng #$id');

    final now = DateTime.now().toIso8601String();
    final rawItems = data['items'];

    Map<int, int> oldCounts = {};
    if (rawItems is List) {
      // Đếm tổng số lượng các món chưa thanh toán hiện tại
      final unpaidItems = await _db.queryWhere(
        'order_items',
        where: 'order_id = ? AND is_paid = 0',
        whereArgs: [id],
      );
      for (final it in unpaidItems) {
        final mid = it['menu_item_id'] as int?;
        final qty = (it['quantity'] as num?)?.toInt() ?? 0;
        if (mid != null && qty > 0) {
          oldCounts[mid] = (oldCounts[mid] ?? 0) + qty;
        }
      }
    }

    if (rawItems is List) {
      final db = await _db.database;
      // Remove unpaid items only
      await db.delete(
        'order_items',
        where: 'order_id = ? AND is_paid = 0',
        whereArgs: [id],
      );

      final Map<int, int> newCounts = {};

      for (final raw in rawItems) {
        final menuItemId = raw['menu_item_id'];
        if (menuItemId == null) continue;
        final mid = menuItemId as int;
        final qty = (raw['quantity'] as num?)?.toInt() ?? 1;
        final options = raw['options'] as List? ?? [];

        final menuItem = await _db.queryById('menu_items', mid);
        if (menuItem == null) continue;

        double unitPrice = (menuItem['price'] as num?)?.toDouble() ?? 0;
        for (final opt in options) {
          if (opt is Map) {
            unitPrice += ((opt['extra_price'] as num?)?.toDouble() ?? 0);
          }
        }
        final itemSubtotal = unitPrice * qty;

        await _db.upsert('order_items', {
          'order_id': id,
          'menu_item_id': mid,
          'quantity': qty,
          'unit_price': unitPrice,
          'subtotal': itemSubtotal,
          'notes': raw['notes'],
          'options': options,
          'is_paid': false,
          'created_at': now,
          'updated_at': now,
        });

        if (qty > 0) {
          newCounts[mid] = (newCounts[mid] ?? 0) + qty;
        }
      }

      await _recalculate(id);

      // Tính diff để ghi history: Thêm/Xóa/Sửa món
      final allIds = <int>{...oldCounts.keys, ...newCounts.keys}.toList();
      final removedParts = <String>[];
      final addedParts = <String>[];

      // Lấy tên món theo id
      final Map<int, String> namesById = {};
      for (final mid in allIds) {
        final row = await _db.queryById('menu_items', mid);
        if (row != null) {
          namesById[mid] = (row['name'] as String?) ?? 'Món #$mid';
        } else {
          namesById[mid] = 'Món #$mid';
        }
      }

      for (final mid in allIds) {
        final oldQty = oldCounts[mid] ?? 0;
        final newQty = newCounts[mid] ?? 0;
        final name = namesById[mid] ?? 'Món #$mid';
        if (oldQty > newQty) {
          removedParts.add('$name x${oldQty - newQty}');
        }
        if (newQty > oldQty) {
          addedParts.add('$name x${newQty - oldQty}');
        }
      }

      final orderAfter = await _db.queryById('orders', id);
      if (orderAfter != null) {
        String history = (orderAfter['order_history'] as String? ?? '');
        bool deletedItem = orderAfter['is_deleted_item'] == true;

        if (removedParts.isNotEmpty) {
          history = _appendHistory(history, 'Xóa món: ${removedParts.join(', ')}');
          deletedItem = true;
        }
        if (addedParts.isNotEmpty) {
          history = _appendHistory(history, 'Thêm món: ${addedParts.join(', ')}');
        }
        if (removedParts.isEmpty && addedParts.isEmpty) {
          history = _appendHistory(history, 'Sửa món');
        }

        await _db.upsert('orders', {
          ...orderAfter,
          'order_history': history,
          'is_deleted_item': deletedItem,
          'updated_at': now,
        });
      }
    }

    // Update other fields
    final updatedOrder = await _db.queryById('orders', id);
    if (updatedOrder != null) {
      final patch = Map<String, dynamic>.from(updatedOrder);
      if (data.containsKey('notes')) patch['notes'] = data['notes'];
      if (data.containsKey('customer_id')) patch['customer_id'] = data['customer_id'];
      patch['updated_at'] = now;
      await _db.upsert('orders', patch);
    }

    final order = await _db.queryById('orders', id);
    return await _attachItems(order!);
  }

  Future<void> updateStatus(int orderId, String status) async {
    final existing = await _db.queryById('orders', orderId);
    if (existing == null) return;
    final now = DateTime.now().toIso8601String();

    String history = (existing['order_history'] as String? ?? '');
    final oldStatus = existing['status'] as String?;
    if (status == 'paid' && oldStatus != 'paid') {
      final amount = (existing['total'] as num?)?.toDouble() ?? 0.0;
      if (amount > 0) {
        history = _appendHistory(history, 'Thanh toán toàn bộ: ${amount.toStringAsFixed(0)}');
      }
    }

    await _db.upsert('orders', {
      ...existing,
      'status': status,
      'order_history': history,
      'updated_at': now,
    });
  }

  Future<void> payItems(int orderId, List<int> itemIds) async {
    final now = DateTime.now().toIso8601String();
    for (final itemId in itemIds) {
      final item = await _db.queryById('order_items', itemId);
      if (item != null) {
        await _db.upsert('order_items', {...item, 'is_paid': true, 'updated_at': now});
      }
    }
    await _recalculate(orderId);

    final order = await _db.queryById('orders', orderId);
    if (order != null) {
      final history = (order['order_history'] as String? ?? '');
      final entry = 'Thanh toán ${itemIds.length} món';
      await _db.upsert('orders', {
        ...order,
        'is_deleted_item': false,
        'order_history': _appendHistory(history, entry),
        'updated_at': now,
      });
    }
  }

  /// Pay items with split-quantity support.
  Future<void> payItemsWithQuantities(int orderId, List<Map<String, dynamic>> items) async {
    final now = DateTime.now().toIso8601String();
    double paidAmount = 0.0;

    for (final item in items) {
      final itemId = item['id'] as int?;
      final payQty = (item['quantity'] as num?)?.toInt() ?? 1;
      if (itemId == null) continue;

      final existing = await _db.queryById('order_items', itemId);
      if (existing == null) continue;

      final totalQty = (existing['quantity'] as num?)?.toInt() ?? 1;
      final unitPrice = (existing['unit_price'] as num?)?.toDouble() ?? 0.0;

      if (payQty >= totalQty) {
        // Pay entire item
        paidAmount += unitPrice * totalQty;
        await _db.upsert('order_items', {...existing, 'is_paid': true, 'updated_at': now});
      } else {
        // Split: reduce original qty, create new paid item
        paidAmount += unitPrice * payQty;
        await _db.upsert('order_items', {
          ...existing,
          'quantity': totalQty - payQty,
          'subtotal': unitPrice * (totalQty - payQty),
          'updated_at': now,
        });
        await _db.upsert('order_items', {
          'order_id': orderId,
          'menu_item_id': existing['menu_item_id'],
          'quantity': payQty,
          'unit_price': unitPrice,
          'subtotal': unitPrice * payQty,
          'notes': existing['notes'],
          'options': existing['options'],
          'is_paid': true,
          'created_at': now,
          'updated_at': now,
        });
      }
    }

    await _recalculate(orderId);

    if (paidAmount > 0) {
      final order = await _db.queryById('orders', orderId);
      if (order != null) {
        final history = (order['order_history'] as String? ?? '');
        final entry =
            'Thanh toán một phần: ${paidAmount.toStringAsFixed(0)}';
        await _db.upsert('orders', {
          ...order,
          'order_history': _appendHistory(history, entry),
          'updated_at': now,
        });
      }
    }
  }

  Future<void> recordPrint(int orderId, double amount,
      {bool isPartial = false}) async {
    final order = await _db.queryById('orders', orderId);
    if (order == null) return;

    final currentTotal = (order['total'] as num?)?.toDouble() ?? 0.0;
    final currentHighest = (order['highest_total'] as num?)?.toDouble();
    final newHighest =
        (currentHighest == null || currentTotal > currentHighest) ? currentTotal : currentHighest;

    final history = (order['order_history'] as String? ?? '');

    String entry;
    if (isPartial) {
      // In hóa đơn một phần: dùng đúng số tiền phần vừa thanh toán.
      entry = 'In hóa đơn một phần: ${amount.toStringAsFixed(0)}';
    } else {
      // In hóa đơn full: log theo tổng còn phải thanh toán (bỏ qua item đã is_paid = true).
      final items = await _db.queryWhere(
        'order_items',
        where: 'order_id = ?',
        whereArgs: [orderId],
      );
      double remain = 0.0;
      for (final it in items) {
        if (it['is_paid'] == true) continue;
        final s = (it['subtotal'] as num?)?.toDouble() ?? 0.0;
        remain += s;
      }
      entry = 'In hóa đơn: ${remain.toStringAsFixed(0)}';
    }

    await _db.upsert('orders', {
      ...order,
      'highest_total': newHighest,
      'order_history': _appendHistory(history, entry),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> mergeTables(int sourceTableId, int targetTableId) async {
    if (sourceTableId == targetTableId) return;

    final now = DateTime.now().toIso8601String();
    final sourceOrders = await _db.queryWhere(
      'orders',
      where: "table_id = ? AND status IN ('pending','in_progress')",
      whereArgs: [sourceTableId],
      orderBy: 'created_at ASC',
    );
    if (sourceOrders.isEmpty) return;

    final targetOrder = await _findActiveOrderForTable(targetTableId);

    // Nếu bàn đích chưa có đơn pending/in_progress: chỉ chuyển table_id
    if (targetOrder == null) {
      for (final order in sourceOrders) {
        final history = (order['order_history'] as String? ?? '');
        final entry = 'Chuyển bàn';
        await _db.upsert('orders', {
          ...order,
          'table_id': targetTableId,
          'order_history': history.isEmpty ? entry : '$history;$entry',
          'updated_at': now,
        });
      }
      return;
    }

    final targetOrderId = targetOrder['id'] as int?;
    if (targetOrderId == null) return;

    // Cả hai bàn đều có đơn: gộp item vào đơn mới nhất của bàn đích
    for (final order in sourceOrders) {
      final orderId = order['id'] as int?;
      if (orderId == null || orderId == targetOrderId) continue;

      final items = await _db.queryWhere(
        'order_items',
        where: 'order_id = ?',
        whereArgs: [orderId],
      );

      for (final item in items) {
        await _db.upsert('order_items', {
          'order_id': targetOrderId,
          'menu_item_id': item['menu_item_id'],
          'quantity': item['quantity'],
          'unit_price': item['unit_price'],
          'subtotal': item['subtotal'],
          'notes': item['notes'],
          'options': item['options'],
          'is_paid': item['is_paid'] ?? false,
          'created_at': now,
          'updated_at': now,
        });
      }

      final history = (order['order_history'] as String? ?? '');
      final entry = 'Đã gộp vào bàn khác';
      await _db.upsert('orders', {
        ...order,
        'status': 'cancelled',
        'table_id': null,
        'order_history': history.isEmpty ? entry : '$history;$entry',
        'updated_at': now,
      });
    }

    // Cập nhật lịch sử + tổng tiền cho đơn đích
    final refreshedTarget = await _db.queryById('orders', targetOrderId);
    if (refreshedTarget != null) {
      final history = (refreshedTarget['order_history'] as String? ?? '');
      final entry = 'Gộp bàn';
      await _db.upsert('orders', {
        ...refreshedTarget,
        'order_history': history.isEmpty ? entry : '$history;$entry',
        'updated_at': now,
      });
      await _recalculate(targetOrderId);
    }
  }

  Future<void> moveTable(int sourceTableId, int targetTableId, {int? orderId}) async {
    final now = DateTime.now().toIso8601String();
    if (orderId != null) {
      final order = await _db.queryById('orders', orderId);
      if (order != null) {
        await _db.upsert('orders', {...order, 'table_id': targetTableId, 'updated_at': now});
      }
    } else {
      final sourceOrders = await _db.queryWhere('orders',
          where: "table_id = ? AND status IN ('pending','in_progress')",
          whereArgs: [sourceTableId]);
      for (final order in sourceOrders) {
        await _db.upsert('orders', {...order, 'table_id': targetTableId, 'updated_at': now});
      }
    }
  }

  Future<void> clearTableOrders(int tableId) async {
    final now = DateTime.now().toIso8601String();
    final orders = await _db.queryWhere('orders',
        where: "table_id = ? AND status IN ('pending','in_progress')",
        whereArgs: [tableId]);
    for (final order in orders) {
      await _db.upsert('orders', {...order, 'status': 'cancelled', 'updated_at': now});
    }
  }

  // ---------------------------------------------------------------------------
  // Recalculate totals
  // ---------------------------------------------------------------------------

  Future<void> _recalculate(int orderId) async {
    final allItems = await _db.queryWhere('order_items',
        where: 'order_id = ?', whereArgs: [orderId]);

    double subtotal = 0;
    double totalAll = 0;

    for (final item in allItems) {
      final s = (item['subtotal'] as num?)?.toDouble() ?? 0.0;
      totalAll += s;
      if (item['is_paid'] != true) subtotal += s;
    }

    final existing = await _db.queryById('orders', orderId);
    if (existing == null) return;

    final discount = (existing['discount'] as num?)?.toDouble() ?? 0.0;
    final tax = (existing['tax'] as num?)?.toDouble() ?? 0.0;
    final total = subtotal + tax - discount;

    await _db.upsert('orders', {
      ...existing,
      'subtotal': subtotal,
      'total': total < 0 ? 0.0 : total,
      'total_all': totalAll,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // ---------------------------------------------------------------------------
  // Attach items & table info
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> _attachItems(Map<String, dynamic> order) async {
    final id = order['id'];
    if (id == null) return order;

    final rawItems = await _db.queryWhere('order_items',
        where: 'order_id = ?', whereArgs: [id]);

    final items = <Map<String, dynamic>>[];
    for (final item in rawItems) {
      final menuId = item['menu_item_id'];
      Map<String, dynamic>? menu;
      if (menuId != null) {
        final menuRow = await _db.queryById('menu_items', menuId as int);
        if (menuRow != null) {
          menu = {'id': menuRow['id'], 'name': menuRow['name'], 'price': menuRow['price']};
        }
      }
      items.add({...item, if (menu != null) 'menu_item': menu});
    }

    Map<String, dynamic>? table;
    final tableId = order['table_id'];
    if (tableId != null) {
      final tableRow = await _db.queryById('layout_objects', tableId as int);
      if (tableRow != null) {
        table = {'id': tableRow['id'], 'name': tableRow['name']};
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
  return OrderRepository(ref.watch(localDatabaseProvider));
});
