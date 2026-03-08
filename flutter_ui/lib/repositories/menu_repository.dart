import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/local_database.dart';

class MenuRepository {
  final LocalDatabase _db;

  MenuRepository(this._db);

  // ---------------------------------------------------------------------------
  // Categories
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getCategories() async {
    return _db.queryAll('categories', orderBy: 'sort_order ASC');
  }

  Future<bool> saveCategory(Map<String, dynamic> data, {int? id}) async {
    final now = DateTime.now().toIso8601String();
    if (id != null) {
      final existing = await _db.queryById('categories', id);
      if (existing == null) return false;
      await _db.upsert('categories', {...existing, ...data, 'id': id, 'updated_at': now});
    } else {
      await _db.upsert('categories', {...data, 'is_active': true, 'sort_order': data['sort_order'] ?? 0, 'created_at': now, 'updated_at': now});
    }
    return true;
  }

  Future<bool> deleteCategory(int id) async {
    await _db.deleteByIds('categories', [id]);
    return true;
  }

  // ---------------------------------------------------------------------------
  // Menu Items
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getItems({int? categoryId}) async {
    final List<Map<String, dynamic>> items;
    if (categoryId != null) {
      items = await _db.queryWhere('menu_items',
          where: 'category_id = ?', whereArgs: [categoryId], orderBy: 'sort_order ASC');
    } else {
      items = await _db.queryAll('menu_items', orderBy: 'sort_order ASC');
    }
    return _attachOptions(items);
  }

  Future<List<Map<String, dynamic>>> _attachOptions(List<Map<String, dynamic>> items) async {
    final result = <Map<String, dynamic>>[];
    for (final item in items) {
      final id = item['id'];
      if (id == null) {
        result.add(item);
        continue;
      }
      final options = await _db.queryWhere('menu_item_options',
          where: 'menu_item_id = ?', whereArgs: [id]);
      result.add({...item, 'options': options});
    }
    return result;
  }

  Future<bool> saveItem(Map<String, dynamic> data, {int? id}) async {
    final now = DateTime.now().toIso8601String();
    final options = data['options'];

    if (id != null) {
      final existing = await _db.queryById('menu_items', id);
      if (existing == null) return false;
      await _db.upsert('menu_items', {...existing, ...data, 'id': id, 'updated_at': now});

      // Sync options: delete old ones and re-insert
      if (options is List) {
        final db = await _db.database;
        await db.delete('menu_item_options', where: 'menu_item_id = ?', whereArgs: [id]);
        for (final opt in options) {
          if (opt is Map<String, dynamic>) {
            await _db.upsert('menu_item_options', {
              ...opt,
              'menu_item_id': id,
              'created_at': now,
              'updated_at': now,
            });
          }
        }
      }
    } else {
      final itemData = Map<String, dynamic>.from(data)..remove('options');
      await _db.upsert('menu_items', {
        ...itemData,
        'is_available': true,
        'sort_order': data['sort_order'] ?? 0,
        'created_at': now,
        'updated_at': now,
      });

      // Get inserted id
      final db = await _db.database;
      final rows = await db.query('menu_items', orderBy: 'id DESC', limit: 1);
      if (rows.isNotEmpty && options is List) {
        final newId = rows.first['id'] as int;
        for (final opt in options) {
          if (opt is Map<String, dynamic>) {
            await _db.upsert('menu_item_options', {
              ...opt,
              'menu_item_id': newId,
              'created_at': now,
              'updated_at': now,
            });
          }
        }
      }
    }
    return true;
  }

  Future<bool> deleteItem(int id) async {
    await _db.deleteByIds('menu_items', [id]);
    return true;
  }
}

final menuRepositoryProvider = Provider<MenuRepository>((ref) {
  return MenuRepository(ref.watch(localDatabaseProvider));
});
