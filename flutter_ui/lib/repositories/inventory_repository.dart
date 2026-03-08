import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/database/local_database.dart';

class InventoryRepository {
  final LocalDatabase _db;

  InventoryRepository(this._db);

  Future<List<Map<String, dynamic>>> getItems({bool lowStockOnly = false}) async {
    final all = await _db.queryAll('inventory_items', orderBy: 'name ASC');
    if (lowStockOnly) {
      return all.where((item) {
        final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
        final min = (item['min_quantity'] as num?)?.toDouble() ?? 0;
        return qty <= min;
      }).toList();
    }
    return all;
  }

  Future<Map<String, dynamic>?> getItemById(int id) async {
    return _db.queryById('inventory_items', id);
  }

  Future<Map<String, dynamic>> createItem(Map<String, dynamic> data) async {
    final now = DateTime.now().toIso8601String();
    await _db.upsert('inventory_items', {...data, 'created_at': now, 'updated_at': now});
    final db = await _db.database;
    final rows = await db.query('inventory_items', orderBy: 'id DESC', limit: 1);
    return Map<String, dynamic>.from(rows.first);
  }

  Future<void> updateItem(int id, Map<String, dynamic> data) async {
    final existing = await _db.queryById('inventory_items', id);
    if (existing == null) return;
    await _db.upsert('inventory_items', {
      ...existing,
      ...data,
      'id': id,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteItem(int id) async {
    await _db.deleteByIds('inventory_items', [id]);
  }

  Future<void> addTransaction({
    required int itemId,
    required String type,
    required double quantity,
    String? reason,
  }) async {
    final item = await _db.queryById('inventory_items', itemId);
    if (item == null) throw Exception('Không tìm thấy mặt hàng #$itemId');

    final now = DateTime.now().toIso8601String();
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    await _db.upsert('inventory_transactions', {
      'inventory_item_id': itemId,
      'type': type,
      'quantity': quantity,
      'reason': reason,
      'user_id': userId,
      'created_at': now,
      'updated_at': now,
    });

    final currentQty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
    double newQty;
    switch (type) {
      case 'in':
        newQty = currentQty + quantity;
        break;
      case 'out':
        newQty = currentQty - quantity;
        break;
      case 'adjust':
        newQty = quantity;
        break;
      default:
        return;
    }

    await _db.upsert('inventory_items', {
      ...item,
      'quantity': newQty < 0 ? 0.0 : newQty,
      'updated_at': now,
    });
  }

  Future<List<Map<String, dynamic>>> getTransactions(int itemId) async {
    return _db.queryWhere('inventory_transactions',
        where: 'inventory_item_id = ?', whereArgs: [itemId], orderBy: 'id DESC');
  }
}

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(ref.watch(localDatabaseProvider));
});
