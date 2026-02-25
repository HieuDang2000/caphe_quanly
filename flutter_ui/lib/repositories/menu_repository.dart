import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/api_config.dart';
import '../core/database/local_database.dart';
import '../core/network/api_client.dart';

class MenuRepository {
  final ApiClient _api;
  final LocalDatabase _db;

  MenuRepository(this._api, this._db);

  // ---------------------------------------------------------------------------
  // Categories
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getCategories({bool forceRefresh = false}) async {
    final local = await _db.queryAll('categories', orderBy: 'sort_order ASC');
    if (local.isNotEmpty && !forceRefresh) {
      _refreshCategories();
      return local;
    }
    try {
      return await _refreshCategories();
    } catch (e) {
      if (local.isNotEmpty) return local;
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _refreshCategories() async {
    final res = await _api.get(ApiConfig.categories);
    final data = List<Map<String, dynamic>>.from(res.data);
    await _db.upsertBatch('categories', data);
    await _db.setSyncTime('categories', DateTime.now());
    return data;
  }

  Future<bool> saveCategory(Map<String, dynamic> data, {int? id}) async {
    if (id != null) {
      await _api.put('${ApiConfig.categories}/$id', data: data);
    } else {
      await _api.post(ApiConfig.categories, data: data);
    }
    await _refreshCategories();
    return true;
  }

  Future<bool> deleteCategory(int id) async {
    await _api.delete('${ApiConfig.categories}/$id');
    await _db.deleteByIds('categories', [id]);
    return true;
  }

  // ---------------------------------------------------------------------------
  // Menu Items
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getItems({int? categoryId}) async {
    final local = categoryId != null
        ? await _db.queryWhere('menu_items',
            where: 'category_id = ?', whereArgs: [categoryId], orderBy: 'sort_order ASC')
        : await _db.queryAll('menu_items', orderBy: 'sort_order ASC');

    if (local.isNotEmpty) {
      _refreshItems(categoryId: categoryId);
      return _attachOptions(local);
    }
    try {
      final fresh = await _refreshItems(categoryId: categoryId);
      return _attachOptions(fresh);
    } catch (e) {
      if (local.isNotEmpty) return _attachOptions(local);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _refreshItems({int? categoryId}) async {
    final params = categoryId != null
        ? <String, dynamic>{'category_id': categoryId.toString()}
        : null;
    final res = await _api.get(ApiConfig.menuItems, queryParameters: params);
    final data = List<Map<String, dynamic>>.from(res.data);

    for (final item in data) {
      await _db.upsert('menu_items', item);
      final options = item['options'];
      if (options is List && options.isNotEmpty) {
        await _db.upsertBatch('menu_item_options',
            List<Map<String, dynamic>>.from(options));
      }
    }
    await _db.setSyncTime('menu_items', DateTime.now());
    return data;
  }

  Future<List<Map<String, dynamic>>> _attachOptions(
      List<Map<String, dynamic>> items) async {
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
    if (id != null) {
      await _api.put('${ApiConfig.menuItems}/$id', data: data);
    } else {
      await _api.post(ApiConfig.menuItems, data: data);
    }
    await _refreshItems();
    return true;
  }

  Future<bool> deleteItem(int id) async {
    await _api.delete('${ApiConfig.menuItems}/$id');
    await _db.deleteByIds('menu_items', [id]);
    return true;
  }

  Future<bool> uploadImage(int itemId, String filePath) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(filePath),
    });
    await _api.upload('${ApiConfig.menuItems}/$itemId/image', formData);
    await _refreshItems();
    return true;
  }
}

final menuRepositoryProvider = Provider<MenuRepository>((ref) {
  return MenuRepository(
    ref.watch(apiClientProvider),
    ref.watch(localDatabaseProvider),
  );
});
